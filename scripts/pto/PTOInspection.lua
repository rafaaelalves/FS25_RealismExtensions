-- Read-only, on-demand PTO differential diagnostic.
-- No hook, no motor control, no per-frame polling, and no network events.
RealismExtensionsPTOInspection = RealismExtensionsPTOInspection or {}
local Inspection = RealismExtensionsPTOInspection
Inspection.VERSION = 1
Inspection.commandInstalled = false

local function safeCall(object, method)
    if object == nil or type(object[method]) ~= "function" then
        return nil
    end
    local ok, a, b = pcall(object[method], object)
    if ok then return a, b end
    return nil
end

local function countTable(value)
    if type(value) ~= "table" then return 0 end
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    return count
end

local function value(value)
    if value == nil then return "-" end
    return tostring(value)
end

local function label(object)
    if object == nil then return "-" end
    return value(safeCall(object, "getName")
        or object.configFileName
        or object.typeName)
end

local function getMotor(vehicle)
    return safeCall(vehicle, "getMotor")
        or (vehicle ~= nil and vehicle.spec_motorized ~= nil
        and vehicle.spec_motorized.motor or nil)
end

local function getVehicle()
    local vehicle = safeCall(g_localPlayer, "getCurrentVehicle")
    if vehicle ~= nil then return vehicle end
    local mission = g_currentMission
    if mission == nil then return nil end
    return mission.controlledVehicle
        or safeCall(mission, "getControlledVehicle")
        or (mission.hud ~= nil and mission.hud.speedMeter ~= nil
            and mission.hud.speedMeter.vehicle or nil)
end

