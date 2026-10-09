-- TerrainPassTracker R10 phase A1 (observation-only).
-- Measures physically completed tillage passes, not GIANTS callback frequency.
-- Never requests terrain writes, alters stamps or changes recovery strength.
RealismExtensionsTerrainPassTracker = RealismExtensionsTerrainPassTracker or {}
local Tracker = RealismExtensionsTerrainPassTracker

Tracker.VERSION = 1
Tracker.DEFAULTS = {
    idleGapMs = 1500,
    scanIntervalMs = 250,
    maxObservedCellsPerPass = 4096,
    minWorkingSpeedKph = 0.5,
    -- Exclude teleports and invalid observations; distance is observed
    -- world movement, not speed * dt inferred from callback count.
    maxStepM = 30
}

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function positionOf(operation)
    local vehicle = operation.rootVehicle or operation.vehicle
    local rootNode = vehicle ~= nil and vehicle.rootNode or nil
    if rootNode ~= nil and rootNode ~= 0
        and type(getWorldTranslation) == "function" then
        local ok, x, _, z = pcall(getWorldTranslation, rootNode)
        if ok and finite(x) and finite(z) then return x, z end
    end
    -- A fallback work-area centroid is sufficient for observability, but a
    -- change of workArea in the same frame must not count as driving distance.
    local g = operation.geometry
    if type(g) == "table"
        and finite(g.xs) and finite(g.zs)
        and finite(g.ux) and finite(g.uz)
        and finite(g.vx) and finite(g.vz) then
        return g.xs + 0.5 * (g.ux + g.vx),
            g.zs + 0.5 * (g.uz + g.vz)
    end
    return nil, nil
end

local function freshState()
    return setmetatable({}, { __mode = "k" })
end

function Tracker.reset()
    Tracker.active = freshState()
    Tracker.nextId = 0
    Tracker.completed = 0
    Tracker.started = 0
    Tracker.lastSummary = nil
    Tracker.lastSweepMs = nil
end

if Tracker.active == nil then Tracker.reset() end

local function getBucket(vehicle)
    local bucket = Tracker.active[vehicle]
    if bucket == nil then
        bucket = {}
        Tracker.active[vehicle] = bucket
    end
    return bucket
end

local function close(vehicle, operationKind, reason)
    local bucket = Tracker.active[vehicle]
    local pass = bucket ~= nil and bucket[operationKind] or nil
    if pass == nil then return nil end
    bucket[operationKind] = nil
    if next(bucket) == nil then Tracker.active[vehicle] = nil end
    Tracker.completed = Tracker.completed + 1
    local summary = {
        passId = pass.passId,
        operationKind = pass.operationKind,
        toolProfileId = pass.toolProfileId,
        reason = reason,
        durationMs = math.max(0, pass.lastActiveMs - pass.startedMs),
        distanceM = pass.distanceM,
        meanSpeedKph = pass.speedTimeMs > 0
            and pass.speedWeightedSum / pass.speedTimeMs
            or pass.lastSpeedKph,
        minSpeedKph = pass.minSpeedKph,
        maxSpeedKph = pass.maxSpeedKph,
        callbacks = pass.callbacks,
        changedCallbacks = pass.changedCallbacks,
        repeatCallbacks = pass.repeatCallbacks,
        changedArea = pass.changedArea,
        processedArea = pass.processedArea,
        uniqueCausalCells = pass.uniqueCausalCells,
        cellsCapped = pass.cellsCapped
    }
    Tracker.lastSummary = summary
    return summary
end

local function start(vehicle, operation, nowMs)
    Tracker.nextId = Tracker.nextId + 1
    Tracker.started = Tracker.started + 1
    local speed = math.max(0, tonumber(operation.speedKph) or 0)
    local profile = operation.toolProfile
    local pass = {
        passId = Tracker.nextId,
        operationKind = operation.operationKind or "CULTIVATOR",
        toolProfileId = profile ~= nil and tostring(profile.id or "UNKNOWN") or "UNKNOWN",
        startedMs = nowMs,
        lastActiveMs = nowMs,
        lastSampleMs = nil,
        lastSpeedKph = speed,
        minSpeedKph = speed,
        maxSpeedKph = speed,
        speedWeightedSum = 0,
        speedTimeMs = 0,
        distanceM = 0,
        callbacks = 0,
        changedCallbacks = 0,
        repeatCallbacks = 0,
        changedArea = 0,
        processedArea = 0,
        observedCells = {},
        uniqueCausalCells = 0,
        cellsCapped = false
    }
    getBucket(vehicle)[pass.operationKind] = pass
    return pass
end

