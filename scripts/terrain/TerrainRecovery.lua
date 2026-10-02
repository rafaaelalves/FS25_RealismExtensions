RealismExtensionsTerrainRecovery = RealismExtensionsTerrainRecovery or {}
local Recovery = RealismExtensionsTerrainRecovery

Recovery.VERSION = 5
Recovery.DEFAULTS = {
    -- Cultivation repair is a surface-conditioning pass, not a point repair.
    -- Cover the actual GIANTS work-area footprint uniformly and let native
    -- TerrainDeformation smoothing reduce local relief over repeated passes.
    shallowSmoothAmountM = 0.035,
    deepSmoothAmountM = 0.028,
    shallowStrength = 0.20,
    deepStrength = 0.16,
    shallowRadiusM = 0.55,
    deepRadiusM = 0.50,
    brushHardness = 0.22,
    targetSpacingFactor = 1.15,
    maxBrushesPerWorkArea = 24,

    -- A moving implement reports overlapping work areas every update. World
    -- space stamps ensure one physical patch is smoothed once per pass rather
    -- than being recursively re-selected while the callback is in flight.
    stampCellSizeM = 0.40,
    passageCooldownMs = 5000,

    -- Logical RE history follows verified reduction in physical roughness.
    -- Center-height sign is deliberately irrelevant: flattening a ridge may
    -- lower the center while still making the worked surface better.
    minRoughnessImprovementM = 0.00015,
    shallowHistoryFraction = 0.30,
    deepHistoryFraction = 0.20,
    shallowMaxHistoryRecoveryM = 0.015,
    deepMaxHistoryRecoveryM = 0.010,
    minHistoryRutM = 0.003
}

Recovery.processedStamps = Recovery.processedStamps or {}
Recovery.pendingStamps = Recovery.pendingStamps or {}
Recovery.stats = Recovery.stats or {
    workAreaCalls = 0,
    workedAreaCalls = 0,
    coveragePoints = 0,
    stampSkips = 0,
    brushesEnqueued = 0,
    brushesRejected = 0,
    callbacks = 0,
    roughnessVerified = 0,
    roughnessImproved = 0,
    roughnessWorsened = 0,
    roughnessNeutral = 0,
    roughnessImprovementM = 0,
    roughnessWorseningM = 0,
    centerRaised = 0,
    centerLowered = 0,
    historyRecoveredCells = 0,
    historyRecoveredDepthM = 0
}

local function enabled()
    return RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.modules ~= nil
        and RealismExtensionsConfig.modules.TerrainDeformation == true
        and RealismExtensionsConfig.modules.TerrainRecovery == true
end

local function getWorkAreaGeometry(workArea)
    if workArea == nil or workArea.start == nil
        or workArea.width == nil or workArea.height == nil then return nil end

    local okS, xs, _, zs = pcall(getWorldTranslation, workArea.start)
    local okW, xw, _, zw = pcall(getWorldTranslation, workArea.width)
    local okH, xh, _, zh = pcall(getWorldTranslation, workArea.height)
    if not okS or not okW or not okH then return nil end

    local ux, uz = xw - xs, zw - zs
    local vx, vz = xh - xs, zh - zs
    local widthM = math.sqrt(ux * ux + uz * uz)
    local depthM = math.sqrt(vx * vx + vz * vz)
    if widthM < 0.05 or depthM < 0.05 then return nil end

    return {
        xs=xs, zs=zs, ux=ux, uz=uz, vx=vx, vz=vz,
        widthM=widthM, depthM=depthM
    }
end

local function buildCoveragePoints(g, radius)
    local spacing = math.max(0.20, radius * Recovery.DEFAULTS.targetSpacingFactor)
    local maxBrushes = math.max(1, Recovery.DEFAULTS.maxBrushesPerWorkArea)

    local nx = math.max(1, math.ceil(g.widthM / spacing))
    local nz = math.max(1, math.ceil(g.depthM / spacing))
    while nx * nz > maxBrushes do
        spacing = spacing * 1.15
        nx = math.max(1, math.ceil(g.widthM / spacing))
        nz = math.max(1, math.ceil(g.depthM / spacing))
    end

    local points = {}
    for iz = 1, nz do
        local b = (iz - 0.5) / nz
        for ix = 1, nx do
            local a = (ix - 0.5) / nx
            points[#points + 1] = {
                x = g.xs + g.ux * a + g.vx * b,
                z = g.zs + g.uz * a + g.vz * b
            }
        end
    end
    return points
end

local function stampKey(x, z)
    local s = math.max(0.10, Recovery.DEFAULTS.stampCellSizeM)
    local ix = math.floor(x / s + 0.5)
    local iz = math.floor(z / s + 0.5)
    return tostring(ix) .. ":" .. tostring(iz)
end

local function stampAvailable(key, nowMs)
    if Recovery.pendingStamps[key] == true then return false end
    local last = Recovery.processedStamps[key]
    return last == nil or nowMs <= 0
        or nowMs - last >= Recovery.DEFAULTS.passageCooldownMs
end

