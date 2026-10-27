local created = {}
local queued = {}
local heights = {}

TerrainDeformation = {
    STATE_SUCCESS = 1,
    NO_TERRAIN_BRUSH = -1
}

function TerrainDeformation.new(terrain)
    local d = {
        terrain = terrain,
        brushes = {},
        deleted = false
    }

    function d:enableAdditiveDeformationMode()
        self.additive = true
    end

    function d:enableSmoothingMode()
        self.smoothing = true
    end

    function d:enableSetDeformationMode()
        self.targetMode = true
    end

    function d:setHeightTarget(minY,maxY,nx,ny,nz,distance)
        self.target = {
            minY=minY,maxY=maxY,nx=nx,ny=ny,nz=nz,d=distance
        }
    end

    function d:setAdditiveHeightChangeAmount(value)
        self.depth = value
    end

    function d:setOutsideAreaConstraints(a,b,c) self.outside={a,b,c} end
    function d:setBlockedAreaMaxDisplacement(v) self.blocked=v end
    function d:setDynamicObjectCollisionMask(v) self.mask=v end
    function d:setDynamicObjectMaxDisplacement(v) self.dynamic=v end

    function d:addSoftCircleBrush(x, z, radius, hardness, opacity, brush)
        self.brushes[#self.brushes + 1] = {
            x=x,z=z,radius=radius,hardness=hardness,opacity=opacity,brush=brush
        }
    end

    function d:apply(preview, callbackName, target)
        self.applyCalls = (self.applyCalls or 0) + 1
        self.lastApplyPreview = preview
        if preview == true then
            target[callbackName](target, TerrainDeformation.STATE_SUCCESS, 0.125, nil)
        else
            for _, brush in ipairs(self.brushes) do
                local key = tostring(brush.x) .. ":" .. tostring(brush.z)
                if self.smoothing then
                    heights[key] = (heights[key] or 10) + 0.002
                elseif self.targetMode then
                    local current = heights[key] or 10
                    local t = self.target
                    local targetY = -(
                        t.nx * brush.x + t.nz * brush.z + t.d
                    ) / t.ny
                    if current < targetY then
                        heights[key] = math.min(targetY, current + self.depth)
                    elseif current > targetY then
                        heights[key] = math.max(targetY, current - self.depth)
                    end
                else
                    heights[key] = (heights[key] or 10) + self.depth
                end
            end
            target[callbackName](target, TerrainDeformation.STATE_SUCCESS, 0.125, nil)
        end
        return true
    end

    function d:delete()
        self.deleted = true
    end

    created[#created + 1] = d
    return d
end

function getTerrainHeightAtWorldPos(terrain, x, y, z)
    local key = tostring(x) .. ":" .. tostring(z)
    return heights[key] or 10
end

g_currentMission = { terrainRootNode = 42 }
g_asyncTaskManager = {
    addTask = function(self, fn) fn() end
}
g_terrainDeformationQueue = {
    queueJob = function(self, deformation, preview, callbackName, target)
        queued[#queued + 1] = deformation
        deformation.lastQueuePreview = preview
        for _, brush in ipairs(deformation.brushes) do
            local key = tostring(brush.x) .. ":" .. tostring(brush.z)
            if deformation.smoothing then
                heights[key] = (heights[key] or 10) + 0.002
            elseif deformation.targetMode then
                local current = heights[key] or 10
                local t = deformation.target
                local targetY = -(
                    t.nx * brush.x + t.nz * brush.z + t.d
                ) / t.ny
                if current < targetY then
                    heights[key] = math.min(targetY, current + deformation.depth)
                elseif current > targetY then
                    heights[key] = math.max(targetY, current - deformation.depth)
                end
            else
                heights[key] = (heights[key] or 10) + deformation.depth
            end
        end
        target[callbackName](target, TerrainDeformation.STATE_SUCCESS, 0.125, nil)
        return #queued
    end
}

RealismExtensionsConfig = {
    modules = { SoilMassTransport = true },
    diagnostics = {
        verbose = true,
        expensiveGeometry = true
    }
}
dofile("scripts/terrain/SoilMassTransportModel.lua")
dofile("scripts/terrain/RecoverySurfaceEstimator.lua")
dofile("scripts/terrain/TerrainWriter.lua")

local w = RealismExtensionsTerrainWriter.new({
    maxBrushesPerFrame = 5,
    maxJobsPerFrame = 2,
    maxBrushesPerJob = 3,
    depthBucketM = 0.001,
    minDepthM = 0.0004
})

assert(w:enqueue({x=0,z=0,depthM=0.0051,radiusM=0.2,hardness=0.3}))
assert(w:enqueue({x=1,z=0,depthM=0.0052,radiusM=0.2,hardness=0.3}))
assert(w:enqueue({x=2,z=0,depthM=0.0050,radiusM=0.2,hardness=0.3}))
assert(w:enqueue({x=3,z=0,depthM=0.0030,radiusM=0.2,hardness=0.3}))
assert(w:enqueue({x=4,z=0,depthM=0.0030,radiusM=0.2,hardness=0.3}))
assert(w:enqueue({x=5,z=0,depthM=0.0030,radiusM=0.2,hardness=0.3}))
assert(w:enqueue({x=6,z=0,depthM=0.0001,radiusM=0.2}) == false)

local brushes, jobs = w:flush()
assert(jobs == 2)
assert(brushes == 5)
assert(#created == 2)
assert(#created[1].brushes == 3)
assert(#created[2].brushes == 2)
assert(created[1].depth < 0 and created[2].depth < 0)
assert(created[1].deleted == true and created[2].deleted == true)
assert(w.stats.submittedBrushes == 5)
assert(w.stats.submittedJobs == 2)
assert(w:getQueueSize() == 1)

local brushes2, jobs2 = w:flush()
assert(brushes2 == 1 and jobs2 == 1)
assert(w:getQueueSize() == 0)

print("terrain_writer_harness: OK")

assert(created[1].outside ~= nil)
assert(created[1].blocked == 0)
assert(created[1].mask == 0)
assert(created[1].dynamic == 0)
assert(w.stats.geometrySamples == 6)
assert(w.stats.geometryObservedLoweringM > 0)
assert(w.stats.geometryRequestedDepthM > 0)
assert(w.stats.maxObservedLoweringM > 0)

-- Production mode skips expensive before/after terrain-height probes while
-- preserving native TerrainDeformation callbacks and physics.
RealismExtensionsConfig.diagnostics.expensiveGeometry = false
local pw = RealismExtensionsTerrainWriter.new({
    maxBrushesPerFrame=2,
    maxJobsPerFrame=1,
    maxBrushesPerJob=2,
    minDepthM=0.0004
})
assert(pw:enqueue({x=30,z=30,depthM=0.003,radiusM=0.2}))
local pb,pj = pw:flush()
assert(pb == 1 and pj == 1)
assert(pw.stats.geometrySamples == 0)
assert(pw.stats.callbackSuccessJobs == 1)
RealismExtensionsConfig.diagnostics.expensiveGeometry = true

assert(w.stats.callbackSuccessJobs == 3)
assert(math.abs(w.stats.callbackDisplacedVolumeM3 - 0.375) < 0.000001)
assert(math.abs(w.stats.callbackMaxDisplacedVolumeM3 - 0.125) < 0.000001)
assert(w.stats.callbackVolumeMissing == 0)


-- Mass transport is a second asynchronous terrain phase: a lowering callback
-- budgets real displaced volume, then two positive berm brushes are queued.
local originalQueueJob = g_terrainDeformationQueue.queueJob
g_terrainDeformationQueue.queueJob = function(self, deformation, preview, callbackName, target)
    queued[#queued + 1] = deformation
    for _, brush in ipairs(deformation.brushes) do
        local key = tostring(brush.x) .. ":" .. tostring(brush.z)
        heights[key] = (heights[key] or 10) + deformation.depth
    end
    local volume = deformation.depth < 0 and 0.10 or 0.018
    target[callbackName](target, TerrainDeformation.STATE_SUCCESS, volume, nil)
    return #queued
end

local mw = RealismExtensionsTerrainWriter.new({
    maxBrushesPerFrame=8,
    maxJobsPerFrame=4,
    maxBrushesPerJob=4,
    depthBucketM=0.0005,
    minDepthM=0.0004
})
assert(mw:enqueue({
    x=20,z=20,depthM=0.004,radiusM=0.30,hardness=0.35,
    massTransport={
        travelDirX=0,travelDirZ=1,
        wetness01=0.95,deformability01=1.0,
        longitudinalSlip=0.95,lateralSlip=0,
        innerBermSide=1
    },
    source="RUT"
}))
local mb1,mj1 = mw:flush()
assert(mb1 == 1 and mj1 == 1)
assert(mw.stats.massTransportSourceVolumeM3 > 0.099)
assert(mw.stats.massTransportTargetVolumeM3 > 0)
assert(mw.stats.massTransportTargetVolumeM3 < mw.stats.massTransportSourceVolumeM3)
assert(mw.stats.massTransportCompactionVolumeM3 > 0)
assert(math.abs(
    mw.stats.massTransportSourceVolumeM3
    - mw.stats.massTransportTargetVolumeM3
    - mw.stats.massTransportCompactionVolumeM3
) < 0.000001)
assert(mw.stats.massTransportBermsEnqueued >= 1 and mw.stats.massTransportBermsEnqueued <= 2)
assert(mw:getQueueSize() == mw.stats.massTransportBermsEnqueued)

local mb2,mj2 = mw:flush()
assert(mb2 == mw.stats.massTransportBermsEnqueued)
assert(mj2 >= 1)
assert(mw:getQueueSize() == 0)
assert(mw.stats.massTransportRaiseJobs >= 1)
assert(mw.stats.massTransportRaisedVolumeM3 > 0)
assert(mw.stats.recoveryRaisedVolumeM3 == 0)
assert(mw.stats.unclassifiedRaisedVolumeM3 == 0)
assert(mw.stats.geometryObservedRaisingM > 0)

-- Recovery raises must not pollute berm realization telemetry.
local rw = RealismExtensionsTerrainWriter.new({
    maxBrushesPerFrame=4,
    maxJobsPerFrame=2,
    maxBrushesPerJob=4,
    depthBucketM=0.0005,
    minDepthM=0.0004
})
assert(rw:enqueue({
    x=40,z=40,mode="RAISE",raiseHeightM=0.003,radiusM=0.13,
    hardness=0.55,source="RECOVERY"
}))
local rb,rj = rw:flush()
assert(rb == 1 and rj == 1)
assert(rw.stats.recoveryRaiseJobs == 1)
assert(rw.stats.recoveryRaisedVolumeM3 > 0)
assert(rw.stats.massTransportRaiseJobs == 0)
assert(rw.stats.massTransportRaisedVolumeM3 == 0)

g_terrainDeformationQueue.queueJob = originalQueueJob
print("terrain_writer_mass_transport_harness: OK")


-- Native smoothing mode uses TerrainDeformation, not DensityMapHeightUtil, and
-- exposes the observed center-height delta to asynchronous recovery ownership.
local sw = RealismExtensionsTerrainWriter.new({
    maxBrushesPerFrame=4,
    maxJobsPerFrame=2,
    maxBrushesPerJob=4,
    depthBucketM=0.0005,
    minDepthM=0.0004
})
local smoothDelta = nil
assert(sw:enqueue({
    x=50,z=50,mode="SMOOTH",smoothAmountM=0.05,radiusM=0.5,
    hardness=0.25,strength=0.25,source="RECOVERY",
    onApplied=function(state,deltaY)
        assert(state == TerrainDeformation.STATE_SUCCESS)
        smoothDelta = deltaY
    end
}))
local sb,sj = sw:flush()
assert(sb == 1 and sj == 1)
assert(created[#created].smoothing == true)
assert(created[#created].additive ~= true)
assert(math.abs(created[#created].brushes[1].opacity - 0.25) < 0.000001)
assert(smoothDelta ~= nil and smoothDelta > 0.0019)
assert(sw.stats.recoverySmoothJobs == 1)
assert(sw.stats.recoverySmoothSamples == 1)
assert(sw.stats.recoverySmoothRaisedSamples == 1)
assert(sw.stats.recoverySmoothMaxDeltaM > 0.0019)
assert(created[#created].applyCalls == 1)
assert(created[#created].lastApplyPreview == false)
assert(sw.stats.recoveryMachineSmoothJobs == 1)
assert(sw.stats.recoveryMachineSmoothBrushes == 1)
assert(created[#created].brushes[1].brush == -1)
print("terrain_writer_smoothing_harness: OK")

-- R5 target-plane recovery uses a strong set-deformation actuator amount, but
-- the target plane -- not the amount -- bounds world-space motion.
local tw = RealismExtensionsTerrainWriter.new({
    maxBrushesPerFrame=4,
    maxJobsPerFrame=2,
    maxBrushesPerJob=4,
    depthBucketM=0.0005,
    minDepthM=0.0004
})
heights["60:60"] = 9.88
local targetDelta,targetGeometry=nil,nil
local reusedPreProbe=tw:measureRecoveryAt(60,60,1.5)
assert(reusedPreProbe~=nil)
assert(tw:enqueue({
    x=60,z=60,mode="TARGET",targetY=10.0,
    targetPlaneAx=0,targetPlaneAz=0,targetAmount=0.75,
    radiusM=0.40,hardness=0.20,strength=0.35,
    source="RECOVERY",probeRadiusM=1.5,
    recoveryPreProbe=reusedPreProbe,
    onApplied=function(state,deltaY,beforeY,afterY,volume,geometry)
        assert(state == TerrainDeformation.STATE_SUCCESS)
        targetDelta=deltaY
        targetGeometry=geometry
    end
}))
local tb,tj=tw:flush()
assert(tb==1 and tj==1)
local td=created[#created]
assert(td.targetMode==true and td.smoothing~=true and td.additive~=true)
assert(td.target~=nil)
assert(math.abs(td.depth-0.75)<0.000001)
assert(td.brushes[1].brush==-1)
assert(math.abs((heights["60:60"] or 0)-10.0)<0.000001)
assert(targetDelta~=nil and targetDelta>0.119 and targetDelta<0.121)
assert(targetGeometry~=nil)
assert(targetGeometry.centerDeficitBeforeM>0.119)
assert(targetGeometry.centerDeficitAfterM<0.001)
assert(tw.stats.recoveryTargetJobs==1)
assert(tw.stats.recoveryTargetBrushes==1)
assert(tw.stats.recoveryTargetRaisedSamples==1)
assert(tw.stats.recoveryTargetLoweredSamples==0)
assert(tw.stats.recoveryTargetMaxDeltaM>0.119)
assert(tw.stats.recoveryMachineTargetJobs==1)
assert(tw.stats.recoveryMachineTargetBrushes==1)
assert(tw.stats.recoveryPreProbeReused==1)
assert(tw.stats.targetIntensitySamples==1)
assert(math.abs(tw.stats.targetIntensitySum-0.75)<0.000001)
assert(math.abs(tw.stats.targetIntensityMax-0.75)<0.000001)
assert(tw.stats.geometryRequestedDepthM==0)
assert(tw:getQueueSize()==0)

-- The same target mode must also remove a recovery-created positive peak
-- without crossing below the target plane.
heights["61:61"]=10.20
local peakDelta=nil
assert(tw:enqueue({
    x=61,z=61,mode="TARGET",targetY=10.0,
    targetPlaneAx=0,targetPlaneAz=0,targetAmount=0.75,
    radiusM=0.40,hardness=0.20,strength=0.35,
    source="RECOVERY",probeRadiusM=1.25,
    onApplied=function(state,deltaY)
        assert(state==TerrainDeformation.STATE_SUCCESS)
        peakDelta=deltaY
    end
}))
local tpb,tpj=tw:flush()
assert(tpb==1 and tpj==1)
assert(math.abs((heights["61:61"] or 0)-10.0)<0.000001)
assert(peakDelta~=nil and peakDelta < -0.199 and peakDelta > -0.201)
assert(tw.stats.recoveryTargetLoweredSamples==1)
assert(tw.stats.targetIntensitySamples==2)
assert(math.abs(tw.stats.targetIntensitySum-1.50)<0.000001)
assert(tw.stats.geometryRequestedDepthM==0)
assert(tw:sampleHeightAt(61,61)==10.0)
print("terrain_writer_target_recovery_harness: OK")


-- R2 recovery fill uses one-way additive RAISE and exposes local geometry.
local fw = RealismExtensionsTerrainWriter.new({
    maxBrushesPerFrame=4,maxJobsPerFrame=2,maxBrushesPerJob=4,
    depthBucketM=0.0005,minDepthM=0.0004
})
heights["70:70"]=9.96
local fillDelta,fillGeometry=nil,nil
assert(fw:enqueue({
    x=70,z=70,mode="RAISE",raiseHeightM=0.02,
    radiusM=0.35,hardness=0.55,strength=1.0,
    source="RECOVERY",probeRadiusM=1.2,
    onApplied=function(state,deltaY,beforeY,afterY,volume,geometry)
        assert(state==TerrainDeformation.STATE_SUCCESS)
        fillDelta=deltaY
        fillGeometry=geometry
    end
}))
local fb,fj=fw:flush()
assert(fb==1 and fj==1)
assert(fillDelta~=nil and fillDelta>0.019)
assert(fillGeometry~=nil)
assert(fillGeometry.centerDeficitBeforeM>0.039)
assert(fillGeometry.centerDeficitAfterM<0.021)
assert(fw.stats.recoveryRaiseJobs==1)
assert(fw.stats.recoveryRaiseBrushes==1)
assert(fw.stats.recoveryRaiseSamples==1)
assert(fw.stats.recoveryRaiseRaisedSamples==1)
assert(fw.stats.recoveryRaiseLoweredSamples==0)
assert(fw.stats.recoveryRaiseMaxDeltaM>0.019)
print("terrain_writer_r2_recovery_raise_harness: OK")


-- R3 recovery commands may be far below the normal rut writer threshold and
-- must remain one direct machine brush, never batched through construction.
local cw = RealismExtensionsTerrainWriter.new({
    maxBrushesPerFrame=4,maxJobsPerFrame=2,maxBrushesPerJob=4,
    depthBucketM=0.00001,minDepthM=0.0004,
    minRecoveryRaiseCommandM=0.00002
})
heights["80:80"]=9.98
local cDelta=nil
assert(cw:enqueue({
    x=80,z=80,mode="RAISE",raiseHeightM=0.00010,
    radiusM=0.30,hardness=0.35,strength=0.35,
    source="RECOVERY",probeRadiusM=1.2,
    onApplied=function(state,deltaY) cDelta=deltaY end
}))
local cb,cj=cw:flush()
assert(cb==1 and cj==1)
local cd=created[#created]
assert(cd.applyCalls==1 and cd.lastApplyPreview==false)
assert(cd.brushes[1].brush==-1)
assert(cw.stats.recoveryMachineRaiseJobs==1)
assert(cw.stats.recoveryMachineRaiseBrushes==1)
assert(cDelta~=nil and cDelta>0)
print("terrain_writer_r3_direct_micro_raise_harness: OK")


-- R6 queue uses O(1) head-index dequeue while preserving FIFO/budget behavior.
local qw=RealismExtensionsTerrainWriter.new({
    maxBrushesPerFrame=3,maxJobsPerFrame=1,maxBrushesPerJob=3,
    minDepthM=0.0004
})
for i=1,7 do
    assert(qw:enqueue({x=100+i,z=100,depthM=0.002,radiusM=0.2}))
end
assert(qw:getQueueSize()==7)
local qb1,qj1=qw:flush()
assert(qb1==3 and qj1==1 and qw:getQueueSize()==4)
local qb2,qj2=qw:flush()
assert(qb2==3 and qj2==1 and qw:getQueueSize()==1)
local qb3,qj3=qw:flush()
assert(qb3==1 and qj3==1 and qw:getQueueSize()==0)
assert(qw.queueHead==1 and qw.queueTail==0)
print("terrain_writer_r6_queue_harness: OK")

-- A callback-bearing LOWER is a *single native transaction*. A former
-- batch of 3 distinct 2.4mm brushes caused each wheel's journal callback
-- to sample geometry AFTER all 3 commands, corrupting attribution. In
-- contrast, regular no-callback brushes may still batch for throughput.
local causal = RealismExtensionsTerrainWriter.new({
    maxBrushesPerFrame=5,maxJobsPerFrame=2,maxBrushesPerJob=8,
    depthBucketM=0.0005,minDepthM=0.0004
})
local beforeJobs=#created
local confirmations={}
for i=1,3 do
    local ix=140+i
    local original=10
    assert(causal:enqueue({
        x=ix,z=140,depthM=0.0024,radiusM=0.21,
        onApplied=function(state)
            assert(state==TerrainDeformation.STATE_SUCCESS)
            confirmations[#confirmations+1]=ix
            assert(math.abs((heights[tostring(ix)..":140"] or 10)
                -(original-0.0024))<0.000001)
        end
    }))
end
local n1,j1=causal:flush()
assert(n1==2 and j1==2)
assert(#created==beforeJobs+2)
assert(#confirmations==2)
assert(causal:getQueueSize()==1)
for i=beforeJobs+1,beforeJobs+2 do
    assert(#created[i].brushes==1)
    assert(math.abs(created[i].depth+0.0024)<0.000001,
        "native command may not round the requested 2.4mm to 2.5mm")
end
local n2,j2=causal:flush()
assert(n2==1 and j2==1)
assert(#confirmations==3 and causal:getQueueSize()==0)
assert(#created[beforeJobs+3].brushes==1)
assert(math.abs(created[beforeJobs+3].depth+0.0024)<0.000001)
print("terrain_writer_causal_single_brush_harness: OK")

-- In causal mode, a native callback MUST arrive before any other RE
-- deformation job starts, even in the following frame. This prevents RE
-- recovery, grading, or further wheel writes from contaminating the pending
-- journal's before/after measurements.
local nativeQ=g_terrainDeformationQueue.queueJob
local pendingNative={}
g_terrainDeformationQueue.queueJob=function(self,deformation,preview,name,target)
    pendingNative[#pendingNative+1]={name=name,target=target,d=deformation}
    return #pendingNative
end
RealismExtensionsConfig.modules.TerrainCausalRecovery=true
local asyncW=RealismExtensionsTerrainWriter.new({
    maxBrushesPerFrame=5,maxJobsPerFrame=4,maxBrushesPerJob=8,
    depthBucketM=0.0005
})
local completed=0
for i=1,3 do
    assert(asyncW:enqueue({
        x=170+i,z=170,depthM=0.0024,radiusM=0.22,
        onApplied=function() completed=completed+1 end
    }))
end
local as,aj=asyncW:flush()
assert(as==1 and aj==1 and #pendingNative==1)
assert(asyncW.nativeCausalPending==true)
assert(asyncW:getQueueSize()==2)
as,aj=asyncW:flush()
assert(as==0 and aj==0 and #pendingNative==1)
assert(asyncW.stats.causalNativePendingSkips==1)
pendingNative[1].target[pendingNative[1].name](
    pendingNative[1].target,TerrainDeformation.STATE_SUCCESS,0.01,nil)
assert(asyncW.nativeCausalPending==false and completed==1)
as,aj=asyncW:flush()
assert(as==1 and aj==1 and #pendingNative==2)
assert(asyncW.nativeCausalPending==true)
pendingNative[2].target[pendingNative[2].name](
    pendingNative[2].target,TerrainDeformation.STATE_SUCCESS,0.01,nil)
assert(completed==2)
as,aj=asyncW:flush()
assert(as==1 and aj==1 and #pendingNative==3)
pendingNative[3].target[pendingNative[3].name](
    pendingNative[3].target,TerrainDeformation.STATE_SUCCESS,0.01,nil)
assert(completed==3 and asyncW.nativeCausalPending==false)
assert(asyncW.stats.causalNativeStarted==3)
assert(asyncW.stats.causalNativeFinished==3)
assert(asyncW:getQueueSize()==0)
RealismExtensionsConfig.modules.TerrainCausalRecovery=false
g_terrainDeformationQueue.queueJob=nativeQ
print("terrain_writer_causal_async_exclusion_harness: OK")

-- Fail closed BEFORE a native handle is constructed if a wheel's
-- enqueue-time geometry sample is stale; always release causal locks via
-- the ordinary callback-on-submission-failure path.
RealismExtensionsConfig.modules.TerrainCausalRecovery=true
local guardW=RealismExtensionsTerrainWriter.new()
local nativeCreated=#created
local guardCalled=0
local callbackFailed=false
assert(guardW:enqueue({
    x=193,z=193,depthM=0.0024,radiusM=0.23,
    beforeSubmit=function()
        guardCalled=guardCalled+1
        return false,"QUEUED_GEOMETRY_DRIFT"
    end,
    onApplied=function(state)
        callbackFailed=(state==false)
    end
}))
local guardBrushes,guardJobs=guardW:flush()
assert(guardBrushes==0 and guardJobs==0)
assert(guardW:getQueueSize()==0)
assert(guardCalled==1 and callbackFailed==true)
assert(#created==nativeCreated)
assert(guardW.stats.nativePreflightRejected==1)
assert(guardW.nativeCausalPending~=true)
RealismExtensionsConfig.modules.TerrainCausalRecovery=false
print("terrain_writer_native_preflight_harness: OK")

-- Real TerrainWriter integration of the one-shot protective boundary.
-- Runs *after* legacy writer tests: no production behavior is affected if
-- TerrainControlledWriteTrial was not explicitly selected.
dofile("scripts/terrain/TerrainControlledWriteTrial.lua")
local Trial=RealismExtensionsTerrainControlledWriteTrial
RealismExtensionsConfig.modules.TerrainControlledWriteTrial=true
RealismExtensionsConfig.modules.TerrainCausalRecovery=true
RealismExtensionsConfig.modules.SoilMassTransport=false
g_server={}
g_currentMission.missionInfo={isMultiplayer=false}
g_currentMission.missionDynamicInfo={isMultiplayer=false}
RealismExtensionsTerrainRuntime={
    nativeDamageQuarantined=false,geometryJournal={unitM=1}
}
RealismExtensionsTerrainNativeQueueProbe={
    owner={},enabled=true,pollIntegrity=function()return true end
}
RealismExtensionsTerrainNativeSpatialProbe={
    owner={},checkIntegrity=function()return true end
}
RealismExtensionsTerrainGeometryProbe={
    position={x=901,z=901},previous={x=901,z=901,label="beforeOneShot"}
}
local pilot=RealismExtensionsTerrainWriter.new({
    maxBrushesPerFrame=1,maxJobsPerFrame=1,maxBrushesPerJob=1,
    coalesceDistanceFactor=0,minDepthM=0.0004
})
local beforePilot=#created
local fakeCallback=function() end
assert(pilot:enqueue({
    x=900,z=900,depthM=0.002,radiusM=0.4,
    onApplied=fakeCallback,trialTicket=1234
}))
local observed,jobs=pilot:flush()
assert(observed==0 and jobs==0)
assert(#created==beforePilot and #queued>=1)
assert(Trial.stats.nativeRejected>=1)

Trial:consoleCommand("arm")
assert(Trial.tryReserve(910,910)==nil) -- out-of-patch wheel cannot win
local ticket=assert(Trial.tryReserve(901,901))
assert(pilot:enqueue({
    x=901,z=901,depthM=0.002,radiusM=0.4,
    trialTicket=ticket,
    onApplied=function(state)
        assert(state==TerrainDeformation.STATE_SUCCESS)
        assert(Trial.callback(ticket)==true)
    end
}))
observed,jobs=pilot:flush()
assert(observed==1 and jobs==1)
assert(#created==beforePilot+1)
assert(Trial.stats.nativeApproved==1 and Trial.pending==false)
assert(Trial.armed==false)
assert(pilot:enqueue({
    x=902,z=902,depthM=0.002,radiusM=0.4,
    trialTicket=ticket,onApplied=fakeCallback
}))
observed,jobs=pilot:flush()
assert(observed==0 and jobs==0)
assert(#created==beforePilot+1)
RealismExtensionsConfig.modules.TerrainControlledWriteTrial=false
RealismExtensionsConfig.modules.TerrainCausalRecovery=false
print("terrain_writer_protected_one_shot_harness: OK")
