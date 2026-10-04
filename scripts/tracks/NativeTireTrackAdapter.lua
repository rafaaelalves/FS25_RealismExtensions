RealismExtensionsNativeTireTrackAdapter =
    RealismExtensionsNativeTireTrackAdapter or {}
local Adapter = RealismExtensionsNativeTireTrackAdapter

Adapter.VERSION = 2
Adapter.METHODS = { "createTrack", "addTrackPoint", "cutTrack" }
Adapter.SIGNATURE_SAMPLE_LIMIT = 32
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
    maxCutArgs = 0,
    signatureSamples = 0
}
Adapter.signatures = Adapter.signatures or {}
Adapter.observers = Adapter.observers or {}
Adapter.installed = Adapter.installed == true
Adapter.probeEnabled = Adapter.probeEnabled == true
Adapter._lastDriftReason = nil

local unpackFn = table.unpack or unpack

local function pack(...)
    return { n = select("#", ...), ... }
end

local function typeName(v)
    local t = type(v)
    if t == "table"
        and type(v.x) == "number"
        and type(v.y) == "number"
        and type(v.z) == "number" then
        return "vec3"
    end
    return t
end

local function signatureVarargs(n, ...)
    local sig = ""
    for i = 1, n do
        if i > 1 then sig = sig .. "," end
        sig = sig .. typeName(select(i, ...))
    end
    return sig
end

local function signaturePacked(args)
    local sig = ""
    for i = 1, args.n do
        if i > 1 then sig = sig .. "," end
        sig = sig .. typeName(args[i])
    end
    return sig
end

local function recordProbeCount(method, argc)
    if Adapter.probeEnabled ~= true then return false end

    local key = method .. "Calls"
    Adapter.stats[key] = (Adapter.stats[key] or 0) + 1

    if method == "createTrack" then
        Adapter.stats.maxCreateArgs = math.max(Adapter.stats.maxCreateArgs or 0, argc)
    elseif method == "addTrackPoint" then
        Adapter.stats.maxPointArgs = math.max(Adapter.stats.maxPointArgs or 0, argc)
    elseif method == "cutTrack" then
        Adapter.stats.maxCutArgs = math.max(Adapter.stats.maxCutArgs or 0, argc)
    end

    return (Adapter.stats.signatureSamples or 0)
        < Adapter.SIGNATURE_SAMPLE_LIMIT
end

local function storeSignature(method, sig)
    local bucket = Adapter.signatures[method]
    if bucket == nil then
        bucket = {}
        Adapter.signatures[method] = bucket
    end
    bucket[sig] = (bucket[sig] or 0) + 1
    Adapter.stats.signatureSamples =
        (Adapter.stats.signatureSamples or 0) + 1
end

local function recordProbeVarargs(method, argc, ...)
    if not recordProbeCount(method, argc) then return end
    storeSignature(method, signatureVarargs(argc, ...))
end

local function recordProbePacked(method, args)
    if not recordProbeCount(method, args.n) then return end
    storeSignature(method, signaturePacked(args))
end

local function notifyObservers(method, system, args, results)
    for _, observer in ipairs(Adapter.observers or {}) do
        local fn = observer ~= nil and observer[method] or nil
        if type(fn) == "function" then
            local ok, err = pcall(fn, observer, system, args, results)
            if not ok then
                Adapter.stats.observerErrors =
                    (Adapter.stats.observerErrors or 0) + 1
                Adapter.lastObserverError = tostring(err)
            end
        end
    end
end

function Adapter.setProbeEnabled(enabled)
    Adapter.probeEnabled = enabled == true
end

