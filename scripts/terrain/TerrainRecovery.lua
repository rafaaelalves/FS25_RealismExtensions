RealismExtensionsTerrainRecovery = RealismExtensionsTerrainRecovery or {}
local Recovery = RealismExtensionsTerrainRecovery

Recovery.VERSION = 10
Recovery.DEFAULTS = {
    -- Cultivation repair is a surface-conditioning pass, not a point repair.
    -- Cover the actual GIANTS work-area footprint uniformly and let native
    -- TerrainDeformation smoothing reduce local relief over repeated passes.
    -- Match the game's native Construction "Soften/Amenizar" primitive.
    -- ConstructionBrushSculpt uses a 2 m radius at its default 4 m cursor,
    -- hardness 0.2, smoothing height change 0.05 and effective strength 0.5.
    smoothAmountM = 0.050,
    smoothStrength = 0.50,
    smoothRadiusM = 2.00,
    brushHardness = 0.20,
    targetSpacingFactor = 0.85,
    maxBrushesPerWorkArea = 24,

    -- Cultivation owns the final surface state for a short window, mirroring
    -- vanilla Cultivator.processCultivatorArea() erasing tire tracks inside
    -- the worked parallelogram. Front wheels may rut first and are then
    -- repaired; trailing implement wheels cannot immediately undo the pass.
    protectionCellSizeM = 0.40,
    protectionDurationMs = 8000,

    -- A moving implement reports overlapping work areas every update. World
    -- space stamps ensure one physical patch is smoothed once per pass rather
    -- than being recursively re-selected while the callback is in flight.
    stampCellSizeM = 0.40,
    -- Native Construction smooth is continuous while the mouse is held.
    -- Revisit a worked patch during the same agricultural pass at a restrained
    -- cadence instead of giving it only one tiny native smoothing pulse.
    passageCooldownMs = 750,

    -- While a cultivator is genuinely processing ground, suspend only RE's
    -- persistent rut-writing for the complete tractor/implement combination.
    -- Contact, MR/Mud physics, footprint and visual tyre tracks remain active.
    activeCombinationGraceMs = 1500,

    -- Logical RE history follows verified reduction in physical roughness.
    -- Center-height sign is deliberately irrelevant: flattening a ridge may
    -- lower the center while still making the worked surface better.
    minRoughnessImprovementM = 0.00015,
    shallowHistoryFraction = 0.40,
    deepHistoryFraction = 0.30,
    shallowMaxHistoryRecoveryM = 0.025,
    deepMaxHistoryRecoveryM = 0.018,
    minHistoryRutM = 0.003
}

Recovery.processedStamps = Recovery.processedStamps or {}
Recovery.pendingStamps = Recovery.pendingStamps or {}
Recovery.protectedCells = Recovery.protectedCells or {}
Recovery.activeCombinationUntil = Recovery.activeCombinationUntil
    or setmetatable({}, { __mode = "k" })
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
    historyRecoveredDepthM = 0,
    protectedCellsMarked = 0,
    protectionSkips = 0,
    workAreaGeometrySamples = 0,
    minWorkAreaWidthM = nil,
    maxWorkAreaWidthM = 0,
    minWorkAreaDepthM = nil,
    maxWorkAreaDepthM = 0,
    activeCombinationMarks = 0,
    activeCombinationQueries = 0,
    activeCombinationHits = 0,
    physicalWorkAreaCalls = 0,
    changedWorkAreaCalls = 0,
    repeatWorkAreaCalls = 0,
    areaPositiveCalls = 0,
    preSuperActiveMarks = 0,
    changedAreaUnits = 0,
    processedAreaUnits = 0,
    repeatAreaUnits = 0
}

local function enabled()
    return RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.modules ~= nil
        and RealismExtensionsConfig.modules.TerrainDeformation == true
        and RealismExtensionsConfig.modules.TerrainRecovery == true
end

local function getCombinationRoot(vehicle)
    if vehicle == nil then return nil end
    if type(vehicle.getRootVehicle) == "function" then
        local ok, root = pcall(vehicle.getRootVehicle, vehicle)
        if ok and root ~= nil then return root end
    end

    local current = vehicle
    local seen = {}
    for _ = 1, 8 do
        if current == nil or seen[current] == true then break end
        seen[current] = true
        if type(current.getAttacherVehicle) ~= "function" then break end
        local ok, parent = pcall(current.getAttacherVehicle, current)
        if not ok or parent == nil or parent == current then break end
        current = parent
    end
    return current
end

local function markActiveCombination(vehicle, nowMs)
    local root = getCombinationRoot(vehicle)
    if root == nil or nowMs <= 0 then return end
    Recovery.activeCombinationUntil[root] =
        nowMs + Recovery.DEFAULTS.activeCombinationGraceMs
    Recovery.stats.activeCombinationMarks =
        Recovery.stats.activeCombinationMarks + 1
