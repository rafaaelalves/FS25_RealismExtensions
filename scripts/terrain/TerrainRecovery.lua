RealismExtensionsTerrainRecovery = RealismExtensionsTerrainRecovery or {}
local Recovery = RealismExtensionsTerrainRecovery

Recovery.VERSION = 3
Recovery.DEFAULTS = {
    -- GIANTS Leveler/Shovel precedent: smoothing is accumulated from travelled
    -- distance, not repeated once per render/update frame.
    minSpeedKmh = 0.7,
    shallowSmoothPerMeter = 0.55,
    deepSmoothPerMeter = 0.35,
    shallowRadiusM = 0.55,
    deepRadiusM = 0.40,
    overlap = 0.20,
    -- v13 never treats a successful native call as proof of geometric work.
    -- A small before/after terrain probe must observe a real height change.
    physicalChangeEpsilonM = 0.00005,
    -- History is secondary state. Physical smoothing is authoritative.
    shallowHistoryRelax = 0.30,
    deepHistoryRelax = 0.18,
    maxHistoryCellsPerCall = 64,
    minHistoryRutM = 0.003,
    historyCooldownMs = 1500
}

Recovery.accumulationByVehicle = Recovery.accumulationByVehicle or setmetatable({}, {__mode="k"})

Recovery.stats = Recovery.stats or {
    workAreaCalls = 0,
    workedAreaCalls = 0,
    smoothingAttempts = 0,
    smoothingCalls = 0,
    smoothingErrors = 0,
    smoothAmount = 0,
    physicalProbeCalls = 0,
    physicalProbeSamples = 0,
    physicalChangedCalls = 0,
    physicalNoChangeCalls = 0,
    physicalUnverifiedCalls = 0,
    physicalChangedSamples = 0,
    physicalAbsDeltaM = 0,
    physicalMaxDeltaM = 0,
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

local function sampleTerrainHeight(x, z)
    local terrain = g_currentMission ~= nil and g_currentMission.terrainRootNode or nil
    if getTerrainHeightAtWorldPos == nil or terrain == nil or terrain == 0 then
        return nil
    end
    local ok, value = pcall(getTerrainHeightAtWorldPos, terrain, x, 0, z)
    if ok and type(value) == "number" then return value end
    return nil
end

local function capturePhysicalProbe(g)
    local xo, zo = g.xw + g.xh - g.xs, g.zw + g.zh - g.zs
    local cx, cz = (g.xs + xo) * 0.5, (g.zs + zo) * 0.5
    local points = {
        { x=(g.xs + g.xw) * 0.5, z=(g.zs + g.zw) * 0.5 },
        { x=(g.xh + xo) * 0.5, z=(g.zh + zo) * 0.5 },
        { x=(g.xs + g.xh) * 0.5, z=(g.zs + g.zh) * 0.5 },
        { x=(g.xw + xo) * 0.5, z=(g.zw + zo) * 0.5 },
        { x=cx, z=cz }
    }

    local samples = {}
    for _, point in ipairs(points) do
        local y = sampleTerrainHeight(point.x, point.z)
        if y ~= nil then
            samples[#samples + 1] = { x=point.x, z=point.z, y=y }
        end
    end
    return #samples > 0 and samples or nil
end

local function verifyPhysicalProbe(before)
    if before == nil then return nil, 0, 0, 0 end

    local changedSamples, sumAbsDeltaM, maxAbsDeltaM, validSamples = 0, 0, 0, 0
    local epsilon = Recovery.DEFAULTS.physicalChangeEpsilonM

    for _, sample in ipairs(before) do
        local afterY = sampleTerrainHeight(sample.x, sample.z)
        if afterY ~= nil then
            validSamples = validSamples + 1
            local delta = math.abs(afterY - sample.y)
            sumAbsDeltaM = sumAbsDeltaM + delta
            maxAbsDeltaM = math.max(maxAbsDeltaM, delta)
            if delta > epsilon then
                changedSamples = changedSamples + 1
            end
        end
    end

    if validSamples == 0 then return nil, 0, 0, 0 end
    return changedSamples > 0, changedSamples, sumAbsDeltaM, maxAbsDeltaM
end

local function relaxHistory(runtime, g, deep, nowMs, physicalMaxDeltaM)
    if runtime == nil or runtime.history == nil
        or runtime.history.recoverParallelogram == nil then return 0,0 end

    local fraction = deep and Recovery.DEFAULTS.deepHistoryRelax
        or Recovery.DEFAULTS.shallowHistoryRelax
    local maxRaiseM = math.min(0.012, math.max(0, tonumber(physicalMaxDeltaM) or 0))
    if maxRaiseM <= Recovery.DEFAULTS.physicalChangeEpsilonM then return 0,0 end

    -- No TerrainWriter callback here: geometry has already been physically
    -- smoothed by GIANTS. This only reconciles RE's memory so it does not
    -- immediately try to recreate the old rut state.
    return runtime.history:recoverParallelogram(
        g.xs,g.zs,g.xw,g.zw,g.xh,g.zh,
        {
            fraction=fraction,
            maxRaiseM=maxRaiseM,
            minRutM=Recovery.DEFAULTS.minHistoryRutM,
            cooldownMs=Recovery.DEFAULTS.historyCooldownMs,
            nowMs=nowMs,
            maxCells=Recovery.DEFAULTS.maxHistoryCellsPerCall
        },
        function(x,z,raiseM)
            -- Numeric return means logical relaxation only; v13 diagnostics
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
    local added = movedM * perMeter
    if added <= 0 then return end

    if vehicle == nil then return end
    local accumulationByArea = Recovery.accumulationByVehicle[vehicle]
    if accumulationByArea == nil then
        accumulationByArea = {}
        Recovery.accumulationByVehicle[vehicle] = accumulationByArea
    end
    local areaKey = g.node
    local accumulated = (accumulationByArea[areaKey] or 0) + added
    Recovery.stats.smoothingAttempts = Recovery.stats.smoothingAttempts + 1
    local rounded = DensityMapHeightUtil.getRoundedHeightValue ~= nil
        and DensityMapHeightUtil.getRoundedHeightValue(accumulated)
        or accumulated
    if rounded == nil or rounded <= 0 then
        accumulationByArea[areaKey] = accumulated
        return
    end
    accumulationByArea[areaKey] = math.max(0, accumulated - rounded)

    local physicalProbe = capturePhysicalProbe(g)
    if physicalProbe ~= nil then
        Recovery.stats.physicalProbeCalls = Recovery.stats.physicalProbeCalls + 1
        Recovery.stats.physicalProbeSamples =
            Recovery.stats.physicalProbeSamples + #physicalProbe
    end

    local ok = pcall(
        DensityMapHeightUtil.smoothAroundLine,
        g.node, g.width, radius, Recovery.DEFAULTS.overlap, rounded
    )
    if not ok then
        -- Do not consume distance when GIANTS rejected the operation.
        accumulationByArea[areaKey] = (accumulationByArea[areaKey] or 0) + rounded
        Recovery.stats.smoothingErrors = Recovery.stats.smoothingErrors + 1
        return
    end

    Recovery.stats.smoothingCalls = Recovery.stats.smoothingCalls + 1
    Recovery.stats.smoothAmount = Recovery.stats.smoothAmount + rounded

    local changed, changedSamples, absDeltaM, maxDeltaM =
        verifyPhysicalProbe(physicalProbe)

    if changed == nil then
        Recovery.stats.physicalUnverifiedCalls =
            Recovery.stats.physicalUnverifiedCalls + 1
        return
    end

    Recovery.stats.physicalChangedSamples =
        Recovery.stats.physicalChangedSamples + changedSamples
    Recovery.stats.physicalAbsDeltaM =
        Recovery.stats.physicalAbsDeltaM + absDeltaM
    Recovery.stats.physicalMaxDeltaM =
        math.max(Recovery.stats.physicalMaxDeltaM, maxDeltaM)

    if not changed then
        Recovery.stats.physicalNoChangeCalls =
            Recovery.stats.physicalNoChangeCalls + 1
        return
    end

    Recovery.stats.physicalChangedCalls =
        Recovery.stats.physicalChangedCalls + 1

    local runtime = RealismExtensionsTerrainRuntime
    local nowMs = g_currentMission ~= nil and g_currentMission.time or 0
    local cells, depth = relaxHistory(runtime, g, deep, nowMs, maxDeltaM)
    Recovery.stats.historyRelaxedCells =
        Recovery.stats.historyRelaxedCells + (cells or 0)
    Recovery.stats.historyRelaxedDepthM =
        Recovery.stats.historyRelaxedDepthM + (depth or 0)
end

function Recovery.processCultivatorArea(vehicle, superFunc, workArea, dt)
    Recovery.stats.workAreaCalls = Recovery.stats.workAreaCalls + 1
    local realArea, area = superFunc(vehicle, workArea, dt)
    if (tonumber(realArea) or 0) > 0 then
        Recovery.stats.workedAreaCalls = Recovery.stats.workedAreaCalls + 1

        -- Measure only RE's own post-processing. v12 incorrectly included the
        -- base Cultivator superFunc, so its recovery max/average could not be
        -- attributed to this module.
        local perfStarted = RealismExtensionsTerrainPerformance ~= nil
            and RealismExtensionsTerrainPerformance.begin() or nil
        smoothWorkedArea(vehicle, workArea, realArea, dt)
        if RealismExtensionsTerrainPerformance ~= nil then
            RealismExtensionsTerrainPerformance.finish("recovery", perfStarted)
        end
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
