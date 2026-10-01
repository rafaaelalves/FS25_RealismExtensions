RealismExtensionsTerrainResponseModel = RealismExtensionsTerrainResponseModel or {}
local Model = RealismExtensionsTerrainResponseModel

Model.VERSION = 4

Model.DEFAULTS = {
    referencePressurePa = 100000,
    pressureExponent = 0.55,

    drySusceptibilityFloor = 0.06,
    wetnessExponent = 1.65,
    mudPotentialWeight = 0.25,

    -- Mud sink is an instantaneous mobility state, not automatically a
    -- permanent terrain displacement. Only a wetness/slip-dependent fraction
    -- is transferred into persistent plastic rut geometry.
    plasticSinkStartWetness = 0.45,
    plasticSinkFullWetness = 0.90,
    plasticSinkMaxTransfer = 0.75,
    plasticSinkSlipBoost = 0.15,
    plasticSinkMaxWithSlip = 0.90,
    plasticSinkSlipStart = 0.15,
    plasticSinkSlipFull = 0.85,

    hardFreezeMultiplier = 0.02,

    -- Maximum geometric rut capacity relative to structural tire radius.
    maxRutDepthFraction = 0.36,
    minRutDepthFraction = 0.01,

    -- Janosi-Hanamoto-inspired displacement scale for shear mobilization.
    -- This is deliberately kept separate from slip-sinkage history below:
    -- shear stress can mobilize quickly while geometric excavation continues
    -- to evolve over substantially more relative wheel/soil displacement.
    longitudinalShearK = 0.18,
    lateralShearK = 0.14,

    -- High longitudinal slip is experimentally known to increase sinkage
    -- beyond static pressure-sinkage. We model that as a second, slower
    -- saturating capacity term instead of allowing shear itself to grow
    -- without bound. Characteristic displacement scales with tire radius.
    slipSinkageCharacteristicRadii = 4.0,
    slipSinkageHistoryMultiple = 6.0,
    slipSinkageMaxMultiplier = 2.50,
    maxSlipRutDepthFraction = 0.65,

    longitudinalSlipDeadband = 0.025,
    lateralSlipDeadband = 0.020,

    -- Incremental exposure weights. These are applied to physical travel /
    -- relative contact displacement, not once per update sample. This keeps
    -- rut progression approximately invariant to speed and sampling cadence.
    basePassDrive = 0.10,
    verticalPassWeight = 0.32,
    longitudinalPassWeight = 0.48,
    lateralPassWeight = 0.28,
    normalPassCharacteristicLengthFactor = 1.0,
    normalPassCharacteristicMinM = 0.10,

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

local function smoothstep01(value)
    local t = clamp(tonumber(value) or 0, 0, 1)
    return t * t * (3 - 2 * t)
end

local function computePlasticSinkTransfer(context, options)
    if context.hardFrozen == true then return 0, 0, 0 end

    local wetness = clamp(tonumber(context.physicalGroundWetness) or 0, 0, 1)
    local wetStart = clamp(tonumber(options.plasticSinkStartWetness) or 0.45, 0, 0.99)
    local wetFull = clamp(
        tonumber(options.plasticSinkFullWetness) or 0.90,
        wetStart + 0.01,
        1
    )
    local wetPlasticity = smoothstep01((wetness - wetStart) / (wetFull - wetStart))

    local slip = math.abs(tonumber(context.longitudinalSlip) or 0)
    local slipStart = clamp(tonumber(options.plasticSinkSlipStart) or 0.15, 0, 0.99)
    local slipFull = math.max(
        slipStart + 0.01,
        tonumber(options.plasticSinkSlipFull) or 0.85
    )
    local slipActivation = smoothstep01((slip - slipStart) / (slipFull - slipStart))

    local baseTransfer = wetPlasticity
        * math.max(0, tonumber(options.plasticSinkMaxTransfer) or 0.75)
    local slipBoost = wetPlasticity * slipActivation
        * math.max(0, tonumber(options.plasticSinkSlipBoost) or 0.15)

    local transfer = clamp(
        baseTransfer + slipBoost,
        0,
        tonumber(options.plasticSinkMaxWithSlip) or 0.90
    )

    return transfer, wetPlasticity, slipActivation
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
    local vehicleSpeedMps = math.abs(tonumber(context.speedKph) or 0) / 3.6
    local normalTravelDistanceM = vehicleSpeedMps * dtSeconds

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

    -- Vertical loading establishes the static rut capacity.
    local minCapacity = radius * math.max(0, options.minRutDepthFraction)
    local maxStaticCapacity = radius * math.max(
        options.minRutDepthFraction,
        options.maxRutDepthFraction
    )
    local absoluteStaticCap = tonumber(options.absoluteMaxStaticRutDepthM)
    if validPositive(absoluteStaticCap) then
        maxStaticCapacity = math.min(maxStaticCapacity, absoluteStaticCap)
    end

    local capacityFraction = clamp(
        susceptibility * pressureDrive,
        0,
        1
    )

    local staticRutCapacityM = minCapacity
        + (maxStaticCapacity - minCapacity) * capacityFraction

    -- Slip sinkage is a distinct geometric effect from rapid shear-stress
    -- mobilization. Keep a longer displacement history so a wheel spinning
    -- against an obstacle can continue excavating after ordinary shear has
    -- already saturated, while still converging to a finite depth.
    local slipSinkageK = radius
        * math.max(0.25, tonumber(options.slipSinkageCharacteristicRadii) or 4.0)
    local maxSlipHistory = slipSinkageK
        * math.max(1, tonumber(options.slipSinkageHistoryMultiple) or 6.0)
    local cumulativeSlipExcavation = clamp(
        (tonumber(history.slipExcavationDistanceM) or 0) + longIncrement,
        0,
        maxSlipHistory
    )
    local slipSinkage01 = saturateDisplacement(
        cumulativeSlipExcavation,
        slipSinkageK
    )

    -- Wetness is a useful local susceptibility proxy in the current stack but
    -- it is not a complete soil-strength model. Preserve some slip-sinkage
    -- response on dry deformable ground; hard-frozen ground remains strongly
    -- suppressed.
    local slipSoilFactor
    if context.hardFrozen == true then
        slipSoilFactor = susceptibility
    else
        slipSoilFactor = 0.35 + 0.65 * susceptibility
    end

    local maxSlipMultiplier = math.max(
        1,
        tonumber(options.slipSinkageMaxMultiplier) or 1
    )
    local slipSinkageMultiplier = 1
        + (maxSlipMultiplier - 1) * slipSinkage01 * slipSoilFactor

    local maxSlipCapacity = radius * math.max(
        options.maxRutDepthFraction,
        tonumber(options.maxSlipRutDepthFraction)
            or options.maxRutDepthFraction
    )
    local absoluteSlipCap = tonumber(options.absoluteMaxSlipRutDepthM)
    if validPositive(absoluteSlipCap) then
        maxSlipCapacity = math.min(maxSlipCapacity, absoluteSlipCap)
    end
    local slipRutCapacityM = math.min(
        maxSlipCapacity,
        staticRutCapacityM * slipSinkageMultiplier
    )

    local sinkDepthM = tonumber(context.sinkDepthM)
    local observedSinkM = validNumber(sinkDepthM) and math.max(0, sinkDepthM) or 0
    local sinkPlasticTransfer01, wetPlasticity01, sinkSlipActivation01 =
        computePlasticSinkTransfer(context, options)
    local persistentSinkM = observedSinkM * sinkPlasticTransfer01

    -- Mud owns instantaneous sink/mobility. RE owns persistent heightfield
    -- geometry. A transient radius reduction therefore informs plastic rutting
    -- but is not an automatic permanent lower bound.
    local rutCapacityM = math.max(
        staticRutCapacityM,
        slipRutCapacityM,
        persistentSinkM
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

    -- Progress is driven by incremental physical exposure, not by how often
    -- this function happens to be sampled. A slow wheel therefore does not
    -- create extra "passes" merely because it remains in the same history cell
    -- for more update ticks.
    --
    -- Normal rolling uses body travel relative to the contact-patch length.
    -- Longitudinal/lateral damage use newly accumulated relative displacement.
    -- The exponential form composes cleanly when one physical traversal is
    -- subdivided into many smaller samples.
    local footprintLengthM = tonumber(footprint.footprintLengthM)
    if not validPositive(footprintLengthM) then
        footprintLengthM = math.max(
            tonumber(options.normalPassCharacteristicMinM) or 0.10,
            radius * 0.50
        )
    end
    local normalCharacteristicM = math.max(
        tonumber(options.normalPassCharacteristicMinM) or 0.10,
        footprintLengthM
            * math.max(0.05, tonumber(options.normalPassCharacteristicLengthFactor) or 1)
    )

    local normalPassExposure = normalTravelDistanceM / normalCharacteristicM
    local longitudinalIncrementExposure = longIncrement
        / math.max(0.001, tonumber(options.longitudinalShearK) or 0.18)
    local lateralIncrementExposure = latIncrement
        / math.max(0.001, tonumber(options.lateralShearK) or 0.14)

    local verticalExposureDrive = normalPassExposure * (
        math.max(0, tonumber(options.basePassDrive) or 0)
        + math.max(0, tonumber(options.verticalPassWeight) or 0) * verticalImprint01
    )
    local longitudinalExposureDrive =
        math.max(0, tonumber(options.longitudinalPassWeight) or 0)
        * longitudinalIncrementExposure
        * susceptibility
        * math.min(1.25, pressureDrive)
    local lateralExposureDrive =
        math.max(0, tonumber(options.lateralPassWeight) or 0)
        * lateralIncrementExposure
        * susceptibility
        * math.min(1.15, pressureDrive)

    local incrementalExposure = math.max(
        0,
        verticalExposureDrive
            + longitudinalExposureDrive
            + lateralExposureDrive
    )
    local passDrive = clamp(1 - math.exp(-incrementalExposure), 0, 0.95)

    local previousRutM = clamp(
        tonumber(history.rutDepthM) or 0,
        0,
        rutCapacityM
    )

    -- Store cumulative physical exposure separately from rut depth. Depth is
    -- then reconstructed from total exposure and the current capacity instead
    -- of recursively applying one "pass" per sample. This makes equivalent
    -- travel/slip histories converge to the same result regardless of update
    -- cadence or how many intermediate samples occurred.
    local previousExposure = math.max(
        0,
        tonumber(history.deformationExposure) or 0
    )
    local deformationExposure = previousExposure + incrementalExposure
    local exposureDrive = clamp(
        1 - math.exp(-deformationExposure),
        0,
        0.999999
    )

    local modeledBaseM = persistentSinkM
    local modeledRangeM = math.max(0, rutCapacityM - modeledBaseM)
    local exposureTargetM = modeledBaseM + modeledRangeM * exposureDrive

    -- Never heal an already-written rut in history when current conditions
    -- weaken, but only persistent plastic sink becomes an immediate lower bound.
    local nextRutM = clamp(
        math.max(previousRutM, persistentSinkM, exposureTargetM),
        0,
        rutCapacityM
    )

    local sinkSeverity = clamp(
        validPositive(radius) and persistentSinkM / radius or 0,
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
        slipExcavationDistanceM = cumulativeSlipExcavation,
        deformationExposure = deformationExposure,
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

        normalTravelDistanceM = normalTravelDistanceM,
        normalPassExposure = normalPassExposure,
        longitudinalIncrementExposure = longitudinalIncrementExposure,
        lateralIncrementExposure = lateralIncrementExposure,
        incrementalExposure = incrementalExposure,

        longitudinalShearIncrementM = longIncrement,
        lateralShearIncrementM = latIncrement,
        longitudinalShearDistanceM = cumulativeLong,
        lateralShearDistanceM = cumulativeLat,

        observedSinkDepthM = observedSinkM,
        persistentSinkDepthM = persistentSinkM,
        sinkPlasticTransfer01 = sinkPlasticTransfer01,
        wetPlasticity01 = wetPlasticity01,
        sinkSlipActivation01 = sinkSlipActivation01,
        physicalGroundWetness01 = clamp(tonumber(context.physicalGroundWetness) or 0, 0, 1),
        longitudinalSlip01 = clamp(math.abs(tonumber(context.longitudinalSlip) or 0), 0, 1),
        staticRutCapacityM = staticRutCapacityM,
        slipRutCapacityM = slipRutCapacityM,
        slipSinkage01 = slipSinkage01,
        slipSinkageMultiplier = slipSinkageMultiplier,
        slipExcavationDistanceM = cumulativeSlipExcavation,
        rutCapacityM = rutCapacityM,
        previousRutDepthM = previousRutM,
        rutDepthM = nextRutM,
        rutDepthDeltaM = math.max(0, nextRutM - previousRutM),
        rutWidthM = rutWidthM,

        passDrive01 = passDrive,
        deformationExposure = deformationExposure,
        exposureDrive01 = exposureDrive,
        hardFrozen = context.hardFrozen == true,

        nextHistory = nextHistory
    }
end