local function recoverWorkedArea(vehicle, workArea, realArea)
    if not enabled() or (tonumber(realArea) or 0) <= 0 then return end

    local runtime = RealismExtensionsTerrainRuntime
    if runtime == nil or runtime.history == nil or runtime.writer == nil
        or runtime.history.applyRecoveryCircle == nil then
        return
    end

    local g = getWorkAreaGeometry(workArea)
    if g == nil then return end

    local spec = vehicle ~= nil and vehicle.spec_cultivator or nil
    local deep = spec ~= nil and spec.useDeepMode == true
    local radius = deep and Recovery.DEFAULTS.deepRadiusM
        or Recovery.DEFAULTS.shallowRadiusM
    local smoothAmount = deep and Recovery.DEFAULTS.deepSmoothAmountM
        or Recovery.DEFAULTS.shallowSmoothAmountM
    local strength = deep and Recovery.DEFAULTS.deepStrength
        or Recovery.DEFAULTS.shallowStrength
    local historyFraction = deep and Recovery.DEFAULTS.deepHistoryFraction
        or Recovery.DEFAULTS.shallowHistoryFraction
    local maxHistoryRecovery = deep and Recovery.DEFAULTS.deepMaxHistoryRecoveryM
        or Recovery.DEFAULTS.shallowMaxHistoryRecoveryM

    local nowMs = g_currentMission ~= nil and g_currentMission.time or 0
    local points = buildCoveragePoints(g, radius)
    Recovery.stats.coveragePoints = Recovery.stats.coveragePoints + #points

    for _, point in ipairs(points) do
        local key = stampKey(point.x, point.z)
        if not stampAvailable(key, nowMs) then
            Recovery.stats.stampSkips = Recovery.stats.stampSkips + 1
        else
            Recovery.pendingStamps[key] = true
            -- Claim the physical patch at enqueue time. Even a no-op smoothing
            -- result must not be hammered again every frame of the same pass.
            Recovery.processedStamps[key] = nowMs

            local accepted = runtime.writer:enqueue({
                x = point.x,
                z = point.z,
                mode = "SMOOTH",
                smoothAmountM = smoothAmount,
                radiusM = radius,
                hardness = Recovery.DEFAULTS.brushHardness,
                strength = strength,
                source = "RECOVERY",
                probeRadiusM = radius * 0.75,
                onApplied = function(state, deltaY, beforeY, afterY, callbackVolume, geometry)
                    Recovery.pendingStamps[key] = nil
                    Recovery.stats.callbacks = Recovery.stats.callbacks + 1

                    if type(deltaY) == "number" then
                        if deltaY > 0.00005 then
                            Recovery.stats.centerRaised = Recovery.stats.centerRaised + 1
                        elseif deltaY < -0.00005 then
                            Recovery.stats.centerLowered = Recovery.stats.centerLowered + 1
                        end
                    end

                    local beforeR = geometry ~= nil
                        and tonumber(geometry.roughnessBeforeM) or nil
                    local afterR = geometry ~= nil
                        and tonumber(geometry.roughnessAfterM) or nil
                    if beforeR == nil or afterR == nil then
                        Recovery.stats.roughnessNeutral =
                            Recovery.stats.roughnessNeutral + 1
                        return
                    end

                    Recovery.stats.roughnessVerified =
                        Recovery.stats.roughnessVerified + 1
                    local improvement = beforeR - afterR
                    local epsilon = Recovery.DEFAULTS.minRoughnessImprovementM

                    if improvement > epsilon then
                        Recovery.stats.roughnessImproved =
                            Recovery.stats.roughnessImproved + 1
                        Recovery.stats.roughnessImprovementM =
                            Recovery.stats.roughnessImprovementM + improvement

                        local amount = math.min(maxHistoryRecovery, improvement)
                        local cells, depth = runtime.history:applyRecoveryCircle(
                            point.x,
                            point.z,
                            radius,
                            amount,
                            historyFraction,
                            {
                                minRutM = Recovery.DEFAULTS.minHistoryRutM,
                                nowMs = g_currentMission ~= nil
                                    and g_currentMission.time or nowMs
                            }
                        )
                        Recovery.stats.historyRecoveredCells =
                            Recovery.stats.historyRecoveredCells + (cells or 0)
                        Recovery.stats.historyRecoveredDepthM =
                            Recovery.stats.historyRecoveredDepthM + (depth or 0)
                    elseif improvement < -epsilon then
                        Recovery.stats.roughnessWorsened =
                            Recovery.stats.roughnessWorsened + 1
                        Recovery.stats.roughnessWorseningM =
                            Recovery.stats.roughnessWorseningM - improvement
                    else
                        Recovery.stats.roughnessNeutral =
                            Recovery.stats.roughnessNeutral + 1
                    end
                end
            })

            if accepted then
                Recovery.stats.brushesEnqueued =
                    Recovery.stats.brushesEnqueued + 1
            else
                Recovery.pendingStamps[key] = nil
                Recovery.processedStamps[key] = nil
                Recovery.stats.brushesRejected =
                    Recovery.stats.brushesRejected + 1
            end
        end
    end
end

function Recovery.processCultivatorArea(vehicle, superFunc, workArea, dt)
    Recovery.stats.workAreaCalls = Recovery.stats.workAreaCalls + 1

    local realArea, area = superFunc(vehicle, workArea, dt)
    if (tonumber(realArea) or 0) > 0 then
        Recovery.stats.workedAreaCalls = Recovery.stats.workedAreaCalls + 1
        local perfStarted = RealismExtensionsTerrainPerformance ~= nil
            and RealismExtensionsTerrainPerformance.begin() or nil

        recoverWorkedArea(vehicle, workArea, realArea)

        if RealismExtensionsTerrainPerformance ~= nil then
            RealismExtensionsTerrainPerformance.finish("recovery", perfStarted)
        end
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