end

function Recovery.isRutGenerationSuppressed(vehicle, nowMs)
    Recovery.stats.activeCombinationQueries =
        Recovery.stats.activeCombinationQueries + 1
    local root = getCombinationRoot(vehicle)
    if root == nil then return false end
    nowMs = tonumber(nowMs) or (g_currentMission ~= nil and g_currentMission.time or 0)
    local expires = Recovery.activeCombinationUntil[root]
    if type(expires) ~= "number" then return false end
    if nowMs > 0 and expires < nowMs then
        Recovery.activeCombinationUntil[root] = nil
        return false
    end
    Recovery.stats.activeCombinationHits =
        Recovery.stats.activeCombinationHits + 1
    return true
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

local function pointInParallelogram(x,z,g)
    local det = g.ux * g.vz - g.uz * g.vx
    if math.abs(det) < 0.000001 then return false end
    local dx,dz = x-g.xs,z-g.zs
    local a = (dx*g.vz - dz*g.vx) / det
    local b = (g.ux*dz - g.uz*dx) / det
    return a >= -0.05 and a <= 1.05 and b >= -0.05 and b <= 1.05
end

local function protectionKey(x,z)
    local s=math.max(0.10,Recovery.DEFAULTS.protectionCellSizeM)
    return tostring(math.floor(x/s+0.5))..":"..tostring(math.floor(z/s+0.5))
end

local function protectWorkArea(g,nowMs)
    if nowMs<=0 then return end
    local s=math.max(0.10,Recovery.DEFAULTS.protectionCellSizeM)
    local xo,zo=g.xs+g.ux+g.vx,g.zs+g.uz+g.vz
    local minX=math.min(g.xs,g.xs+g.ux,g.xs+g.vx,xo)
    local maxX=math.max(g.xs,g.xs+g.ux,g.xs+g.vx,xo)
    local minZ=math.min(g.zs,g.zs+g.uz,g.zs+g.vz,zo)
    local maxZ=math.max(g.zs,g.zs+g.uz,g.zs+g.vz,zo)
    local marked=0
    for ix=math.floor(minX/s)-1,math.ceil(maxX/s)+1 do
        for iz=math.floor(minZ/s)-1,math.ceil(maxZ/s)+1 do
            local x,z=ix*s,iz*s
            if pointInParallelogram(x,z,g) then
                Recovery.protectedCells[tostring(ix)..":"..tostring(iz)] =
                    nowMs + Recovery.DEFAULTS.protectionDurationMs
                marked=marked+1
            end
        end
    end
    Recovery.stats.protectedCellsMarked =
        Recovery.stats.protectedCellsMarked + marked
end

function Recovery.isRecentlyCultivated(x,z,nowMs)
    if type(x)~="number" or type(z)~="number" then return false end
    nowMs=tonumber(nowMs) or (g_currentMission~=nil and g_currentMission.time or 0)
    local expires=Recovery.protectedCells[protectionKey(x,z)]
    if type(expires)~="number" then return false end
    if nowMs>0 and expires<nowMs then
        Recovery.protectedCells[protectionKey(x,z)]=nil
        return false
    end
    return true
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

local function cleanupOldStamps(nowMs)
    if nowMs <= 0 then return end
    local lastCleanup = Recovery._lastStampCleanupMs or 0
    if nowMs - lastCleanup < 10000 then return end
    Recovery._lastStampCleanupMs = nowMs
    local maxAge = math.max(20000, Recovery.DEFAULTS.passageCooldownMs * 4)
    for key, stampMs in pairs(Recovery.processedStamps) do
        if Recovery.pendingStamps[key] ~= true
            and type(stampMs) == "number"
            and nowMs - stampMs > maxAge then
            Recovery.processedStamps[key] = nil
        end
    end
    for key,expires in pairs(Recovery.protectedCells) do
        if type(expires)~="number" or expires<nowMs then
            Recovery.protectedCells[key]=nil
        end
    end
end

