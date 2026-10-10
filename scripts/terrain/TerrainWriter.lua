RealismExtensionsTerrainWriter = RealismExtensionsTerrainWriter or {}
local Writer = RealismExtensionsTerrainWriter

Writer.VERSION = 14

Writer.DEFAULTS = {
    maxBrushesPerFrame = 24,
    maxJobsPerFrame = 4,
    maxBrushesPerJob = 8,
    maxQueuedBrushes = 512,
    depthBucketM = 0.0005,
    minDepthM = 0.0004,
    minRecoveryRaiseCommandM = 0.00002,
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
        queueHead = 1,
        queueTail = 0,
        queueCount = 0,
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
            targetIntensitySamples = 0,
            targetIntensitySum = 0,
            targetIntensityMax = 0,
            recoveryPreProbeReused = 0,
            maintenancePreProbeReused = 0,
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
            recoveryRaiseBrushes = 0,
            recoveryRaiseSamples = 0,
            recoveryRaiseRaisedSamples = 0,
            recoveryRaiseLoweredSamples = 0,
            recoveryRaiseAbsDeltaM = 0,
            recoveryRaiseMaxDeltaM = 0,
            recoveryMachineRaiseJobs = 0,
            recoveryMachineRaiseBrushes = 0,
            unclassifiedRaisedVolumeM3 = 0,
            recoverySmoothJobs = 0,
            recoverySmoothSamples = 0,
            recoverySmoothRaisedSamples = 0,
            recoverySmoothLoweredSamples = 0,
            recoverySmoothAbsDeltaM = 0,
            recoverySmoothMaxDeltaM = 0,
            recoveryMachineSmoothJobs = 0,
            recoveryMachineSmoothBrushes = 0,
            recoveryTargetJobs = 0,
            recoveryTargetBrushes = 0,
            recoveryTargetRaisedSamples = 0,
            recoveryTargetLoweredSamples = 0,
            recoveryTargetAbsDeltaM = 0,
            recoveryTargetMaxDeltaM = 0,
            recoveryMachineTargetJobs = 0,
            recoveryMachineTargetBrushes = 0,
            unclassifiedRaisedVolumeM3 = 0,
            unclassifiedRaiseJobs = 0
        }
    }
    return setmetatable(self, { __index = Writer })
end

local function popQueue(self)
    if (self.queueCount or 0) <= 0 then return nil end
    local index = self.queueHead
    local brush = self.queue[index]
    self.queue[index] = nil
    self.queueHead = index + 1
    self.queueCount = self.queueCount - 1

    if self.queueCount <= 0 then
        self.queue = {}
        self.queueHead = 1
        self.queueTail = 0
        self.queueCount = 0
    end
    return brush
end

function Writer:getQueueSize()
    return math.max(0, tonumber(self.queueCount) or 0)
end

