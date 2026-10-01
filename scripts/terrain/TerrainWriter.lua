RealismExtensionsTerrainWriter = RealismExtensionsTerrainWriter or {}
local Writer = RealismExtensionsTerrainWriter

Writer.VERSION = 4

Writer.DEFAULTS = {
    maxBrushesPerFrame = 24,
    maxJobsPerFrame = 4,
    maxBrushesPerJob = 8,
    maxQueuedBrushes = 512,
    depthBucketM = 0.0005,
    minDepthM = 0.0004,
    minRadiusM = 0.10,
    defaultHardness = 0.35,
    coalesceDistanceFactor = 0.35
}

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

local function mergeOptions(options)
    local out = {}
    for k, v in pairs(Writer.DEFAULTS) do out[k] = v end
    for k, v in pairs(options or {}) do out[k] = v end
    return out
end

function Writer.new(options)
    local self = {
        options = mergeOptions(options),
        queue = {},
        stats = {
            enqueued = 0,
            submittedBrushes = 0,
            submittedJobs = 0,
            droppedInvalid = 0,
            failedJobs = 0,
            droppedOverflow = 0,
            coalescedBrushes = 0,
            geometrySamples = 0,
            geometryRequestedDepthM = 0,
            geometryObservedLoweringM = 0,
            geometryObservedRaisingM = 0,
            geometryZeroChangeSamples = 0,
            geometryShallowSamples = 0,
            maxRequestedDepthM = 0,
            maxObservedLoweringM = 0,
            callbackSuccessJobs = 0,
            callbackDisplacedVolumeM3 = 0,
            callbackMaxDisplacedVolumeM3 = 0,
            callbackVolumeMissing = 0,
            massTransportSourceVolumeM3 = 0,
            massTransportTargetVolumeM3 = 0,
            massTransportRaisedVolumeM3 = 0,
            massTransportCompactionVolumeM3 = 0,
            massTransportBermsEnqueued = 0,
            massTransportModelRejects = 0,
            massTransportRaiseJobs = 0,
            recoveryRaisedVolumeM3 = 0,
            recoveryRaiseJobs = 0,
            unclassifiedRaisedVolumeM3 = 0,
            unclassifiedRaiseJobs = 0
        }
    }
    return setmetatable(self, { __index = Writer })
end

function Writer:enqueue(brush)
    if #self.queue >= math.max(1, math.floor(self.options.maxQueuedBrushes)) then
        self.stats.droppedOverflow = self.stats.droppedOverflow + 1
        return false
    end

    local mode = brush ~= nil and brush.mode or "LOWER"
    local amount = brush ~= nil and tonumber(brush.depthM) or nil
    if mode == "RAISE" then
        amount = brush ~= nil and tonumber(brush.raiseHeightM or brush.depthM) or nil
    end

    if type(brush) ~= "table"
        or type(brush.x) ~= "number"
        or type(brush.z) ~= "number"
        or type(amount) ~= "number"
        or type(brush.radiusM) ~= "number"
        or amount < self.options.minDepthM
        or brush.radiusM <= 0
        or (mode ~= "LOWER" and mode ~= "RAISE") then
        self.stats.droppedInvalid = self.stats.droppedInvalid + 1
        return false
    end

    self.queue[#self.queue + 1] = {
        x = brush.x,
        z = brush.z,
        depthM = amount,
        mode = mode,
        radiusM = math.max(self.options.minRadiusM, brush.radiusM),
        hardness = clamp(
            tonumber(brush.hardness) or self.options.defaultHardness,
            0.05,
            0.98
        ),
        massTransport = brush.massTransport,
        targetVolumeM3 = tonumber(brush.targetVolumeM3),
        source = brush.source
    }
    self.stats.enqueued = self.stats.enqueued + 1
    return true
end

local function depthBucket(depth, bucket)
    return math.max(bucket, math.floor(depth / bucket + 0.5) * bucket)
end

