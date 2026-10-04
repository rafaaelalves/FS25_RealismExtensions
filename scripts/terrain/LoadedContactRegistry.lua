RealismExtensionsLoadedContactRegistry = RealismExtensionsLoadedContactRegistry or {}
local Registry = RealismExtensionsLoadedContactRegistry

Registry.VERSION = 1
Registry.DEFAULTS = {
    cellSizeM = 2.0,
    ttlMs = 600,
    minLoadN = 500,
    guardMarginM = 0.15
}

Registry.entriesByWheel = Registry.entriesByWheel
    or setmetatable({}, { __mode = "k" })
Registry.cells = Registry.cells or {}
Registry.maxRecordedRadiusM = Registry.maxRecordedRadiusM or 0

local function validNumber(v)
    return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function cellCoord(v)
    local s = Registry.DEFAULTS.cellSizeM
    return math.floor(v / s)
end

local function cellKey(ix, iz)
    return tostring(ix) .. ":" .. tostring(iz)
end

local function removeEntry(entry)
    if entry == nil then return end
    local bucket = Registry.cells[entry.cellKey]
    if bucket ~= nil then
        bucket[entry.wheel] = nil
        if next(bucket) == nil then
            Registry.cells[entry.cellKey] = nil
        end
    end
    if entry.wheel ~= nil then
        Registry.entriesByWheel[entry.wheel] = nil
    end
end

local function stale(entry, nowMs)
    if entry == nil then return true end
    if not validNumber(nowMs) or nowMs <= 0 then return false end
    local stamp = tonumber(entry.timestampMs)
    return stamp ~= nil and nowMs - stamp > Registry.DEFAULTS.ttlMs
end

function Registry.clear()
    Registry.entriesByWheel = setmetatable({}, { __mode = "k" })
    Registry.cells = {}
    Registry.maxRecordedRadiusM = 0
end

function Registry.remove(wheel)
    if wheel == nil then return end
    removeEntry(Registry.entriesByWheel[wheel])
end

function Registry.record(wheel, owner, x, z, radiusM, loadN, nowMs)
    if wheel == nil
        or not validNumber(x)
        or not validNumber(z)
        or not validNumber(radiusM)
        or radiusM <= 0
        or not validNumber(loadN)
        or loadN < Registry.DEFAULTS.minLoadN then
        Registry.remove(wheel)
        return false
    end

    Registry.remove(wheel)

    local ix, iz = cellCoord(x), cellCoord(z)
    local key = cellKey(ix, iz)
    local bucket = Registry.cells[key]
    if bucket == nil then
        bucket = setmetatable({}, { __mode = "k" })
        Registry.cells[key] = bucket
    end

    local entry = {
        wheel = wheel,
        owner = owner,
        x = x,
        z = z,
        radiusM = radiusM,
        loadN = loadN,
        timestampMs = tonumber(nowMs) or 0,
        cellKey = key
    }

    Registry.entriesByWheel[wheel] = entry
    bucket[wheel] = entry
    Registry.maxRecordedRadiusM = math.max(
        tonumber(Registry.maxRecordedRadiusM) or 0,
        radiusM
    )
    return true
end

function Registry.overlapsCircle(x, z, radiusM, nowMs, options)
    if not validNumber(x) or not validNumber(z)
        or not validNumber(radiusM) or radiusM < 0 then
        return false, nil
    end

    options = options or {}
    local margin = math.max(
        0,
        tonumber(options.guardMarginM) or Registry.DEFAULTS.guardMarginM
    )
    local searchRadius = radiusM + margin
        + math.max(0, tonumber(Registry.maxRecordedRadiusM) or 0)
    local minIx, maxIx = cellCoord(x - searchRadius), cellCoord(x + searchRadius)
    local minIz, maxIz = cellCoord(z - searchRadius), cellCoord(z + searchRadius)

    for ix = minIx, maxIx do
        for iz = minIz, maxIz do
            local key = cellKey(ix, iz)
            local bucket = Registry.cells[key]
            if bucket ~= nil then
                local staleWheels = nil
                for wheel, entry in pairs(bucket) do
                    if stale(entry, nowMs) then
                        staleWheels = staleWheels or {}
                        staleWheels[#staleWheels + 1] = wheel
                    elseif entry.owner ~= options.excludeOwner then
                        local combined = radiusM + entry.radiusM + margin
                        local dx, dz = entry.x - x, entry.z - z
                        if dx * dx + dz * dz <= combined * combined then
                            return true, entry
                        end
                    end
                end
                for _, wheel in ipairs(staleWheels or {}) do
                    Registry.remove(wheel)
                end
            end
        end
    end

    return false, nil
end

function Registry.getStats(nowMs)
    local count = 0
    local maxLoadN = 0
    for wheel, entry in pairs(Registry.entriesByWheel) do
        if stale(entry, nowMs) then
            Registry.remove(wheel)
        else
            count = count + 1
            maxLoadN = math.max(maxLoadN, tonumber(entry.loadN) or 0)
        end
    end
    return {
        activeContacts = count,
        maxLoadN = maxLoadN
    }
end

return Registry
