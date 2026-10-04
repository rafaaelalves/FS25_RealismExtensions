RealismExtensionsTerrainRecovery = RealismExtensionsTerrainRecovery or {}
local Recovery = RealismExtensionsTerrainRecovery

Recovery.VERSION = 11
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

    -- Strategy H: agricultural recovery is allowed only where SpatialHistory
    -- still carries RE-attributable rut debt. Candidate rut cells are clustered
    -- into native-smoothing centers instead of smoothing the full implement
    -- footprint blindly.
    historyIntentMaxCells = 512,
    minHistoryIntentRutM = 0.003,

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

    -- Recovery requested while a loaded wheel overlaps the smoothing footprint
    -- is not discarded. Keep a bounded, short-lived patch request and retry it
    -- after the vehicle/implement contact clears the area.
    deferredRetryMs = 200,
    deferredTtlMs = 5000,
    maxDeferredPatches = 2048,
    maxDeferredChecksPerUpdate = 16,

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

local function newStats()
    return {
        workAreaCalls = 0,
        workedAreaCalls = 0,
        coveragePoints = 0,
        intentCandidateCells = 0,
        intentPoints = 0,
        intentEmptyWorkAreas = 0,
        intentMaxRutM = 0,
        intentDeferredGone = 0,
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
        reliefVerified = 0,
        reliefImproved = 0,
        reliefWorsened = 0,
        reliefNeutral = 0,
        reliefImprovementM = 0,
        reliefWorseningM = 0,
        maxReliefBeforeM = 0,
        maxReliefAfterM = 0,
        centerRaised = 0,
        centerLowered = 0,
        historyRecoveredCells = 0,
        historyRecoveredDepthM = 0,
        protectedCellsMarked = 0,
        protectionSkips = 0,
        loadedContactQueries = 0,
        loadedContactSkips = 0,
        loadedContactMaxLoadN = 0,
        deferredCreated = 0,
        deferredCoalesced = 0,
        deferredChecks = 0,
        deferredStillBlocked = 0,
        deferredApplied = 0,
        deferredExpired = 0,
        deferredSuperseded = 0,
        deferredRejected = 0,
        deferredDroppedCapacity = 0,
        deferredQueuePeak = 0,
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
end

function Recovery.resetRuntimeState()
    Recovery.processedStamps = {}
    Recovery.pendingStamps = {}
    Recovery.protectedCells = {}
    Recovery.deferredByKey = {}
    Recovery.deferredQueue = {}
    Recovery.deferredQueueHead = 1
    Recovery.deferredCount = 0
    Recovery.activeCombinationUntil = setmetatable({}, { __mode = "k" })
    Recovery._lastStampCleanupMs = 0
    Recovery.stats = newStats()
end

if Recovery.stats == nil then
    Recovery.resetRuntimeState()
end

local function enabled()
    return RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.modules ~= nil
        and RealismExtensionsConfig.modules.TerrainDeformation == true
        and RealismExtensionsConfig.modules.TerrainRecovery == true
end

local function markActiveCombination(vehicle, nowMs)
    local workApi = RealismExtensionsTerrainWorkContext
    local root = workApi ~= nil
        and workApi.getCombinationRoot(vehicle) or vehicle
    if root == nil or nowMs <= 0 then return end

    Recovery.activeCombinationUntil[root] =
        nowMs + Recovery.DEFAULTS.activeCombinationGraceMs
    Recovery.stats.activeCombinationMarks =
        Recovery.stats.activeCombinationMarks + 1
end

function Recovery.isRutGenerationSuppressed(vehicle, nowMs)
    Recovery.stats.activeCombinationQueries =
        Recovery.stats.activeCombinationQueries + 1

    local workApi = RealismExtensionsTerrainWorkContext
    local root = workApi ~= nil
        and workApi.getCombinationRoot(vehicle) or vehicle
    if root == nil then return false end

    nowMs = tonumber(nowMs)
        or (g_currentMission ~= nil and g_currentMission.time or 0)
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

local function buildHistoryGuidedPoints(history, g, radius, nowMs)
    if history == nil
        or type(history.getRecoveryCandidatesParallelogram) ~= "function" then
        return {}
    end

    local candidates = history:getRecoveryCandidatesParallelogram(
        g.xs,
        g.zs,
        g.xs + g.ux,
        g.zs + g.uz,
        g.xs + g.vx,
        g.zs + g.vz,
        {
            minRutM = Recovery.DEFAULTS.minHistoryIntentRutM,
            nowMs = nowMs,
            cooldownMs = 0,
            maxCells = Recovery.DEFAULTS.historyIntentMaxCells
        }
    ) or {}

    Recovery.stats.intentCandidateCells =
        Recovery.stats.intentCandidateCells + #candidates

    if #candidates == 0 then
        Recovery.stats.intentEmptyWorkAreas =
            Recovery.stats.intentEmptyWorkAreas + 1
        return {}
    end

    local spacing = math.max(
        0.20,
        radius * Recovery.DEFAULTS.targetSpacingFactor
    )
    local groups = {}

    for _, candidate in ipairs(candidates) do
        local x = tonumber(candidate.x)
        local z = tonumber(candidate.z)
        local rut = math.max(0, tonumber(candidate.rutDepthM) or 0)
        if x ~= nil and z ~= nil
            and rut >= Recovery.DEFAULTS.minHistoryIntentRutM then
            local ix = math.floor(x / spacing + 0.5)
            local iz = math.floor(z / spacing + 0.5)
            local key = tostring(ix) .. ":" .. tostring(iz)
            local current = groups[key]
            if current == nil or rut > current.rutDepthM then
                groups[key] = {
                    x = x,
                    z = z,
                    rutDepthM = rut,
                    intentCellKey = candidate.key
                }
            end
            Recovery.stats.intentMaxRutM =
                math.max(Recovery.stats.intentMaxRutM, rut)
        end
    end

    local points = {}
    for _, point in pairs(groups) do
        points[#points + 1] = point
    end

    table.sort(points, function(a, b)
        if a.rutDepthM ~= b.rutDepthM then
            return a.rutDepthM > b.rutDepthM
        end
        if a.x ~= b.x then return a.x < b.x end
        return a.z < b.z
    end)

    local maxBrushes = math.max(
        1,
        math.floor(Recovery.DEFAULTS.maxBrushesPerWorkArea)
    )
    while #points > maxBrushes do
        points[#points] = nil
    end

    Recovery.stats.intentPoints =
        Recovery.stats.intentPoints + #points
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

local function queryLoadedContact(x, z, radius, nowMs)
    local registry = RealismExtensionsLoadedContactRegistry
    if registry == nil or type(registry.overlapsCircle) ~= "function" then
        return false, nil
    end

    Recovery.stats.loadedContactQueries =
        Recovery.stats.loadedContactQueries + 1

    local blocked, contact = registry.overlapsCircle(
        x, z, radius, nowMs
    )

    if blocked then
        Recovery.stats.loadedContactSkips =
            Recovery.stats.loadedContactSkips + 1
        if contact ~= nil then
            Recovery.stats.loadedContactMaxLoadN = math.max(
                Recovery.stats.loadedContactMaxLoadN,
                tonumber(contact.loadN) or 0
            )
        end
    end

    return blocked, contact
end

local function enqueueRecoveryPoint(runtime, point, key, params, nowMs, deferred)
    Recovery.pendingStamps[key] = true
    -- Claim the physical patch at enqueue time. Even a no-op smoothing result
    -- must not be hammered every frame of the same pass.
    Recovery.processedStamps[key] = nowMs

    local accepted = runtime.writer:enqueue({
        x = point.x,
        z = point.z,
        mode = "SMOOTH",
        smoothAmountM = params.smoothAmount,
        radiusM = params.radius,
        hardness = Recovery.DEFAULTS.brushHardness,
        strength = params.strength,
        source = "RECOVERY",
        probeRadiusM = params.radius * 0.75,
        onApplied = function(state, deltaY, beforeY, afterY, callbackVolume, geometry)
            Recovery.pendingStamps[key] = nil
            Recovery.stats.callbacks = Recovery.stats.callbacks + 1

            if type(deltaY) == "number" then
                if deltaY > 0.00005 then
                    Recovery.stats.centerRaised =
                        Recovery.stats.centerRaised + 1
                elseif deltaY < -0.00005 then
                    Recovery.stats.centerLowered =
                        Recovery.stats.centerLowered + 1
                end
            end

            local beforeRelief = geometry ~= nil
                and tonumber(geometry.reliefBeforeM) or nil
            local afterRelief = geometry ~= nil
                and tonumber(geometry.reliefAfterM) or nil
            if beforeRelief ~= nil and afterRelief ~= nil then
                Recovery.stats.reliefVerified =
                    Recovery.stats.reliefVerified + 1
                Recovery.stats.maxReliefBeforeM = math.max(
                    Recovery.stats.maxReliefBeforeM,
                    beforeRelief
                )
                Recovery.stats.maxReliefAfterM = math.max(
                    Recovery.stats.maxReliefAfterM,
                    afterRelief
                )

                local reliefImprovement = beforeRelief - afterRelief
                local reliefEpsilon =
                    Recovery.DEFAULTS.minRoughnessImprovementM
                if reliefImprovement > reliefEpsilon then
                    Recovery.stats.reliefImproved =
                        Recovery.stats.reliefImproved + 1
                    Recovery.stats.reliefImprovementM =
                        Recovery.stats.reliefImprovementM
                        + reliefImprovement
                elseif reliefImprovement < -reliefEpsilon then
                    Recovery.stats.reliefWorsened =
                        Recovery.stats.reliefWorsened + 1
                    Recovery.stats.reliefWorseningM =
                        Recovery.stats.reliefWorseningM
                        - reliefImprovement
                else
                    Recovery.stats.reliefNeutral =
                        Recovery.stats.reliefNeutral + 1
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

                -- This reconciliation rule remains intentionally unchanged
                -- during the deferred-safety experiment. A later geometry
                -- probe will decide whether roughness is sufficient to reduce
                -- logical rut history.
                local amount = math.min(
                    params.maxHistoryRecovery,
                    improvement
                )
                local cells, depth = runtime.history:applyRecoveryCircle(
                    point.x,
                    point.z,
                    params.radius,
                    amount,
                    params.historyFraction,
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
        if deferred then
            Recovery.stats.deferredApplied =
                Recovery.stats.deferredApplied + 1
        end
        return true
    end

    Recovery.pendingStamps[key] = nil
    Recovery.processedStamps[key] = nil
    Recovery.stats.brushesRejected =
        Recovery.stats.brushesRejected + 1
    if deferred then
        Recovery.stats.deferredRejected =
            Recovery.stats.deferredRejected + 1
    end
    return false
end

local function compactDeferredQueue()
    local head = Recovery.deferredQueueHead or 1
    local queue = Recovery.deferredQueue
    if head <= 512 or head <= #queue * 0.5 then return end

    local compact = {}
    for i = head, #queue do
        local entry = queue[i]
        if entry ~= nil and entry ~= false then
            compact[#compact + 1] = entry
        end
    end
    Recovery.deferredQueue = compact
    Recovery.deferredQueueHead = 1
end

local function removeDeferred(entry)
    if entry == nil then return end
    if Recovery.deferredByKey[entry.key] == entry then
        Recovery.deferredByKey[entry.key] = nil
        Recovery.deferredCount = math.max(
            0, (Recovery.deferredCount or 0) - 1
        )
    end
end

local function scheduleDeferred(point, key, params, nowMs)
    local existing = Recovery.deferredByKey[key]
    if existing ~= nil then
        existing.x = point.x
        existing.z = point.z
        existing.params = params
        existing.expiresAtMs =
            nowMs + Recovery.DEFAULTS.deferredTtlMs
        existing.lastRequestedMs = nowMs
        Recovery.stats.deferredCoalesced =
            Recovery.stats.deferredCoalesced + 1
        return true
    end

    if (Recovery.deferredCount or 0)
        >= Recovery.DEFAULTS.maxDeferredPatches then
        Recovery.stats.deferredDroppedCapacity =
            Recovery.stats.deferredDroppedCapacity + 1
        return false
    end

    local entry = {
        key = key,
        x = point.x,
        z = point.z,
        params = params,
        createdAtMs = nowMs,
        lastRequestedMs = nowMs,
        nextAttemptMs = nowMs + Recovery.DEFAULTS.deferredRetryMs,
        expiresAtMs = nowMs + Recovery.DEFAULTS.deferredTtlMs
    }

    Recovery.deferredByKey[key] = entry
    Recovery.deferredQueue[#Recovery.deferredQueue + 1] = entry
    Recovery.deferredCount = (Recovery.deferredCount or 0) + 1
    Recovery.stats.deferredCreated =
        Recovery.stats.deferredCreated + 1
    Recovery.stats.deferredQueuePeak = math.max(
        Recovery.stats.deferredQueuePeak,
        Recovery.deferredCount
    )
    return true
end

function Recovery.update(dt)
    if not enabled() or (Recovery.deferredCount or 0) <= 0 then
        return
    end

    local runtime = RealismExtensionsTerrainRuntime
    if runtime == nil or runtime.history == nil or runtime.writer == nil then
        return
    end

    local nowMs = g_currentMission ~= nil and g_currentMission.time or 0
    if nowMs <= 0 then return end

    local checks = 0
    local maxChecks = math.max(
        1,
        math.floor(Recovery.DEFAULTS.maxDeferredChecksPerUpdate)
    )

    while checks < maxChecks
        and Recovery.deferredQueueHead <= #Recovery.deferredQueue do
        local index = Recovery.deferredQueueHead
        local entry = Recovery.deferredQueue[index]
        Recovery.deferredQueue[index] = false
        Recovery.deferredQueueHead = index + 1

        if entry ~= nil and entry ~= false
            and Recovery.deferredByKey[entry.key] == entry then
            checks = checks + 1
            Recovery.stats.deferredChecks =
                Recovery.stats.deferredChecks + 1

            if nowMs > entry.expiresAtMs then
                removeDeferred(entry)
                Recovery.stats.deferredExpired =
                    Recovery.stats.deferredExpired + 1
            elseif not stampAvailable(entry.key, nowMs) then
                -- Another direct/deferred brush already handled this patch.
                removeDeferred(entry)
                Recovery.stats.deferredSuperseded =
                    Recovery.stats.deferredSuperseded + 1
            elseif nowMs < entry.nextAttemptMs then
                Recovery.deferredQueue[#Recovery.deferredQueue + 1] = entry
            else
                -- The brush center is a real SpatialHistory candidate cell.
                -- If another successful recovery already erased that local
                -- debt while this request waited under a loaded wheel, the
                -- physical smoothing request is no longer justified.
                local h = type(runtime.history.get) == "function"
                    and runtime.history:get(entry.x, entry.z) or nil
                local remainingRut = h ~= nil
                    and math.max(0, tonumber(h.rutDepthM) or 0) or 0
                if remainingRut < Recovery.DEFAULTS.minHistoryIntentRutM then
                    removeDeferred(entry)
                    Recovery.stats.intentDeferredGone =
                        Recovery.stats.intentDeferredGone + 1
                else
                    local blocked = queryLoadedContact(
                        entry.x,
                        entry.z,
                        entry.params.radius,
                        nowMs
                    )
                    if blocked then
                        entry.nextAttemptMs =
                            nowMs + Recovery.DEFAULTS.deferredRetryMs
                        Recovery.deferredQueue[#Recovery.deferredQueue + 1] = entry
                        Recovery.stats.deferredStillBlocked =
                            Recovery.stats.deferredStillBlocked + 1
                    else
                        local accepted = enqueueRecoveryPoint(
                            runtime,
                            {x=entry.x,z=entry.z},
                            entry.key,
                            entry.params,
                            nowMs,
                            true
                        )
                        if accepted then
                            removeDeferred(entry)
                        else
                            entry.nextAttemptMs =
                                nowMs + Recovery.DEFAULTS.deferredRetryMs
                            Recovery.deferredQueue[#Recovery.deferredQueue + 1] =
                                entry
                        end
                    end
                end
            end
        end
    end

    compactDeferredQueue()
end

local function recoverWorkedArea(vehicle, workArea, processedArea)
    if not enabled() or (tonumber(processedArea) or 0) <= 0 then return end

    local runtime = RealismExtensionsTerrainRuntime
    if runtime == nil or runtime.history == nil or runtime.writer == nil
        or runtime.history.applyRecoveryCircle == nil then
        return
    end

    local g = RealismExtensionsTerrainWorkContext ~= nil
        and RealismExtensionsTerrainWorkContext.getWorkAreaGeometry(workArea)
        or nil
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
    local params = {
        radius = radius,
        smoothAmount = Recovery.DEFAULTS.smoothAmountM,
        strength = Recovery.DEFAULTS.smoothStrength,
        historyFraction = deep
            and Recovery.DEFAULTS.deepHistoryFraction
            or Recovery.DEFAULTS.shallowHistoryFraction,
        maxHistoryRecovery = deep
            and Recovery.DEFAULTS.deepMaxHistoryRecoveryM
            or Recovery.DEFAULTS.shallowMaxHistoryRecoveryM
    }

    local nowMs = g_currentMission ~= nil and g_currentMission.time or 0
    cleanupOldStamps(nowMs)
    protectWorkArea(g, nowMs)
    local points = buildHistoryGuidedPoints(
        runtime.history,
        g,
        radius,
        nowMs
    )
    Recovery.stats.coveragePoints =
        Recovery.stats.coveragePoints + #points

    for _, point in ipairs(points) do
        local key = stampKey(point.x, point.z)
        if not stampAvailable(key, nowMs) then
            Recovery.stats.stampSkips =
                Recovery.stats.stampSkips + 1
        else
            local blocked = queryLoadedContact(
                point.x, point.z, radius, nowMs
            )
            if blocked then
                scheduleDeferred(point, key, params, nowMs)
            else
                enqueueRecoveryPoint(
                    runtime, point, key, params, nowMs, false
                )
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
    local workApi = RealismExtensionsTerrainWorkContext
    local pre = workApi ~= nil
        and workApi.captureCultivatorPre(vehicle, nowMs) or nil
    local preWorking = pre ~= nil and pre.potentiallyWorking == true

    -- processCultivatorArea itself is only invoked for an active work area.
    -- Mark before superFunc so wheel sampling later in the same frame cannot
    -- reopen persistent ruts merely because the density-map state is unchanged.
    if preWorking then
        markActiveCombination(vehicle, nowMs)
        Recovery.stats.preSuperActiveMarks =
            Recovery.stats.preSuperActiveMarks + 1
    end

    local realArea, area = superFunc(vehicle, workArea, dt)

    local operation = workApi ~= nil
        and workApi.captureCultivatorPost(
            vehicle, workArea, realArea, area, nowMs, pre
        ) or nil
    local physicallyWorking = operation ~= nil
        and operation.physicallyWorking == true

    if physicallyWorking then
        Recovery.stats.physicalWorkAreaCalls =
            Recovery.stats.physicalWorkAreaCalls + 1

        local changedUnits = operation.changedArea
        local processedUnits = operation.processedArea
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

        if operation.changedArea > 0 then
            Recovery.stats.changedWorkAreaCalls =
                Recovery.stats.changedWorkAreaCalls + 1
        else
            Recovery.stats.repeatWorkAreaCalls =
                Recovery.stats.repeatWorkAreaCalls + 1
        end

        if operation.processedArea > 0 then
            Recovery.stats.workedAreaCalls = Recovery.stats.workedAreaCalls + 1
            Recovery.stats.areaPositiveCalls =
                Recovery.stats.areaPositiveCalls + 1

            local perfStarted = RealismExtensionsTerrainPerformance ~= nil
                and RealismExtensionsTerrainPerformance.begin() or nil

            -- Use total processed area, not changed area. Repeated passes must
            -- continue smoothing even when the vanilla field state no longer
            -- changes.
            recoverWorkedArea(vehicle, workArea, operation.processedArea)

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
    out.deferredCount = Recovery.deferredCount or 0
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
