RealismExtensionsTerrainMaintenance =
    RealismExtensionsTerrainMaintenance or {}
local Maintenance = RealismExtensionsTerrainMaintenance

Maintenance.VERSION = 1

Maintenance.DEFAULTS = {
    minRutM = 0.003,
    toleranceM = 0.004,

    neighborMinAgePeriods = 1,
    municipalMinAgePeriods = 2,

    neighborRadiusM = 0.45,
    municipalRadiusM = 0.30,
    neighborProbeRadiusM = 1.25,
    municipalProbeRadiusM = 1.10,

    neighborTargetAmount = 0.75,
    municipalTargetAmount = 0.70,
    neighborStrength = 0.35,
    municipalStrength = 0.30,
    neighborHardness = 0.20,
    municipalHardness = 0.18,

    neighborMaxPulses = 3,
    municipalMaxPulses = 2,

    neighborSpacingM = 0.68,
    municipalSpacingM = 0.60,
    maxNeighborPatchesPerPeriod = 256,
    maxMunicipalPatchesPerPeriod = 128,

    maxPatchCells = 64,
    maxBlockedRetries = 20,
    blockedRetryMs = 750
}

Maintenance.initialized = false
Maintenance.queue = {}
Maintenance.queueHead = 1
Maintenance.queueTail = 0
Maintenance.queueCount = 0
Maintenance.inFlight = false

local function resetStats()
    Maintenance.stats = {
        periods = 0,
        historyScanned = 0,
        eligibleNeighborCells = 0,
        eligibleMunicipalCells = 0,
        neighborBuckets = 0,
        municipalBuckets = 0,
        queuedNeighbor = 0,
        queuedMunicipal = 0,
        queueSuperseded = 0,

        tasksStarted = 0,
        targetApplied = 0,
        completed = 0,
        staleDebtCleared = 0,
        blockedContacts = 0,
        blockedExpired = 0,
        boundaryRejected = 0,
        surfaceRejected = 0,
        ownershipChanged = 0,
        historyGone = 0,
        probeFailed = 0,
        targetRejected = 0,
        callbackFailed = 0,

        patchCellsExamined = 0,
        patchCellsRecovered = 0,
        patchRecoveredDepthM = 0,
        historyRetiredObserved = 0,

        neighborCompleted = 0,
        municipalCompleted = 0,
        maxQueue = 0
    }
end
resetStats()

local function enabled()
    local modules = RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.modules or nil
    return modules ~= nil
        and modules.TerrainDeformation == true
        and modules.TerrainMaintenance == true
end

local function runtime()
    return RealismExtensionsTerrainRuntime
end

local function queueReset()
    Maintenance.queue = {}
    Maintenance.queueHead = 1
    Maintenance.queueTail = 0
    Maintenance.queueCount = 0
end

local function queuePush(task)
    Maintenance.queueTail = Maintenance.queueTail + 1
    Maintenance.queue[Maintenance.queueTail] = task
    Maintenance.queueCount = Maintenance.queueCount + 1
    Maintenance.stats.maxQueue = math.max(
        Maintenance.stats.maxQueue,
        Maintenance.queueCount
    )
end

local function queuePop()
    if Maintenance.queueCount <= 0 then return nil end
    local task = Maintenance.queue[Maintenance.queueHead]
    Maintenance.queue[Maintenance.queueHead] = nil
    Maintenance.queueHead = Maintenance.queueHead + 1
    Maintenance.queueCount = Maintenance.queueCount - 1

    if Maintenance.queueCount <= 0 then queueReset() end
    return task
end

local function localFarmId()
    if g_currentMission ~= nil
        and type(g_currentMission.getFarmId) == "function" then
        local ok, id = pcall(g_currentMission.getFarmId, g_currentMission)
        if ok then return id end
    end
    return nil
end

