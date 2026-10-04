RealismExtensionsTerrainRecovery = RealismExtensionsTerrainRecovery or {}
local Recovery = RealismExtensionsTerrainRecovery

Recovery.VERSION = 15
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
    -- R3 keeps fill footprints from overlapping along the same rut. R2 used
    -- ~0.30 m center spacing for 0.70 m diameter brushes, guaranteeing stacking.
    targetSpacingFactor = 2.10,
    maxBrushesPerWorkArea = 12,

    -- A centered native-smooth pulse is allowed to continue converging after
    -- the work-area callback has moved on. Manual landscaping succeeds partly
    -- because SOFTEN is applied repeatedly while dragging; machine recovery
    -- needs the same temporal property, but only on RE-owned rut centers.
    convergenceRetryMs = 150,
    convergenceTtlMs = 3000,
    maxConvergencePulses = 8,
    minCenterDeficitM = 0.003,
    minCenterRecoveryM = 0.00015,

    -- Strategy R2: recovery is a monotonic fill operation. Measure first,
    -- then raise only the RE-owned low point. No recovery actuator is allowed
    -- to lower terrain. The current local boundary plane is used only as the
    -- stop condition; total fill is additionally capped by remaining rut debt.
    structuralThresholdM = 0.003,
    structuralRadiusM = 0.30,
    structuralProbeRadiusM = 1.20,

    -- R3 is closed-loop. "command" is the opaque TerrainDeformation additive
    -- amount; "physical step" is measured world-space height. Runtime R2
    -- proved they are not 1:1 (<=27 mm command produced >1 m observed delta
    -- under overlap/stale sampling), so never treat command units as metres.
    structuralDesiredPhysicalStepM = 0.012,
    structuralDeficitFraction = 0.60,
    structuralInitialGain = 64.0,
    structuralGainMin = 0.5,
    structuralGainMax = 256.0,
    structuralGainAlpha = 0.50,
    structuralGainSafety = 0.70,
    structuralNoopGainDecay = 0.50,
    structuralCommandMin = 0.00002,
    structuralCommandMax = 0.00250,
    structuralOvershootToleranceM = 0.004,
    structuralStrength = 0.35,
    structuralHardness = 0.35,
    structuralRetryMs = 50,
    structuralTtlMs = 10000,
    structuralInFlightTimeoutMs = 2000,
    maxStructuralPulses = 48,

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

    -- Roughness/relief remain diagnostics. Logical rut debt is reconciled only
    -- from verified reduction of the causal center deficit at the exact
    -- SpatialHistory cell. A broad reduction in roughness is not sufficient.
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
        centerDeficitVerified = 0,
        centerDeficitImproved = 0,
        centerDeficitWorsened = 0,
        centerDeficitNeutral = 0,
        centerDeficitReductionM = 0,
        centerDeficitWorseningM = 0,
        maxCenterDeficitBeforeM = 0,
        maxCenterDeficitAfterM = 0,
        convergenceScheduled = 0,
        convergenceApplied = 0,
        convergenceCompleted = 0,
        convergenceStalled = 0,
        convergenceExpired = 0,
        structuralScheduled = 0,
        structuralApplied = 0,
        structuralCompleted = 0,
        structuralStalled = 0,
        structuralOwnershipExhausted = 0,
        structuralDeficitReductionM = 0,
        structuralCenterRaisedM = 0,
        structuralMaxDeficitBeforeM = 0,
        structuralMaxDeficitAfterM = 0,
        structuralLoweringViolations = 0,
        structuralNoopPulses = 0,
        structuralPreflightNoDeficit = 0,
        structuralOvershootCount = 0,
        structuralOvershootM = 0,
        structuralMaxOvershootM = 0,
        structuralGainSamples = 0,
        structuralObservedGainSum = 0,
        structuralObservedGainMax = 0,
        structuralCommandSum = 0,
        structuralCommandMax = 0,
        structuralInFlightTimeouts = 0,
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
    Recovery.structuralInFlightKey = nil
    Recovery.structuralInFlightSinceMs = 0
    Recovery.raiseGainEstimate = Recovery.DEFAULTS.structuralInitialGain
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

local scheduleDeferred
local enqueueStructuralRecoveryPoint

