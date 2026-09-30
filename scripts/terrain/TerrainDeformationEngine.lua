RealismExtensionsTerrainDeformationEngine = RealismExtensionsTerrainDeformationEngine or {}
local Engine = RealismExtensionsTerrainDeformationEngine

Engine.SPEC_NAME = "realismExtensionsTerrainDeformation"
Engine.SPEC_FIELD = "spec_" .. Engine.SPEC_NAME

Engine.DEFAULTS = {
    sampleIntervalMs = 250,
    pathSpacingFactor = 0.45,
    minPathSpacingM = 0.10,
    maxSamplesPerWheelTick = 6,
    inactiveSpeedKph = 0.10,
    inactiveWheelSpeedMps = 0.05,
    maxBrushDepthM = 0.003,
    brushHardness = 0.35,
    historyCellSizeM = 0.20,
    maxHistoryCells = 50000
}

local function distance2D(x1, z1, x2, z2)
    local dx, dz = x2 - x1, z2 - z1
    return math.sqrt(dx * dx + dz * dz)
end

local function copyHistoryForAppliedDepth(response, previousDepth, appliedDepth)
    local h = {}
    for k, v in pairs(response.nextHistory or {}) do h[k] = v end
    h.rutDepthM = math.max(previousDepth or 0, (previousDepth or 0) + appliedDepth)
    return h
end

local function diagnosticsEnabled()
    return RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.diagnostics ~= nil
        and RealismExtensionsConfig.diagnostics.verbose == true
end

local function diagCount(name, delta)
    if not diagnosticsEnabled() then return end
    local runtime = RealismExtensionsTerrainRuntime
    if runtime == nil then return end
    runtime.stats = runtime.stats or {}
    runtime.stats[name] = (tonumber(runtime.stats[name]) or 0) + (delta or 1)
end

local function diagMax(name, value)
    if not diagnosticsEnabled() or type(value) ~= "number" then return end
    local runtime = RealismExtensionsTerrainRuntime
    if runtime == nil then return end
    runtime.stats = runtime.stats or {}
    runtime.stats[name] = math.max(tonumber(runtime.stats[name]) or 0, value)
end

local function diagMin(name, value)
    if not diagnosticsEnabled() or type(value) ~= "number" then return end
    local runtime = RealismExtensionsTerrainRuntime
    if runtime == nil then return end
    runtime.stats = runtime.stats or {}
    local current = tonumber(runtime.stats[name])
    runtime.stats[name] = current == nil and value or math.min(current, value)
end

function Engine.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Wheels, specializations)
end

function Engine.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", Engine)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", Engine)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", Engine)
end

function Engine:onLoad(savegame)
    local wheels = nil
    if self.getWheels ~= nil then
        wheels = self:getWheels()
    elseif self.spec_wheels ~= nil then
        wheels = self.spec_wheels.wheels
    end

    self[Engine.SPEC_FIELD] = {
        wheels = wheels or {},
        states = setmetatable({}, { __mode = "k" }),
        axleContacts = {},
        diagnosticEpoch = 0
    }

    diagCount("vehiclesLoaded", 1)
    local wheelCount = 0
    for _ in pairs(wheels or {}) do wheelCount = wheelCount + 1 end
    diagCount("wheelsAttached", wheelCount)
end

local function getCheapVehicleSpeedKph(vehicle)
    if vehicle ~= nil and type(vehicle.getLastSpeed) == "function" then
        local ok, value = pcall(vehicle.getLastSpeed, vehicle)
        if ok and type(value) == "number" then return math.abs(value) end
    end
    return 0
end

local function getCheapWheelSpeedMps(wheel, physics)
    if physics ~= nil and type(physics.mrLastWheelSpeed) == "number" then
        return math.abs(physics.mrLastWheelSpeed)
    end

    if getWheelShapeAxleSpeed ~= nil
        and wheel ~= nil
        and wheel.node ~= nil
        and physics ~= nil
        and physics.wheelShape ~= nil then
        local ok, axleSpeed = pcall(getWheelShapeAxleSpeed, wheel.node, physics.wheelShape)
        if ok and type(axleSpeed) == "number" then
            local radius = tonumber(physics.radius) or tonumber(physics.radiusOriginal)
            if radius ~= nil and radius > 0 then
                return math.abs(axleSpeed * radius)
            end
        end
    end

    return 0
