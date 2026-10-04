RealismExtensionsLoadedContactRegistry = RealismExtensionsLoadedContactRegistry or {}
local Registry = RealismExtensionsLoadedContactRegistry

Registry.VERSION = 2
Registry.DEFAULTS = {
    cellSizeM = 2.0,
    ttlMs = 2500,
    minLoadN = 500,
    minContactRadiusM = 0.05,
    maxContactRadiusM = 4.0,
    guardMarginM = 0.15
}

Registry.entriesByWheel = Registry.entriesByWheel
    or setmetatable({}, { __mode = "k" })
Registry.cells = Registry.cells or {}

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

local function coveredKeys(x, z, radiusM)
    local keys = {}
    local minIx, maxIx = cellCoord(x - radiusM), cellCoord(x + radiusM)
    local minIz, maxIz = cellCoord(z - radiusM), cellCoord(z + radiusM)
    for ix = minIx, maxIx do
        for iz = minIz, maxIz do
            keys[#keys + 1] = cellKey(ix, iz)
        end
    end
    return keys
end

local function removeEntry(wheel, entry)
    if wheel == nil or entry == nil then return end
    for _, key in ipairs(entry.cellKeys or {}) do
        local bucket = Registry.cells[key]
        if bucket ~= nil then
            bucket[wheel] = nil
            if next(bucket) == nil then Registry.cells[key] = nil end
        end
    end
    Registry.entriesByWheel[wheel] = nil
end

local function stale(entry, nowMs)
    if entry == nil then return true end
    if not validNumber(nowMs) or nowMs <= 0 then return false end
    local stamp = tonumber(entry.timestampMs)
    if stamp == nil then return true end
    return nowMs - stamp > Registry.DEFAULTS.ttlMs
end

function Registry.clear()
    Registry.entriesByWheel = setmetatable({}, { __mode = "k" })
    Registry.cells = {}
end

function Registry.remove(wheel)
    if wheel == nil then return end
    removeEntry(wheel, Registry.entriesByWheel[wheel])
end

function Registry.touch(wheel, nowMs)
    local entry = wheel ~= nil and Registry.entriesByWheel[wheel] or nil
    if entry == nil then return false end
    entry.timestampMs = tonumber(nowMs) or entry.timestampMs or 0
    return true
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

    radiusM = math.max(
        Registry.DEFAULTS.minContactRadiusM,
        math.min(Registry.DEFAULTS.maxContactRadiusM, radiusM)
    )

    Registry.remove(wheel)

    local keys = coveredKeys(x, z, radiusM)
    local entry = {
        owner = owner,
        x = x,
        z = z,
        radiusM = radiusM,
        loadN = loadN,
        timestampMs = tonumber(nowMs) or 0,
        cellKeys = keys
    }

    Registry.entriesByWheel[wheel] = entry
    for _, key in ipairs(keys) do
        local bucket = Registry.cells[key]
        if bucket == nil then
            bucket = setmetatable({}, { __mode = "k" })
            Registry.cells[key] = bucket
        end
        bucket[wheel] = entry
    end
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

    -- Contacts are indexed into every grid cell touched by their own footprint.
    -- The query therefore expands only by its own radius + safety margin;
    -- there is no global maximum-radius term that can permanently inflate cost.
    local queryRadius = radiusM + margin
    local minIx, maxIx = cellCoord(x - queryRadius), cellCoord(x + queryRadius)
    local minIz, maxIz = cellCoord(z - queryRadius), cellCoord(z + queryRadius)

    local seen = setmetatable({}, { __mode = "k" })
    local staleWheels = nil

    for ix = minIx, maxIx do
        for iz = minIz, maxIz do
            local bucket = Registry.cells[cellKey(ix, iz)]
            if bucket ~= nil then
                for wheel, entry in pairs(bucket) do
                    if seen[wheel] ~= true then
                        seen[wheel] = true
                        if stale(entry, nowMs) then
                            staleWheels = staleWheels or {}
                            staleWheels[#staleWheels + 1] = wheel
                        elseif entry.owner ~= options.excludeOwner then
                            local combined = radiusM + entry.radiusM + margin
                            local dx, dz = entry.x - x, entry.z - z
                            if dx * dx + dz * dz <= combined * combined then
                                for _, staleWheel in ipairs(staleWheels or {}) do
                                    Registry.remove(staleWheel)
                                end
                                return true, entry
                            end
                        end
                    end
                end
            end
        end
    end

    for _, wheel in ipairs(staleWheels or {}) do Registry.remove(wheel) end
    return false, nil
end

function Registry.getStats(nowMs)
    local count, maxLoadN, indexedCells = 0, 0, 0
    local staleWheels = {}

    for wheel, entry in pairs(Registry.entriesByWheel) do
        if stale(entry, nowMs) then
            staleWheels[#staleWheels + 1] = wheel
        else
            count = count + 1
            maxLoadN = math.max(maxLoadN, tonumber(entry.loadN) or 0)
            indexedCells = indexedCells + #(entry.cellKeys or {})
        end
    end

    for _, wheel in ipairs(staleWheels) do Registry.remove(wheel) end

    return {
        activeContacts = count,
        maxLoadN = maxLoadN,
        indexedCellReferences = indexedCells
    }
end

return Registry
