RealismExtensionsTerrainPersistence = {
    FILE_NAME = "realismExtensionsTerrain.xml",
    ROOT_KEY = "realismExtensionsTerrain",
    FORMAT_VERSION = 2
}

local Persistence = RealismExtensionsTerrainPersistence

Persistence.GEOMETRY_SAMPLE_LIMIT = 512
Persistence.GEOMETRY_TOLERANCE_M = 0.005
Persistence.GEOMETRY_MISMATCH_RATIO = 0.10

local function sampleTerrainHeight(x, z)
    if getTerrainHeightAtWorldPos == nil
        or g_terrainNode == nil
        or g_terrainNode == 0 then
        return nil
    end
    local ok, value = pcall(getTerrainHeightAtWorldPos, g_terrainNode, x, 0, z)
    if ok and type(value) == "number" then return value end
    return nil
end

local function getMapIdentity()
    local mission = g_currentMission
    local info = mission ~= nil and mission.missionInfo or nil
    if info == nil then return nil end
    return tostring(info.mapId or info.mapTitle or "")
end

function Persistence.getPath(missionInfo)
    if missionInfo == nil or missionInfo.savegameDirectory == nil then return nil end
    return missionInfo.savegameDirectory .. "/" .. Persistence.FILE_NAME
end

function Persistence.save(missionInfo, history)
    if g_server == nil or history == nil or missionInfo == nil
        or missionInfo.isValid ~= true then
        return false, "not authoritative save context"
    end

    local path = Persistence.getPath(missionInfo)
    if path == nil then return false, "savegame directory unavailable" end

    local snapshot = history:exportSnapshot()
    local xmlFile = XMLFile.create(
        "realismExtensionsTerrain",
        path,
        Persistence.ROOT_KEY
    )
    if xmlFile == nil then return false, "unable to create terrain history XML" end

    local root = Persistence.ROOT_KEY
    xmlFile:setInt(root .. "#formatVersion", Persistence.FORMAT_VERSION)
    xmlFile:setString(root .. "#mapId", getMapIdentity() or "")
    xmlFile:setFloat(root .. "#cellSizeM", snapshot.cellSizeM)
    xmlFile:setInt(root .. "#historyVersion", snapshot.version)

    for i, cell in ipairs(snapshot.cells) do
        local key = string.format("%s.cells.cell(%d)", root, i - 1)
        xmlFile:setInt(key .. "#ix", cell.ix)
        xmlFile:setInt(key .. "#iz", cell.iz)

        local h = cell.history or {}
        if h.rutDepthM ~= nil then xmlFile:setFloat(key .. "#rutDepthM", h.rutDepthM) end
        if h.longitudinalShearDistanceM ~= nil then xmlFile:setFloat(key .. "#longitudinalShearDistanceM", h.longitudinalShearDistanceM) end
        if h.lateralShearDistanceM ~= nil then xmlFile:setFloat(key .. "#lateralShearDistanceM", h.lateralShearDistanceM) end
        if h.slipExcavationDistanceM ~= nil then xmlFile:setFloat(key .. "#slipExcavationDistanceM", h.slipExcavationDistanceM) end
        if h.deformationExposure ~= nil then xmlFile:setFloat(key .. "#deformationExposure", h.deformationExposure) end
        if h.passCount ~= nil then xmlFile:setInt(key .. "#passCount", h.passCount) end
        if h.maintenanceAgePeriods ~= nil then
            xmlFile:setInt(
                key .. "#maintenanceAgePeriods",
                math.max(0, math.floor(h.maintenanceAgePeriods))
            )
        end

        local worldX = cell.ix * snapshot.cellSizeM
        local worldZ = cell.iz * snapshot.cellSizeM
        local surfaceHeightM = sampleTerrainHeight(worldX, worldZ)
        if surfaceHeightM ~= nil then
            xmlFile:setFloat(key .. "#surfaceHeightM", surfaceHeightM)
        end
    end

    xmlFile:save()
    xmlFile:delete()
    return true, #snapshot.cells
end

