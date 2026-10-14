RealismExtensionsTerrainPerformance = RealismExtensionsTerrainPerformance or {}
local Perf = RealismExtensionsTerrainPerformance

Perf.stats = Perf.stats or {}
Perf.timerAvailable = type(getTimeSec) == "function"

local function enabled()
    return RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.diagnostics ~= nil
        and RealismExtensionsConfig.diagnostics.performanceTiming == true
        and Perf.timerAvailable == true
end

function Perf.begin()
    if not enabled() then return nil end
    local ok, value = pcall(getTimeSec)
    if ok and type(value) == "number" then
        return value * 1000
    end
    return nil
end

function Perf.finish(name, startedMs)
    if startedMs == nil or type(name) ~= "string" then return nil end
    local ok, value = pcall(getTimeSec)
    if not ok or type(value) ~= "number" then return nil end

    local elapsedMs = math.max(0, value * 1000 - startedMs)
    local stat = Perf.stats[name]
    if stat == nil then
        stat = { samples = 0, totalMs = 0, maxMs = 0 }
        Perf.stats[name] = stat
    end
    stat.samples = stat.samples + 1
    stat.totalMs = stat.totalMs + elapsedMs
    stat.maxMs = math.max(stat.maxMs, elapsedMs)
    return elapsedMs
end

function Perf.get(name)
    local stat = Perf.stats[name]
    if stat == nil then
        return { samples = 0, totalMs = 0, maxMs = 0, avgMs = 0 }
    end
    return {
        samples = stat.samples or 0,
        totalMs = stat.totalMs or 0,
        maxMs = stat.maxMs or 0,
        avgMs = (stat.samples or 0) > 0
            and (stat.totalMs or 0) / stat.samples or 0
    }
end

function Perf.snapshot()
    return {
        timerAvailable = Perf.timerAvailable == true,
        vehicleUpdate = Perf.get("vehicleUpdate"),
        flush = Perf.get("flush"),
        callback = Perf.get("callback"),
        recovery = Perf.get("recovery")
    }
end

function Perf.clear()
    Perf.stats = {}
end
