RealismExtensionsTerrainMaintenancePolicy =
    RealismExtensionsTerrainMaintenancePolicy or {}
local Policy = RealismExtensionsTerrainMaintenancePolicy

Policy.VERSION = 1

Policy.CLASS = {
    PLAYER_PRIVATE = "PLAYER_PRIVATE",
    OTHER_FARM_PRIVATE = "OTHER_FARM_PRIVATE",
    NPC_FIELD = "NPC_FIELD",
    PUBLIC_WORLD = "PUBLIC_WORLD",
    UNOWNED_BUYABLE = "UNOWNED_BUYABLE",
    UNKNOWN = "UNKNOWN"
}

Policy.MAINTAINER = {
    NONE = "NONE",
    NEIGHBOR = "NEIGHBOR",
    MUNICIPAL = "MUNICIPAL"
}

local function getLocalFarmId()
    if g_currentMission ~= nil
        and type(g_currentMission.getFarmId) == "function" then
        local ok, farmId = pcall(g_currentMission.getFarmId, g_currentMission)
        if ok and type(farmId) == "number" then return farmId end
    end
    return nil
end

local function getFieldForFarmlandId(farmlandId)
    if g_fieldManager == nil
        or type(g_fieldManager.farmlandIdFieldMapping) ~= "table" then
        return nil
    end
    return g_fieldManager.farmlandIdFieldMapping[farmlandId]
end

local function fieldIsNpcManaged(field)
    if field == nil then return false end

    if type(field.getHasOwner) == "function" then
        local ok, owned = pcall(field.getHasOwner, field)
        if ok and owned == false then return true end
    end

    -- Fallback for maps/versions where getHasOwner is not exposed. Presence
    -- in FieldManager plus an unowned farmland is intentionally not enough by
    -- itself to call arbitrary buyable land an NPC field; only explicit field
    -- objects reach this fallback.
    local farmland = field.farmland
    if farmland ~= nil and type(farmland.getNPC) == "function" then
        local ok, npc = pcall(farmland.getNPC, farmland)
        if ok and npc ~= nil then return true end
    end

    return false
end

function Policy.classifyAt(x, z, localFarmId)
    local manager = g_farmlandManager
    if manager == nil
        or type(manager.getFarmlandIdAtWorldPosition) ~= "function"
        or type(manager.getFarmlandOwner) ~= "function" then
        return {
            class = Policy.CLASS.UNKNOWN,
            maintainer = Policy.MAINTAINER.NONE
        }
    end

    local farmlandId = manager:getFarmlandIdAtWorldPosition(x, z)
    local noOwner = FarmlandManager ~= nil
        and FarmlandManager.NO_OWNER_FARM_ID or 0
    local notBuyable = FarmlandManager ~= nil
        and FarmlandManager.NOT_BUYABLE_FARM_ID or nil

    -- GIANTS may represent no valid/buyable farmland as nil or the reserved
    -- non-buyable id depending on call path/map data.
    if farmlandId == nil
        or farmlandId == noOwner
        or (notBuyable ~= nil and farmlandId == notBuyable) then
        return {
            class = Policy.CLASS.PUBLIC_WORLD,
            maintainer = Policy.MAINTAINER.MUNICIPAL,
            farmlandId = farmlandId,
            ownerFarmId = noOwner
        }
    end

    local ownerFarmId = manager:getFarmlandOwner(farmlandId)
    local farmId = localFarmId
    if farmId == nil then farmId = getLocalFarmId() end

    if ownerFarmId ~= nil and ownerFarmId ~= noOwner then
        if farmId ~= nil and ownerFarmId == farmId then
            return {
                class = Policy.CLASS.PLAYER_PRIVATE,
                maintainer = Policy.MAINTAINER.NONE,
                farmlandId = farmlandId,
                ownerFarmId = ownerFarmId
            }
        end
        return {
            class = Policy.CLASS.OTHER_FARM_PRIVATE,
            maintainer = Policy.MAINTAINER.NONE,
            farmlandId = farmlandId,
            ownerFarmId = ownerFarmId
        }
    end

    local field = getFieldForFarmlandId(farmlandId)
    if fieldIsNpcManaged(field) then
        return {
            class = Policy.CLASS.NPC_FIELD,
            maintainer = Policy.MAINTAINER.NEIGHBOR,
            farmlandId = farmlandId,
            ownerFarmId = noOwner,
            field = field
        }
    end

    -- A buyable but currently unowned forest/lot is not automatically public
    -- infrastructure. Leave it untouched until an explicit ownership/event
    -- source says otherwise.
    return {
        class = Policy.CLASS.UNOWNED_BUYABLE,
        maintainer = Policy.MAINTAINER.NONE,
        farmlandId = farmlandId,
        ownerFarmId = noOwner
    }
end

function Policy.isPassiveMaintenanceEligible(classification)
    if type(classification) ~= "table" then return false end
    return classification.maintainer == Policy.MAINTAINER.NEIGHBOR
        or classification.maintainer == Policy.MAINTAINER.MUNICIPAL
end

return Policy
