RealismExtensionsTerrainTelemetry = RealismExtensionsTerrainTelemetry or {}
local Telemetry = RealismExtensionsTerrainTelemetry

Telemetry.VERSION = 1

local function numeric(value)
    return type(value) == "number" and value or 0
end

local function delta(previous, current, key)
    return math.max(0, numeric(current[key]) - numeric(previous[key]))
end

local function collectWriterEntries(runtime, previous, prefix)
    local out = {}
    for key, value in pairs(runtime or {}) do
        if type(value) == "number" and value > 0
            and string.sub(key, 1, #prefix) == prefix then
            out[#out + 1] = {
                key = key,
                name = string.sub(key, #prefix + 1),
                count = value,
                window = math.max(0, value - numeric(previous[key]))
            }
        end
    end
    table.sort(out, function(a,b)
        if a.window ~= b.window then return a.window > b.window end
        if a.count ~= b.count then return a.count > b.count end
        return a.name < b.name
    end)
    return out
end

function Telemetry.capture(recovery, runtime)
    local snapshot = {}
    for k,v in pairs(recovery or {}) do
        if type(v) == "number" then snapshot[k] = v end
    end

    for _,key in ipairs({
        "activeCultivatorRutSkips",
        "cultivationProtectionSkips",
        "brushesAccepted"
    }) do
        snapshot[key] = numeric(runtime ~= nil and runtime[key] or 0)
    end

    for k,v in pairs(runtime or {}) do
        if type(v) == "number"
            and (string.sub(k,1,10) == "rutWriter_"
                or string.sub(k,1,14) == "rutWriterRoot_") then
            snapshot[k] = v
        end
    end

    return snapshot
end

function Telemetry.buildWindow(previous, recovery, runtime)
    previous = previous or {}
    recovery = recovery or {}
    runtime = runtime or {}

    local nextSnapshot = Telemetry.capture(recovery, runtime)
    return {
        work = delta(previous, recovery, "physicalWorkAreaCalls"),
        changed = delta(previous, recovery, "changedWorkAreaCalls"),
        repeatWork = delta(previous, recovery, "repeatWorkAreaCalls"),
        processedArea = delta(previous, recovery, "processedAreaUnits"),
        repeatArea = delta(previous, recovery, "repeatAreaUnits"),
        smooth = delta(previous, recovery, "brushesEnqueued"),
        callbacks = delta(previous, recovery, "callbacks"),
        improved = delta(previous, recovery, "roughnessImproved"),
        worsened = delta(previous, recovery, "roughnessWorsened"),
        rutBlocked = delta(previous, runtime, "activeCultivatorRutSkips"),
        protected = delta(previous, runtime, "cultivationProtectionSkips"),
        rutAccepted = delta(previous, runtime, "brushesAccepted"),
        writers = collectWriterEntries(runtime, previous, "rutWriter_"),
        rootWriters = collectWriterEntries(runtime, previous, "rutWriterRoot_")
    }, nextSnapshot
end

function Telemetry.formatWriters(items, limit)
    local parts = {}
    for i=1,math.min(limit or 5,#(items or {})) do
        local item=items[i]
        parts[#parts+1]=string.format(
            "%s=%d(+%d)",
            tostring(item.name),
            numeric(item.count),
            numeric(item.window)
        )
    end
    return table.concat(parts," ")
end

return Telemetry
