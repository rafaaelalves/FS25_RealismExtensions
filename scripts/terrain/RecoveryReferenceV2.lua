-- Surface-only reference selection for RE-owned rut recovery.
-- Does not move soil or infer initial terrain heights from stored rut depth.
-- Low confidence means NO structural target, rather than blind regrading.
RealismExtensionsRecoveryReferenceV2 = RealismExtensionsRecoveryReferenceV2 or {}
local V2 = RealismExtensionsRecoveryReferenceV2

V2.DEFAULTS = {
    maskDebtM = 0.008,
    minCleanSamples = 7,
    minPerRingForCurvatureCheck = 5,
    maxRingReferenceDriftM = 0.035,
    minAxisFraction = 0.27,
    minBoundaryInlierRatio = 0.50,
}

local function valid(v)
    return type(v) == "number" and v == v
        and v ~= math.huge and v ~= -math.huge
end

local function fit(samples, estimator)
    if #samples < 3 then return nil end
    return estimator.fitReferencePlane(samples)
end

local function coverage(samples, radius, fraction)
    local positivesX, negativesX, positivesZ, negativesZ = false,false,false,false
    local t = radius * fraction
    for _, s in ipairs(samples) do
        if s.dx > t then positivesX = true end
        if s.dx < -t then negativesX = true end
        if s.dz > t then positivesZ = true end
        if s.dz < -t then negativesZ = true end
    end
    return positivesX and negativesX and positivesZ and negativesZ
end

function V2.measure(samples, options)
    options = options or {}
    local estimator = RealismExtensionsRecoverySurfaceEstimator
    if type(estimator) ~= "table"
        or type(estimator.measure) ~= "function"
        or type(estimator.fitReferencePlane) ~= "function" then
        return nil, "ESTIMATOR_MISSING"
    end
    if type(samples) ~= "table" or #samples < 4 then
        return nil, "INSUFFICIENT_SAMPLES"
    end

    local center = samples[1]
    if center == nil or not valid(center.y) then
        return nil, "INVALID_CENTER"
    end

    local inner, outer, clean = {},{},{}
    local masked = 0
    local maskDebt = tonumber(options.maskDebtM) or V2.DEFAULTS.maskDebtM
    for i = 2, #samples do
        local s = samples[i]
        if s ~= nil and valid(s.dx) and valid(s.dz) and valid(s.y) then
            if (tonumber(s.rutDebtM) or 0) >= maskDebt then
                masked = masked + 1
            else
                clean[#clean + 1] = s
                if s.ring == "outer" then
                    outer[#outer + 1] = s
                else
                    inner[#inner + 1] = s
                end
            end
        end
    end

    local minClean = math.max(4,
        tonumber(options.minCleanSamples) or V2.DEFAULTS.minCleanSamples)
    if #clean < minClean then return nil, "NO_CLEAN_REFERENCE" end

    local innerRadius = math.max(0.1, tonumber(options.innerRadiusM) or 1.2)
    if not coverage(clean, innerRadius, V2.DEFAULTS.minAxisFraction) then
        return nil, "UNBALANCED_REFERENCE"
    end

    local minRing = tonumber(options.minPerRingForCurvatureCheck)
        or V2.DEFAULTS.minPerRingForCurvatureCheck
    local innerFit = #inner >= minRing and fit(inner, estimator) or nil
    local outerFit = #outer >= minRing and fit(outer, estimator) or nil

    -- Where only one annulus is supported by undamaged history, the remaining
    -- plane would be an uncontrolled extrapolation across natural curvature.
    if innerFit == nil or outerFit == nil then
        return nil, "INSUFFICIENT_CROSS_RADIUS"
    end
    local driftM = math.abs(innerFit.c - outerFit.c)
    local maxDrift = tonumber(options.maxRingReferenceDriftM)
        or V2.DEFAULTS.maxRingReferenceDriftM
    if driftM > maxDrift then
        return nil, "CURVED_OR_INCONSISTENT"
    end

    local measureInput = { {
        dx=0, dz=0, y=center.y, center=true, boundary=false
    } }
    for _, s in ipairs(clean) do
        measureInput[#measureInput + 1] = {
            dx=s.dx, dz=s.dz, y=s.y, boundary=true
        }
    end
    local measured,reason = estimator.measure(measureInput)
    if measured == nil then return nil, reason or "MEASURE_FAILED" end
    if (measured.boundaryInlierRatio or 0)
        < V2.DEFAULTS.minBoundaryInlierRatio then
        return nil, "UNSTABLE_PLANE"
    end

    measured.centerY = center.y
    measured.referenceV2 = true
    measured.referenceCleanCount = #clean
    measured.referenceMaskedCount = masked
    measured.referenceInnerClean = #inner
    measured.referenceOuterClean = #outer
    measured.referenceInterRingDriftM = driftM
    return measured, nil
end

return V2