local function enqueueRecoveryPoint(runtime, point, key, params, nowMs, deferred, pulseIndex, deferredKind)
    pulseIndex = math.max(1, math.floor(tonumber(pulseIndex) or 1))
    Recovery.pendingStamps[key] = true

    -- Direct work-area requests claim the passage stamp. Convergence retries
    -- intentionally bypass this cadence: they are continuation of the same
    -- authorized repair, not a second agricultural pass.
    if deferredKind ~= "CONVERGENCE" then
        Recovery.processedStamps[key] = nowMs
    end

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

            -- Roughness remains useful telemetry, but it is no longer allowed
            -- to erase rut ownership. v23 could lower shoulders, improve RMS
            -- roughness, and incorrectly declare the wheel channel recovered.
            local beforeR = geometry ~= nil
                and tonumber(geometry.roughnessBeforeM) or nil
            local afterR = geometry ~= nil
                and tonumber(geometry.roughnessAfterM) or nil
            if beforeR ~= nil and afterR ~= nil then
                Recovery.stats.roughnessVerified =
                    Recovery.stats.roughnessVerified + 1
                local improvement = beforeR - afterR
                local epsilon = Recovery.DEFAULTS.minRoughnessImprovementM
                if improvement > epsilon then
                    Recovery.stats.roughnessImproved =
                        Recovery.stats.roughnessImproved + 1
                    Recovery.stats.roughnessImprovementM =
                        Recovery.stats.roughnessImprovementM + improvement
                elseif improvement < -epsilon then
                    Recovery.stats.roughnessWorsened =
                        Recovery.stats.roughnessWorsened + 1
                    Recovery.stats.roughnessWorseningM =
                        Recovery.stats.roughnessWorseningM - improvement
                else
                    Recovery.stats.roughnessNeutral =
                        Recovery.stats.roughnessNeutral + 1
                end
            else
                Recovery.stats.roughnessNeutral =
                    Recovery.stats.roughnessNeutral + 1
            end

            local beforeDeficit = geometry ~= nil
                and tonumber(geometry.centerDeficitBeforeM) or nil
            local afterDeficit = geometry ~= nil
                and tonumber(geometry.centerDeficitAfterM) or nil

            if beforeDeficit == nil or afterDeficit == nil then
                Recovery.stats.convergenceStalled =
                    Recovery.stats.convergenceStalled + 1
                return
            end

            Recovery.stats.centerDeficitVerified =
                Recovery.stats.centerDeficitVerified + 1
            Recovery.stats.maxCenterDeficitBeforeM = math.max(
                Recovery.stats.maxCenterDeficitBeforeM,
                beforeDeficit
            )
            Recovery.stats.maxCenterDeficitAfterM = math.max(
                Recovery.stats.maxCenterDeficitAfterM,
                afterDeficit
            )

            local centerImprovement = beforeDeficit - afterDeficit
            local centerEpsilon = Recovery.DEFAULTS.minCenterRecoveryM

            if centerImprovement > centerEpsilon then
                Recovery.stats.centerDeficitImproved =
                    Recovery.stats.centerDeficitImproved + 1
                Recovery.stats.centerDeficitReductionM =
                    Recovery.stats.centerDeficitReductionM
                    + centerImprovement

                -- Reconcile only the exact causal history cell represented by
                -- this centered brush. Never erase a 2 m circle merely because
                -- the surrounding region became a little less rough.
                if type(runtime.history.applyRecoveryAt) == "function" then
                    local amount = math.min(
                        params.maxHistoryRecovery,
                        centerImprovement
                    )
                    local applied = runtime.history:applyRecoveryAt(
                        point.x,
                        point.z,
                        amount,
                        {
                            minRutM = Recovery.DEFAULTS.minHistoryRutM,
                            nowMs = g_currentMission ~= nil
                                and g_currentMission.time or nowMs
                        }
                    )
                    if (tonumber(applied) or 0) > 0 then
                        Recovery.stats.historyRecoveredCells =
                            Recovery.stats.historyRecoveredCells + 1
                        Recovery.stats.historyRecoveredDepthM =
                            Recovery.stats.historyRecoveredDepthM
                            + applied
                    end
                end
            elseif centerImprovement < -centerEpsilon then
                Recovery.stats.centerDeficitWorsened =
                    Recovery.stats.centerDeficitWorsened + 1
                Recovery.stats.centerDeficitWorseningM =
                    Recovery.stats.centerDeficitWorseningM
                    - centerImprovement
            else
                Recovery.stats.centerDeficitNeutral =
                    Recovery.stats.centerDeficitNeutral + 1
            end

            -- Once the causal center is physically flat within tolerance,
            -- clear any remaining modeled debt at that exact cell. This
            -- prevents model over-estimation from keeping a repaired patch
            -- alive indefinitely.
            if afterDeficit <= Recovery.DEFAULTS.minCenterDeficitM
                and type(runtime.history.get) == "function"
                and type(runtime.history.applyRecoveryAt) == "function" then
                local h = runtime.history:get(point.x, point.z)
                local remainingRut = h ~= nil
                    and math.max(0, tonumber(h.rutDepthM) or 0) or 0
                if remainingRut >= Recovery.DEFAULTS.minHistoryRutM then
                    local applied = runtime.history:applyRecoveryAt(
                        point.x,
                        point.z,
                        remainingRut,
                        {
                            minRutM = Recovery.DEFAULTS.minHistoryRutM,
                            nowMs = g_currentMission ~= nil
                                and g_currentMission.time or nowMs
                        }
                    )
                    if (tonumber(applied) or 0) > 0 then
                        Recovery.stats.historyRecoveredCells =
                            Recovery.stats.historyRecoveredCells + 1
                        Recovery.stats.historyRecoveredDepthM =
                            Recovery.stats.historyRecoveredDepthM
                            + applied
                    end
                end
                Recovery.stats.convergenceCompleted =
                    Recovery.stats.convergenceCompleted + 1
                return
            end

            -- H2 proved native SMOOTH is excellent finishing work but a poor
            -- structural actuator: in runtime it mostly lowered shoulders.
            -- Once the measured center deficit is deeper than the finishing
            -- band, hand ownership to R1 and target the current local plane.
            if afterDeficit > Recovery.DEFAULTS.structuralThresholdM
                and type(runtime.history.get) == "function"
                and scheduleDeferred ~= nil then
                local h = runtime.history:get(point.x, point.z)
                local remainingRut = h ~= nil
                    and math.max(0, tonumber(h.rutDepthM) or 0) or 0
                local targetY = geometry ~= nil
                    and tonumber(geometry.referenceAfterY) or nil
                local planeAx = geometry ~= nil
                    and tonumber(geometry.planeAxAfter) or nil
                local planeAz = geometry ~= nil
                    and tonumber(geometry.planeAzAfter) or nil

                if remainingRut >= Recovery.DEFAULTS.minHistoryRutM
                    and targetY ~= nil and planeAx ~= nil and planeAz ~= nil then
                    local structuralParams = {
                        radius = Recovery.DEFAULTS.structuralRadiusM,
                        probeRadius = Recovery.DEFAULTS.smoothRadiusM * 0.75,
                        targetY = targetY,
                        targetPlaneAx = planeAx,
                        targetPlaneAz = planeAz,
                        maxStep = math.min(
                            Recovery.DEFAULTS.structuralMaxStepM,
                            remainingRut,
                            afterDeficit
                        ),
                        strength = Recovery.DEFAULTS.structuralStrength,
                        hardness = Recovery.DEFAULTS.structuralHardness,
                        finishParams = params
                    }

                    if scheduleDeferred(
                        point,
                        key,
                        structuralParams,
                        g_currentMission ~= nil
                            and g_currentMission.time or nowMs,
                        "STRUCTURAL",
                        1
                    ) then
                        Recovery.stats.structuralScheduled =
                            Recovery.stats.structuralScheduled + 1
                        return
                    end
                else
                    Recovery.stats.structuralOwnershipExhausted =
                        Recovery.stats.structuralOwnershipExhausted + 1
                end
            end

            -- Manual Landscaping SOFTEN is repeatedly applied while the cursor
            -- is dragged. Reproduce that temporal behavior only for the
            -- history-owned rut center, and stop on material worsening.
            if afterDeficit > Recovery.DEFAULTS.minCenterDeficitM
                and pulseIndex < Recovery.DEFAULTS.maxConvergencePulses
                and centerImprovement >= -centerEpsilon
                and scheduleDeferred ~= nil then
                if scheduleDeferred(
                    point,
                    key,
                    params,
                    g_currentMission ~= nil
                        and g_currentMission.time or nowMs,
                    "CONVERGENCE",
                    pulseIndex + 1
                ) then
                    Recovery.stats.convergenceScheduled =
                        Recovery.stats.convergenceScheduled + 1
                    return
                end
            end

            Recovery.stats.convergenceStalled =
                Recovery.stats.convergenceStalled + 1
        end
    })

    if accepted then
        Recovery.stats.brushesEnqueued =
            Recovery.stats.brushesEnqueued + 1
        if deferredKind == "CONVERGENCE" then
            Recovery.stats.convergenceApplied =
                Recovery.stats.convergenceApplied + 1
        elseif deferred then
            Recovery.stats.deferredApplied =
                Recovery.stats.deferredApplied + 1
        end
        return true
    end

    Recovery.pendingStamps[key] = nil
    if deferredKind ~= "CONVERGENCE" then
        Recovery.processedStamps[key] = nil
    end
    Recovery.stats.brushesRejected =
        Recovery.stats.brushesRejected + 1
    if deferred and deferredKind ~= "CONVERGENCE" then
        Recovery.stats.deferredRejected =
            Recovery.stats.deferredRejected + 1
    end
    return false
