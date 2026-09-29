RealismExtensionsTerrainDeformationEngine = RealismExtensionsTerrainDeformationEngine or {}
local Engine = RealismExtensionsTerrainDeformationEngine

Engine.SPEC_NAME = "realismExtensionsTerrainDeformation"
Engine.SPEC_FIELD = "spec_" .. Engine.SPEC_NAME

Engine.DEFAULTS = {
    sampleIntervalMs = 100,
    pathSpacingFactor = 0.45,
    minPathSpacingM = 0.10,
    maxSamplesPerWheelTick = 6,
    inactiveSpeedKph = 0.10,
    inactiveWheelSpeedMps = 0.05,
    maxBrushDepthM = 0.015,
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
        states = setmetatable({}, { __mode = "k" })
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

function Engine.processSample(vehicle, wheel, wheelState, context, footprint, x, z, dtMs, stationaryWheelspin)
    diagCount("samplesProcessed", 1)
    local historyStore = RealismExtensionsTerrainRuntime.history
    local writer = RealismExtensionsTerrainRuntime.writer

    local history = historyStore:get(x, z)
    local previousDepth = history ~= nil and tonumber(history.rutDepthM) or 0

    local response = RealismExtensionsTerrainResponseModel.compute(
        context,
        footprint,
        history,
        dtMs
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
    local context = RealismExtensionsState.getWheelContext(vehicle, wheel)
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
    if context.soilContact ~= true then
        diagCount("notSoilContact", 1)
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
