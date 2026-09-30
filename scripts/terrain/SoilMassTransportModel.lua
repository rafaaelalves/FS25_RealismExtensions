RealismExtensionsSoilMassTransportModel = RealismExtensionsSoilMassTransportModel or {}
local Model = RealismExtensionsSoilMassTransportModel

Model.VERSION = 1

Model.DEFAULTS = {
    -- Only part of apparent rut volume is transported at the surface. The
    -- remainder represents pore collapse / compaction / unresolved sub-surface
    -- rearrangement. Wet plastic soil transports more mass laterally.
    minTransportFraction = 0.08,
    wetnessTransportWeight = 0.34,
    deformabilityTransportWeight = 0.18,
    slipTransportWeight = 0.16,
    maxTransportFraction = 0.68,

    -- Berm geometry. Offsets are expressed from rut radius so berms sit just
    -- outside the contact footprint rather than rebuilding the rut itself.
    bermOffsetRadiusFactor = 1.15,
    bermRadiusFactor = 0.55,
    minBermRadiusM = 0.10,
    maxBermRadiusM = 0.42,

    -- Conservative first-pass conversion from requested volume to additive
    -- height. Runtime callback telemetry measures the real result and lets us
    -- calibrate this rather than assuming perfect circle-volume response.
    effectiveAreaFactor = 0.62,
    minRaiseHeightM = 0.0004,
    maxRaiseHeightM = 0.012,

    -- Lateral scrub can bias mass toward one side, but never remove the second
    -- berm entirely.
    lateralBiasStrength = 0.28,
    minSideShare = 0.25
}

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

local function mergeOptions(options)
    local out = {}
    for k, v in pairs(Model.DEFAULTS) do out[k] = v end
    for k, v in pairs(options or {}) do out[k] = v end
    return out
end

local function normalize2(x, z)
    x, z = tonumber(x), tonumber(z)
    if x == nil or z == nil then return nil, nil end
    local len = math.sqrt(x * x + z * z)
    if len < 0.0001 then return nil, nil end
    return x / len, z / len
end

function Model.compute(input, options)
    input = input or {}
    options = mergeOptions(options)

    local volume = math.max(0, tonumber(input.displacedVolumeM3) or 0)
    local radius = math.max(0, tonumber(input.rutRadiusM) or 0)
    if volume <= 0 or radius <= 0 then
        return { available=false, reason="NO_VOLUME" }
    end

    local dirX, dirZ = normalize2(input.travelDirX, input.travelDirZ)
    if dirX == nil then
        return { available=false, reason="NO_TRAVEL_DIRECTION" }
    end

    local wetness = clamp(tonumber(input.wetness01) or 0, 0, 1)
    local deformability = clamp(tonumber(input.deformability01) or 0, 0, 1)
    local longSlip = clamp(math.abs(tonumber(input.longitudinalSlip) or 0), 0, 1)
    local latSlip = clamp(tonumber(input.lateralSlip) or 0, -1, 1)

    local transportFraction = clamp(
        options.minTransportFraction
            + options.wetnessTransportWeight * wetness
            + options.deformabilityTransportWeight * deformability
            + options.slipTransportWeight * longSlip,
        options.minTransportFraction,
        options.maxTransportFraction
    )

    -- Very firm/non-deformable surfaces must not grow berms merely because a
    -- callback reported some numerical height displacement.
    transportFraction = transportFraction * deformability
    local transportedVolume = volume * transportFraction
    if transportedVolume <= 0.000001 then
        return { available=false, reason="NO_TRANSPORTABLE_VOLUME" }
    end

    local leftX, leftZ = -dirZ, dirX
    local bermRadius = clamp(
        radius * options.bermRadiusFactor,
        options.minBermRadiusM,
        options.maxBermRadiusM
    )
    local offset = radius + bermRadius * options.bermOffsetRadiusFactor

    local bias = clamp(latSlip * options.lateralBiasStrength, -0.25, 0.25)
    local leftShare = clamp(0.5 + bias, options.minSideShare, 1 - options.minSideShare)
    local rightShare = 1 - leftShare

    local function makeBerm(side, share)
        local targetVolume = transportedVolume * share
        local effectiveArea = math.pi * bermRadius * bermRadius
            * math.max(0.10, tonumber(options.effectiveAreaFactor) or 0.62)
        local height = clamp(
            targetVolume / math.max(0.001, effectiveArea),
            options.minRaiseHeightM,
            options.maxRaiseHeightM
        )
        return {
            x = (tonumber(input.x) or 0) + leftX * offset * side,
            z = (tonumber(input.z) or 0) + leftZ * offset * side,
            radiusM = bermRadius,
            raiseHeightM = height,
            targetVolumeM3 = targetVolume,
            side = side < 0 and "RIGHT" or "LEFT"
        }
    end

    return {
        available = true,
        transportFraction = transportFraction,
        displacedVolumeM3 = volume,
        transportedVolumeM3 = transportedVolume,
        retainedCompactionVolumeM3 = math.max(0, volume - transportedVolume),
        left = makeBerm(1, leftShare),
        right = makeBerm(-1, rightShare),
        lateralBias = bias
    }
end
