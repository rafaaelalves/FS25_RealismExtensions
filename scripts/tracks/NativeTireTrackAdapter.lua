RealismExtensionsNativeTireTrackAdapter =
    RealismExtensionsNativeTireTrackAdapter or {}
local Adapter = RealismExtensionsNativeTireTrackAdapter

Adapter.VERSION = 1
Adapter.METHODS = { "createTrack", "addTrackPoint", "cutTrack" }
Adapter.stats = Adapter.stats or {
    installAttempts = 0,
    installs = 0,
    uninstallCalls = 0,
    pointerDrift = 0,
    observerErrors = 0,
    createTrackCalls = 0,
    addTrackPointCalls = 0,
    cutTrackCalls = 0,
    maxCreateArgs = 0,
    maxPointArgs = 0,
    maxCutArgs = 0
}
Adapter.signatures = Adapter.signatures or {}
Adapter.observers = Adapter.observers or {}
Adapter.installed = Adapter.installed == true

local unpackFn = table.unpack or unpack
local function pack(...)
    return { n = select("#", ...), ... }
end

local function signature(args)
    local parts = {}
    for i = 1, args.n do
        local v = args[i]
        local t = type(v)
        if t == "table" then
            if type(v.x) == "number" and type(v.y) == "number"
                and type(v.z) == "number" then
                t = "vec3"
            end
        end
        parts[#parts + 1] = t
    end
    return table.concat(parts, ",")
end

local function recordProbe(method, args)
    local key = method .. "Calls"
    Adapter.stats[key] = (Adapter.stats[key] or 0) + 1

    if method == "createTrack" then
        Adapter.stats.maxCreateArgs = math.max(Adapter.stats.maxCreateArgs or 0, args.n)
    elseif method == "addTrackPoint" then
        Adapter.stats.maxPointArgs = math.max(Adapter.stats.maxPointArgs or 0, args.n)
    elseif method == "cutTrack" then
        Adapter.stats.maxCutArgs = math.max(Adapter.stats.maxCutArgs or 0, args.n)
    end

    local sig = signature(args)
    local bucket = Adapter.signatures[method]
    if bucket == nil then
        bucket = {}
        Adapter.signatures[method] = bucket
    end
    bucket[sig] = (bucket[sig] or 0) + 1
end

local function notify(method, system, args, results)
    recordProbe(method, args)
    for _, observer in ipairs(Adapter.observers or {}) do
        local fn = observer ~= nil and observer[method] or nil
        if type(fn) == "function" then
            local ok = pcall(fn, observer, system, args, results)
            if not ok then
                Adapter.stats.observerErrors =
                    (Adapter.stats.observerErrors or 0) + 1
            end
        end
    end
end

function Adapter.addObserver(observer)
    if type(observer) ~= "table" then return false end
    Adapter.observers[#Adapter.observers + 1] = observer
    return true
end

function Adapter.removeObserver(observer)
    for i = #(Adapter.observers or {}), 1, -1 do
        if Adapter.observers[i] == observer then
            table.remove(Adapter.observers, i)
            return true
        end
    end
    return false
end

local function resolveMethodOwner(system)
    if system == nil then return nil end
    local mt = getmetatable(system)
    if type(mt) == "table" then
        local complete = true
        for _, method in ipairs(Adapter.METHODS) do
            if type(mt[method]) ~= "function" then
                complete = false
                break
            end
        end
        if complete then return mt end
    end

    local complete = true
    for _, method in ipairs(Adapter.METHODS) do
        if type(system[method]) ~= "function" then
            complete = false
            break
        end
    end
    return complete and system or nil
end

function Adapter.checkIntegrity()
    if Adapter.installed ~= true or Adapter.owner == nil then
        return false, "not installed"
    end
    for _, method in ipairs(Adapter.METHODS) do
        if Adapter.owner[method] ~= Adapter.wrappers[method] then
            Adapter.stats.pointerDrift =
                (Adapter.stats.pointerDrift or 0) + 1
            return false, method .. " pointer drift"
        end
    end
    return true, nil
end

function Adapter.install(system)
    Adapter.stats.installAttempts = (Adapter.stats.installAttempts or 0) + 1

    if Adapter.installed == true then
        local ok = Adapter.checkIntegrity()
        if ok then return true, nil end
        return false, "existing adapter lost ownership"
    end

    local owner = resolveMethodOwner(system)
    if owner == nil then
        return false, "TireTrackSystem methods unavailable"
    end

    local originals, wrappers = {}, {}
    for _, method in ipairs(Adapter.METHODS) do
        local original = owner[method]
        originals[method] = original

        wrappers[method] = function(self, ...)
            local args = pack(...)
            local results = pack(original(self, ...))
            notify(method, self, args, results)
            return unpackFn(results, 1, results.n)
        end
    end

    -- Install only after every required method was resolved.
    for _, method in ipairs(Adapter.METHODS) do
        owner[method] = wrappers[method]
    end

    Adapter.system = system
    Adapter.owner = owner
    Adapter.originals = originals
    Adapter.wrappers = wrappers
    Adapter.installed = true
    Adapter.stats.installs = (Adapter.stats.installs or 0) + 1
    return true, nil
end

function Adapter.installFromMission()
    local system = g_currentMission ~= nil
        and g_currentMission.tireTrackSystem or nil
    if system == nil then
        return false, "mission tireTrackSystem unavailable"
    end
    return Adapter.install(system)
end

function Adapter.uninstall()
    Adapter.stats.uninstallCalls = (Adapter.stats.uninstallCalls or 0) + 1
    if Adapter.installed ~= true then return true end

    -- Never restore over a later owner. Only put the captured function back
    -- when RE still owns the exact pointer.
    for _, method in ipairs(Adapter.METHODS) do
        if Adapter.owner ~= nil
            and Adapter.owner[method] == Adapter.wrappers[method] then
            Adapter.owner[method] = Adapter.originals[method]
        end
    end

    Adapter.system = nil
    Adapter.owner = nil
    Adapter.originals = nil
    Adapter.wrappers = nil
    Adapter.installed = false
    return true
end

function Adapter.resetProbe()
    Adapter.signatures = {}
    for _, key in ipairs({
        "createTrackCalls", "addTrackPointCalls", "cutTrackCalls",
        "maxCreateArgs", "maxPointArgs", "maxCutArgs", "observerErrors"
    }) do
        Adapter.stats[key] = 0
    end
end

function Adapter.getDiagnostics()
    local out = {}
    for k, v in pairs(Adapter.stats or {}) do out[k] = v end
    out.installed = Adapter.installed == true
    local ok, reason = Adapter.checkIntegrity()
    out.integrity = ok
    out.integrityReason = reason
    out.signatures = Adapter.signatures
    return out
end

return Adapter
