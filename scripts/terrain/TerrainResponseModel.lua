RealismExtensionsTerrainResponseModel = RealismExtensionsTerrainResponseModel or {}
local Model = RealismExtensionsTerrainResponseModel

Model.VERSION = 1

Model.DEFAULTS = {
    referencePressurePa = 100000,
    pressureExponent = 0.55,

    drySusceptibilityFloor = 0.06,
    wetnessExponent = 1.65,
    mudPotentialWeight = 0.25,

    hardFreezeMultiplier = 0.02,

    -- Maximum geometric rut capacity relative to structural tire radius.
    maxRutDepthFraction = 0.36,
    minRutDepthFraction = 0.01,

    -- Janosi-Hanamoto-inspired displacement scale. This is not a calibrated
    -- soil K parameter; it controls how quickly slip-induced deformation
    -- approaches saturation in this first clean-room model.
    longitudinalShearK = 0.18,
    lateralShearK = 0.14,

    longitudinalSlipDeadband = 0.025,
    lateralSlipDeadband = 0.020,

    basePassDrive = 0.10,
    verticalPassWeight = 0.32,
    longitudinalPassWeight = 0.48,
    lateralPassWeight = 0.28,

    lateralWidthGain = 0.35,
    sinkWidthGain = 0.18,

    maxHistoryShearMultiple = 6
}

local function validNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function validPositive(value)
    return validNumber(value) and value > 0
end

local function clamp(value, lo, hi)
    return math.max(lo, math.min(hi, value))
end

local function mergeOptions(options)
    local result = {}
    for key, value in pairs(Model.DEFAULTS) do result[key] = value end
    for key, value in pairs(options or {}) do result[key] = value end
    return result
end

local function unavailable(reason)
    return {
        available = false,
        reason = reason
    }
end

local function saturateDisplacement(distanceM, kM)
    if not validPositive(kM) then return 0 end
    local d = math.max(0, tonumber(distanceM) or 0)
    return 1 - math.exp(-d / kM)
end

local function removeDeadband(value, deadband)
    local x = math.abs(tonumber(value) or 0)
    local d = math.max(0, tonumber(deadband) or 0)
    if x <= d then return 0 end
    return x - d
end

local function computePressureDrive(footprint, options)
    local pressure = tonumber(footprint.groundPressurePa)
    local reference = tonumber(options.referencePressurePa)
    if not validPositive(pressure) or not validPositive(reference) then
        return nil
    end

    -- Sub-linear response: doubling pressure matters, but should not double
    -- geometric rut capacity by itself.
    return clamp(
        (pressure / reference) ^ math.max(0.05, options.pressureExponent),
        0.20,
        2.50
    )
end

local function computeSoilSusceptibility(context, options)
    if context.hardFrozen == true then
        return clamp(options.hardFreezeMultiplier, 0, 1), "HARD_FROZEN"
    end

    local wetness = clamp(tonumber(context.physicalGroundWetness) or 0, 0, 1)
    local dryFloor = clamp(options.drySusceptibilityFloor, 0, 1)
    local wetResponse = wetness ^ math.max(0.1, options.wetnessExponent)

    local susceptibility = dryFloor + (1 - dryFloor) * wetResponse

    -- Mud's groundMudPotential is used only as a weak terrain-state hint.
    -- It is not treated as a deformation coefficient.
    local mudPotential = tonumber(context.groundMudPotential)
    if validNumber(mudPotential) then
        local weight = clamp(options.mudPotentialWeight, 0, 1)
        local terrainFactor = (1 - weight) + weight * clamp(mudPotential, 0, 1)
        susceptibility = susceptibility * terrainFactor
    end

    return clamp(susceptibility, 0, 1), "WETNESS"
end

local function computeShearIncrement(context, dtSeconds, slip, deadband)
    local effectiveSlip = removeDeadband(slip, deadband)
    if effectiveSlip <= 0 then return 0 end

    local vehicleSpeedMps = math.abs(tonumber(context.speedKph) or 0) / 3.6
    local wheelSpeedMps = math.abs(tonumber(context.wheelSurfaceSpeedMps) or 0)

    -- Use whichever body/wheel speed can actually move the contact patch.
    -- This preserves deformation for:
    --   * spinning wheel, nearly stationary vehicle;
    --   * locked/sliding wheel, moving vehicle.
    local referenceSpeed = math.max(vehicleSpeedMps, wheelSpeedMps)
    if referenceSpeed <= 0 then return 0 end

    return referenceSpeed * math.max(0, dtSeconds) * effectiveSlip
end