end

local function cheapActivityGate(vehicle, wheel, physics, state)
    local bodySpeed = getCheapVehicleSpeedKph(vehicle)
    local wheelSpeed = getCheapWheelSpeedMps(wheel, physics)

    if state.hadContext ~= true then
        return true, bodySpeed, wheelSpeed
    end

    return bodySpeed >= Engine.DEFAULTS.inactiveSpeedKph
        or wheelSpeed >= Engine.DEFAULTS.inactiveWheelSpeedMps,
        bodySpeed,
        wheelSpeed
end

local function shouldSample(state, dt, intervalMs)
    state.elapsedMs = (state.elapsedMs or intervalMs) + math.max(0, tonumber(dt) or 0)
    if state.elapsedMs < intervalMs then return false, 0 end
    local elapsed = state.elapsedMs
    state.elapsedMs = 0
    return true, elapsed
end

local function sampleTerrainHeight(x, z)
    local mission = g_currentMission
    local terrain = mission ~= nil and mission.terrainRootNode or g_terrainNode
    if terrain == nil or terrain == 0 or getTerrainHeightAtWorldPos == nil then
        return nil
    end
    local ok, y = pcall(getTerrainHeightAtWorldPos, terrain, x, 0, z)
    if ok and type(y) == "number" then return y end
    return nil
end

function Engine.computeCentralTerrainCrest(left, right, heightFn)
    if type(left) ~= "table" or type(right) ~= "table" then return nil end
    if type(left.x) ~= "number" or type(left.z) ~= "number"
        or type(right.x) ~= "number" or type(right.z) ~= "number" then
        return nil
    end

    heightFn = heightFn or sampleTerrainHeight
    local leftY = heightFn(left.x, left.z)
    local rightY = heightFn(right.x, right.z)
    local centerX = (left.x + right.x) * 0.5
    local centerZ = (left.z + right.z) * 0.5
    local centerY = heightFn(centerX, centerZ)
    if type(leftY) ~= "number" or type(rightY) ~= "number"
        or type(centerY) ~= "number" then
        return nil
    end

    local expectedPlaneY = (leftY + rightY) * 0.5
    local dx, dz = right.x - left.x, right.z - left.z
    return {
        crestHeightM = centerY - expectedPlaneY,
        axleSpanM = math.sqrt(dx * dx + dz * dz),
        centerX = centerX,
        centerZ = centerZ,
        centerTerrainY = centerY,
        leftTerrainY = leftY,
        rightTerrainY = rightY
    }
end

function Engine.updateAxleCrestDiagnostics(vehicle, physics, context)
    if not diagnosticsEnabled() or vehicle == nil
        or physics == nil or context == nil then return end

    local localX = tonumber(physics.positionX)
    local localZ = tonumber(physics.positionZ)
    if localX == nil or localZ == nil
        or type(context.worldX) ~= "number"
        or type(context.worldZ) ~= "number" then
        return
    end

    -- Bucket left/right contacts by axle longitudinal position. 0.25 m is
    -- narrow enough to keep distinct axles apart while tolerating modded wheel
    -- placement noise, matching the grouping precedent from SoilCompaction.
    local axleKey = math.floor(localZ * 4 + 0.5)
    local spec = vehicle[Engine.SPEC_FIELD]
    if spec == nil then return end
    spec.axleContacts = spec.axleContacts or {}

    local axle = spec.axleContacts[axleKey]
    if axle == nil or axle.epoch ~= spec.diagnosticEpoch then
        axle = { epoch = spec.diagnosticEpoch }
        spec.axleContacts[axleKey] = axle
    end

    local side = localX < 0 and "left" or (localX > 0 and "right" or nil)
    if side == nil then return end

    axle[side] = {
        x = context.worldX,
        z = context.worldZ,
        supportWidthM = tonumber(context.supportWidthM),
        baseTireWidthM = tonumber(context.baseTireWidthM)
    }

    if axle.left == nil or axle.right == nil or axle.measured == true then return end
    axle.measured = true

    local result = Engine.computeCentralTerrainCrest(axle.left, axle.right)
    if result == nil then return end

    diagCount("axleCrestSamples", 1)
    diagMax("maxAxleSpanM", result.axleSpanM)
    diagMax("maxCentralTerrainCrestM", result.crestHeightM)
    if result.crestHeightM >= 0.05 then
        diagCount("centralCrestOver5cm", 1)
    end
    if result.crestHeightM >= 0.10 then
        diagCount("centralCrestOver10cm", 1)
    end
    if result.crestHeightM >= 0.15 then
        diagCount("centralCrestOver15cm", 1)
    end
