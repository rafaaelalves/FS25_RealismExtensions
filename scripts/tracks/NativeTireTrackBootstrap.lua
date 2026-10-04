RealismExtensionsNativeTireTrackBootstrap =
    RealismExtensionsNativeTireTrackBootstrap or {}
local Bootstrap = RealismExtensionsNativeTireTrackBootstrap

Bootstrap.VERSION = 1
Bootstrap.installed = Bootstrap.installed == true
Bootstrap.stats = Bootstrap.stats or {
    preLoadCalls = 0,
    adapterInstallAttempts = 0,
    adapterInstalls = 0,
    adapterAlreadyActive = 0,
    adapterUnavailable = 0
}

local function getModules()
    return RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.modules or {}
end

local function adapterNeeded()
    local modules = getModules()
    return modules.NativeTireTrackProbe == true
        or modules.VisualTrackCapture == true
end

function Bootstrap.tryInstallFromMission()
    local adapter = RealismExtensionsNativeTireTrackAdapter
    if adapter == nil then
        Bootstrap.stats.adapterUnavailable =
            Bootstrap.stats.adapterUnavailable + 1
        return false, "native TireTrack adapter unavailable"
    end

    if type(adapter.setProbeEnabled) == "function" then
        adapter.setProbeEnabled(getModules().NativeTireTrackProbe == true)
    end

    if not adapterNeeded() then
        return false, "native TireTrack adapter disabled"
    end

    if adapter.installed == true then
        Bootstrap.stats.adapterAlreadyActive =
            Bootstrap.stats.adapterAlreadyActive + 1
        return true, "already active"
    end

    Bootstrap.stats.adapterInstallAttempts =
        Bootstrap.stats.adapterInstallAttempts + 1
    local ok, reason = adapter.installFromMission()
    if ok then
        Bootstrap.stats.adapterInstalls =
            Bootstrap.stats.adapterInstalls + 1
        if RealismExtensionsDiagnostics ~= nil
            and type(RealismExtensionsDiagnostics.info) == "function" then
            RealismExtensionsDiagnostics.info(
                "native TireTrack adapter installed from TireTracks:onPreLoad bootstrap"
            )
        end
    end
    return ok, reason
end

function Bootstrap.onPreLoad(vehicle, savegame)
    Bootstrap.stats.preLoadCalls = Bootstrap.stats.preLoadCalls + 1
    Bootstrap.tryInstallFromMission()
end

function Bootstrap.install()
    if Bootstrap.installed == true then return true, nil end
    if TireTracks == nil or type(TireTracks.onPreLoad) ~= "function" then
        return false, "TireTracks:onPreLoad unavailable"
    end
    if Utils == nil or type(Utils.prependedFunction) ~= "function" then
        return false, "Utils.prependedFunction unavailable"
    end

    Bootstrap.originalOnPreLoad = TireTracks.onPreLoad
    Bootstrap.wrapper = Utils.prependedFunction(
        TireTracks.onPreLoad,
        Bootstrap.onPreLoad
    )
    TireTracks.onPreLoad = Bootstrap.wrapper
    Bootstrap.installed = true
    return true, nil
end

function Bootstrap.getDiagnostics()
    local out = {}
    for k,v in pairs(Bootstrap.stats or {}) do out[k]=v end
    out.installed = Bootstrap.installed == true
    return out
end

Bootstrap.install()
return Bootstrap