function Model.compute(context, footprint, history, dtMs, options)
    if type(context) ~= "table" then
        return unavailable("wheel context unavailable")
    end
    if type(footprint) ~= "table" or footprint.available ~= true then
        return unavailable("footprint unavailable")
    end
    if context.grounded ~= true then
        return unavailable("wheel is not grounded")
    end

    local radius = tonumber(context.structuralRadiusM or footprint.structuralRadiusM)
    local supportWidth = tonumber(footprint.supportWidthM or context.supportWidthM)
    if not validPositive(radius) then
        return unavailable("structural radius unavailable")
    end
    if not validPositive(supportWidth) then
        return unavailable("support width unavailable")
    end

    options = mergeOptions(options)
    history = type(history) == "table" and history or {}

    local pressureDrive = computePressureDrive(footprint, options)
    if pressureDrive == nil then
        return unavailable("ground pressure unavailable")
    end

    local susceptibility, susceptibilitySource =
        computeSoilSusceptibility(context, options)

    local dtSeconds = math.max(0, tonumber(dtMs) or 0) / 1000

    local longIncrement = computeShearIncrement(
        context,
        dtSeconds,
        context.longitudinalSlip,
        options.longitudinalSlipDeadband
    )
    local latIncrement = computeShearIncrement(
        context,
        dtSeconds,
        context.lateralSlip,
        options.lateralSlipDeadband
    )

    local maxLongHistory = options.longitudinalShearK
        * math.max(1, options.maxHistoryShearMultiple)
    local maxLatHistory = options.lateralShearK
        * math.max(1, options.maxHistoryShearMultiple)

    local cumulativeLong = clamp(
        (tonumber(history.longitudinalShearDistanceM) or 0) + longIncrement,
        0,
        maxLongHistory
    )
    local cumulativeLat = clamp(
        (tonumber(history.lateralShearDistanceM) or 0) + latIncrement,
        0,
        maxLatHistory
    )

    local longitudinalShear01 =
        saturateDisplacement(cumulativeLong, options.longitudinalShearK)
    local lateralScrub01 =
        saturateDisplacement(cumulativeLat, options.lateralShearK)

    -- Vertical loading capacity is pressure-driven and soil-limited.
    local minCapacity = radius * math.max(0, options.minRutDepthFraction)
    local maxCapacity = radius * math.max(
        options.minRutDepthFraction,
        options.maxRutDepthFraction
    )

    local capacityFraction = clamp(
        susceptibility * pressureDrive,
        0,
        1
    )

    local rutCapacityM = minCapacity
        + (maxCapacity - minCapacity) * capacityFraction

    local sinkDepthM = tonumber(context.sinkDepthM)
    local observedSinkM = validNumber(sinkDepthM) and math.max(0, sinkDepthM) or 0

    -- If the active physics owner already says the wheel sank deeper than our
    -- current capacity estimate, geometry must never contradict that observed
    -- state. Raise capacity just enough to admit it, bounded by radius.
    rutCapacityM = clamp(
        math.max(rutCapacityM, observedSinkM),
        0,
        radius * options.maxRutDepthFraction
    )

    local verticalImprint01 = clamp(
        susceptibility * math.min(1, pressureDrive),
        0,
        1
    )

    local excavation01 = clamp(
        longitudinalShear01 * susceptibility * math.min(1.25, pressureDrive),
        0,
        1
    )

    local scrub01 = clamp(
        lateralScrub01 * susceptibility * math.min(1.15, pressureDrive),
        0,
        1
    )

    local passDrive = clamp(
        options.basePassDrive
        + options.verticalPassWeight * verticalImprint01
        + options.longitudinalPassWeight * excavation01
        + options.lateralPassWeight * scrub01,
        0,
        0.95
    )

    local previousRutM = clamp(
        tonumber(history.rutDepthM) or 0,
        0,
        rutCapacityM
    )

    -- Observed sink is an immediate lower bound. Beyond that, repeated passes
    -- approach capacity asymptotically via the remaining-depth term.
    local baseRutM = math.max(previousRutM, observedSinkM)
    local remainingM = math.max(0, rutCapacityM - baseRutM)
    local nextRutM = clamp(
        baseRutM + remainingM * passDrive,
        0,
        rutCapacityM
    )

    local sinkSeverity = clamp(
        tonumber(context.sinkSeverity)
            or (validPositive(radius) and observedSinkM / radius or 0),
        0,
        1
    )

    local rutWidthM = supportWidth * (
        1
        + options.lateralWidthGain * scrub01
        + options.sinkWidthGain * sinkSeverity
    )

    local nextHistory = {
        rutDepthM = nextRutM,
        longitudinalShearDistanceM = cumulativeLong,
        lateralShearDistanceM = cumulativeLat,
        passCount = math.max(0, tonumber(history.passCount) or 0) + 1
    }

    return {
        available = true,
        modelVersion = Model.VERSION,

        soilSusceptibility01 = susceptibility,
        susceptibilitySource = susceptibilitySource,
        pressureDrive = pressureDrive,

        verticalImprint01 = verticalImprint01,
        longitudinalExcavation01 = excavation01,
        lateralScrub01 = scrub01,

        longitudinalShearIncrementM = longIncrement,
        lateralShearIncrementM = latIncrement,
        longitudinalShearDistanceM = cumulativeLong,
        lateralShearDistanceM = cumulativeLat,

        observedSinkDepthM = observedSinkM,
        rutCapacityM = rutCapacityM,
        previousRutDepthM = previousRutM,
        rutDepthM = nextRutM,
        rutDepthDeltaM = math.max(0, nextRutM - previousRutM),
        rutWidthM = rutWidthM,

        passDrive01 = passDrive,
        hardFrozen = context.hardFrozen == true,

        nextHistory = nextHistory
    }
end
