RealismExtensionsSoilMassTransportModel = RealismExtensionsSoilMassTransportModel or {}
local Model = RealismExtensionsSoilMassTransportModel

Model.VERSION = 2

Model.DEFAULTS = {
    -- Only part of apparent rut volume is transported at the surface. The
    -- remainder represents pore collapse / compaction / unresolved sub-surface
    -- rearrangement. Wet plastic soil transports more mass laterally.
    -- Surface heave should be minor in merely damp/trafficable soil. Most
    -- apparent rut volume is treated as compaction/sub-surface rearrangement
    -- until the soil becomes plastic enough for visible lateral flow.
    minTransportFraction = 0.005,
    wetnessPlasticStart = 0.48,
    wetnessPlasticFull = 0.88,
    wetTransportFraction = 0.075,
    slipTransportFraction = 0.075,
    wetSlipCouplingFraction = 0.055,
    maxTransportFraction = 0.18,

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
    -- Runtime v9.0 showed GIANTS additive raising realized roughly 7-17x the
    -- naive geometric target. Apply a deliberately conservative calibration
    -- factor; callback telemetry will tell us whether this converges near 1.0.
    raiseRealizationCalibration = 0.10,
    minRaiseHeightM = 0.0004,
    maxRaiseHeightM = 0.0030,

    -- Lateral scrub can bias mass, but the berm facing the vehicle center is
    -- deliberately small to avoid building a rigid center ridge between wheel
    -- tracks. When wheel side is unknown we fall back to symmetric berms.
    lateralBiasStrength = 0.10,
    innerSideShare = 0.12,
    maxInnerSideShare = 0.18
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

    local plasticRange = math.max(
        0.01,
        (tonumber(options.wetnessPlasticFull) or 0.88)
            - (tonumber(options.wetnessPlasticStart) or 0.48)
    )
    local plasticWetness = clamp(
        (wetness - (tonumber(options.wetnessPlasticStart) or 0.48))
            / plasticRange,
        0,
        1
    )
    -- Smooth the transition so 0.50 wetness remains close to compaction while
    -- truly wet/plastic soil ramps more decisively into lateral displacement.
    plasticWetness = plasticWetness * plasticWetness * (3 - 2 * plasticWetness)

    local slipActivation = clamp((longSlip - 0.15) / 0.70, 0, 1)
    slipActivation = slipActivation * slipActivation

    local transportFraction = clamp(
        (tonumber(options.minTransportFraction) or 0.005)
            + (tonumber(options.wetTransportFraction) or 0.075) * plasticWetness
            + (tonumber(options.slipTransportFraction) or 0.075)
                * slipActivation * plasticWetness
            + (tonumber(options.wetSlipCouplingFraction) or 0.055)
                * plasticWetness * slipActivation,
        tonumber(options.minTransportFraction) or 0.005,
        tonumber(options.maxTransportFraction) or 0.18
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

    local bias = clamp(
        latSlip * (tonumber(options.lateralBiasStrength) or 0.10),
        -0.10,
        0.10
    )

    local wheelSideSign = tonumber(input.wheelSideSign)
    local leftShare, rightShare
    if wheelSideSign == -1 or wheelSideSign == 1 then
        -- side=1 is world-left relative to travel; side=-1 is world-right.
        -- Given FS local wheel X convention used by our axle diagnostics,
        -- wheelSideSign identifies the inward berm side directly:
        -- left wheel (-1) -> world-right (-1) is inward
        -- right wheel (+1) -> world-left (+1) is inward.
        local innerShare = clamp(
            (tonumber(options.innerSideShare) or 0.12) + bias * wheelSideSign,
            0.05,
            tonumber(options.maxInnerSideShare) or 0.18
        )
        if wheelSideSign == 1 then
            leftShare, rightShare = innerShare, 1 - innerShare
        else
            leftShare, rightShare = 1 - innerShare, innerShare
        end
    else
        leftShare = clamp(0.5 + bias, 0.35, 0.65)
        rightShare = 1 - leftShare
    end

    local function makeBerm(side, share)
        local targetVolume = transportedVolume * share
        local effectiveArea = math.pi * bermRadius * bermRadius
            * math.max(0.10, tonumber(options.effectiveAreaFactor) or 0.62)
        local rawHeight = targetVolume / math.max(0.001, effectiveArea)
        local height = clamp(
            rawHeight * math.max(
                0.01,
                tonumber(options.raiseRealizationCalibration) or 0.10
            ),
            options.minRaiseHeightM,
            options.maxRaiseHeightM
        )
        local isInner = wheelSideSign ~= nil and side == wheelSideSign
        return {
            x = (tonumber(input.x) or 0) + leftX * offset * side,
            z = (tonumber(input.z) or 0) + leftZ * offset * side,
            radiusM = bermRadius,
            raiseHeightM = height,
            targetVolumeM3 = targetVolume,
            side = side < 0 and "RIGHT" or "LEFT",
            role = isInner and "INNER" or "OUTER"
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
        lateralBias = bias,
        plasticWetness01 = plasticWetness,
        slipActivation01 = slipActivation
    }
end
