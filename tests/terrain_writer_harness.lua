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
        target[callbackName](target, TerrainDeformation.STATE_SUCCESS, 0, nil)
        return #queued
    end
}

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
