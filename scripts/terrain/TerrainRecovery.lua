RealismExtensionsTerrainRecovery = RealismExtensionsTerrainRecovery or {}
local Recovery = RealismExtensionsTerrainRecovery

Recovery.VERSION = 1
Recovery.DEFAULTS = {
    -- Surface repair strength is deliberately conservative while GIANTS
    -- additive RAISE still over-realizes requested displacement at runtime.
    -- These are per-pass logical targets; physical writer requests are further
    -- calibrated below.
    shallowFraction = 0.45,
    shallowMaxRaiseM = 0.015,
    deepFraction = 0.25,
    deepMaxRaiseM = 0.010,
    raiseCalibration = 0.30,
    minRutM = 0.003,
    cooldownMs = 1500,
    maxCellsPerWorkAreaCall = 48,
    brushRadiusM = 0.13,
    brushHardness = 0.55
}

Recovery.stats = Recovery.stats or {
    workAreaCalls = 0,
    workedAreaCalls = 0,
    recoveredCells = 0,
    requestedRaiseM = 0,
    brushesEnqueued = 0,
    brushesRejected = 0
}

local function enabled()
    return RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.modules ~= nil
        and RealismExtensionsConfig.modules.TerrainDeformation == true
        and RealismExtensionsConfig.modules.TerrainRecovery == true
end

local function recoverWorkedArea(vehicle, workArea, realArea)
    if not enabled() or (tonumber(realArea) or 0) <= 0 then return end
    local runtime = RealismExtensionsTerrainRuntime
    if runtime == nil or runtime.history == nil or runtime.writer == nil then return end
    if workArea == nil or workArea.start == nil
        or workArea.width == nil or workArea.height == nil then return end

    local okS, xs, _, zs = pcall(getWorldTranslation, workArea.start)
    local okW, xw, _, zw = pcall(getWorldTranslation, workArea.width)
    local okH, xh, _, zh = pcall(getWorldTranslation, workArea.height)
    if not okS or not okW or not okH then return end

    local spec = vehicle ~= nil and vehicle.spec_cultivator or nil
    local deep = spec ~= nil and spec.useDeepMode == true
    local fraction = deep and Recovery.DEFAULTS.deepFraction
        or Recovery.DEFAULTS.shallowFraction
    local maxRaiseM = deep and Recovery.DEFAULTS.deepMaxRaiseM
        or Recovery.DEFAULTS.shallowMaxRaiseM
    local nowMs = g_currentMission ~= nil and g_currentMission.time or 0

    Recovery.stats.workedAreaCalls = Recovery.stats.workedAreaCalls + 1
    local cells, raised = runtime.history:recoverParallelogram(
        xs, zs, xw, zw, xh, zh,
        {
            fraction = fraction,
            maxRaiseM = maxRaiseM,
            minRutM = Recovery.DEFAULTS.minRutM,
            cooldownMs = Recovery.DEFAULTS.cooldownMs,
            nowMs = nowMs,
            maxCells = Recovery.DEFAULTS.maxCellsPerWorkAreaCall
        },
        function(x, z, raiseM)
            local writerRaiseM = raiseM * Recovery.DEFAULTS.raiseCalibration
            if runtime.writer:enqueue({
                x = x,
                z = z,
                mode = "RAISE",
                raiseHeightM = writerRaiseM,
                radiusM = Recovery.DEFAULTS.brushRadiusM,
                hardness = Recovery.DEFAULTS.brushHardness,
                source = "RECOVERY"
            }) then
                Recovery.stats.brushesEnqueued = Recovery.stats.brushesEnqueued + 1
                return writerRaiseM
            else
                Recovery.stats.brushesRejected = Recovery.stats.brushesRejected + 1
                return false
            end
        end
    )
    Recovery.stats.recoveredCells = Recovery.stats.recoveredCells + cells
    Recovery.stats.requestedRaiseM = Recovery.stats.requestedRaiseM + raised
end

function Recovery.processCultivatorArea(vehicle, superFunc, workArea, dt)
    local perfStarted = RealismExtensionsTerrainPerformance ~= nil
        and RealismExtensionsTerrainPerformance.begin() or nil
    Recovery.stats.workAreaCalls = Recovery.stats.workAreaCalls + 1
    local realArea, area = superFunc(vehicle, workArea, dt)
    recoverWorkedArea(vehicle, workArea, realArea)
    if RealismExtensionsTerrainPerformance ~= nil then
        RealismExtensionsTerrainPerformance.finish("recovery", perfStarted)
    end
    return realArea, area
end

function Recovery.getDiagnostics()
    local out = {}
    for k, v in pairs(Recovery.stats) do out[k] = v end
    return out
end

function Recovery.prerequisitesPresent(specializations)
    return Cultivator ~= nil
        and SpecializationUtil.hasSpecialization(Cultivator, specializations)
end

function Recovery.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(
        vehicleType,
        "processCultivatorArea",
        Recovery.processCultivatorArea
    )
end