function Writer:enqueue(brush)
    if self:getQueueSize() >= math.max(1, math.floor(self.options.maxQueuedBrushes)) then
        self.stats.droppedOverflow = self.stats.droppedOverflow + 1
        return false
    end

    local mode = brush ~= nil and brush.mode or "LOWER"
    local amount = brush ~= nil and tonumber(brush.depthM) or nil
    if mode == "RAISE" then
        amount = brush ~= nil and tonumber(brush.raiseHeightM or brush.depthM) or nil
    elseif mode == "SMOOTH" then
        amount = brush ~= nil and tonumber(brush.smoothAmountM or brush.depthM) or nil
    elseif mode == "TARGET" then
        -- In GIANTS set-deformation mode this is actuator intensity, not a
        -- requested world-space delta. TerraFarm's current flatten path uses
        -- 0.75 and relies on setHeightTarget() to bound the destination.
        amount = brush ~= nil and tonumber(
            brush.targetAmount or brush.maxStepM or brush.depthM
        ) or nil
    end

    local minAmount = self.options.minDepthM
    if mode == "RAISE" and brush ~= nil and brush.source == "RECOVERY" then
        minAmount = math.max(
            0.000001,
            tonumber(self.options.minRecoveryRaiseCommandM) or 0.00002
        )
    end

    if type(brush) ~= "table"
        or type(brush.x) ~= "number"
        or type(brush.z) ~= "number"
        or type(amount) ~= "number"
        or type(brush.radiusM) ~= "number"
        or amount < minAmount
        or brush.radiusM <= 0
        or (mode ~= "LOWER" and mode ~= "RAISE"
            and mode ~= "SMOOTH" and mode ~= "TARGET")
        or (mode == "TARGET"
            and type(brush.targetY) ~= "number") then
        self.stats.droppedInvalid = self.stats.droppedInvalid + 1
        return false
    end

    self.queueTail = (self.queueTail or 0) + 1
    self.queue[self.queueTail] = {
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
        strength = clamp(tonumber(brush.strength) or 1.0, 0.01, 1.0),
        massTransport = brush.massTransport,
        targetVolumeM3 = tonumber(brush.targetVolumeM3),
        source = brush.source,
        probeRadiusM = tonumber(brush.probeRadiusM),
        targetY = tonumber(brush.targetY),
        targetPlaneAx = tonumber(brush.targetPlaneAx) or 0,
        targetPlaneAz = tonumber(brush.targetPlaneAz) or 0,
        recoveryPreProbe = brush.recoveryPreProbe,
        onApplied = brush.onApplied
    }
    self.queueCount = (self.queueCount or 0) + 1
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
    -- Callback-bearing brushes keep one-to-one identity so asynchronous
    -- recovery can reconcile the exact history cell only after geometry moves.
    if brush.onApplied ~= nil then return false end
    -- MASS_TRANSPORT brushes encode a calibrated volume in radius + height.
    -- Merging them by enlarging radius while keeping height inflates volume.
    if brush.source == "MASS_TRANSPORT" then return false end

    -- Coalesce only brushes compatible by operation, depth bucket and transport
    -- direction/state. This keeps the performance win without turning two
    -- unrelated wheel paths into one averaged berm source.
    for _, existing in ipairs(group) do
        if existing.onApplied ~= nil then
            -- Do not merge work whose completion belongs to another history cell.
        elseif
        existing.mode == brush.mode and compatibleTransport(existing, brush) then
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


