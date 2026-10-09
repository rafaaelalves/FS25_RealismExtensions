RealismExtensionsTerrainSurfaceResponse = RealismExtensionsTerrainSurfaceResponse or {}
local Surface = RealismExtensionsTerrainSurfaceResponse

Surface.VERSION = 2

local HARD_KEYS = { "ASPHALT", "CONCRETE", "PAVE", "COBBLE", "CEMENT" }
local GRAVEL_KEYS = { "GRAVEL", "STONE", "ROCK" }
local DIRT_KEYS = { "DIRT", "EARTH", "GROUND" }
local MUD_KEYS = { "MUD", "MIRE", "LOAM" }

local FIELD_SOFT_KEYS = { "PLOW", "PLOUGH", "CULTIV", "SEEDBED", "STUBBLE" }
local FIELD_FIRM_KEYS = { "ROLLED", "DIRECT", "SOWN", "PLANTED", "GRASS", "ROLLER" }

local cache = {
    terrain = nil,
    candidates = nil
}

local function upper(value)
    return string.upper(tostring(value or ""))
end

local function containsAny(value, keys)
    local s = upper(value)
    for _, key in ipairs(keys) do
        if string.find(s, key, 1, true) ~= nil then return true end
    end
    return false
end

local function getTerrain()
    local mission = g_currentMission
    if mission ~= nil and mission.terrainRootNode ~= nil then
        return mission.terrainRootNode
    end
    return g_terrainNode
end

local function refreshTerrainLayers(terrain)
    cache.terrain = terrain
    cache.candidates = {}

    if terrain == nil or terrain == 0
        or getTerrainNumOfLayers == nil
        or getTerrainLayerName == nil then
        return
    end

    local count = tonumber(getTerrainNumOfLayers(terrain)) or 0
    for id = 0, count - 1 do
        local name = getTerrainLayerName(terrain, id)
        if name ~= nil then
            local category = nil
            if containsAny(name, HARD_KEYS) then category = "HARD"
            elseif containsAny(name, GRAVEL_KEYS) then category = "GRAVEL"
            elseif containsAny(name, MUD_KEYS) then category = "MUD"
            elseif containsAny(name, DIRT_KEYS) then category = "DIRT"
            end

            if category ~= nil then
                cache.candidates[#cache.candidates + 1] = {
                    id = id,
                    name = tostring(name),
                    category = category
                }
            end
        end
    end
end

local function terrainCategoryAt(x, z)
    local terrain = getTerrain()
    if terrain == nil or terrain == 0 then return nil, nil, 0 end
    if cache.terrain ~= terrain or cache.candidates == nil then
        refreshTerrainLayers(terrain)
    end
    if getTerrainLayerAtWorldPos == nil then return nil, nil, 0 end

    local best, bestWeight = nil, 0
    for _, item in ipairs(cache.candidates or {}) do
        local ok, weight = pcall(
            getTerrainLayerAtWorldPos,
            terrain,
            item.id,
            x,
            0,
            z
        )
        if ok and type(weight) == "number" and weight > bestWeight then
            best, bestWeight = item, weight
        end
    end

    if best ~= nil and bestWeight > 0.05 then
        return best.category, best.name, math.min(1, bestWeight)
    end
    return nil, nil, 0
end

local function profile(category, source, deformability, staticCap, slipCap, minWetness, minSlip)
    return {
        available = true,
        category = category,
        source = source,
        deformability01 = deformability,
        maxStaticRutDepthM = staticCap,
        maxSlipRutDepthM = slipCap,
        minWetness = minWetness or 0,
        minLongitudinalSlip = minSlip or 0
    }
end

function Surface.classifyTerrainAt(x, z)
    local category, name, weight = terrainCategoryAt(x, z)
    return {
        category = category or "UNKNOWN",
        name = name,
        weight = tonumber(weight) or 0
    }
end

function Surface.isMunicipalMaintenanceSurface(x, z)
    local info = Surface.classifyTerrainAt(x, z)
    return info.category == "GRAVEL" or info.category == "DIRT", info
end

function Surface.resolve(context, x, z)
    context = context or {}
    local wetness = math.max(0, math.min(1, tonumber(context.physicalGroundWetness) or 0))
    local longSlip = math.abs(tonumber(context.longitudinalSlip) or 0)

    -- The specialist Mud provider has the strongest field-state information.
    -- Prefer it over decorative terrain paint when it says this is soil.
    if context.soilContact == true then
        local name = tostring(context.groundProfileName or "")
        if containsAny(name, FIELD_SOFT_KEYS) then
            return profile("FIELD_SOFT", "groundProfile:" .. name, 1.00, 0.08, 0.18)
        end
        if containsAny(name, FIELD_FIRM_KEYS) then
            return profile("FIELD_FIRM", "groundProfile:" .. name, 0.55, 0.04, 0.10)
        end
        return profile("FIELD", "soilContact", 0.80, 0.06, 0.15)
    end

    local category, name, weight = terrainCategoryAt(x, z)
    if category == "HARD" then
        return profile("HARD", "terrainLayer:" .. tostring(name), 0, 0, 0)
    end

    if category == "GRAVEL" then
        -- A compacted gravel road may rut in extreme saturation, but normal rain
        -- should not turn it into a ploughed field.
        if wetness < 0.75 or longSlip < 0.30 then
            return profile("GRAVEL", "terrainLayer:" .. tostring(name), 0, 0, 0, 0.75, 0.30)
        end
        return profile("GRAVEL_WET", "terrainLayer:" .. tostring(name), 0.18 * weight, 0.012, 0.035, 0.75, 0.30)
    end

    if category == "DIRT" then
        if wetness < 0.60 or longSlip < 0.22 then
            return profile("DIRT_COMPACTED", "terrainLayer:" .. tostring(name), 0, 0, 0, 0.60, 0.22)
        end
        return profile("DIRT_WET", "terrainLayer:" .. tostring(name), 0.28 * weight, 0.018, 0.050, 0.60, 0.22)
    end

    if category == "MUD" then
        return profile("MUD", "terrainLayer:" .. tostring(name), 0.90 * weight, 0.07, 0.17)
    end

    return {
        available = false,
        category = "UNKNOWN",
        source = "no-deformable-surface"
    }
end

function Surface.clear()
    cache.terrain = nil
    cache.candidates = nil
end