local function add(lines, message)
    lines[#lines + 1] = message
end

local function formatRoot(vehicle, lines)
    local owner = nil
    -- Owner API is static (getVehicleState(vehicle)), not an instance method.
    if RealismExtensionsPTO ~= nil
        and type(RealismExtensionsPTO.getVehicleState) == "function" then
        local ok, result = pcall(
            RealismExtensionsPTO.getVehicleState, vehicle
        )
        if ok and type(result) == "table" then owner = result end
    end
    local engaged, source
    if RealismExtensionsPTOResolver ~= nil
        and type(RealismExtensionsPTOResolver.isPtoEngaged) == "function" then
        local ok, active, reason = pcall(
            RealismExtensionsPTOResolver.isPtoEngaged, vehicle
        )
        if ok then engaged, source = active, reason end
    end
    local motor = getMotor(vehicle)
    local rpm = safeCall(motor, "getNonClampedMotorRpm")
        or safeCall(motor, "getLastRealMotorRpm")
        or (motor ~= nil and motor.lastRealMotorRpm or nil)
    local ptoDemand = nil
    if PowerConsumer ~= nil
        and type(PowerConsumer.getMaxPtoRpm) == "function" then
        local ok, result = pcall(PowerConsumer.getMaxPtoRpm, vehicle)
        if ok then ptoDemand = result end
    end
    local ai = safeCall(vehicle, "getIsAIActive")
    add(lines, string.format(
        "ROOT name=%s ai=%s gear=%s selected=%s required=%s nominalFamily=%s gearCompatibility=%s known=%s unknown=%s conflict=%s hasConsumer=%s engaged=%s engagementSource=%s",
        label(vehicle), value(ai),
        value(owner ~= nil and owner.modeToken),
        value(owner ~= nil and owner.shaftRpm),
        value(owner ~= nil and owner.requiredShaftRpm),
        value(owner ~= nil and owner.requiredGearboxFamilyRpm),
        value(owner ~= nil and owner.gearCompatibility),
        value(owner ~= nil and owner.knownRequirementCount),
        value(owner ~= nil and owner.unknownRequirementCount),
        value(owner ~= nil and owner.requirementConflict),
        value(owner ~= nil and owner.hasPtoConsumer),
        value(engaged), value(source)
    ))
    add(lines, string.format(
        "MOTOR engineRPM=%s effectiveRatio=%s handTargetRPM=%s maxPtoDemand=%s mrMinPtoRot=%s mrMinPtoIdleRot=%s",
        value(rpm),
        value(owner ~= nil and owner.effectiveMotorRatio),
        value(owner ~= nil and owner.handThrottleRpm),
        value(ptoDemand),
        value(motor ~= nil and motor.mrLastMinRotForPTO),
        value(motor ~= nil and motor.mrLastMinRotForPTOidle)
    ))
end

local function formatConsumers(vehicle, lines)
    local visited = {}
    local count = 0
    local limit = 32
    local function walk(parent, depth)
        if parent == nil or visited[parent] or depth > 8 then return end
        visited[parent] = true
        local implements = safeCall(parent, "getAttachedImplements")
        if type(implements) ~= "table" then return end
        for _, attachment in pairs(implements) do
            if count >= limit then return end
            local tool = attachment ~= nil and attachment.object or nil
            if tool ~= nil and not visited[tool] then
                count = count + 1
                local spec = tool.spec_powerConsumer or {}
                local pto = tool.spec_powerTakeOffs or {}
                local inputs = safeCall(tool, "getInputPowerTakeOffs")
                    or pto.inputPowerTakeOffs
                local connected = 0
                if type(inputs) == "table" then
                    for _, input in pairs(inputs) do
                        if type(input) == "table"
                            and input.connectedVehicle ~= nil then
                            connected = connected + 1
                        end
                    end
                end
                local liveRpm = safeCall(tool, "getPtoRpm")
                local consumes = safeCall(tool, "getDoConsumePtoPower")
                local turnedOn = safeCall(tool, "getIsTurnedOn")
                local active = safeCall(tool, "getIsPowerTakeOffActive")
                add(lines, string.format(
                    "TOOL[%d] depth=%d name=%s path=%s inputPto=%d connectedInput=%d rawConsumerRPM=%s liveConsumerRPM=%s mrPtoCurrentRPM=%s mrPtoRpmRatio=%s forcePtoRpm=%s mrBalerPowerKW=%s consumePower=%s turnedOn=%s activePto=%s powerKW=%s",
                    count, depth, label(tool), value(tool.configFileName),
                    countTable(inputs), connected,
                    value(spec.ptoRpm), value(liveRpm),
                    value(tool.mrPtoCurrentRpm),
                    value(tool.mrPtoCurrentRpmRatio),
                    value(tool.mrPowerConsumerForcePtoRpm),
                    value(tool.mrBalerLastNeededPower),
                    value(consumes), value(turnedOn), value(active),
                    value(spec.neededMaxPtoPower or spec.neededPtoPower)
                ))
                walk(tool, depth + 1)
            end
        end
    end
    walk(vehicle, 1)
    if count == 0 then add(lines, "TOOL none attached") end
    return count
end

function Inspection.snapshot(vehicle)
    local lines = {}
    if vehicle == nil then
        return { "PTO inspection: no controlled vehicle" }
    end
    formatRoot(vehicle, lines)
    formatConsumers(vehicle, lines)
    return lines
end

function Inspection:consoleCommandInspect()
    local lines = Inspection.snapshot(getVehicle())
    if RealismExtensionsDiagnostics ~= nil
        and type(RealismExtensionsDiagnostics.info) == "function" then
        for _, message in ipairs(lines) do
            RealismExtensionsDiagnostics.info(
                "PTO INSPECT | " .. message
            )
        end
    end
    return string.format(
        "PTO inspection: %d line(s) written to game log", #lines
    )
end

function Inspection:loadMap()
    if not self.commandInstalled
        and type(addConsoleCommand) == "function" then
        addConsoleCommand(
            "rePTOInspect",
            "Read-only snapshot: current PTO tractor, motor and implements",
            "consoleCommandInspect",
            self
        )
        self.commandInstalled = true
    end
end

function Inspection:deleteMap()
    if self.commandInstalled
        and type(removeConsoleCommand) == "function" then
        removeConsoleCommand("rePTOInspect")
    end
    self.commandInstalled = false
end

addModEventListener(Inspection)
return Inspection
