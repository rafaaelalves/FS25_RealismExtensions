RealismExtensionsTerrainWriter = RealismExtensionsTerrainWriter or {}
local Writer = RealismExtensionsTerrainWriter

Writer.VERSION = 1

Writer.DEFAULTS = {
    maxBrushesPerFrame = 24,
    maxJobsPerFrame = 4,
    maxBrushesPerJob = 8,
    maxQueuedBrushes = 512,
    depthBucketM = 0.0005,
    minDepthM = 0.0004,
    minRadiusM = 0.10,
    defaultHardness = 0.35
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
            droppedOverflow = 0
        }
    }
    return setmetatable(self, { __index = Writer })
end

function Writer:enqueue(brush)
    if #self.queue >= math.max(1, math.floor(self.options.maxQueuedBrushes)) then
        self.stats.droppedOverflow = self.stats.droppedOverflow + 1
        return false
    end

    if type(brush) ~= "table"
        or type(brush.x) ~= "number"
        or type(brush.z) ~= "number"
        or type(brush.depthM) ~= "number"
        or type(brush.radiusM) ~= "number"
        or brush.depthM < self.options.minDepthM
        or brush.radiusM <= 0 then
        self.stats.droppedInvalid = self.stats.droppedInvalid + 1
        return false
    end

    self.queue[#self.queue + 1] = {
        x = brush.x,
        z = brush.z,
        depthM = brush.depthM,
        radiusM = math.max(self.options.minRadiusM, brush.radiusM),
        hardness = clamp(
            tonumber(brush.hardness) or self.options.defaultHardness,
            0.05,
            0.98
        )
    }
    self.stats.enqueued = self.stats.enqueued + 1
    return true
end

local function depthBucket(depth, bucket)
    return math.max(bucket, math.floor(depth / bucket + 0.5) * bucket)
end

function Writer:_submitBatch(depthM, brushes)
    local mission = g_currentMission
    local terrain = mission ~= nil and mission.terrainRootNode or g_terrainNode
    if TerrainDeformation == nil or terrain == nil or terrain == 0 then
        return false, "terrain deformation API unavailable"
    end

    local deformation = TerrainDeformation.new(terrain)
    if deformation == nil then return false, "could not allocate TerrainDeformation" end

    deformation:enableAdditiveDeformationMode()
    deformation:setAdditiveHeightChangeAmount(-math.abs(depthM))

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
        owner = self
    }

    function callbackTarget:done(state, displacedVolume, blockedObjectName)
        if state ~= nil
            and TerrainDeformation.STATE_SUCCESS ~= nil
            and state ~= TerrainDeformation.STATE_SUCCESS then
            self.owner.stats.failedJobs = self.owner.stats.failedJobs + 1
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

    local brushBudget = math.max(1, math.floor(self.options.maxBrushesPerFrame))
    local jobBudget = math.max(1, math.floor(self.options.maxJobsPerFrame))
    local perJob = math.max(1, math.floor(self.options.maxBrushesPerJob))
    local bucketM = math.max(0.0001, tonumber(self.options.depthBucketM) or 0.0005)

    local groups = {}
    local consumed = 0

    while consumed < brushBudget and #self.queue > 0 do
        local brush = table.remove(self.queue, 1)
        local bucket = depthBucket(brush.depthM, bucketM)
        groups[bucket] = groups[bucket] or {}
        groups[bucket][#groups[bucket] + 1] = brush
        consumed = consumed + 1
    end

    local depths = {}
    for depth in pairs(groups) do depths[#depths + 1] = depth end
    table.sort(depths, function(a, b) return a > b end)

    local jobs = 0
    local submitted = 0
    local leftovers = {}

    for _, depth in ipairs(depths) do
        local group = groups[depth]
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

            local ok = self:_submitBatch(depth, batch)
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

    return submitted, jobs
end

function Writer:clear()
    self.queue = {}
end