end

function Engine.processSample(vehicle, wheel, wheelState, context, footprint, x, z, dtMs, stationaryWheelspin)
    diagCount("samplesProcessed", 1)
    local historyStore = RealismExtensionsTerrainRuntime.history
    local writer = RealismExtensionsTerrainRuntime.writer

    local history = historyStore:get(x, z)
    local previousDepth = history ~= nil and tonumber(history.rutDepthM) or 0

    local surface = RealismExtensionsTerrainSurfaceResponse ~= nil
        and RealismExtensionsTerrainSurfaceResponse.resolve(context, x, z) or nil
    if surface == nil or surface.available ~= true then
        diagCount("surfaceRejects", 1)
        diagCount("surfaceSeen_UNKNOWN", 1)
        return false
    end
    diagCount("surfaceSeen_" .. tostring(surface.category or "UNKNOWN"), 1)
    if (tonumber(surface.deformability01) or 0) <= 0 then
        diagCount("surfaceRejects", 1)
        diagCount("surfaceBlocked_" .. tostring(surface.category or "UNKNOWN"), 1)
        return false
    end
    diagCount("surfaceAccepted", 1)
    diagCount("surfaceDeformable_" .. tostring(surface.category or "UNKNOWN"), 1)

    local response = RealismExtensionsTerrainResponseModel.compute(
        context,
        footprint,
        history,
        dtMs,
        {
            absoluteMaxStaticRutDepthM = surface.maxStaticRutDepthM,
            absoluteMaxSlipRutDepthM = surface.maxSlipRutDepthM
        }
    )
    if response == nil or response.available ~= true then
        diagCount("responseRejects", 1)
        return false
    end

    diagMax("maxRutDepthM", tonumber(response.rutDepthM) or 0)
    diagMax("maxRutCapacityM", tonumber(response.rutCapacityM) or 0)
    diagMax("maxStaticRutCapacityM", tonumber(response.staticRutCapacityM) or 0)
    diagMax("maxSlipRutCapacityM", tonumber(response.slipRutCapacityM) or 0)
    diagMax("maxSlipSinkageMultiplier", tonumber(response.slipSinkageMultiplier) or 0)

    local desiredDelta = math.max(0, tonumber(response.rutDepthM) - previousDepth)
    diagCount("requestedDepthM", desiredDelta)
    local appliedDepth = math.min(
        desiredDelta,
        Engine.DEFAULTS.maxBrushDepthM
    )
    appliedDepth = appliedDepth
        * math.max(0, math.min(1, tonumber(surface.deformability01) or 1))

    if appliedDepth <= writer.options.minDepthM then
        -- Preserve shear/pass history even when the geometric delta is too
        -- small to justify a brush.
        historyStore:commit(x, z, copyHistoryForAppliedDepth(response, previousDepth, 0))
        diagCount("belowBrushThreshold", 1)
        return false
    end

    local accepted = writer:enqueue({
        x = x,
        z = z,
        depthM = appliedDepth,
        radiusM = math.max(0.10, response.rutWidthM * 0.5),
        hardness = Engine.DEFAULTS.brushHardness
    })

    if accepted then
        historyStore:commit(
            x,
            z,
            copyHistoryForAppliedDepth(response, previousDepth, appliedDepth)
        )
        diagCount("brushesAccepted", 1)
        diagCount("appliedDepthM", appliedDepth)
        diagCount("surfaceBrushes_" .. tostring(surface.category or "UNKNOWN"), 1)
        diagCount("surfaceAppliedDepth_" .. tostring(surface.category or "UNKNOWN"), appliedDepth)
        if stationaryWheelspin == true then
            diagCount("stationaryBrushesAccepted", 1)
            diagCount("stationaryAppliedDepthM", appliedDepth)
            diagMax("stationaryMaxRutDepthM", tonumber(response.rutDepthM) or 0)
            diagMax("stationaryMaxRutCapacityM", tonumber(response.rutCapacityM) or 0)
        end
        return true
    end

    diagCount("writerRejects", 1)
    return false
