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
    if state.hadContext ~= true then return true end

    local bodySpeed = getCheapVehicleSpeedKph(vehicle)
    local wheelSpeed = getCheapWheelSpeedMps(wheel, physics)

    return bodySpeed >= Engine.DEFAULTS.inactiveSpeedKph
        or wheelSpeed >= Engine.DEFAULTS.inactiveWheelSpeedMps
end

local function shouldSample(state, dt, intervalMs)
    state.elapsedMs = (state.elapsedMs or intervalMs) + math.max(0, tonumber(dt) or 0)
    if state.elapsedMs < intervalMs then return false, 0 end
    local elapsed = state.elapsedMs
    state.elapsedMs = 0
    return true, elapsed
end

function Engine:_processSample(vehicle, wheel, wheelState, context, footprint, x, z, dtMs)
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
    if response == nil or response.available ~= true then return false end

    local desiredDelta = math.max(0, tonumber(response.rutDepthM) - previousDepth)
    local appliedDepth = math.min(
        desiredDelta,
        Engine.DEFAULTS.maxBrushDepthM
    )

    if appliedDepth <= writer.options.minDepthM then
        -- Preserve shear/pass history even when the geometric delta is too
        -- small to justify a brush.
        historyStore:commit(x, z, copyHistoryForAppliedDepth(response, previousDepth, 0))
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
        return true
    end

    return false
end

function Engine:_processWheel(vehicle, wheel, dt)
    if wheel == nil then return end
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

    if not cheapActivityGate(vehicle, wheel, physics, state) then
        return
    end

    local context = RealismExtensionsState.getWheelContext(vehicle, wheel)
    if context == nil
        or context.grounded ~= true
        or context.soilContact ~= true
        or type(context.worldX) ~= "number"
        or type(context.worldZ) ~= "number" then
        state.lastX, state.lastZ = nil, nil
        return
    end

    state.hadContext = true

    local footprint = RealismExtensionsFootprintModel.compute(context)
    if footprint == nil or footprint.available ~= true then
        state.lastX, state.lastZ = context.worldX, context.worldZ
        return
    end

    local x, z = context.worldX, context.worldZ
    local lastX, lastZ = state.lastX, state.lastZ
    state.lastX, state.lastZ = x, z

    if lastX == nil or lastZ == nil then
        self:_processSample(vehicle, wheel, state, context, footprint, x, z, elapsedMs)
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
    end

    local sampleDt = elapsedMs / movingSamples

    for i = 1, movingSamples do
        local t = i / movingSamples
        local sx = lastX + (x - lastX) * t
        local sz = lastZ + (z - lastZ) * t
        self:_processSample(
            vehicle,
            wheel,
            state,
            context,
            footprint,
            sx,
            sz,
            sampleDt
        )
    end
end

function Engine:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
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
        self:_processWheel(self, wheel, dt)
    end
end

function Engine:onDelete()
    self[Engine.SPEC_FIELD] = nil
end

RealismExtensionsTerrainRuntime = RealismExtensionsTerrainRuntime or {
    history = nil,
    writer = nil
}

function RealismExtensionsTerrainRuntime.initialize()
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

function RealismExtensionsTerrainRuntime.clear()
    if RealismExtensionsTerrainRuntime.history ~= nil then
        RealismExtensionsTerrainRuntime.history:clear()
    end
    if RealismExtensionsTerrainRuntime.writer ~= nil then
        RealismExtensionsTerrainRuntime.writer:clear()
    end
    RealismExtensionsTerrainRuntime.history = nil
    RealismExtensionsTerrainRuntime.writer = nil
end

-- Inject the specialization into every wheeled vehicle type. This gives player,
-- GIANTS AI, Courseplay-controlled vehicles and wheeled implements the same
-- event-driven path without scanning g_currentMission.vehicles.
if g_specializationManager ~= nil and g_specializationManager:getSpecializationByName(Engine.SPEC_NAME) == nil then
    g_specializationManager:addSpecialization(
        Engine.SPEC_NAME,
        "RealismExtensionsTerrainDeformationEngine",
        g_currentModDirectory .. "scripts/terrain/TerrainDeformationEngine.lua",
        g_currentModName
    )
end

local function installSpecialization(typeManager)
    if typeManager == nil or typeManager.typeName ~= "vehicle" then return end

    local fullName = g_currentModName .. "." .. Engine.SPEC_NAME
    for typeName, typeDef in pairs(typeManager:getTypes()) do
        if typeDef ~= nil
            and typeName ~= "locomotive"
            and typeDef.specializationsByName["wheels"] ~= nil
            and typeDef.specializationsByName[fullName] == nil then
            typeManager:addSpecialization(typeName, fullName)
        end
    end
end

TypeManager.validateTypes = Utils.appendedFunction(
    TypeManager.validateTypes,
    installSpecialization
)