local function recoverWorkedArea(vehicle, workArea, processedArea)
    if not enabled() or (tonumber(processedArea) or 0) <= 0 then return end

    local runtime = RealismExtensionsTerrainRuntime
    if runtime == nil or runtime.history == nil or runtime.writer == nil
        or runtime.history.applyRecoveryCircle == nil then
        return
    end

    local g = getWorkAreaGeometry(workArea)
    if g == nil then return end

    Recovery.stats.workAreaGeometrySamples =
        Recovery.stats.workAreaGeometrySamples + 1
    Recovery.stats.minWorkAreaWidthM = Recovery.stats.minWorkAreaWidthM == nil
        and g.widthM or math.min(Recovery.stats.minWorkAreaWidthM, g.widthM)
    Recovery.stats.maxWorkAreaWidthM =
        math.max(Recovery.stats.maxWorkAreaWidthM, g.widthM)
    Recovery.stats.minWorkAreaDepthM = Recovery.stats.minWorkAreaDepthM == nil
        and g.depthM or math.min(Recovery.stats.minWorkAreaDepthM, g.depthM)
    Recovery.stats.maxWorkAreaDepthM =
        math.max(Recovery.stats.maxWorkAreaDepthM, g.depthM)

    local spec = vehicle ~= nil and vehicle.spec_cultivator or nil
    local deep = spec ~= nil and spec.useDeepMode == true
    local radius = Recovery.DEFAULTS.smoothRadiusM
    local smoothAmount = Recovery.DEFAULTS.smoothAmountM
    local strength = Recovery.DEFAULTS.smoothStrength
    local historyFraction = deep and Recovery.DEFAULTS.deepHistoryFraction
        or Recovery.DEFAULTS.shallowHistoryFraction
    local maxHistoryRecovery = deep and Recovery.DEFAULTS.deepMaxHistoryRecoveryM
        or Recovery.DEFAULTS.shallowMaxHistoryRecoveryM

    local nowMs = g_currentMission ~= nil and g_currentMission.time or 0
    cleanupOldStamps(nowMs)
    protectWorkArea(g,nowMs)
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

    -- GIANTS separates changed agricultural area (realArea) from total
    -- processed work area (area). realArea legitimately becomes zero when a
    -- cultivator passes over ground that is already cultivated. That must NOT
    -- mean the implement stopped physically working.
    local nowMs = g_currentMission ~= nil and g_currentMission.time or 0
    local specBefore = vehicle ~= nil and vehicle.spec_cultivator or nil
    local speedBefore = 0
    if vehicle ~= nil and type(vehicle.getLastSpeed) == "function" then
        local ok, value = pcall(vehicle.getLastSpeed, vehicle)
        if ok then speedBefore = tonumber(value) or 0 end
    end
    local preWorking = specBefore ~= nil
        and specBefore.isEnabled ~= false
        and speedBefore > 0.5

    -- processCultivatorArea itself is only invoked for an active work area.
    -- Mark before superFunc so wheel sampling later in the same frame cannot
    -- reopen persistent ruts merely because the density-map state is unchanged.
    if preWorking then
        markActiveCombination(vehicle, nowMs)
        Recovery.stats.preSuperActiveMarks =
            Recovery.stats.preSuperActiveMarks + 1
    end

    local realArea, area = superFunc(vehicle, workArea, dt)

    local spec = vehicle ~= nil and vehicle.spec_cultivator or nil
    local physicallyWorking = spec ~= nil
        and spec.isEnabled ~= false
        and spec.isWorking == true

    if physicallyWorking then
        Recovery.stats.physicalWorkAreaCalls =
            Recovery.stats.physicalWorkAreaCalls + 1

        local changedUnits = math.max(0, tonumber(realArea) or 0)
        local processedUnits = math.max(0, tonumber(area) or 0)
        Recovery.stats.changedAreaUnits =
            Recovery.stats.changedAreaUnits + changedUnits
        Recovery.stats.processedAreaUnits =
            Recovery.stats.processedAreaUnits + processedUnits
        if changedUnits <= 0 and processedUnits > 0 then
            Recovery.stats.repeatAreaUnits =
                Recovery.stats.repeatAreaUnits + processedUnits
        end

        -- Refresh if the pre-super speed state was unavailable/stale.
        if not preWorking then
            markActiveCombination(vehicle, nowMs)
        end

        if (tonumber(realArea) or 0) > 0 then
            Recovery.stats.changedWorkAreaCalls =
                Recovery.stats.changedWorkAreaCalls + 1
        else
            Recovery.stats.repeatWorkAreaCalls =
                Recovery.stats.repeatWorkAreaCalls + 1
        end

        if (tonumber(area) or 0) > 0 then
            Recovery.stats.workedAreaCalls = Recovery.stats.workedAreaCalls + 1
            Recovery.stats.areaPositiveCalls =
                Recovery.stats.areaPositiveCalls + 1

            local perfStarted = RealismExtensionsTerrainPerformance ~= nil
                and RealismExtensionsTerrainPerformance.begin() or nil

            -- Use total processed area, not changed area. Repeated passes must
            -- continue smoothing even when the vanilla field state no longer
            -- changes.
            recoverWorkedArea(vehicle, workArea, area)

            if RealismExtensionsTerrainPerformance ~= nil then
                RealismExtensionsTerrainPerformance.finish("recovery", perfStarted)
            end
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
