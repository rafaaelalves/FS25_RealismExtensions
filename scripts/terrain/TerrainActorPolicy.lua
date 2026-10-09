RealismExtensionsTerrainActorPolicy =
    RealismExtensionsTerrainActorPolicy or {}
local Policy = RealismExtensionsTerrainActorPolicy

Policy.VERSION = 1

Policy.KIND = {
    PLAYER = "PLAYER",
    AI_FIELD = "AI_FIELD",
    AI_GENERIC = "AI_GENERIC"
}

-- These are anti-pathology guards, not alternate vehicle physics.
-- Normal vertical/load-driven imprint is deliberately left untouched.
-- Actor identity must not change ordinary vehicle physics. During a valid
-- straight AI pass, the exact same TerrainResponse model is used as for a
-- player. Policy intervenes only in explicit navigation-pathology states.
local function safeBooleanMethod(object, name)
    if object == nil or type(object[name]) ~= "function" then return nil end
    local ok, value = pcall(object[name], object)
    if ok and type(value) == "boolean" then return value end
    return nil
end

local function resolveRoot(vehicle)
    local work = RealismExtensionsTerrainWorkContext
    if work ~= nil and type(work.getCombinationRoot) == "function" then
        local root = work.getCombinationRoot(vehicle)
        if root ~= nil then return root end
    end

    if vehicle ~= nil and type(vehicle.getRootVehicle) == "function" then
        local ok, root = pcall(vehicle.getRootVehicle, vehicle)
        if ok and root ~= nil then return root end
    end
    return vehicle
end

function Policy.classify(vehicle)
    local root = resolveRoot(vehicle)
    if root == nil then
        return {
            kind = Policy.KIND.PLAYER,
            rootVehicle = vehicle,
            aiActive = false,
            fieldWorkActive = false,
            turning = false,
            cornerCutOut = false
        }
    end

    local fieldWorkActive = safeBooleanMethod(root, "getIsFieldWorkActive")
    local aiActive = safeBooleanMethod(root, "getIsAIActive")
    local turning = safeBooleanMethod(root, "getAIFieldWorkerIsTurning")
    local cornerCutOut =
        safeBooleanMethod(root, "getAIFieldWorkerIsCornerCutOutActive")

    local fieldSpec = root.spec_aiFieldWorker
    if fieldWorkActive == nil and type(fieldSpec) == "table" then
        fieldWorkActive = fieldSpec.isActive == true
    end
    if turning == nil and type(fieldSpec) == "table" then
        turning = fieldSpec.isTurning == true
    end

    fieldWorkActive = fieldWorkActive == true
    aiActive = aiActive == true or fieldWorkActive
    turning = turning == true
    cornerCutOut = cornerCutOut == true

    local kind = Policy.KIND.PLAYER
    if fieldWorkActive then
        kind = Policy.KIND.AI_FIELD
    elseif aiActive then
        kind = Policy.KIND.AI_GENERIC
    end

    return {
        kind = kind,
        rootVehicle = root,
        aiActive = aiActive,
        fieldWorkActive = fieldWorkActive,
        turning = turning,
        cornerCutOut = cornerCutOut
    }
end

function Policy.getSuppressionReason(actor, stationaryWheelspin)
    if type(actor) ~= "table" or actor.aiActive ~= true then return nil end

    -- GIANTS explicitly marks field-course turn segments. Their shape is an AI
    -- navigation decision, not player-authored driving, so do not persistently
    -- remodel terrain while the worker is executing one.
    if actor.turning == true or actor.cornerCutOut == true then
        return "AI_TURN"
    end

    -- A blocked/stuck helper can spin in place until its drive strategy
    -- recovers. Keep upstream wheel/Mud physics alive but do not let waiting
    -- time become permanent excavation.
    if stationaryWheelspin == true then
        return "AI_STATIONARY_SPIN"
    end

    return nil
end

function Policy.getModelOverrides(actor)
    -- Reserved extension point. Deliberately nil: normal AI work uses the
    -- exact player physics model. If future runtime evidence justifies a
    -- distinction, it must be causal and state-specific rather than a generic
    -- "AI is weaker" multiplier.
    return nil
end

return Policy