function Persistence.load(missionInfo, history)
    if g_server == nil or history == nil then
        return false, "not authoritative load context"
    end

    local path = Persistence.getPath(missionInfo)
    if path == nil or fileExists(path) ~= true then
        return false, "no persisted terrain history"
    end

    local xmlFile = XMLFile.load("realismExtensionsTerrain", path)
    if xmlFile == nil then return false, "unable to load terrain history XML" end

    local root = Persistence.ROOT_KEY
    local formatVersion = xmlFile:getInt(root .. "#formatVersion", 0)
    local mapId = xmlFile:getString(root .. "#mapId", "")
    local cellSizeM = xmlFile:getFloat(root .. "#cellSizeM", -1)
    local historyVersion = xmlFile:getInt(root .. "#historyVersion", 0)

    if formatVersion ~= Persistence.FORMAT_VERSION then
        xmlFile:delete()
        return false, "format version mismatch"
    end
    if mapId ~= (getMapIdentity() or "") then
        xmlFile:delete()
        return false, "map identity mismatch"
    end

    local snapshot = {
        version = historyVersion,
        cellSizeM = cellSizeM,
        cells = {}
    }

    xmlFile:iterate(root .. ".cells.cell", function(_, key)
        local cell = {
            ix = xmlFile:getInt(key .. "#ix"),
            iz = xmlFile:getInt(key .. "#iz"),
            history = {},
            surfaceHeightM = xmlFile:getFloat(key .. "#surfaceHeightM")
        }
        if cell.ix == nil or cell.iz == nil then return end

        local h = cell.history
        h.rutDepthM = xmlFile:getFloat(key .. "#rutDepthM")
        h.longitudinalShearDistanceM = xmlFile:getFloat(key .. "#longitudinalShearDistanceM")
        h.lateralShearDistanceM = xmlFile:getFloat(key .. "#lateralShearDistanceM")
        h.slipExcavationDistanceM = xmlFile:getFloat(key .. "#slipExcavationDistanceM")
        h.deformationExposure = xmlFile:getFloat(key .. "#deformationExposure")
        h.passCount = xmlFile:getInt(key .. "#passCount")
        h.maintenanceAgePeriods =
            xmlFile:getInt(key .. "#maintenanceAgePeriods", 0)
        snapshot.cells[#snapshot.cells + 1] = cell
    end)

    xmlFile:delete()

    -- Compare a bounded sample of persisted absolute surface heights with the
    -- terrain that GIANTS actually loaded. If the sidecar survived but the
    -- heightmap did not, restoring RE's rut/shear memory would create an
    -- impossible state ("deep rut internally, flat terrain visually").
    local sampleCount = math.min(
        #snapshot.cells,
        math.max(1, Persistence.GEOMETRY_SAMPLE_LIMIT)
    )
    local checked, mismatches, maxDelta = 0, 0, 0
    if sampleCount > 0 then
        local stride = math.max(1, math.floor(#snapshot.cells / sampleCount))
        local i = 1
        while i <= #snapshot.cells and checked < sampleCount do
            local cell = snapshot.cells[i]
            local expected = tonumber(cell.surfaceHeightM)
            if expected ~= nil then
                local x = cell.ix * snapshot.cellSizeM
                local z = cell.iz * snapshot.cellSizeM
                local actual = sampleTerrainHeight(x, z)
                if actual ~= nil then
                    checked = checked + 1
                    local delta = math.abs(actual - expected)
                    maxDelta = math.max(maxDelta, delta)
                    if delta > Persistence.GEOMETRY_TOLERANCE_M then
                        mismatches = mismatches + 1
                    end
                end
            end
            i = i + stride
        end
    end

    if checked > 0 then
        local ratio = mismatches / checked
        if ratio >= Persistence.GEOMETRY_MISMATCH_RATIO then
            return false, string.format(
                "geometry mismatch checked=%d mismatches=%d ratio=%.3f maxDelta=%.4f",
                checked,
                mismatches,
                ratio,
                maxDelta
            )
        end
    end

    local ok, reason = history:importSnapshot(snapshot)
    if not ok then return false, reason end
    return true, #snapshot.cells
end