local function taskProfile(maintainer)
    local policy = RealismExtensionsTerrainMaintenancePolicy
    if policy ~= nil
        and maintainer == policy.MAINTAINER.MUNICIPAL then
        return {
            radiusM = Maintenance.DEFAULTS.municipalRadiusM,
            probeRadiusM = Maintenance.DEFAULTS.municipalProbeRadiusM,
            targetAmount = Maintenance.DEFAULTS.municipalTargetAmount,
            strength = Maintenance.DEFAULTS.municipalStrength,
            hardness = Maintenance.DEFAULTS.municipalHardness,
            maxPulses = Maintenance.DEFAULTS.municipalMaxPulses,
            minAgePeriods = Maintenance.DEFAULTS.municipalMinAgePeriods
        }
    end

    return {
        radiusM = Maintenance.DEFAULTS.neighborRadiusM,
        probeRadiusM = Maintenance.DEFAULTS.neighborProbeRadiusM,
        targetAmount = Maintenance.DEFAULTS.neighborTargetAmount,
        strength = Maintenance.DEFAULTS.neighborStrength,
        hardness = Maintenance.DEFAULTS.neighborHardness,
        maxPulses = Maintenance.DEFAULTS.neighborMaxPulses,
        minAgePeriods = Maintenance.DEFAULTS.neighborMinAgePeriods
    }
end

local function bucketKey(x, z, spacingM)
    local spacing = math.max(0.10, tonumber(spacingM) or 0.60)
    local ix = math.floor((x / spacing) + 0.5)
    local iz = math.floor((z / spacing) + 0.5)
    return tostring(ix) .. ":" .. tostring(iz)
end

local function putBucket(bucket, x, z, h, maintainer, spacingM)
    local key = bucketKey(x, z, spacingM)
    local rut = math.max(0, tonumber(h.rutDepthM) or 0)
    local age = math.max(
        0,
        math.floor(tonumber(h.maintenanceAgePeriods) or 0)
    )
    local score = age * 0.01 + rut
    local current = bucket[key]

    if current == nil or score > current.score then
        bucket[key] = {
            x = x,
            z = z,
            maintainer = maintainer,
            agePeriods = age,
            rutDepthM = rut,
            score = score,
            attempts = 0,
            blockedRetries = 0,
            notBeforeMs = 0
        }
    end
end