end

function Engine.processWheel(vehicle, wheel, dt)
    if wheel == nil then return end
    diagCount("wheelTicks", 1)
    local physics = wheel.physics
    if physics == nil then return end

    local spec = vehicle[Engine.SPEC_FIELD]
    local state = spec.states[wheel]
    if state == nil then
        state = { elapsedMs = Engine.DEFAULTS.sampleIntervalMs }
        spec.states[wheel] = state
    end

    local sample, elapsedMs = shouldSample(
        state,
        dt,
        Engine.DEFAULTS.sampleIntervalMs
    )
    if not sample then return end
    diagCount("sampleTicks", 1)

    local active, bodySpeedKph, wheelSpeedMps =
        cheapActivityGate(vehicle, wheel, physics, state)
    if not active then
        diagCount("activityGateSkips", 1)
        return
    end

    local stationaryWheelspin =
        bodySpeedKph < Engine.DEFAULTS.inactiveSpeedKph
        and wheelSpeedMps >= Engine.DEFAULTS.inactiveWheelSpeedMps
    if stationaryWheelspin then
        diagCount("stationaryWheelspinCandidates", 1)
    end

    diagCount("contextRequests", 1)
    local context = RealismExtensionsState.getWheelContext(vehicle, wheel, {
        speedKph = bodySpeedKph,
        wheelSurfaceSpeedMps = wheelSpeedMps
    })
    if context == nil then
        diagCount("contextUnavailable", 1)
        state.lastX, state.lastZ = nil, nil
        return
    end
    if context.grounded ~= true then
        diagCount("notGrounded", 1)
        state.lastX, state.lastZ = nil, nil
        return
    end
    if type(context.worldX) ~= "number" or type(context.worldZ) ~= "number" then
        diagCount("missingContactPosition", 1)
        state.lastX, state.lastZ = nil, nil
        return
    end

    diagCount("contextAccepted", 1)
    state.hadContext = true

    local footprint = RealismExtensionsFootprintModel.compute(context)
    if footprint == nil or footprint.available ~= true then
        diagCount("footprintRejects", 1)
        state.lastX, state.lastZ = context.worldX, context.worldZ
        return
    end

    diagCount("footprintAccepted", 1)
    Engine.updateAxleCrestDiagnostics(vehicle, physics, context)

    -- Footprint telemetry is intentionally source-state focused. It lets the
    -- next runtime test prove how MR/Mud represent duals before RE invents any
    -- dual-specific multiplier.
    local supportWidthM = tonumber(footprint.supportWidthM)
    local baseWidthM = tonumber(context.baseTireWidthM)
    local contactAreaM2 = tonumber(footprint.contactAreaM2)
    local groundPressurePa = tonumber(footprint.groundPressurePa)
    local wheelLoadN = tonumber(footprint.wheelLoadN or context.wheelLoadN)
    local inflationBar = tonumber(footprint.inflationPressureBar or context.tirePressureBar)

    diagMax("maxSupportWidthM", supportWidthM)
    diagMax("maxBaseTireWidthM", baseWidthM)
    diagMax("maxContactAreaM2", contactAreaM2)
    diagMax("maxWheelLoadN", wheelLoadN)
    diagMax("maxInflationPressureBar", inflationBar)
    diagMin("minGroundPressurePa", groundPressurePa)
    diagMax("maxGroundPressurePa", groundPressurePa)

    if supportWidthM ~= nil and baseWidthM ~= nil and baseWidthM > 0 then
        local ratio = supportWidthM / baseWidthM
        diagMax("maxSupportWidthRatio", ratio)
        if ratio >= 1.45 then
            diagCount("wideSupportContexts", 1)
        end
    end

    local x, z = context.worldX, context.worldZ
    local lastX, lastZ = state.lastX, state.lastZ
    state.lastX, state.lastZ = x, z

    if lastX == nil or lastZ == nil then
        Engine.processSample(vehicle, wheel, state, context, footprint, x, z, elapsedMs, stationaryWheelspin)
        return
    end

    local pathDistance = distance2D(lastX, lastZ, x, z)
    local spacing = math.max(
        Engine.DEFAULTS.minPathSpacingM,
        math.min(footprint.supportWidthM, footprint.footprintLengthM)
            * Engine.DEFAULTS.pathSpacingFactor
    )

    local movingSamples = math.max(1, math.ceil(pathDistance / spacing))
    movingSamples = math.min(
        movingSamples,
        Engine.DEFAULTS.maxSamplesPerWheelTick
    )

    -- Stationary wheelspin is still processed at the current contact cell.
    if pathDistance < Engine.DEFAULTS.minPathSpacingM then
        movingSamples = 1
        diagCount("stationaryContactSamples", 1)
    else
        diagCount("movingContactSamples", movingSamples)
    end

    local sampleDt = elapsedMs / movingSamples

    for i = 1, movingSamples do
        local t = i / movingSamples
        local sx = lastX + (x - lastX) * t
        local sz = lastZ + (z - lastZ) * t
        Engine.processSample(
            vehicle,
            wheel,
            state,
            context,
            footprint,
            sx,
            sz,
            sampleDt,
            stationaryWheelspin
        )
    end