function Tracker.observe(operation)
    if type(operation) ~= "table" then return nil end
    local vehicle = operation.vehicle
    if type(vehicle) ~= "table" then return nil end
    local nowMs = tonumber(operation.nowMs)
    if not finite(nowMs) then return nil end
    local kind = operation.operationKind or "CULTIVATOR"
    local bucket = Tracker.active[vehicle]
    local pass = bucket ~= nil and bucket[kind] or nil

    local working = operation.physicallyWorking == true
        and (tonumber(operation.speedKph) or 0)
            > Tracker.DEFAULTS.minWorkingSpeedKph
        and (tonumber(operation.processedArea) or 0) > 0
    if not working then
        -- A zero-area callback can be a duplicate workArea in an otherwise
        -- active tick. Explicit lift/stop closes; ordinary zero-area waits
        -- for the idle timeout instead of splitting a pass spuriously.
        if pass ~= nil and (operation.physicallyWorking ~= true
            or (tonumber(operation.speedKph) or 0)
                <= Tracker.DEFAULTS.minWorkingSpeedKph) then
            return nil, close(vehicle, kind, "INACTIVE")
        end
        return pass ~= nil and pass.passId or nil
    end

    if pass ~= nil and (nowMs < pass.lastActiveMs
        or nowMs - pass.lastActiveMs > Tracker.DEFAULTS.idleGapMs) then
        close(vehicle, kind, "GAP")
        pass = nil
    end
    if pass == nil then pass = start(vehicle, operation, nowMs) end

    pass.callbacks = pass.callbacks + 1
    local changed = math.max(0, tonumber(operation.changedArea) or 0)
    local processed = math.max(0, tonumber(operation.processedArea) or 0)
    pass.changedArea = pass.changedArea + changed
    pass.processedArea = pass.processedArea + processed
    if changed > 0 then
        pass.changedCallbacks = pass.changedCallbacks + 1
    else
        pass.repeatCallbacks = pass.repeatCallbacks + 1
    end

    local speed = math.max(0, tonumber(operation.speedKph) or 0)
    pass.minSpeedKph = math.min(pass.minSpeedKph, speed)
    pass.maxSpeedKph = math.max(pass.maxSpeedKph, speed)
    local x, z = positionOf(operation)
    if pass.lastSampleMs ~= nowMs then
        local elapsed = pass.lastSampleMs ~= nil
            and math.max(0, nowMs - pass.lastSampleMs) or 0
        if elapsed > 0 then
            pass.speedWeightedSum = pass.speedWeightedSum
                + 0.5 * (pass.lastSpeedKph + speed) * elapsed
            pass.speedTimeMs = pass.speedTimeMs + elapsed
        end
        if x ~= nil and pass.lastX ~= nil then
            local dx, dz = x - pass.lastX, z - pass.lastZ
            local step = math.sqrt(dx * dx + dz * dz)
            if step <= Tracker.DEFAULTS.maxStepM then
                pass.distanceM = pass.distanceM + step
            end
        end
        if x ~= nil then
            pass.lastX, pass.lastZ = x, z
        end
        pass.lastSampleMs = nowMs
        pass.lastSpeedKph = speed
    end
    pass.lastActiveMs = nowMs
    return pass.passId
end

-- Observational only: never used to authorize actual recovery or skip a write.
-- Bounded per pass even during hours of continuous work.
function Tracker.observeCausalCell(vehicle, operationKind, cellKey)
    local bucket = Tracker.active[vehicle]
    local pass = bucket ~= nil and bucket[operationKind or "CULTIVATOR"] or nil
    if pass == nil or type(cellKey) ~= "string" then return nil end
    if pass.observedCells[cellKey] then return false end
    if pass.uniqueCausalCells >= Tracker.DEFAULTS.maxObservedCellsPerPass then
        pass.cellsCapped = true
        return nil
    end
    pass.observedCells[cellKey] = true
    pass.uniqueCausalCells = pass.uniqueCausalCells + 1
    return true
end

function Tracker.getActivePassId(vehicle, operationKind)
    local bucket = Tracker.active[vehicle]
    local pass = bucket ~= nil and bucket[operationKind or "CULTIVATOR"] or nil
    return pass ~= nil and pass.passId or nil
end

-- Runs on server, amortized. An implement that stops generating area callbacks
-- must still close the pass even if it was deleted, lifted or teleported.
function Tracker.expire(nowMs)
    nowMs = tonumber(nowMs)
    if not finite(nowMs) then return end
    if Tracker.lastSweepMs ~= nil and nowMs >= Tracker.lastSweepMs
        and nowMs - Tracker.lastSweepMs < Tracker.DEFAULTS.scanIntervalMs then
        return
    end
    Tracker.lastSweepMs = nowMs
    local due = {}
    for vehicle, bucket in pairs(Tracker.active) do
        for kind, pass in pairs(bucket) do
            if nowMs < pass.lastActiveMs
                or nowMs - pass.lastActiveMs > Tracker.DEFAULTS.idleGapMs then
                due[#due + 1] = {vehicle, kind}
            end
        end
    end
    for _, item in ipairs(due) do
        close(item[1], item[2], "IDLE")
    end
end

function Tracker.getDiagnostics()
    local count = 0
    for _, bucket in pairs(Tracker.active) do
        for _ in pairs(bucket) do count = count + 1 end
    end
    return {
        passStarted = Tracker.started,
        passCompleted = Tracker.completed,
        passActive = count,
        passLast = Tracker.lastSummary
    }
end

return Tracker