local function compatibleTransport(a, b)
    if a.source ~= b.source then return false end
    local ma, mb = a.massTransport, b.massTransport
    if ma == nil and mb == nil then return true end
    if ma == nil or mb == nil then return false end

    local ax, az = tonumber(ma.travelDirX), tonumber(ma.travelDirZ)
    local bx, bz = tonumber(mb.travelDirX), tonumber(mb.travelDirZ)
    if ax == nil or az == nil or bx == nil or bz == nil then return false end
    local dot = ax * bx + az * bz
    if dot < 0.95 then return false end

    local aw, bw = tonumber(ma.wetness01) or 0, tonumber(mb.wetness01) or 0
    local ad, bd = tonumber(ma.deformability01) or 0, tonumber(mb.deformability01) or 0
    return math.abs(aw - bw) <= 0.15 and math.abs(ad - bd) <= 0.15
end

local function tryCoalesce(group, brush, factor)
    -- Coalesce only brushes compatible by operation, depth bucket and transport
    -- direction/state. This keeps the performance win without turning two
    -- unrelated wheel paths into one averaged berm source.
    for _, existing in ipairs(group) do
        if existing.mode == brush.mode and compatibleTransport(existing, brush) then
            local dx, dz = brush.x - existing.x, brush.z - existing.z
            local distance = math.sqrt(dx * dx + dz * dz)
            local threshold = math.min(existing.radiusM, brush.radiusM) * factor
            if distance <= threshold then
                local minX = math.min(existing.x - existing.radiusM, brush.x - brush.radiusM)
                local maxX = math.max(existing.x + existing.radiusM, brush.x + brush.radiusM)
                local minZ = math.min(existing.z - existing.radiusM, brush.z - brush.radiusM)
                local maxZ = math.max(existing.z + existing.radiusM, brush.z + brush.radiusM)
                existing.x = (minX + maxX) * 0.5
                existing.z = (minZ + maxZ) * 0.5
                existing.radiusM = math.max(maxX - minX, maxZ - minZ) * 0.5
                existing.hardness = math.max(existing.hardness, brush.hardness)

                if existing.massTransport ~= nil and brush.massTransport ~= nil then
                    local a, b = existing.massTransport, brush.massTransport
                    a.wetness01 = math.max(tonumber(a.wetness01) or 0, tonumber(b.wetness01) or 0)
                    a.deformability01 = math.max(tonumber(a.deformability01) or 0, tonumber(b.deformability01) or 0)
                    a.longitudinalSlip = math.max(
                        math.abs(tonumber(a.longitudinalSlip) or 0),
                        math.abs(tonumber(b.longitudinalSlip) or 0)
                    )
                    if math.abs(tonumber(b.lateralSlip) or 0) > math.abs(tonumber(a.lateralSlip) or 0) then
                        a.lateralSlip = b.lateralSlip
                    end
                end
                return true
            end
        end
    end
    return false
end


local function sampleTerrainHeight(terrain, x, z)
    if getTerrainHeightAtWorldPos == nil or terrain == nil or terrain == 0 then
        return nil
    end
    local ok, value = pcall(getTerrainHeightAtWorldPos, terrain, x, 0, z)
    if ok and type(value) == "number" then return value end
    return nil
end

local function expensiveGeometryDiagnosticsEnabled()
    return RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.diagnostics ~= nil
        and RealismExtensionsConfig.diagnostics.expensiveGeometry == true
end

local function configureDeformationConstraints(deformation)
    -- TerraFarm explicitly clears conservative collision/blocking limits before
    -- applying terrain work. Match that precedent so RE's requested geometric
    -- depth is not silently clipped by TerrainDeformation defaults.
    if type(deformation.setOutsideAreaConstraints) == "function" then
        deformation:setOutsideAreaConstraints(0, math.rad(75), math.rad(75))
    end
    if type(deformation.setBlockedAreaMaxDisplacement) == "function" then
        deformation:setBlockedAreaMaxDisplacement(0)
    end
    if type(deformation.setDynamicObjectCollisionMask) == "function" then
        deformation:setDynamicObjectCollisionMask(0)
    end
    if type(deformation.setDynamicObjectMaxDisplacement) == "function" then
        deformation:setDynamicObjectMaxDisplacement(0)
    end
end

