-- Read-only analysis of a completed GIANTS TARGET job.
-- This module does NOT prescribe a terrain correction or modify history.
RealismExtensionsRecoveryTargetOutcome = RealismExtensionsRecoveryTargetOutcome or {}
local Outcome = RealismExtensionsRecoveryTargetOutcome

local function finite(v)
    return type(v) == "number" and v == v
        and v ~= math.huge and v ~= -math.huge
end

function Outcome.classify(sample, options)
    sample = sample or {}
    options = options or {}
    local beforeY = tonumber(sample.beforeY)
    local afterY = tonumber(sample.afterY)
    local targetY = tonumber(sample.targetY)
    if not finite(beforeY) or not finite(afterY) or not finite(targetY) then
        return { kind = "UNMEASURED", valid = false }
    end

    local threshold = math.max(0, tonumber(options.motionThresholdM) or 0.00005)
    local epsilon = math.max(0, tonumber(options.improvementThresholdM) or 0.00015)
    local tolerance = math.max(0, tonumber(options.targetToleranceM) or 0.004)
    local deltaM = afterY - beforeY
    local errorBeforeM = beforeY - targetY
    local errorAfterM = afterY - targetY
    local gainM = math.abs(errorBeforeM) - math.abs(errorAfterM)
    local kind

    if math.abs(deltaM) <= threshold then
        kind = "CENTER_UNCHANGED"
    elseif math.abs(errorAfterM) <= tolerance then
        kind = "TARGET_REACHED"
    elseif gainM > epsilon then
        kind = "TOWARD_TARGET"
    elseif gainM < -epsilon then
        kind = "AWAY_FROM_TARGET"
    else
        kind = "MOVED_WITHOUT_GAIN"
    end

    local queuedCenterY = tonumber(sample.queuedCenterY)
    local beforeReferenceY = tonumber(sample.beforeReferenceY)
    local afterReferenceY = tonumber(sample.afterReferenceY)
    local queueDriftM = finite(queuedCenterY)
        and (beforeY - queuedCenterY) or nil
    local referenceDriftM = finite(beforeReferenceY)
        and finite(afterReferenceY)
        and (afterReferenceY - beforeReferenceY) or nil

    return {
        kind = kind,
        valid = true,
        deltaM = deltaM,
        fixedErrorBeforeM = errorBeforeM,
        fixedErrorAfterM = errorAfterM,
        fixedTargetGainM = gainM,
        queueDriftM = queueDriftM,
        referenceDriftM = referenceDriftM,
        residualBeforeM = tonumber(sample.residualBeforeM),
        residualAfterM = tonumber(sample.residualAfterM),
    }
end

return Outcome
