RealismExtensionsSpatialHistory = RealismExtensionsSpatialHistory or {}
local History = RealismExtensionsSpatialHistory

History.VERSION = 1

function History.new(options)
    options = options or {}
    local self = {
        cellSizeM = math.max(0.05, tonumber(options.cellSizeM) or 0.20),
        maxCells = math.max(100, math.floor(tonumber(options.maxCells) or 50000)),
        pruneBatch = math.max(10, math.floor(tonumber(options.pruneBatch) or 1000)),
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
        self:prune(math.max(0, self.maxCells - self.pruneBatch))
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

function History:clear()
    self.cells = {}
    self.count = 0
    self.touchCounter = 0
end
