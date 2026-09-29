RealismExtensionsTerrainPersistence = {
    FILE_NAME = "realismExtensionsTerrain.xml",
    ROOT_KEY = "realismExtensionsTerrain",
    FORMAT_VERSION = 1
}

local Persistence = RealismExtensionsTerrainPersistence

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
        if h.passCount ~= nil then xmlFile:setInt(key .. "#passCount", h.passCount) end
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
            history = {}
        }
        if cell.ix == nil or cell.iz == nil then return end

        local h = cell.history
        h.rutDepthM = xmlFile:getFloat(key .. "#rutDepthM")
        h.longitudinalShearDistanceM = xmlFile:getFloat(key .. "#longitudinalShearDistanceM")
        h.lateralShearDistanceM = xmlFile:getFloat(key .. "#lateralShearDistanceM")
        h.slipExcavationDistanceM = xmlFile:getFloat(key .. "#slipExcavationDistanceM")
        h.passCount = xmlFile:getInt(key .. "#passCount")
        snapshot.cells[#snapshot.cells + 1] = cell
    end)

    xmlFile:delete()
    local ok, reason = history:importSnapshot(snapshot)
    if not ok then return false, reason end
    return true, #snapshot.cells
end