function Adapter.addObserver(observer)
    if type(observer) ~= "table" then return false end
    for _, existing in ipairs(Adapter.observers) do
        if existing == observer then return true end
    end
    Adapter.observers[#Adapter.observers + 1] = observer
    return true
end

function Adapter.removeObserver(observer)
    for i = #Adapter.observers, 1, -1 do
        if Adapter.observers[i] == observer then
            table.remove(Adapter.observers, i)
            return true
        end
    end
    return false
end

local function resolveInstance(system)
    if type(system) ~= "table" then return nil end
    for _, method in ipairs(Adapter.METHODS) do
        if type(system[method]) ~= "function" then return nil end
    end
    return system
end

function Adapter.checkIntegrity()
    if Adapter.installed ~= true or Adapter.owner == nil then
        return false, "not installed"
    end
    for _, method in ipairs(Adapter.METHODS) do
        if Adapter.owner[method] ~= Adapter.wrappers[method] then
            return false, method .. " pointer drift"
        end
    end
    return true, nil
end

function Adapter.pollIntegrity()
    local ok, reason = Adapter.checkIntegrity()
    if ok then
        Adapter._lastDriftReason = nil
        return true, nil
    end

    if Adapter.installed == true and reason ~= Adapter._lastDriftReason then
        Adapter.stats.pointerDrift =
            (Adapter.stats.pointerDrift or 0) + 1
        Adapter._lastDriftReason = reason
    end
    return false, reason
end

function Adapter.install(system)
    Adapter.stats.installAttempts = (Adapter.stats.installAttempts or 0) + 1

    if Adapter.installed == true then
        local ok = Adapter.pollIntegrity()
        if ok then return true, nil end
        return false, "existing adapter lost ownership"
    end

    local owner = resolveInstance(system)
    if owner == nil then
        return false, "TireTrackSystem methods unavailable"
    end

    local originals, rawOriginals, wrappers = {}, {}, {}

    for _, method in ipairs(Adapter.METHODS) do
        originals[method] = owner[method]
        rawOriginals[method] = rawget(owner, method)
    end

    for _, method in ipairs(Adapter.METHODS) do
        local original = originals[method]
        wrappers[method] = function(self, ...)
            local argc = select("#", ...)

            -- Probe-only is the common development hot path. Avoid allocating
            -- argument/result tables for every native tire-track point.
            if #Adapter.observers == 0 then
                recordProbeVarargs(method, argc, ...)
                return original(self, ...)
            end

            local args = pack(...)
            local results = pack(original(self, ...))
            recordProbePacked(method, args)
            notifyObservers(method, self, args, results)
            return unpackFn(results, 1, results.n)
        end
    end

    for _, method in ipairs(Adapter.METHODS) do
        owner[method] = wrappers[method]
    end

    Adapter.system = system
    Adapter.owner = owner
    Adapter.originals = originals
    Adapter.rawOriginals = rawOriginals
    Adapter.wrappers = wrappers
    Adapter.installed = true
    Adapter._lastDriftReason = nil
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

    -- Restore the exact pre-install lookup shape. If the method was inherited
    -- from the class, remove our instance override rather than freezing a copy
    -- of that inherited function on the mission instance.
    for _, method in ipairs(Adapter.METHODS) do
        if Adapter.owner ~= nil
            and Adapter.owner[method] == Adapter.wrappers[method] then
            Adapter.owner[method] = Adapter.rawOriginals[method]
        end
    end

    Adapter.system = nil
    Adapter.owner = nil
    Adapter.originals = nil
    Adapter.rawOriginals = nil
    Adapter.wrappers = nil
    Adapter.installed = false
    Adapter._lastDriftReason = nil
    return true
end

function Adapter.resetProbe()
    Adapter.signatures = {}
    Adapter.lastObserverError = nil
    for _, key in ipairs({
        "createTrackCalls", "addTrackPointCalls", "cutTrackCalls",
        "maxCreateArgs", "maxPointArgs", "maxCutArgs",
        "observerErrors", "signatureSamples"
    }) do
        Adapter.stats[key] = 0
    end
end

function Adapter.getDiagnostics()
    local out = {}
    for k, v in pairs(Adapter.stats or {}) do out[k] = v end
    out.installed = Adapter.installed == true
    out.probeEnabled = Adapter.probeEnabled == true
    local ok, reason = Adapter.pollIntegrity()
    out.integrity = ok
    out.integrityReason = reason
    out.signatures = Adapter.signatures
    out.lastObserverError = Adapter.lastObserverError
    return out
end

return Adapter
