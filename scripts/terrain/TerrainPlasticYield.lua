-- The RE heightmap is NOT the soil-compaction model. A loaded contact
-- only earns permanent rut geometry when demand exceeds estimated bearing
-- capacity. Mud still owns transient sink/traction and SoilCompaction remains
-- the sole author of agronomic compaction.
--
-- These are deliberately conservative, tunable *game-model* envelopes (Pa),
-- not measured bearing capacities for a specific real-world soil. Never map
-- SoilCompaction's yield-loss percentage onto pressure or bulk density.
RealismExtensionsTerrainPlasticYield = RealismExtensionsTerrainPlasticYield or {}
local Yield = RealismExtensionsTerrainPlasticYield

Yield.VERSION = 1
Yield.DEFAULTS = {
    wetTransitionStart = 0.42,
    wetTransitionFull = 0.96,
    fullYieldOverload = 0.80,
    slipDeadband = 0.10,
    longitudinalShearDemand = 1.45,
    lateralSlipDeadband = 0.08,
    lateralShearDemand = 0.65,
    frozenBearingMultiplier = 8.0,
    -- Less structured freshly worked topsoil gives way earlier when wet,
    -- but is still allowed to carry normal traffic in suitable conditions.
    bearingPa = {
        FIELD_SOFT = { dry = 320000, wet = 55000 },
        FIELD = { dry = 400000, wet = 95000 },
        FIELD_FIRM = { dry = 520000, wet = 150000 },
        DIRT_WET = { dry = 650000, wet = 150000 },
        MUD = { dry = 280000, wet = 45000 },
        GRAVEL_WET = { dry = 1100000, wet = 300000 }
    }
}

local function finite(n)
    return type(n) == "number" and n == n
        and n ~= math.huge and n ~= -math.huge
end

local function clamp(n, lo, hi)
    return math.max(lo, math.min(hi, n))
end

local function smoothstep(n)
    local t = clamp(n, 0, 1)
    return t * t * (3 - 2 * t)
end

function Yield.compute(context, footprint, surface, options)
    if type(context) ~= "table" or type(footprint) ~= "table" then
        return { available = false, reason = "missing contact state" }
    end
    local pressurePa = tonumber(footprint.groundPressurePa)
    if not finite(pressurePa) or pressurePa <= 0 then
        return { available = false, reason = "missing ground pressure" }
    end
    local opt = options or {}
    local defaults = Yield.DEFAULTS
    local category = type(surface) == "table" and surface.category or "FIELD"
    local bearing = defaults.bearingPa[category] or defaults.bearingPa.FIELD
    local dry = tonumber(bearing.dry)
    local wet = tonumber(bearing.wet)
    if not finite(dry) or not finite(wet) or wet <= 0 or dry < wet then
        return { available = false, reason = "invalid bearing envelope" }
    end

    local wetness = clamp(tonumber(context.physicalGroundWetness) or 0, 0, 1)
    local wetStart = tonumber(opt.wetTransitionStart)
        or defaults.wetTransitionStart
    local wetFull = tonumber(opt.wetTransitionFull)
        or defaults.wetTransitionFull
    wetFull = math.max(wetStart + 0.01, wetFull)
    local wetFraction = smoothstep((wetness - wetStart) / (wetFull - wetStart))
    local bearingPa = dry + (wet - dry) * wetFraction
    if context.hardFrozen == true then
        bearingPa = bearingPa * defaults.frozenBearingMultiplier
    end

    local longSlip = math.abs(tonumber(context.longitudinalSlip) or 0)
    local latSlip = math.abs(tonumber(context.lateralSlip) or 0)
    -- Tire pressure is normal demand; slip adds shearing demand rather than
    -- magically making the ground more wet or multiplying its compaction.
    local shearMultiplier = 1
        + math.max(0, longSlip - defaults.slipDeadband)
            * defaults.longitudinalShearDemand
        + math.max(0, latSlip - defaults.lateralSlipDeadband)
            * defaults.lateralShearDemand
    local demandPa = pressurePa * shearMultiplier
    local overload = demandPa / math.max(1, bearingPa)
    local fullAt = math.max(0.01, tonumber(opt.fullYieldOverload)
        or defaults.fullYieldOverload)
    local plasticYield01 = smoothstep((overload - 1) / fullAt)

    return {
        available = true,
        version = Yield.VERSION,
        soilCategory = category,
        physicalGroundWetness01 = wetness,
        pressurePa = pressurePa,
        shearDemandMultiplier = shearMultiplier,
        contactDemandPa = demandPa,
        estimatedBearingPa = bearingPa,
        demandToBearingRatio = overload,
        plasticYield01 = plasticYield01,
        allowsPermanentRut = plasticYield01 > 0,
        reason = overload <= 1 and "SUPPORTED"
            or (plasticYield01 >= 1 and "FULL_PLASTIC_YIELD" or "PARTIAL_PLASTIC_YIELD"),
        -- Explicit: this result is not agronomic bulk density/compaction.
        compactionModel = "EXTERNAL_SOIL_COMPACTION"
    }
end

return Yield