function Writer:_submitBatch(depthM, brushes, mode)
    local mission = g_currentMission
    local terrain = mission ~= nil and mission.terrainRootNode or g_terrainNode
    if TerrainDeformation == nil or terrain == nil or terrain == 0 then
        return false, "terrain deformation API unavailable"
    end

    local deformation = TerrainDeformation.new(terrain)
    if deformation == nil then return false, "could not allocate TerrainDeformation" end

    deformation:enableAdditiveDeformationMode()
    local signedHeight = math.abs(depthM)
    if mode ~= "RAISE" then signedHeight = -signedHeight end
    deformation:setAdditiveHeightChangeAmount(signedHeight)
    configureDeformationConstraints(deformation)

    local heightSamples = nil
    if expensiveGeometryDiagnosticsEnabled() then
        heightSamples = {}
        for i, brush in ipairs(brushes) do
            heightSamples[i] = sampleTerrainHeight(terrain, brush.x, brush.z)
        end
    end

    for _, brush in ipairs(brushes) do
        deformation:addSoftCircleBrush(
            brush.x,
            brush.z,
            brush.radiusM,
            brush.hardness,
            1.0,
            TerrainDeformation.NO_TERRAIN_BRUSH
        )
    end

    local callbackTarget = {
        deformation = deformation,
        owner = self,
        terrain = terrain,
        depthM = math.abs(depthM),
        mode = mode or "LOWER",
        brushes = brushes,
        source = brushes ~= nil and brushes[1] ~= nil and brushes[1].source or nil,
        heightSamples = heightSamples
    }

    function callbackTarget:done(state, displacedVolume, blockedObjectName)
        local perfStarted = RealismExtensionsTerrainPerformance ~= nil
            and RealismExtensionsTerrainPerformance.begin() or nil
        if state ~= nil
            and TerrainDeformation.STATE_SUCCESS ~= nil
            and state ~= TerrainDeformation.STATE_SUCCESS then
            self.owner.stats.failedJobs = self.owner.stats.failedJobs + 1
        elseif state == nil
            or TerrainDeformation.STATE_SUCCESS == nil
            or state == TerrainDeformation.STATE_SUCCESS then
            local stats = self.owner.stats
            stats.callbackSuccessJobs = stats.callbackSuccessJobs + 1
            local callbackVolume = nil
            if type(displacedVolume) == "number" and displacedVolume == displacedVolume then
                callbackVolume = math.abs(displacedVolume)
                stats.callbackDisplacedVolumeM3 =
                    stats.callbackDisplacedVolumeM3 + callbackVolume
                stats.callbackMaxDisplacedVolumeM3 =
                    math.max(stats.callbackMaxDisplacedVolumeM3, callbackVolume)
                if self.mode == "RAISE" then
                    if self.source == "MASS_TRANSPORT" then
                        stats.massTransportRaisedVolumeM3 =
                            stats.massTransportRaisedVolumeM3 + callbackVolume
                        stats.massTransportRaiseJobs = stats.massTransportRaiseJobs + 1
                    elseif self.source == "RECOVERY" then
                        stats.recoveryRaisedVolumeM3 =
                            stats.recoveryRaisedVolumeM3 + callbackVolume
                        stats.recoveryRaiseJobs = stats.recoveryRaiseJobs + 1
                    else
                        stats.unclassifiedRaisedVolumeM3 =
                            stats.unclassifiedRaisedVolumeM3 + callbackVolume
                        stats.unclassifiedRaiseJobs = stats.unclassifiedRaiseJobs + 1
                    end
                end
            else
                stats.callbackVolumeMissing = stats.callbackVolumeMissing + 1
            end

            if self.mode ~= "RAISE"
                and callbackVolume ~= nil
                and callbackVolume > 0
                and RealismExtensionsSoilMassTransportModel ~= nil then

                local weighted = {}
                local totalBatchWeight = 0
                for _, brush in ipairs(self.brushes or {}) do
                    local weight = math.max(0.001, math.pi * brush.radiusM * brush.radiusM)
                    totalBatchWeight = totalBatchWeight + weight
                    if brush.massTransport ~= nil then
                        weighted[#weighted + 1] = { brush=brush, weight=weight }
                    end
                end

                for _, item in ipairs(weighted) do
                    local brush = item.brush
                    local sourceVolume = callbackVolume * item.weight / math.max(0.001, totalBatchWeight)
                    local mt = brush.massTransport
                    local result = RealismExtensionsSoilMassTransportModel.compute({
                        x = brush.x,
                        z = brush.z,
                        rutRadiusM = brush.radiusM,
                        displacedVolumeM3 = sourceVolume,
                        travelDirX = mt.travelDirX,
                        travelDirZ = mt.travelDirZ,
                        wetness01 = mt.wetness01,
                        deformability01 = mt.deformability01,
                        longitudinalSlip = mt.longitudinalSlip,
                        lateralSlip = mt.lateralSlip,
                        innerBermSide = mt.innerBermSide
                    })

                    stats.massTransportSourceVolumeM3 =
                        stats.massTransportSourceVolumeM3 + sourceVolume

                    if result ~= nil and result.available == true then
                        stats.massTransportTargetVolumeM3 =
                            stats.massTransportTargetVolumeM3
                            + (result.transportedVolumeM3 or 0)
                        stats.massTransportCompactionVolumeM3 =
                            stats.massTransportCompactionVolumeM3
                            + (result.retainedCompactionVolumeM3 or 0)

                        for _, berm in ipairs({ result.left, result.right }) do
                            if berm ~= nil and berm.skipped ~= true and self.owner:enqueue({
                                x = berm.x,
                                z = berm.z,
                                mode = "RAISE",
                                raiseHeightM = berm.raiseHeightM,
                                radiusM = berm.radiusM,
                                hardness = brush.hardness,
                                targetVolumeM3 = berm.targetVolumeM3,
                                source = "MASS_TRANSPORT"
                            }) then
                                stats.massTransportBermsEnqueued =
                                    stats.massTransportBermsEnqueued + 1
                            end
                        end
                    else
                        -- Every eligible source-volume share must have an
                        -- accounting destination. If no representable surface
                        -- berm is produced, fold the whole share into
                        -- compaction/sub-surface rearrangement.
                        stats.massTransportCompactionVolumeM3 =
                            stats.massTransportCompactionVolumeM3 + sourceVolume
                        stats.massTransportModelRejects =
                            stats.massTransportModelRejects + 1
                    end
                end
            end
            for i, brush in ipairs(self.brushes or {}) do
                local beforeY = self.heightSamples ~= nil and self.heightSamples[i] or nil
                local afterY = beforeY ~= nil and sampleTerrainHeight(self.terrain, brush.x, brush.z) or nil
                if beforeY ~= nil and afterY ~= nil then
                    local requested = self.depthM or 0
                    local lowering = beforeY - afterY
                    stats.geometrySamples = stats.geometrySamples + 1
                    stats.geometryRequestedDepthM =
                        stats.geometryRequestedDepthM + requested
                    stats.maxRequestedDepthM =
                        math.max(stats.maxRequestedDepthM, requested)

                    if lowering > 0 then
                        stats.geometryObservedLoweringM =
                            stats.geometryObservedLoweringM + lowering
                        stats.maxObservedLoweringM =
                            math.max(stats.maxObservedLoweringM, lowering)
                    elseif lowering < 0 then
                        stats.geometryObservedRaisingM =
                            stats.geometryObservedRaisingM + (-lowering)
                    end

                    if math.abs(lowering) <= 0.00005 then
                        stats.geometryZeroChangeSamples =
                            stats.geometryZeroChangeSamples + 1
                    elseif requested > 0 and lowering < requested * 0.25 then
                        stats.geometryShallowSamples =
                            stats.geometryShallowSamples + 1
                    end
                end
            end
        end

        if RealismExtensionsTerrainPerformance ~= nil then
            RealismExtensionsTerrainPerformance.finish("callback", perfStarted)
        end

        local d = self.deformation
        self.deformation = nil

        -- Official GIANTS scripts delete queued deformation objects after the
        -- completion callback. Prefer next-frame delete when available.
        if d ~= nil then
            if g_asyncTaskManager ~= nil and g_asyncTaskManager.addTask ~= nil then
                g_asyncTaskManager:addTask(function() d:delete() end)
            else
                d:delete()
            end
        end
    end

    local q = g_terrainDeformationQueue
        or (mission ~= nil and mission.terrainDeformationQueue)

    if q ~= nil and type(q.queueJob) == "function" then
        local ok = pcall(q.queueJob, q, deformation, false, "done", callbackTarget)
        if not ok then
            deformation:delete()
            return false, "queueJob failed"
        end
        return true
    end

    if type(deformation.apply) == "function" then
        local ok = pcall(deformation.apply, deformation, false, "done", callbackTarget)
        if not ok then
            deformation:delete()
            return false, "direct apply failed"
        end
        return true
    end

    deformation:delete()
    return false, "no deformation execution path"
end

function Writer:flush()
    if #self.queue == 0 then return 0, 0 end
    local perfStarted = RealismExtensionsTerrainPerformance ~= nil
        and RealismExtensionsTerrainPerformance.begin() or nil

    local brushBudget = math.max(1, math.floor(self.options.maxBrushesPerFrame))
    local jobBudget = math.max(1, math.floor(self.options.maxJobsPerFrame))
    local perJob = math.max(1, math.floor(self.options.maxBrushesPerJob))
    local bucketM = math.max(0.0001, tonumber(self.options.depthBucketM) or 0.0005)

    local groups = {}
    local consumed = 0

    while consumed < brushBudget and #self.queue > 0 do
        local brush = table.remove(self.queue, 1)
        local bucket = depthBucket(brush.depthM, bucketM)
        local groupKey = tostring(brush.mode or "LOWER")
            .. ":" .. tostring(brush.source or "DEFAULT")
            .. ":" .. tostring(bucket)
        groups[groupKey] = groups[groupKey] or { mode=brush.mode or "LOWER", depth=bucket, brushes={} }
        local groupInfo = groups[groupKey]
        local group = groupInfo.brushes
        local factor = math.max(0, tonumber(self.options.coalesceDistanceFactor) or 0)
        if factor > 0 and tryCoalesce(group, brush, factor) then
            self.stats.coalescedBrushes = self.stats.coalescedBrushes + 1
        else
            group[#group + 1] = brush
        end
        consumed = consumed + 1
    end

    local groupKeys = {}
    for key in pairs(groups) do groupKeys[#groupKeys + 1] = key end
    table.sort(groupKeys, function(a, b)
        local ga, gb = groups[a], groups[b]
        if ga.mode ~= gb.mode then return ga.mode == "LOWER" end
        return ga.depth > gb.depth
    end)

    local jobs = 0
    local submitted = 0
    local leftovers = {}

    for _, key in ipairs(groupKeys) do
        local info = groups[key]
        local depth = info.depth
        local mode = info.mode
        local group = info.brushes
        local index = 1

        while index <= #group do
            if jobs >= jobBudget then
                for i = index, #group do leftovers[#leftovers + 1] = group[i] end
                break
            end

            local batch = {}
            for _ = 1, perJob do
                if index > #group then break end
                batch[#batch + 1] = group[index]
                index = index + 1
            end

            local ok = self:_submitBatch(depth, batch, mode)
            if ok then
                jobs = jobs + 1
                submitted = submitted + #batch
                self.stats.submittedJobs = self.stats.submittedJobs + 1
                self.stats.submittedBrushes = self.stats.submittedBrushes + #batch
            else
                self.stats.failedJobs = self.stats.failedJobs + 1
            end
        end
    end

    -- Requeue work that exceeded the job budget ahead of newly queued work.
    if #leftovers > 0 then
        local nextQueue = {}
        for _, brush in ipairs(leftovers) do nextQueue[#nextQueue + 1] = brush end
        for _, brush in ipairs(self.queue) do nextQueue[#nextQueue + 1] = brush end
        self.queue = nextQueue
    end

    if RealismExtensionsTerrainPerformance ~= nil then
        RealismExtensionsTerrainPerformance.finish("flush", perfStarted)
    end
    return submitted, jobs
end

function Writer:clear()
    self.queue = {}
end