end


enqueueStructuralRecoveryPoint = function(runtime, point, key, params, nowMs, pulseIndex)
    pulseIndex = math.max(1, math.floor(tonumber(pulseIndex) or 1))

    if Recovery.structuralInFlightKey ~= nil then
        return false
    end

    local history = runtime.history
    local writer = runtime.writer
    local h = type(history.get) == "function"
        and history:get(point.x, point.z) or nil
    local remainingRut = h ~= nil
        and math.max(0, tonumber(h.rutDepthM) or 0) or 0

    if remainingRut < Recovery.DEFAULTS.minHistoryIntentRutM then
        Recovery.pendingStamps[key] = nil
        Recovery.stats.structuralOwnershipExhausted =
            Recovery.stats.structuralOwnershipExhausted + 1
        return true
    end

    -- Measure immediately before the actuator command. Work-area callbacks only
    -- schedule intent; they never pre-compute a raise against stale terrain.
    local beforeProbe = type(writer.measureRecoveryAt) == "function"
        and writer:measureRecoveryAt(
            point.x,
            point.z,
            params.probeRadius
        ) or nil

    if beforeProbe == nil then
        Recovery.pendingStamps[key] = nil
        Recovery.stats.structuralStalled =
            Recovery.stats.structuralStalled + 1
        return false
    end

    local beforeDeficit = math.max(
        0,
        tonumber(beforeProbe.centerDeficitM) or 0
    )
    Recovery.stats.structuralMaxDeficitBeforeM = math.max(
        Recovery.stats.structuralMaxDeficitBeforeM,
        beforeDeficit
    )

    if beforeDeficit <= Recovery.DEFAULTS.minCenterDeficitM then
        local applied = history:applyRecoveryAt(
            point.x,
            point.z,
            remainingRut,
            {
                minRutM = Recovery.DEFAULTS.minHistoryRutM,
                nowMs = nowMs
            }
        ) or 0
        if applied > 0 then
            Recovery.stats.historyRecoveredCells =
                Recovery.stats.historyRecoveredCells + 1
            Recovery.stats.historyRecoveredDepthM =
                Recovery.stats.historyRecoveredDepthM + applied
        end
        Recovery.stats.structuralPreflightNoDeficit =
            Recovery.stats.structuralPreflightNoDeficit + 1
        Recovery.stats.structuralCompleted =
            Recovery.stats.structuralCompleted + 1
        Recovery.processedStamps[key] = nowMs
        Recovery.pendingStamps[key] = nil
        return true
    end

    local desiredPhysicalM = math.min(
        Recovery.DEFAULTS.structuralDesiredPhysicalStepM,
        remainingRut,
        beforeDeficit * Recovery.DEFAULTS.structuralDeficitFraction
    )

    local gain = math.max(
        Recovery.DEFAULTS.structuralGainMin,
        math.min(
            Recovery.DEFAULTS.structuralGainMax,
            tonumber(Recovery.raiseGainEstimate)
                or Recovery.DEFAULTS.structuralInitialGain
        )
    )
    local commandM = desiredPhysicalM
        / math.max(Recovery.DEFAULTS.structuralGainMin, gain)
        * Recovery.DEFAULTS.structuralGainSafety
    commandM = math.max(
        Recovery.DEFAULTS.structuralCommandMin,
        math.min(Recovery.DEFAULTS.structuralCommandMax, commandM)
    )

    Recovery.stats.structuralCommandSum =
        Recovery.stats.structuralCommandSum + commandM
    Recovery.stats.structuralCommandMax = math.max(
        Recovery.stats.structuralCommandMax,
        commandM
    )

    Recovery.pendingStamps[key] = true
    Recovery.structuralInFlightKey = key
    Recovery.structuralInFlightSinceMs = nowMs
    if pulseIndex == 1 then
        Recovery.processedStamps[key] = nowMs
    end

    local accepted = writer:enqueue({
        x = point.x,
        z = point.z,
        mode = "RAISE",
        raiseHeightM = commandM,
        radiusM = params.radius,
        hardness = params.hardness,
        strength = params.strength,
        source = "RECOVERY",
        probeRadiusM = params.probeRadius,
        onApplied = function(state, deltaY, beforeY, afterY, callbackVolume, geometry)
            Recovery.pendingStamps[key] = nil
            if Recovery.structuralInFlightKey == key then
                Recovery.structuralInFlightKey = nil
                Recovery.structuralInFlightSinceMs = 0
            end
            Recovery.stats.callbacks = Recovery.stats.callbacks + 1

            local delta = tonumber(deltaY) or 0
            if delta > 0.00005 then
                Recovery.stats.centerRaised =
                    Recovery.stats.centerRaised + 1
            elseif delta < -0.00005 then
                Recovery.stats.centerLowered =
                    Recovery.stats.centerLowered + 1
                Recovery.stats.structuralLoweringViolations =
                    Recovery.stats.structuralLoweringViolations + 1
                Recovery.stats.structuralStalled =
                    Recovery.stats.structuralStalled + 1
                return
            end

            local beforeD = geometry ~= nil
                and tonumber(geometry.centerDeficitBeforeM)
                or beforeDeficit
            local afterD = geometry ~= nil
                and tonumber(geometry.centerDeficitAfterM) or nil
            local afterResidual = geometry ~= nil
                and tonumber(geometry.centerResidualAfterM) or nil

            if (afterD == nil or afterResidual == nil)
                and type(writer.measureRecoveryAt) == "function" then
                local post = writer:measureRecoveryAt(
                    point.x,
                    point.z,
                    params.probeRadius
                )
                if post ~= nil then
                    afterD = afterD ~= nil and afterD
                        or tonumber(post.centerDeficitM)
                    afterResidual = afterResidual ~= nil and afterResidual
                        or tonumber(post.centerResidualM)
                end
            end

            if beforeD ~= nil then
                Recovery.stats.structuralMaxDeficitBeforeM = math.max(
                    Recovery.stats.structuralMaxDeficitBeforeM,
                    beforeD
                )
            end
            if afterD ~= nil then
                Recovery.stats.structuralMaxDeficitAfterM = math.max(
                    Recovery.stats.structuralMaxDeficitAfterM,
                    afterD
                )
            end

            local raisedM = math.max(0, delta)
            if raisedM > Recovery.DEFAULTS.minCenterRecoveryM then
                local observedGain = raisedM / math.max(0.0000001, commandM)
                observedGain = math.max(
                    Recovery.DEFAULTS.structuralGainMin,
                    math.min(
                        Recovery.DEFAULTS.structuralGainMax,
                        observedGain
                    )
                )
                local alpha = Recovery.DEFAULTS.structuralGainAlpha
                Recovery.raiseGainEstimate =
                    (tonumber(Recovery.raiseGainEstimate)
                        or Recovery.DEFAULTS.structuralInitialGain)
                    * (1 - alpha)
                    + observedGain * alpha
                Recovery.stats.structuralGainSamples =
                    Recovery.stats.structuralGainSamples + 1
                Recovery.stats.structuralObservedGainSum =
                    Recovery.stats.structuralObservedGainSum + observedGain
                Recovery.stats.structuralObservedGainMax = math.max(
                    Recovery.stats.structuralObservedGainMax,
                    observedGain
                )

                Recovery.stats.structuralCenterRaisedM =
                    Recovery.stats.structuralCenterRaisedM + raisedM

                if beforeD ~= nil and afterD ~= nil then
                    Recovery.stats.structuralDeficitReductionM =
                        Recovery.stats.structuralDeficitReductionM
                        + math.max(0, beforeD - afterD)
                end

                -- Consume only verified useful fill, never the overshoot tail.
                local usefulFillM = math.min(
                    raisedM,
                    beforeDeficit,
                    remainingRut
                )
                local applied = history:applyRecoveryAt(
                    point.x,
                    point.z,
                    usefulFillM,
                    {
                        minRutM = Recovery.DEFAULTS.minHistoryRutM,
                        nowMs = g_currentMission ~= nil
                            and g_currentMission.time or nowMs
                    }
                ) or 0
                if applied > 0 then
                    Recovery.stats.historyRecoveredCells =
                        Recovery.stats.historyRecoveredCells + 1
                    Recovery.stats.historyRecoveredDepthM =
                        Recovery.stats.historyRecoveredDepthM + applied
                end
            else
                Recovery.stats.structuralNoopPulses =
                    Recovery.stats.structuralNoopPulses + 1
                Recovery.raiseGainEstimate = math.max(
                    Recovery.DEFAULTS.structuralGainMin,
                    (tonumber(Recovery.raiseGainEstimate)
                        or Recovery.DEFAULTS.structuralInitialGain)
                    * Recovery.DEFAULTS.structuralNoopGainDecay
                )
            end

            local overshootM = math.max(0, tonumber(afterResidual) or 0)
            if overshootM > Recovery.DEFAULTS.structuralOvershootToleranceM then
                Recovery.stats.structuralOvershootCount =
                    Recovery.stats.structuralOvershootCount + 1
                Recovery.stats.structuralOvershootM =
                    Recovery.stats.structuralOvershootM + overshootM
                Recovery.stats.structuralMaxOvershootM = math.max(
                    Recovery.stats.structuralMaxOvershootM,
                    overshootM
                )
            end

            if afterD ~= nil
                and afterD <= Recovery.DEFAULTS.minCenterDeficitM then
                local current = type(history.get) == "function"
                    and history:get(point.x, point.z) or nil
                local staleDebt = current ~= nil
                    and math.max(0, tonumber(current.rutDepthM) or 0) or 0
                if staleDebt >= Recovery.DEFAULTS.minHistoryRutM then
                    local applied = history:applyRecoveryAt(
                        point.x,
                        point.z,
                        staleDebt,
                        {
                            minRutM = Recovery.DEFAULTS.minHistoryRutM,
                            nowMs = g_currentMission ~= nil
                                and g_currentMission.time or nowMs
                        }
                    ) or 0
                    if applied > 0 then
                        Recovery.stats.historyRecoveredCells =
                            Recovery.stats.historyRecoveredCells + 1
                        Recovery.stats.historyRecoveredDepthM =
                            Recovery.stats.historyRecoveredDepthM + applied
                    end
                end
                Recovery.stats.structuralCompleted =
                    Recovery.stats.structuralCompleted + 1
                return
            end

            local current = type(history.get) == "function"
                and history:get(point.x, point.z) or nil
            local nextRut = current ~= nil
                and math.max(0, tonumber(current.rutDepthM) or 0) or 0

            if nextRut < Recovery.DEFAULTS.minHistoryIntentRutM then
                Recovery.stats.structuralOwnershipExhausted =
                    Recovery.stats.structuralOwnershipExhausted + 1
                return
            end

            if pulseIndex >= Recovery.DEFAULTS.maxStructuralPulses then
                Recovery.stats.structuralStalled =
                    Recovery.stats.structuralStalled + 1
                return
            end

            if scheduleDeferred ~= nil and scheduleDeferred(
                point,
                key,
                params,
                g_currentMission ~= nil
                    and g_currentMission.time or nowMs,
                "STRUCTURAL",
                pulseIndex + 1
            ) then
                Recovery.stats.structuralScheduled =
                    Recovery.stats.structuralScheduled + 1
            else
                Recovery.stats.structuralStalled =
                    Recovery.stats.structuralStalled + 1
            end
        end
    })

    if accepted then
        Recovery.stats.brushesEnqueued =
            Recovery.stats.brushesEnqueued + 1
        Recovery.stats.structuralApplied =
            Recovery.stats.structuralApplied + 1
        return true
    end

    Recovery.pendingStamps[key] = nil
    if Recovery.structuralInFlightKey == key then
        Recovery.structuralInFlightKey = nil
        Recovery.structuralInFlightSinceMs = 0
    end
    if pulseIndex == 1 then
        Recovery.processedStamps[key] = nil
    end
    Recovery.stats.brushesRejected =
        Recovery.stats.brushesRejected + 1
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

