RealismExtensionsTerrainRecovery = RealismExtensionsTerrainRecovery or {}
local Recovery = RealismExtensionsTerrainRecovery

Recovery.VERSION = 2
Recovery.DEFAULTS = {
    -- GIANTS Leveler/Shovel precedent: smoothing is accumulated from travelled
    -- distance, not repeated once per render/update frame.
    minSpeedKmh = 0.7,
    shallowSmoothPerMeter = 0.55,
    deepSmoothPerMeter = 0.35,
    shallowRadiusM = 0.55,
    deepRadiusM = 0.40,
    overlap = 0.20,
    -- History is secondary state. Physical smoothing is authoritative.
    shallowHistoryRelax = 0.30,
    deepHistoryRelax = 0.18,
    maxHistoryCellsPerCall = 64,
    minHistoryRutM = 0.003,
    historyCooldownMs = 1500
}

Recovery.stats = Recovery.stats or {
    workAreaCalls = 0,
    workedAreaCalls = 0,
    smoothingAttempts = 0,
    smoothingCalls = 0,
    smoothingErrors = 0,
    smoothAmount = 0,
    historyRelaxedCells = 0,
    historyRelaxedDepthM = 0
}

local function enabled()
    return RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.modules ~= nil
        and RealismExtensionsConfig.modules.TerrainDeformation == true
        and RealismExtensionsConfig.modules.TerrainRecovery == true
end

local function workAreaCenterLine(workArea)
    if workArea == nil or workArea.start == nil
        or workArea.width == nil or workArea.height == nil then return nil end

    local okS, xs, ys, zs = pcall(getWorldTranslation, workArea.start)
    local okW, xw, yw, zw = pcall(getWorldTranslation, workArea.width)
    local okH, xh, yh, zh = pcall(getWorldTranslation, workArea.height)
    if not okS or not okW or not okH then return nil end

    -- start->width is the working edge. Build its midpoint and a short
    -- direction node-free line across the actual work width for native
    -- smoothing. smoothAroundLine accepts a scene node, so v12 uses the
    -- cultivator's work-area start node as the moving reference and derives
    -- width from the work-area geometry.
    local width = math.sqrt((xw-xs)^2 + (zw-zs)^2)
    return {
        xs=xs, zs=zs, xw=xw, zw=zw, xh=xh, zh=zh,
        width=math.max(0.10, width),
        node=workArea.start
    }
end

local function relaxHistory(runtime, g, deep, nowMs)
    if runtime == nil or runtime.history == nil
        or runtime.history.recoverParallelogram == nil then return 0,0 end

    local fraction = deep and Recovery.DEFAULTS.deepHistoryRelax
        or Recovery.DEFAULTS.shallowHistoryRelax

    -- No TerrainWriter callback here: geometry has already been physically
    -- smoothed by GIANTS. This only reconciles RE's memory so it does not
    -- immediately try to recreate the old rut state.
    return runtime.history:recoverParallelogram(
        g.xs,g.zs,g.xw,g.zw,g.xh,g.zh,
        {
            fraction=fraction,
            maxRaiseM=0.012,
            minRutM=Recovery.DEFAULTS.minHistoryRutM,
            cooldownMs=Recovery.DEFAULTS.historyCooldownMs,
            nowMs=nowMs,
            maxCells=Recovery.DEFAULTS.maxHistoryCellsPerCall
        },
        function(x,z,raiseM)
            -- Numeric return means logical relaxation only; v12 diagnostics
            -- report this separately and never call it physical recovery.
            return raiseM
        end
    )
end

local function smoothWorkedArea(vehicle, workArea, realArea, dt)
    if not enabled() or (tonumber(realArea) or 0) <= 0 then return end
    if DensityMapHeightUtil == nil
        or type(DensityMapHeightUtil.smoothAroundLine) ~= "function" then return end

    local g = workAreaCenterLine(workArea)
    if g == nil then return end

    local speedKmh = vehicle ~= nil and tonumber(vehicle.lastSpeedReal) or 0
    speedKmh = speedKmh * 3600
    if speedKmh < Recovery.DEFAULTS.minSpeedKmh then return end

    local spec = vehicle ~= nil and vehicle.spec_cultivator or nil
    local deep = spec ~= nil and spec.useDeepMode == true
    local perMeter = deep and Recovery.DEFAULTS.deepSmoothPerMeter
        or Recovery.DEFAULTS.shallowSmoothPerMeter
    local radius = deep and Recovery.DEFAULTS.deepRadiusM
        or Recovery.DEFAULTS.shallowRadiusM

    local movedM = vehicle ~= nil and tonumber(vehicle.lastMovedDistance) or nil
    if movedM == nil or movedM <= 0 then
        movedM = math.max(0, (speedKmh / 3.6) * ((tonumber(dt) or 0) / 1000))
    end
    local smoothAmount = movedM * perMeter
    if smoothAmount <= 0 then return end

    Recovery.stats.smoothingAttempts = Recovery.stats.smoothingAttempts + 1
    local rounded = DensityMapHeightUtil.getRoundedHeightValue ~= nil
        and DensityMapHeightUtil.getRoundedHeightValue(smoothAmount)
        or smoothAmount
    if rounded == nil or rounded <= 0 then return end

    local ok = pcall(
        DensityMapHeightUtil.smoothAroundLine,
        g.node, g.width * 0.5, radius, Recovery.DEFAULTS.overlap, rounded, true
    )
    if not ok then
        Recovery.stats.smoothingErrors = Recovery.stats.smoothingErrors + 1
        return
    end

    Recovery.stats.smoothingCalls = Recovery.stats.smoothingCalls + 1
    Recovery.stats.smoothAmount = Recovery.stats.smoothAmount + rounded

    local runtime = RealismExtensionsTerrainRuntime
    local nowMs = g_currentMission ~= nil and g_currentMission.time or 0
    local cells, depth = relaxHistory(runtime, g, deep, nowMs)
    Recovery.stats.historyRelaxedCells =
        Recovery.stats.historyRelaxedCells + (cells or 0)
    Recovery.stats.historyRelaxedDepthM =
        Recovery.stats.historyRelaxedDepthM + (depth or 0)
end

function Recovery.processCultivatorArea(vehicle, superFunc, workArea, dt)
    local perfStarted = RealismExtensionsTerrainPerformance ~= nil
        and RealismExtensionsTerrainPerformance.begin() or nil
    Recovery.stats.workAreaCalls = Recovery.stats.workAreaCalls + 1
    local realArea, area = superFunc(vehicle, workArea, dt)
    if (tonumber(realArea) or 0) > 0 then
        Recovery.stats.workedAreaCalls = Recovery.stats.workedAreaCalls + 1
        smoothWorkedArea(vehicle, workArea, realArea, dt)
    end
    if RealismExtensionsTerrainPerformance ~= nil then
        RealismExtensionsTerrainPerformance.finish("recovery", perfStarted)
    end
    return realArea, area
end

function Recovery.getDiagnostics()
    local out = {}
    for k,v in pairs(Recovery.stats) do out[k]=v end
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