end

function Engine:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    diagCount("vehicleUpdateCalls", 1)
    if RealismExtensionsConfig == nil
        or RealismExtensionsConfig.modules == nil
        or RealismExtensionsConfig.modules.TerrainDeformation ~= true then
        return
    end

    if self.isServer ~= true then return end
    if RealismExtensionsTerrainRuntime == nil
        or RealismExtensionsTerrainRuntime.history == nil
        or RealismExtensionsTerrainRuntime.writer == nil then
        return
    end

    local spec = self[Engine.SPEC_FIELD]
    if spec == nil then return end
    spec.diagnosticEpoch = (spec.diagnosticEpoch or 0) + 1

    for _, wheel in pairs(spec.wheels or {}) do
        Engine.processWheel(self, wheel, dt)
    end
end

function Engine:onDelete()
    self[Engine.SPEC_FIELD] = nil
end

RealismExtensionsTerrainRuntime = RealismExtensionsTerrainRuntime or {
    history = nil,
    writer = nil,
    stats = {}
}

function RealismExtensionsTerrainRuntime.initialize()
    RealismExtensionsTerrainRuntime.stats = {}
    if RealismExtensionsTerrainRuntime.history == nil then
        RealismExtensionsTerrainRuntime.history = RealismExtensionsSpatialHistory.new({
            cellSizeM = Engine.DEFAULTS.historyCellSizeM,
            maxCells = Engine.DEFAULTS.maxHistoryCells
        })
    end

    if RealismExtensionsTerrainRuntime.writer == nil then
        RealismExtensionsTerrainRuntime.writer = RealismExtensionsTerrainWriter.new()
    end
end

function RealismExtensionsTerrainRuntime.flush()
    if RealismExtensionsTerrainRuntime.writer ~= nil then
        return RealismExtensionsTerrainRuntime.writer:flush()
    end
    return 0, 0
end

function RealismExtensionsTerrainRuntime.getDiagnostics()
    local out = {}
    for key, value in pairs(RealismExtensionsTerrainRuntime.stats or {}) do
        out[key] = value
    end
    return out
end

function RealismExtensionsTerrainRuntime.clear()
    if RealismExtensionsTerrainSurfaceResponse ~= nil
        and RealismExtensionsTerrainSurfaceResponse.clear ~= nil then
        RealismExtensionsTerrainSurfaceResponse.clear()
    end
    if RealismExtensionsTerrainRuntime.history ~= nil then
        RealismExtensionsTerrainRuntime.history:clear()
    end
    if RealismExtensionsTerrainRuntime.writer ~= nil then
        RealismExtensionsTerrainRuntime.writer:clear()
    end
    RealismExtensionsTerrainRuntime.history = nil
    RealismExtensionsTerrainRuntime.writer = nil
    RealismExtensionsTerrainRuntime.stats = {}
end