local function sampleRoughnessProbe(terrain, brush)
    if brush == nil then return nil end
    local r = math.max(
        0.05,
        tonumber(brush.probeRadiusM)
            or tonumber(brush.radiusM) * 0.75
    )
    local offsets = {
        {0,0,false}
    }
    -- Recovery is sparse/serialized, so spend a few extra height samples on a
    -- better local reference plane. A 16-point boundary ring is much harder
    -- for one old rut edge or small berm to bias than the previous 8 samples.
    for i = 0, 15 do
        local a = (math.pi * 2 * i) / 16
        offsets[#offsets + 1] = {
            math.cos(a) * r,
            math.sin(a) * r,
            true
        }
    end

    local samples = {}
    for i,o in ipairs(offsets) do
        local y = sampleTerrainHeight(
            terrain,
            brush.x + o[1],
            brush.z + o[2]
        )
        if type(y) ~= "number" then return nil end
        samples[i] = {
            dx = o[1],
            dz = o[2],
            y = y,
            boundary = o[3] == true,
            center = i == 1
        }
    end

    local estimator = RealismExtensionsRecoverySurfaceEstimator
    if estimator ~= nil and type(estimator.measure) == "function" then
        local measured = estimator.measure(samples)
        if measured ~= nil then
            measured.centerY = samples[1].y
            return measured
        end
    end

    local minY,maxY,sumY = math.huge,-math.huge,0
    for _,s in ipairs(samples) do
        minY=math.min(minY,s.y)
        maxY=math.max(maxY,s.y)
        sumY=sumY+s.y
    end
    local mean=sumY/#samples
    local ss=0
    for _,s in ipairs(samples) do
        local e=s.y-mean
        ss=ss+e*e
    end
    return {
        centerY=samples[1].y,
        centerResidualM=samples[1].y-mean,
        centerDeficitM=math.max(0,mean-samples[1].y),
        roughnessM=math.sqrt(ss/#samples),
        reliefRangeM=math.max(0,maxY-minY),
        valleyDepthM=math.max(0,mean-minY),
        peakHeightM=math.max(0,maxY-mean),
        meanY=mean,
        boundaryInlierRatio=0
    }
end

function Writer:sampleHeightAt(x, z)
    local mission = g_currentMission
    local terrain = mission ~= nil and mission.terrainRootNode or g_terrainNode
    if terrain == nil or terrain == 0
        or type(x) ~= "number" or type(z) ~= "number" then
        return nil
    end
    return sampleTerrainHeight(terrain, x, z)
end

function Writer:measureRecoveryAt(x, z, probeRadiusM)
    local mission = g_currentMission
    local terrain = mission ~= nil and mission.terrainRootNode or g_terrainNode
    if terrain == nil or terrain == 0
        or type(x) ~= "number" or type(z) ~= "number" then
        return nil
    end

    local r = math.max(
        self.options.minRadiusM,
        tonumber(probeRadiusM) or 1.0
    )
    return sampleRoughnessProbe(terrain, {
        x = x,
        z = z,
        radiusM = r,
        probeRadiusM = r
    })
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

    local amount = math.abs(depthM)
    local machineRecoverySmooth = mode == "SMOOTH"
        and brushes ~= nil and brushes[1] ~= nil
        and brushes[1].source == "RECOVERY"
    local machineRecoveryTarget = mode == "TARGET"
        and brushes ~= nil and #brushes == 1
        and brushes[1].source == "RECOVERY"
    local recoveryRaiseMode = mode == "RAISE"
        and brushes ~= nil and #brushes == 1
        and brushes[1].source == "RECOVERY"

    if machineRecoveryTarget then
        local brush = brushes[1]
        if type(deformation.enableSetDeformationMode) ~= "function"
            or type(deformation.setHeightTarget) ~= "function" then
            deformation:delete()
            return false, "terrain target mode unavailable"
        end

        local targetY = tonumber(brush.targetY)
        if targetY == nil then
            deformation:delete()
            return false, "terrain target height unavailable"
        end

        local ax = tonumber(brush.targetPlaneAx) or 0
        local az = tonumber(brush.targetPlaneAz) or 0
        local norm = math.sqrt(ax * ax + 1 + az * az)
        local nx, ny, nz = -ax / norm, 1 / norm, -az / norm
        local d = (-targetY + ax * brush.x + az * brush.z) / norm
        local verticalSpan = math.max(
            0.001,
            (math.abs(ax) + math.abs(az)) * brush.radiusM
        )

        deformation:setAdditiveHeightChangeAmount(amount)
        deformation:setHeightTarget(
            targetY - verticalSpan,
            targetY + verticalSpan,
            nx, ny, nz, d
        )
        deformation:enableSetDeformationMode()
        configureDeformationConstraints(deformation)
    elseif machineRecoverySmooth then
        -- Machine smoothing follows TerraFarm's machine-work path rather than
        -- Construction landscaping. A vehicle is physically occupying the
        -- deformation area, so dynamic/blocking constraints must not veto the
        -- terrain operation.
        if type(deformation.enableSmoothingMode) ~= "function" then
            deformation:delete()
            return false, "terrain smoothing mode unavailable"
        end
        deformation:setAdditiveHeightChangeAmount(amount)
        deformation:enableSmoothingMode()
        configureDeformationConstraints(deformation)
    elseif mode == "SMOOTH" then
        if type(deformation.enableSmoothingMode) ~= "function" then
            deformation:delete()
            return false, "terrain smoothing mode unavailable"
        end
        deformation:setAdditiveHeightChangeAmount(amount)
        deformation:enableSmoothingMode()
        configureDeformationConstraints(deformation)
    else
        deformation:enableAdditiveDeformationMode()
        local signedHeight = mode == "RAISE" and amount or -amount
        deformation:setAdditiveHeightChangeAmount(signedHeight)
        configureDeformationConstraints(deformation)
    end

    local heightSamples = nil
    local roughnessSamples = nil
    local recoveryGeometryMode =
        (mode == "SMOOTH" or mode == "TARGET" or mode == "RAISE")
        and brushes ~= nil and brushes[1] ~= nil
        and (
            brushes[1].source == "RECOVERY"
            or brushes[1].source == "MAINTENANCE"
        )

    if mode == "SMOOTH" or mode == "TARGET" or recoveryRaiseMode
        or expensiveGeometryDiagnosticsEnabled() then
        heightSamples = {}
        for i, brush in ipairs(brushes) do
            local pre = recoveryGeometryMode and brush.recoveryPreProbe or nil
            heightSamples[i] = pre ~= nil and pre.centerY
                or sampleTerrainHeight(terrain, brush.x, brush.z)
        end
    end
    if recoveryGeometryMode then
        roughnessSamples = {}
        for i, brush in ipairs(brushes) do
            local pre = brush.recoveryPreProbe
            if pre ~= nil then
                roughnessSamples[i] = pre
                if brush.source == "MAINTENANCE" then
                    self.stats.maintenancePreProbeReused =
                        self.stats.maintenancePreProbeReused + 1
                else
                    self.stats.recoveryPreProbeReused =
                        self.stats.recoveryPreProbeReused + 1
                end
            else
                roughnessSamples[i] = sampleRoughnessProbe(terrain, brush)
            end
        end
    end

    for _, brush in ipairs(brushes) do
        local terrainBrush = TerrainDeformation.NO_TERRAIN_BRUSH
        if machineRecoverySmooth or machineRecoveryTarget or recoveryRaiseMode then
            -- TerraFarm machine input smoothing uses -1 here; keep the machine
        -- terrain path separate from Construction landscaping semantics.
            terrainBrush = -1
        end
        deformation:addSoftCircleBrush(
            brush.x,
            brush.z,
            brush.radiusM,
            brush.hardness,
            brush.strength or 1.0,
            terrainBrush
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
        heightSamples = heightSamples,
        roughnessSamples = roughnessSamples
    }

    function callbackTarget:done(state, displacedVolume, blockedObjectName)
        local perfStarted = RealismExtensionsTerrainPerformance ~= nil
            and RealismExtensionsTerrainPerformance.begin() or nil
        if state ~= nil
            and TerrainDeformation.STATE_SUCCESS ~= nil
            and state ~= TerrainDeformation.STATE_SUCCESS then
            self.owner.stats.failedJobs = self.owner.stats.failedJobs + 1
            for _, brush in ipairs(self.brushes or {}) do
                if type(brush.onApplied) == "function" then
                    pcall(brush.onApplied, state, nil, nil, nil, nil, nil)
                end
            end
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
                if self.mode == "SMOOTH" and self.source == "RECOVERY" then
                    stats.recoverySmoothJobs = stats.recoverySmoothJobs + 1
                elseif self.mode == "TARGET" and self.source == "RECOVERY" then
                    stats.recoveryTargetJobs = stats.recoveryTargetJobs + 1
                    stats.recoveryTargetBrushes =
                        stats.recoveryTargetBrushes + #(self.brushes or {})
                elseif self.mode == "RAISE" then
                    if self.source == "MASS_TRANSPORT" then
                        stats.massTransportRaisedVolumeM3 =
                            stats.massTransportRaisedVolumeM3 + callbackVolume
                        stats.massTransportRaiseJobs = stats.massTransportRaiseJobs + 1
                    elseif self.source == "RECOVERY" then
                        stats.recoveryRaisedVolumeM3 =
                            stats.recoveryRaisedVolumeM3 + callbackVolume
                        stats.recoveryRaiseJobs = stats.recoveryRaiseJobs + 1
                        stats.recoveryRaiseBrushes =
                            stats.recoveryRaiseBrushes + #(self.brushes or {})
                    else
                        stats.unclassifiedRaisedVolumeM3 =
                            stats.unclassifiedRaisedVolumeM3 + callbackVolume
                        stats.unclassifiedRaiseJobs = stats.unclassifiedRaiseJobs + 1
                    end
                end
            else
                stats.callbackVolumeMissing = stats.callbackVolumeMissing + 1
            end

            local massTransportEnabled = RealismExtensionsConfig ~= nil
                and RealismExtensionsConfig.modules ~= nil
                and RealismExtensionsConfig.modules.SoilMassTransport == true
            if massTransportEnabled
                and self.mode == "LOWER"
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
                local beforeProbe = self.roughnessSamples ~= nil
                    and self.roughnessSamples[i] or nil
                local afterProbe = beforeProbe ~= nil
                    and sampleRoughnessProbe(self.terrain, brush) or nil

                local beforeY = self.heightSamples ~= nil
                    and self.heightSamples[i] or nil
                if beforeY == nil and beforeProbe ~= nil then
                    beforeY = beforeProbe.centerY
                end
                local afterY = afterProbe ~= nil and afterProbe.centerY or nil
                if afterY == nil and beforeY ~= nil then
                    afterY = sampleTerrainHeight(
                        self.terrain,
                        brush.x,
                        brush.z
                    )
                end

                local deltaY = nil
                if beforeY ~= nil and afterY ~= nil then
                    deltaY = afterY - beforeY
                    local requested = self.depthM or 0
                    local lowering = -deltaY
                    stats.geometrySamples = stats.geometrySamples + 1

                    if self.mode == "TARGET" then
                        stats.targetIntensitySamples =
                            stats.targetIntensitySamples + 1
                        stats.targetIntensitySum =
                            stats.targetIntensitySum + requested
                        stats.targetIntensityMax =
                            math.max(stats.targetIntensityMax, requested)
                    else
                        stats.geometryRequestedDepthM =
                            stats.geometryRequestedDepthM + requested
                        stats.maxRequestedDepthM =
                            math.max(stats.maxRequestedDepthM, requested)
                    end

                    if lowering > 0 then
                        stats.geometryObservedLoweringM =
                            stats.geometryObservedLoweringM + lowering
                        stats.maxObservedLoweringM =
                            math.max(stats.maxObservedLoweringM, lowering)
                    elseif lowering < 0 then
                        stats.geometryObservedRaisingM =
                            stats.geometryObservedRaisingM + (-lowering)
                    end

                    if self.mode == "SMOOTH" and self.source == "RECOVERY" then
                        local absDelta = math.abs(deltaY)
                        stats.recoverySmoothSamples =
                            stats.recoverySmoothSamples + 1
                        stats.recoverySmoothAbsDeltaM =
                            stats.recoverySmoothAbsDeltaM + absDelta
                        stats.recoverySmoothMaxDeltaM =
                            math.max(stats.recoverySmoothMaxDeltaM, absDelta)
                        if deltaY > 0.00005 then
                            stats.recoverySmoothRaisedSamples =
                                stats.recoverySmoothRaisedSamples + 1
                        elseif deltaY < -0.00005 then
                            stats.recoverySmoothLoweredSamples =
                                stats.recoverySmoothLoweredSamples + 1
                        end
                    elseif self.mode == "TARGET" and self.source == "RECOVERY" then
                        local absDelta = math.abs(deltaY)
                        stats.recoveryTargetAbsDeltaM =
                            stats.recoveryTargetAbsDeltaM + absDelta
                        stats.recoveryTargetMaxDeltaM =
                            math.max(stats.recoveryTargetMaxDeltaM, absDelta)
                        if deltaY > 0.00005 then
                            stats.recoveryTargetRaisedSamples =
                                stats.recoveryTargetRaisedSamples + 1
                        elseif deltaY < -0.00005 then
                            stats.recoveryTargetLoweredSamples =
                                stats.recoveryTargetLoweredSamples + 1
                        end
                    elseif self.mode == "RAISE" and self.source == "RECOVERY" then
                        local absDelta = math.abs(deltaY)
                        stats.recoveryRaiseSamples =
                            stats.recoveryRaiseSamples + 1
                        stats.recoveryRaiseAbsDeltaM =
                            stats.recoveryRaiseAbsDeltaM + absDelta
                        stats.recoveryRaiseMaxDeltaM =
                            math.max(stats.recoveryRaiseMaxDeltaM, absDelta)
                        if deltaY > 0.00005 then
                            stats.recoveryRaiseRaisedSamples =
                                stats.recoveryRaiseRaisedSamples + 1
                        elseif deltaY < -0.00005 then
                            stats.recoveryRaiseLoweredSamples =
                                stats.recoveryRaiseLoweredSamples + 1
                        end
                    end

                    if math.abs(lowering) <= 0.00005 then
                        stats.geometryZeroChangeSamples =
                            stats.geometryZeroChangeSamples + 1
                    elseif self.mode ~= "SMOOTH"
                        and self.mode ~= "TARGET"
                        and requested > 0
                        and lowering < requested * 0.25 then
                        stats.geometryShallowSamples =
                            stats.geometryShallowSamples + 1
                    end
                end

                local recoveryGeometry = nil
                if beforeProbe ~= nil and afterProbe ~= nil then
                    recoveryGeometry = {
                        roughnessBeforeM = beforeProbe.roughnessM,
                        roughnessAfterM = afterProbe.roughnessM,
                        roughnessDeltaM =
                            beforeProbe.roughnessM - afterProbe.roughnessM,
                        reliefBeforeM = beforeProbe.reliefRangeM,
                        reliefAfterM = afterProbe.reliefRangeM,
                        reliefDeltaM =
                            beforeProbe.reliefRangeM - afterProbe.reliefRangeM,
                        valleyBeforeM = beforeProbe.valleyDepthM,
                        valleyAfterM = afterProbe.valleyDepthM,
                        peakBeforeM = beforeProbe.peakHeightM,
                        peakAfterM = afterProbe.peakHeightM,
                        centerDeficitBeforeM = beforeProbe.centerDeficitM,
                        centerDeficitAfterM = afterProbe.centerDeficitM,
                        centerResidualBeforeM = beforeProbe.centerResidualM,
                        centerResidualAfterM = afterProbe.centerResidualM,
                        meanBeforeY = beforeProbe.meanY,
                        meanAfterY = afterProbe.meanY,
                        boundaryInlierBefore = beforeProbe.boundaryInlierRatio,
                        boundaryInlierAfter = afterProbe.boundaryInlierRatio,
                        centerBeforeY = beforeProbe.centerY,
                        centerAfterY = afterProbe.centerY,
                        referenceBeforeY = beforeProbe.referenceCenterY,
                        referenceAfterY = afterProbe.referenceCenterY,
                        planeAxBefore = beforeProbe.planeAx,
                        planeAzBefore = beforeProbe.planeAz,
                        planeAxAfter = afterProbe.planeAx,
                        planeAzAfter = afterProbe.planeAz
                    }
                end

                if type(brush.onApplied) == "function" then
                    pcall(
                        brush.onApplied,
                        state,
                        deltaY,
                        beforeY,
                        afterY,
                        callbackVolume,
                        recoveryGeometry
                    )
                end
            end
        end

        if RealismExtensionsTerrainPerformance ~= nil then
            RealismExtensionsTerrainPerformance.finish("callback", perfStarted)
        end

        local d = self.deformation
        self.deformation = nil

        -- TerraFarm's machine landscaping owns and deletes the deformation
        -- directly in its completion callback. Deferring delete to a later
        -- async task produced a rare nil-handle delete in R2.
        if d ~= nil then
            d:delete()
        end
    end

    local q = g_terrainDeformationQueue
        or (mission ~= nil and mission.terrainDeformationQueue)

    if machineRecoverySmooth or machineRecoveryTarget or recoveryRaiseMode then
        -- Machine recovery follows TerraFarm's direct landscaping path. It is
        -- serialized by TerrainRecovery, so each callback belongs to exactly
        -- one freshly measured causal patch.
        -- TerraFarm machine landscaping applies directly with preview=false.
        -- This deliberately avoids Construction's dynamic-object validation
        -- semantics, which made nearly every under-machine smoothing job a
        -- physical no-op in v19/v20.
        if type(deformation.apply) ~= "function" then
            deformation:delete()
            return false, "machine smoothing apply unavailable"
        end
        if machineRecoverySmooth then
            self.stats.recoveryMachineSmoothJobs =
                self.stats.recoveryMachineSmoothJobs + 1
            self.stats.recoveryMachineSmoothBrushes =
                self.stats.recoveryMachineSmoothBrushes + #(brushes or {})
        elseif machineRecoveryTarget then
            self.stats.recoveryMachineTargetJobs =
                self.stats.recoveryMachineTargetJobs + 1
            self.stats.recoveryMachineTargetBrushes =
                self.stats.recoveryMachineTargetBrushes + #(brushes or {})
        elseif recoveryRaiseMode then
            self.stats.recoveryMachineRaiseJobs =
                self.stats.recoveryMachineRaiseJobs + 1
            self.stats.recoveryMachineRaiseBrushes =
                self.stats.recoveryMachineRaiseBrushes + #(brushes or {})
        end
        local ok, err = pcall(
            deformation.apply,
            deformation,
            false,
            "done",
            callbackTarget
        )
        if not ok then
            self.stats.lastSubmitError = tostring(err)
            deformation:delete()
            return false, "machine smoothing apply failed: " .. tostring(err)
        end
        return true
    end

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
    if self:getQueueSize() == 0 then return 0, 0 end
    local perfStarted = RealismExtensionsTerrainPerformance ~= nil
        and RealismExtensionsTerrainPerformance.begin() or nil

    local brushBudget = math.max(1, math.floor(self.options.maxBrushesPerFrame))
    local jobBudget = math.max(1, math.floor(self.options.maxJobsPerFrame))
    local perJob = math.max(1, math.floor(self.options.maxBrushesPerJob))
    local bucketM = math.max(0.0001, tonumber(self.options.depthBucketM) or 0.0005)

    local groups = {}
    local consumed = 0

    while consumed < brushBudget and self:getQueueSize() > 0 do
        local brush = popQueue(self)
        local bucket = depthBucket(brush.depthM, bucketM)
        local groupKey = tostring(brush.mode or "LOWER")
            .. ":" .. tostring(brush.source or "DEFAULT")
            .. ":" .. tostring(bucket)
        if brush.mode == "TARGET"
            or (brush.mode == "RAISE" and brush.source == "RECOVERY") then
            groupKey = groupKey
                .. ":" .. string.format("%.3f", brush.x)
                .. ":" .. string.format("%.3f", brush.z)
        end
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
    local modeOrder = { LOWER=1, TARGET=2, SMOOTH=3, RAISE=4 }
    table.sort(groupKeys, function(a, b)
        local ga, gb = groups[a], groups[b]
        if ga.mode ~= gb.mode then
            return (modeOrder[ga.mode] or 99) < (modeOrder[gb.mode] or 99)
        end
        if ga.depth ~= gb.depth then return ga.depth > gb.depth end
        return a < b
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
            local recoveryRaise = mode == "RAISE"
                and group[index] ~= nil
                and group[index].source == "RECOVERY"
            local batchLimit = (mode == "TARGET" or recoveryRaise)
                and 1 or perJob
            for _ = 1, batchLimit do
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

    -- Requeue budget-deferred work ahead of any work enqueued by direct
    -- TerrainDeformation callbacks. This compaction happens only when the job
    -- budget is exceeded; ordinary dequeue is O(1).
    if #leftovers > 0 then
        local nextQueue = {}
        for _, brush in ipairs(leftovers) do
            nextQueue[#nextQueue + 1] = brush
        end
        for index = self.queueHead, self.queueTail do
            local brush = self.queue[index]
            if brush ~= nil then
                nextQueue[#nextQueue + 1] = brush
            end
        end
        self.queue = nextQueue
        self.queueHead = 1
        self.queueTail = #nextQueue
        self.queueCount = #nextQueue
    end

    if RealismExtensionsTerrainPerformance ~= nil then
        RealismExtensionsTerrainPerformance.finish("flush", perfStarted)
    end
    return submitted, jobs
end

function Writer:clear()
    self.queue = {}
    self.queueHead = 1
    self.queueTail = 0
    self.queueCount = 0
end