local function bucketArray(bucket)
    local out = {}
    for _, task in pairs(bucket) do out[#out + 1] = task end
    table.sort(out, function(a, b)
        if a.agePeriods ~= b.agePeriods then
            return a.agePeriods > b.agePeriods
        end
        if a.rutDepthM ~= b.rutDepthM then
            return a.rutDepthM > b.rutDepthM
        end
        if a.x ~= b.x then return a.x < b.x end
        return a.z < b.z
    end)
    return out
end

local function buildPeriodQueue()
    local rt = runtime()
    local history = rt ~= nil and rt.history or nil
    local policy = RealismExtensionsTerrainMaintenancePolicy
    if history == nil or policy == nil
        or type(history.advanceMaintenancePeriod) ~= "function" then
        return false
    end

    if Maintenance.queueCount > 0 then
        Maintenance.stats.queueSuperseded =
            Maintenance.stats.queueSuperseded + Maintenance.queueCount
    end
    queueReset()

    local neighbor = {}
    local municipal = {}
    local farmId = localFarmId()
    local classCache = {}

    local scanned = history:advanceMaintenancePeriod(function(_, x, z, h)
        local rut = math.max(0, tonumber(h.rutDepthM) or 0)
        if rut < Maintenance.DEFAULTS.minRutM then return end

        local farmlandId = type(policy.getFarmlandIdAt) == "function"
            and policy.getFarmlandIdAt(x, z) or nil
        local cacheKey = farmlandId == nil and "__nil" or tostring(farmlandId)
        local classification = classCache[cacheKey]
        if classification == nil then
            classification = type(policy.classifyFarmlandId) == "function"
                and policy.classifyFarmlandId(farmlandId, farmId)
                or policy.classifyAt(x, z, farmId)
            classCache[cacheKey] = classification
        end

        local age = math.max(
            0,
            math.floor(tonumber(h.maintenanceAgePeriods) or 0)
        )

        if classification.maintainer == policy.MAINTAINER.NEIGHBOR
            and age >= Maintenance.DEFAULTS.neighborMinAgePeriods then
            Maintenance.stats.eligibleNeighborCells =
                Maintenance.stats.eligibleNeighborCells + 1
            putBucket(
                neighbor, x, z, h,
                policy.MAINTAINER.NEIGHBOR,
                Maintenance.DEFAULTS.neighborSpacingM
            )
        elseif classification.maintainer == policy.MAINTAINER.MUNICIPAL
            and age >= Maintenance.DEFAULTS.municipalMinAgePeriods then
            Maintenance.stats.eligibleMunicipalCells =
                Maintenance.stats.eligibleMunicipalCells + 1
            putBucket(
                municipal, x, z, h,
                policy.MAINTAINER.MUNICIPAL,
                Maintenance.DEFAULTS.municipalSpacingM
            )
        end
    end)

    Maintenance.stats.historyScanned =
        Maintenance.stats.historyScanned + (tonumber(scanned) or 0)

    local neighborTasks = bucketArray(neighbor)
    local municipalTasks = bucketArray(municipal)
    Maintenance.stats.neighborBuckets =
        Maintenance.stats.neighborBuckets + #neighborTasks
    Maintenance.stats.municipalBuckets =
        Maintenance.stats.municipalBuckets + #municipalTasks

    local nMax = math.min(
        #neighborTasks,
        Maintenance.DEFAULTS.maxNeighborPatchesPerPeriod
    )
    local mMax = math.min(
        #municipalTasks,
        Maintenance.DEFAULTS.maxMunicipalPatchesPerPeriod
    )

    -- Interleave responsibility classes so a heavily damaged NPC field cannot
    -- delay every public-road repair until the tail of a long monthly queue.
    local ni, mi = 1, 1
    while ni <= nMax or mi <= mMax do
        if ni <= nMax then
            queuePush(neighborTasks[ni])
            ni = ni + 1
            Maintenance.stats.queuedNeighbor =
                Maintenance.stats.queuedNeighbor + 1
        end
        if mi <= mMax then
            queuePush(municipalTasks[mi])
            mi = mi + 1
            Maintenance.stats.queuedMunicipal =
                Maintenance.stats.queuedMunicipal + 1
        end
    end

    return true
end

local function municipalSurfaceEligible(x, z, radiusM)
    local surface = RealismExtensionsTerrainSurfaceResponse
    if surface == nil
        or type(surface.isMunicipalMaintenanceSurface) ~= "function" then
        return false
    end

    local r = math.max(0, tonumber(radiusM) or 0) * 0.75
    local samples = {
        {0, 0},
        {r, 0}, {-r, 0}, {0, r}, {0, -r}
    }

    for _, o in ipairs(samples) do
        local ok = surface.isMunicipalMaintenanceSurface(
            x + o[1],
            z + o[2]
        )
        if ok ~= true then return false end
    end
    return true
end

local function queryLoadedContact(x, z, radiusM, nowMs)
    local registry = RealismExtensionsLoadedContactRegistry
    if registry == nil or type(registry.overlapsCircle) ~= "function" then
        return false
    end
    local blocked = registry.overlapsCircle(x, z, radiusM, nowMs)
    return blocked == true
end

local function sameMaintainerCircle(task, radiusM)
    local policy = RealismExtensionsTerrainMaintenancePolicy
    return policy ~= nil
        and type(policy.circleHasMaintainer) == "function"
        and policy.circleHasMaintainer(
            task.x,
            task.z,
            radiusM,
            task.maintainer,
            localFarmId()
        ) == true
end

local function reconcilePatch(task, probe, radiusM, nowMs)
    local rt = runtime()
    local history = rt ~= nil and rt.history or nil
    local writer = rt ~= nil and rt.writer or nil
    local policy = RealismExtensionsTerrainMaintenancePolicy

    if history == nil or writer == nil or policy == nil
        or type(history.getRecoveryCellsCircle) ~= "function"
        or type(history.applyRecoveryAt) ~= "function"
        or type(writer.sampleHeightAt) ~= "function" then
        return 0, 0
    end

    local cells = history:getRecoveryCellsCircle(
        task.x,
        task.z,
        radiusM,
        {
            minRutM = Maintenance.DEFAULTS.minRutM,
            maxCells = Maintenance.DEFAULTS.maxPatchCells
        }
    ) or {}

    Maintenance.stats.patchCellsExamined =
        Maintenance.stats.patchCellsExamined + #cells

    local recoveredCells, recoveredDepth = 0, 0
    local targetY = tonumber(probe.referenceCenterY)
    local planeAx = tonumber(probe.planeAx)
    local planeAz = tonumber(probe.planeAz)
    if targetY == nil or planeAx == nil or planeAz == nil then
        return 0, 0
    end

    for _, cell in ipairs(cells) do
        local classification = policy.classifyAt(
            cell.x,
            cell.z,
            localFarmId()
        )
        if classification.maintainer == task.maintainer then
            local terrainY = writer:sampleHeightAt(cell.x, cell.z)
            if type(terrainY) == "number" then
                local expectedY = targetY
                    + planeAx * (cell.x - task.x)
                    + planeAz * (cell.z - task.z)
                if math.abs(terrainY - expectedY)
                    <= Maintenance.DEFAULTS.toleranceM then
                    local h = type(history.get) == "function"
                        and history:get(cell.x, cell.z) or nil
                    local debt = h ~= nil
                        and math.max(0, tonumber(h.rutDepthM) or 0) or 0
                    if debt >= Maintenance.DEFAULTS.minRutM then
                        local applied = history:applyRecoveryAt(
                            cell.x,
                            cell.z,
                            debt,
                            {
                                minRutM = Maintenance.DEFAULTS.minRutM,
                                nowMs = nowMs
                            }
                        ) or 0
                        if applied > 0 then
                            recoveredCells = recoveredCells + 1
                            recoveredDepth = recoveredDepth + applied
                        end
                    end
                end
            end
        end
    end

    Maintenance.stats.patchCellsRecovered =
        Maintenance.stats.patchCellsRecovered + recoveredCells
    Maintenance.stats.patchRecoveredDepthM =
        Maintenance.stats.patchRecoveredDepthM + recoveredDepth

    return recoveredCells, recoveredDepth
end

local function clearCenterStaleDebt(task, nowMs)
    local rt = runtime()
    local history = rt ~= nil and rt.history or nil
    if history == nil or type(history.get) ~= "function"
        or type(history.applyRecoveryAt) ~= "function" then
        return 0
    end

    local h = history:get(task.x, task.z)
    local debt = h ~= nil
        and math.max(0, tonumber(h.rutDepthM) or 0) or 0
    if debt < Maintenance.DEFAULTS.minRutM then return 0 end

    local applied = history:applyRecoveryAt(
        task.x,
        task.z,
        debt,
        {
            minRutM = Maintenance.DEFAULTS.minRutM,
            nowMs = nowMs
        }
    ) or 0

    if applied > 0 then
        Maintenance.stats.staleDebtCleared =
            Maintenance.stats.staleDebtCleared + 1
        Maintenance.stats.patchRecoveredDepthM =
            Maintenance.stats.patchRecoveredDepthM + applied
    end
    return applied
end

local function finishTask(task)
    Maintenance.stats.completed = Maintenance.stats.completed + 1
    local policy = RealismExtensionsTerrainMaintenancePolicy
    if policy ~= nil
        and task.maintainer == policy.MAINTAINER.MUNICIPAL then
        Maintenance.stats.municipalCompleted =
            Maintenance.stats.municipalCompleted + 1
    else
        Maintenance.stats.neighborCompleted =
            Maintenance.stats.neighborCompleted + 1
    end
end

local function requeue(task, delayMs, nowMs)
    task.notBeforeMs = (tonumber(nowMs) or 0)
        + math.max(0, tonumber(delayMs) or 0)
    queuePush(task)
end

local function recoveryBusy()
    local recovery = RealismExtensionsTerrainRecovery
    if recovery == nil or type(recovery.getDiagnostics) ~= "function" then
        return false
    end
    local d = recovery.getDiagnostics() or {}
    return (tonumber(d.structuralInFlight) or 0) > 0
end

local function writerBusy()
    local rt = runtime()
    local writer = rt ~= nil and rt.writer or nil
    if writer == nil then return true end
    if type(writer.getQueueSize) == "function" then
        return writer:getQueueSize() > 0
    end
    return false
end

local function processTask(task, nowMs)
    local rt = runtime()
    local history = rt ~= nil and rt.history or nil
    local writer = rt ~= nil and rt.writer or nil
    local policy = RealismExtensionsTerrainMaintenancePolicy
    if history == nil or writer == nil or policy == nil then return end

    local h = type(history.get) == "function"
        and history:get(task.x, task.z) or nil
    if h == nil
        or math.max(0, tonumber(h.rutDepthM) or 0)
            < Maintenance.DEFAULTS.minRutM then
        Maintenance.stats.historyGone = Maintenance.stats.historyGone + 1
        return
    end

    local profile = taskProfile(task.maintainer)
    local age = math.max(
        0,
        math.floor(tonumber(h.maintenanceAgePeriods) or 0)
    )
    if age < profile.minAgePeriods then
        -- New traffic touched this cell after the monthly queue was built.
        Maintenance.stats.historyGone = Maintenance.stats.historyGone + 1
        return
    end

    local classification = policy.classifyAt(
        task.x,
        task.z,
        localFarmId()
    )
    if classification.maintainer ~= task.maintainer then
        Maintenance.stats.ownershipChanged =
            Maintenance.stats.ownershipChanged + 1
        return
    end

    if not sameMaintainerCircle(task, profile.radiusM) then
        Maintenance.stats.boundaryRejected =
            Maintenance.stats.boundaryRejected + 1
        return
    end

    if task.maintainer == policy.MAINTAINER.MUNICIPAL
        and not municipalSurfaceEligible(
            task.x,
            task.z,
            profile.radiusM
        ) then
        Maintenance.stats.surfaceRejected =
            Maintenance.stats.surfaceRejected + 1
        return
    end

    if queryLoadedContact(task.x, task.z, profile.radiusM, nowMs) then
        Maintenance.stats.blockedContacts =
            Maintenance.stats.blockedContacts + 1
        task.blockedRetries = (task.blockedRetries or 0) + 1
        if task.blockedRetries <= Maintenance.DEFAULTS.maxBlockedRetries then
            requeue(
                task,
                Maintenance.DEFAULTS.blockedRetryMs,
                nowMs
            )
        else
            Maintenance.stats.blockedExpired =
                Maintenance.stats.blockedExpired + 1
        end
        return
    end

    local probe = type(writer.measureRecoveryAt) == "function"
        and writer:measureRecoveryAt(
            task.x,
            task.z,
            profile.probeRadiusM
        ) or nil
    if probe == nil then
        Maintenance.stats.probeFailed = Maintenance.stats.probeFailed + 1
        return
    end

    local residual = tonumber(probe.centerResidualM)
    if residual == nil then
        Maintenance.stats.probeFailed = Maintenance.stats.probeFailed + 1
        return
    end

    Maintenance.stats.tasksStarted = Maintenance.stats.tasksStarted + 1

    if residual >= -Maintenance.DEFAULTS.toleranceM then
        reconcilePatch(
            task,
            probe,
            profile.radiusM,
            nowMs
        )
        if residual > Maintenance.DEFAULTS.toleranceM then
            clearCenterStaleDebt(task, nowMs)
        end
        finishTask(task)
        return
    end

    task.attempts = (task.attempts or 0) + 1
    Maintenance.inFlight = true

    local accepted = writer:enqueue({
        x = task.x,
        z = task.z,
        mode = "TARGET",
        targetY = probe.referenceCenterY,
        targetPlaneAx = probe.planeAx,
        targetPlaneAz = probe.planeAz,
        targetAmount = profile.targetAmount,
        radiusM = profile.radiusM,
        hardness = profile.hardness,
        strength = profile.strength,
        source = "MAINTENANCE",
        probeRadiusM = profile.probeRadiusM,
        recoveryPreProbe = probe,
        onApplied = function(_, _, _, _, _, geometry)
            Maintenance.inFlight = false
            Maintenance.stats.targetApplied =
                Maintenance.stats.targetApplied + 1

            local callbackNow = g_currentMission ~= nil
                and g_currentMission.time or nowMs

            reconcilePatch(
                task,
                probe,
                profile.radiusM,
                callbackNow
            )

            local afterResidual = geometry ~= nil
                and tonumber(geometry.centerResidualAfterM) or nil
            if afterResidual == nil
                and type(writer.measureRecoveryAt) == "function" then
                local post = writer:measureRecoveryAt(
                    task.x,
                    task.z,
                    profile.probeRadiusM
                )
                afterResidual = post ~= nil
                    and tonumber(post.centerResidualM) or nil
            end

            if afterResidual == nil then
                Maintenance.stats.callbackFailed =
                    Maintenance.stats.callbackFailed + 1
                return
            end

            if afterResidual >= -Maintenance.DEFAULTS.toleranceM then
                if afterResidual > Maintenance.DEFAULTS.toleranceM then
                    clearCenterStaleDebt(task, callbackNow)
                end
                finishTask(task)
                return
            end

            if task.attempts < profile.maxPulses then
                requeue(task, 0, callbackNow)
            else
                -- Leave remaining history intact. It ages into the next
                -- maintenance period rather than being declared repaired.
                finishTask(task)
            end
        end
    })

    if not accepted then
        Maintenance.inFlight = false
        Maintenance.stats.targetRejected =
            Maintenance.stats.targetRejected + 1
    end
end

function Maintenance:onPeriodChanged(currentPeriod)
    if not enabled() or g_server == nil then return end
    Maintenance.stats.periods = Maintenance.stats.periods + 1
    Maintenance.currentPeriod = currentPeriod
    buildPeriodQueue()
end

function Maintenance.initialize()
    if Maintenance.initialized then return true end
    queueReset()
    Maintenance.inFlight = false
    resetStats()

    if g_messageCenter ~= nil and MessageType ~= nil
        and MessageType.PERIOD_CHANGED ~= nil
        and type(g_messageCenter.subscribe) == "function" then
        g_messageCenter:subscribe(
            MessageType.PERIOD_CHANGED,
            Maintenance.onPeriodChanged,
            Maintenance
        )
    end

    Maintenance.initialized = true
    return true
end

function Maintenance.update(dt)
    if not Maintenance.initialized or not enabled()
        or g_server == nil or Maintenance.inFlight then
        return
    end

    if Maintenance.queueCount <= 0
        or recoveryBusy()
        or writerBusy() then
        return
    end

    local nowMs = g_currentMission ~= nil
        and g_currentMission.time or 0
    local task = queuePop()
    if task == nil then return end

    if (tonumber(task.notBeforeMs) or 0) > nowMs then
        queuePush(task)
        return
    end

    processTask(task, nowMs)
end

function Maintenance.shutdown()
    if Maintenance.initialized
        and g_messageCenter ~= nil
        and MessageType ~= nil
        and MessageType.PERIOD_CHANGED ~= nil
        and type(g_messageCenter.unsubscribe) == "function" then
        g_messageCenter:unsubscribe(
            MessageType.PERIOD_CHANGED,
            Maintenance
        )
    end

    queueReset()
    Maintenance.inFlight = false
    Maintenance.initialized = false
end

function Maintenance.getDiagnostics()
    local out = {}
    for k, v in pairs(Maintenance.stats or {}) do out[k] = v end
    out.pending = Maintenance.queueCount
    out.inFlight = Maintenance.inFlight and 1 or 0
    return out
end

return Maintenance
