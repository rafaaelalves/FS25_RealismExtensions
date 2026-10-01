local created = {}
local queued = {}

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

    function d:delete()
        self.deleted = true
    end

    created[#created + 1] = d
    return d
end

local heights = {}
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
        for _, brush in ipairs(deformation.brushes) do
            local key = tostring(brush.x) .. ":" .. tostring(brush.z)
            heights[key] = (heights[key] or 10) + deformation.depth
        end
        target[callbackName](target, TerrainDeformation.STATE_SUCCESS, 0.125, nil)
        return #queued
    end
}

RealismExtensionsConfig = {
    diagnostics = {
        verbose = true,
        expensiveGeometry = true
    }
}
dofile("scripts/terrain/SoilMassTransportModel.lua")
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
assert(#w.queue == 1)

local brushes2, jobs2 = w:flush()
assert(brushes2 == 1 and jobs2 == 1)
assert(#w.queue == 0)

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
assert(#mw.queue == mw.stats.massTransportBermsEnqueued)

local mb2,mj2 = mw:flush()
assert(mb2 == mw.stats.massTransportBermsEnqueued)
assert(mj2 >= 1)
assert(#mw.queue == 0)
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
