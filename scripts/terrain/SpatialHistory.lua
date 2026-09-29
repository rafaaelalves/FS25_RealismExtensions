RealismExtensionsSpatialHistory = RealismExtensionsSpatialHistory or {}
local History = RealismExtensionsSpatialHistory

History.VERSION = 2

function History.new(options)
    options = options or {}
    local self = {
        cellSizeM = math.max(0.05, tonumber(options.cellSizeM) or 0.20),
        maxCells = math.max(1, math.floor(tonumber(options.maxCells) or 50000)),
        pruneBatch = math.max(1, math.floor(tonumber(options.pruneBatch) or 1000)),
        cells = {},
        count = 0,
        touchCounter = 0
    }
    return setmetatable(self, { __index = History })
end

function History:getCellCoordinates(x, z)
    local s = self.cellSizeM
    return math.floor((tonumber(x) or 0) / s + 0.5),
        math.floor((tonumber(z) or 0) / s + 0.5)
end

function History:getKey(x, z)
    local ix, iz = self:getCellCoordinates(x, z)
    return tostring(ix) .. ":" .. tostring(iz), ix, iz
end

function History:get(x, z)
    local key = self:getKey(x, z)
    local cell = self.cells[key]
    if cell == nil then return nil end

    self.touchCounter = self.touchCounter + 1
    cell.touch = self.touchCounter
    return cell.history
end

local function copyHistory(value)
    local out = {}
    for k, v in pairs(value or {}) do out[k] = v end
    return out
end

function History:commit(x, z, value)
    local key, ix, iz = self:getKey(x, z)
    local cell = self.cells[key]

    self.touchCounter = self.touchCounter + 1

    if cell == nil then
        cell = { ix = ix, iz = iz }
        self.cells[key] = cell
        self.count = self.count + 1
    end

    cell.touch = self.touchCounter
    cell.history = copyHistory(value)

    if self.count > self.maxCells then
        local target = self.maxCells
        if self.maxCells >= 1000 then
            target = math.max(0, self.maxCells - self.pruneBatch)
        end
        self:prune(target)
    end

    return cell.history
end

function History:prune(targetCount)
    targetCount = math.max(0, math.floor(tonumber(targetCount) or self.maxCells))
    if self.count <= targetCount then return 0 end

    local ordered = {}
    for key, cell in pairs(self.cells) do
        ordered[#ordered + 1] = { key = key, touch = cell.touch or 0 }
    end
    table.sort(ordered, function(a, b) return a.touch < b.touch end)

    local removeCount = math.min(self.count - targetCount, #ordered)
    for i = 1, removeCount do
        self.cells[ordered[i].key] = nil
    end

    self.count = self.count - removeCount
    return removeCount
end


local PERSISTED_FIELDS = {
    "rutDepthM",
    "longitudinalShearDistanceM",
    "lateralShearDistanceM",
    "slipExcavationDistanceM",
    "passCount"
}

function History:exportSnapshot()
    local snapshot = {
        version = History.VERSION,
        cellSizeM = self.cellSizeM,
        cells = {}
    }

    for _, cell in pairs(self.cells) do
        local values = {}
        local material = false
        for _, field in ipairs(PERSISTED_FIELDS) do
            local value = cell.history ~= nil and tonumber(cell.history[field]) or nil
            if value ~= nil then
                values[field] = value
                if math.abs(value) > 0.000001 then material = true end
            end
        end

        -- The sidecar stores RE domain memory, not the heightmap itself.
        -- TerrainPersistence separately records sampled surface heights so load
        -- can reject this memory when GIANTS did not preserve matching geometry.
        -- Empty/default cells therefore do not belong in the sidecar.
        if material then
            snapshot.cells[#snapshot.cells + 1] = {
                ix = cell.ix,
                iz = cell.iz,
                history = values
            }
        end
    end

    table.sort(snapshot.cells, function(a, b)
        if a.ix == b.ix then return a.iz < b.iz end
        return a.ix < b.ix
    end)
    return snapshot
end

function History:importSnapshot(snapshot)
    if type(snapshot) ~= "table"
        or type(snapshot.cells) ~= "table"
        or tonumber(snapshot.cellSizeM) == nil then
        return false, "invalid snapshot"
    end

    -- Cell coordinates are meaningful only for the grid size that created
    -- them. Refuse silent remapping if tuning changes between releases.
    if math.abs(tonumber(snapshot.cellSizeM) - self.cellSizeM) > 0.000001 then
        return false, "cell size mismatch"
    end

    self:clear()
    for _, source in ipairs(snapshot.cells) do
        local ix, iz = tonumber(source.ix), tonumber(source.iz)
        if ix ~= nil and iz ~= nil and type(source.history) == "table" then
            local key = tostring(ix) .. ":" .. tostring(iz)
            local history = {}
            for _, field in ipairs(PERSISTED_FIELDS) do
                local value = tonumber(source.history[field])
                if value ~= nil then history[field] = value end
            end

            self.touchCounter = self.touchCounter + 1
            self.cells[key] = {
                ix = ix,
                iz = iz,
                touch = self.touchCounter,
                history = history
            }
            self.count = self.count + 1
        end
    end

    if self.count > self.maxCells then self:prune(self.maxCells) end
    return true
end

function History:clear()
    self.cells = {}
    self.count = 0
    self.touchCounter = 0
end