scheduleDeferred = function(point, key, params, nowMs, kind, pulseIndex)
    kind = kind or "BLOCKED"
    pulseIndex = math.max(1, math.floor(tonumber(pulseIndex) or 1))

    local existing = Recovery.deferredByKey[key]
    if existing ~= nil then
        existing.x = point.x
        existing.z = point.z
        existing.params = params
        existing.kind = kind
        existing.pulseIndex = math.max(
            tonumber(existing.pulseIndex) or 1,
            pulseIndex
        )
        existing.expiresAtMs = nowMs + (
            kind == "CONVERGENCE"
                and Recovery.DEFAULTS.convergenceTtlMs
            or kind == "STRUCTURAL"
                and Recovery.DEFAULTS.structuralTtlMs
            or Recovery.DEFAULTS.deferredTtlMs
        )
        existing.lastRequestedMs = nowMs
        existing.nextAttemptMs = math.min(
            tonumber(existing.nextAttemptMs) or math.huge,
            nowMs + (
                kind == "CONVERGENCE"
                    and Recovery.DEFAULTS.convergenceRetryMs
                or kind == "STRUCTURAL"
                    and Recovery.DEFAULTS.structuralRetryMs
                or Recovery.DEFAULTS.deferredRetryMs
            )
        )
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

    local retryMs = kind == "CONVERGENCE"
        and Recovery.DEFAULTS.convergenceRetryMs
        or kind == "STRUCTURAL"
            and Recovery.DEFAULTS.structuralRetryMs
        or Recovery.DEFAULTS.deferredRetryMs
    local ttlMs = kind == "CONVERGENCE"
        and Recovery.DEFAULTS.convergenceTtlMs
        or kind == "STRUCTURAL"
            and Recovery.DEFAULTS.structuralTtlMs
        or Recovery.DEFAULTS.deferredTtlMs

    local entry = {
        key = key,
        x = point.x,
        z = point.z,
        params = params,
        kind = kind,
        pulseIndex = pulseIndex,
        createdAtMs = nowMs,
        lastRequestedMs = nowMs,
        nextAttemptMs = nowMs + retryMs,
        expiresAtMs = nowMs + ttlMs
    }

    Recovery.deferredByKey[key] = entry
    Recovery.deferredQueue[#Recovery.deferredQueue + 1] = entry
    Recovery.deferredCount = (Recovery.deferredCount or 0) + 1

    if kind == "BLOCKED" then
        Recovery.stats.deferredCreated =
            Recovery.stats.deferredCreated + 1
    end

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

    -- One causal fill command at a time. This is intentional control-system
    -- serialization, not a performance accident: every next measurement must
    -- observe the terrain produced by the previous command.
    if Recovery.structuralInFlightKey ~= nil then
        local age = nowMs - (Recovery.structuralInFlightSinceMs or nowMs)
        if age < Recovery.DEFAULTS.structuralInFlightTimeoutMs then
            return
        end
        Recovery.structuralInFlightKey = nil
        Recovery.structuralInFlightSinceMs = 0
        Recovery.stats.structuralInFlightTimeouts =
            Recovery.stats.structuralInFlightTimeouts + 1
        Recovery.stats.structuralStalled =
            Recovery.stats.structuralStalled + 1
    end

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

            local isConvergence = entry.kind == "CONVERGENCE"
            local isStructural = entry.kind == "STRUCTURAL"

            if nowMs > entry.expiresAtMs then
                removeDeferred(entry)
                if isConvergence then
                    Recovery.stats.convergenceExpired =
                        Recovery.stats.convergenceExpired + 1
                elseif isStructural then
                    Recovery.stats.structuralStalled =
                        Recovery.stats.structuralStalled + 1
                else
                    Recovery.stats.deferredExpired =
                        Recovery.stats.deferredExpired + 1
                end
            elseif not isConvergence and not isStructural
                and not stampAvailable(entry.key, nowMs) then
                -- Another direct/deferred brush already handled this blocked
                -- first pulse. Convergence entries deliberately ignore passage
                -- stamps because they continue the same authorized repair.
                removeDeferred(entry)
                Recovery.stats.deferredSuperseded =
                    Recovery.stats.deferredSuperseded + 1
            elseif nowMs < entry.nextAttemptMs then
                Recovery.deferredQueue[#Recovery.deferredQueue + 1] = entry
            else
                local h = type(runtime.history.get) == "function"
                    and runtime.history:get(entry.x, entry.z) or nil
                local remainingRut = h ~= nil
                    and math.max(0, tonumber(h.rutDepthM) or 0) or 0

                -- SpatialHistory authorizes the initial repair location.
                -- Once a CONVERGENCE sequence has started, physical center
                -- deficit is authoritative for completion: logical debt may
                -- reach zero before the actual heightfield channel is flat.
                if not isConvergence
                    and remainingRut < Recovery.DEFAULTS.minHistoryIntentRutM then
                    removeDeferred(entry)
                    if isStructural then
                        Recovery.stats.structuralOwnershipExhausted =
                            Recovery.stats.structuralOwnershipExhausted + 1
                    else
                        Recovery.stats.intentDeferredGone =
                            Recovery.stats.intentDeferredGone + 1
                    end
                else
                    local blocked = queryLoadedContact(
                        entry.x,
                        entry.z,
                        entry.params.radius,
                        nowMs
                    )

                    if blocked then
                        entry.nextAttemptMs = nowMs + (
                            isConvergence
                                and Recovery.DEFAULTS.convergenceRetryMs
                            or isStructural
                                and Recovery.DEFAULTS.structuralRetryMs
                            or Recovery.DEFAULTS.deferredRetryMs
                        )
                        Recovery.deferredQueue[#Recovery.deferredQueue + 1] =
                            entry
                        Recovery.stats.deferredStillBlocked =
                            Recovery.stats.deferredStillBlocked + 1
                    else
                        -- Remove before execution so the completion callback can
                        -- schedule the next convergence pulse under the same
                        -- spatial key without being coalesced into a dying entry.
                        removeDeferred(entry)

                        local accepted
                        if isStructural then
                            accepted = enqueueStructuralRecoveryPoint(
                                runtime,
                                {x=entry.x,z=entry.z},
                                entry.key,
                                entry.params,
                                nowMs,
                                entry.pulseIndex
                            )
                        else
                            accepted = enqueueRecoveryPoint(
                                runtime,
                                {x=entry.x,z=entry.z},
                                entry.key,
                                entry.params,
                                nowMs,
                                true,
                                entry.pulseIndex,
                                entry.kind
                            )
                        end

                        if not accepted then
                            scheduleDeferred(
                                {x=entry.x,z=entry.z},
                                entry.key,
                                entry.params,
                                nowMs,
                                entry.kind,
                                entry.pulseIndex
                            )
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
        or type(runtime.history.getRecoveryCandidatesParallelogram) ~= "function"
        or type(runtime.history.applyRecoveryAt) ~= "function" then
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

    local radius = Recovery.DEFAULTS.structuralRadiusM
    local params = {
        radius = radius,
        probeRadius = Recovery.DEFAULTS.structuralProbeRadiusM,
        strength = Recovery.DEFAULTS.structuralStrength,
        hardness = Recovery.DEFAULTS.structuralHardness
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
            -- Work-area callbacks only authorize a causal patch. Execution is
            -- deferred so the controller can serialize, re-measure and apply
            -- exactly one fresh command at a time.
            if scheduleDeferred(
                point, key, params, nowMs, "STRUCTURAL", 1
            ) then
                Recovery.stats.structuralScheduled =
                    Recovery.stats.structuralScheduled + 1
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
    out.structuralInFlight = Recovery.structuralInFlightKey ~= nil
        and 1 or 0
    out.structuralGainEstimate = tonumber(Recovery.raiseGainEstimate)
        or Recovery.DEFAULTS.structuralInitialGain
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
