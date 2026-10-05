RealismExtensionsPTOControl = RealismExtensionsPTOControl or {}
local Control = RealismExtensionsPTOControl
local Model = RealismExtensionsPTOModel
local Resolver = RealismExtensionsPTOResolver

Control.VERSION = 1
Control.SPEC_NAME = "realismExtensionsPTO"
Control.SPEC_TABLE = "spec_realismExtensionsPTO"

local HAND_THROTTLE_RPM_STEP = 100

Control.stats = Control.stats or {}

local function count(name)
    Control.stats[name] = (Control.stats[name] or 0) + 1
end

local function resetStats()
    Control.stats = {
        actionModeNext = 0,
        actionModePrev = 0,
        actionThrottleUp = 0,
        actionThrottleDown = 0,
        actionThrottleReset = 0,
        stateChanges = 0,
        modeChanges = 0,
        throttleChanges = 0,
        rejectedUnsupported = 0,
        rejectedEngaged = 0,
        actionEventsRegistered = 0,
        actionEventsFailed = 0,
        actionEventsCollisionBypass = 0,
        noops = 0
    }
end

local function vehicleLabel(vehicle)
    if vehicle ~= nil and type(vehicle.getName) == "function" then
        local ok, name = pcall(vehicle.getName, vehicle)
        if ok and name ~= nil and tostring(name) ~= "" then
            return tostring(name)
        end
    end
    return tostring(vehicle ~= nil and vehicle.configFileName or "vehicle")
end

local function notifyOperator(message)
    local mission = g_currentMission
    if mission ~= nil and type(mission.showBlinkingWarning) == "function" then
        mission:showBlinkingWarning(tostring(message), 2500)
    end
end

local function modules()
    return RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.modules or {}
end

local function enabledByConfig()
    return modules().PTOControl == true
end

local function getSpec(vehicle)
    return vehicle ~= nil and vehicle[Control.SPEC_TABLE] or nil
end

local function firstAvailableMode(capability)
    local modes = Model.sortedModes(capability ~= nil and capability.modes or nil)
    return modes[1] or Model.MODE.RPM_540
end

local function isAvailable(spec, mode)
    return spec ~= nil
        and spec.capability ~= nil
        and spec.capability.modes ~= nil
        and spec.capability.modes[Model.normalizeMode(mode)] ~= nil
end

local function getMotorBounds(vehicle)
    local motor = Resolver.getMotor(vehicle)
    if motor == nil then return 850, 2200 end
    local minRpm = tonumber(motor.minRpm) or 850
    local maxRpm = tonumber(motor.maxRpm) or 2200
    if maxRpm < minRpm then maxRpm = minRpm end
    return minRpm, maxRpm
end

local function getCurrentEngineRpm(vehicle)
    local motor = Resolver.getMotor(vehicle)
    if motor == nil then return nil end

    for _, name in ipairs({
        "getLastRealMotorRpm",
        "getLastModRpm",
        "getNonClampedMotorRpm"
    }) do
        local fn = motor[name]
        if type(fn) == "function" then
            local ok, value = pcall(fn, motor)
            value = ok and tonumber(value) or nil
            if value ~= nil and value == value and value >= 0 then
                return value
            end
        end
    end

    return tonumber(motor.lastRealMotorRpm)
        or tonumber(motor.lastMotorRpm)
        or tonumber(motor.equalizedMotorRpm)
end

local function logOperatorState(vehicle, spec, reason)
    if RealismExtensionsDiagnostics == nil or spec == nil then return end
    local mode = Model.getMode(spec.mode)
    local minRpm, maxRpm = getMotorBounds(vehicle)
    local handRpm = Model.handThrottleRpm(
        spec.handThrottlePercent,
        minRpm,
        maxRpm
    )
    RealismExtensionsDiagnostics.verbose(string.format(
        "PTO operator | vehicle=%s reason=%s mode=%s hand=%srpm throttle=%.1f%% required=%s mismatch=%s",
        vehicleLabel(vehicle),
        tostring(reason),
        tostring(mode ~= nil and mode.token or "?"),
        handRpm > 0 and tostring(math.floor(handRpm + 0.5)) or "ROAD/",
        (tonumber(spec.handThrottlePercent) or 0) * 100,
        tostring(spec.requirements ~= nil and spec.requirements.requiredRpm or "-"),
        tostring(spec.requirements ~= nil
            and spec.requirements.requiredRpm ~= nil
            and spec.requirements.requiredRpm ~= mode.shaftRpm)
    ))
end

local function getModeRatio(spec)
    if spec == nil or spec.capability == nil then return nil end
    local entry = spec.capability.modes ~= nil
        and spec.capability.modes[spec.mode] or nil
    return entry ~= nil and tonumber(entry.effectiveMotorRatio) or nil
end

local function availableModeMask(spec)
    local mask = 0
    if spec ~= nil and type(spec.availableModes) == "table" then
        for mode in pairs(spec.availableModes) do
            mode = Model.normalizeMode(mode)
            mask = mask + (2 ^ (mode - 1))
        end
    end
    return mask
end

local function refreshPublicState(vehicle, spec)
    if spec == nil then return end

    spec.publicState = spec.publicState or {}
    spec.revision = (spec.revision or 0) + 1

    local state = spec.publicState
    local modeDef = Model.getMode(spec.mode)
    local minRpm, maxRpm = getMotorBounds(vehicle)
    local requirements = spec.requirements or {}

    state.apiVersion = RealismExtensionsPTO ~= nil
        and RealismExtensionsPTO.API_VERSION or 1
    state.revision = spec.revision
    state.enabled = spec.enabled == true
    state.hasPtoOutput = spec.hasPtoOutput == true
    state.mode = spec.mode
    state.modeToken = modeDef.token
    state.shaftRpm = modeDef.shaftRpm
    state.economy = modeDef.economy == true
    state.effectiveMotorRatio = getModeRatio(spec)
    state.nativeMotorRatio = spec.capability ~= nil
        and spec.capability.nativeMotorRatio or nil
    state.handThrottlePercent = spec.handThrottlePercent or 0
    state.handThrottleRpm = Model.handThrottleRpm(
        spec.handThrottlePercent,
        minRpm,
        maxRpm
    )
    state.requiredShaftRpm = requirements.requiredRpm
    state.requirementKnown = requirements.requiredRpm ~= nil
    state.requirementConflict = requirements.conflict == true
    state.hasPtoConsumer = requirements.hasPtoConsumer == true
    state.unknownRequirementCount = requirements.unknownCount or 0
    state.mismatch = requirements.requiredRpm ~= nil
        and requirements.requiredRpm ~= modeDef.shaftRpm
    state.capabilitySource = spec.capability ~= nil
        and spec.capability.source or "UNKNOWN"
    state.capabilityProfileId = spec.capability ~= nil
        and spec.capability.profileId or nil
    state.availableModeMask = availableModeMask(spec)
end

local function refreshRequirements(vehicle, spec)
    if spec == nil or spec.enabled ~= true then return end
    spec.requirements = Resolver.collectRequirements(vehicle)
    refreshPublicState(vehicle, spec)
end

function Control.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Motorized, specializations)
        and SpecializationUtil.hasSpecialization(Drivable, specializations)
        and SpecializationUtil.hasSpecialization(AttacherJoints, specializations)
end

function Control.initSpecialization()
    if Vehicle == nil or Vehicle.xmlSchemaSavegame == nil then return end

    local schema = Vehicle.xmlSchemaSavegame
    local modName = tostring(g_currentModName or "FS25_RealismExtensions")
    local key = "vehicles.vehicle(?)." .. modName .. "." .. Control.SPEC_NAME

    schema:register(
        XMLValueType.INT,
        key .. "#mode",
        "Selected PTO speed mode"
    )
    schema:register(
        XMLValueType.FLOAT,
        key .. "#handThrottle",
        "PTO hand throttle position 0..1"
    )
end

function Control.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(
        vehicleType,
        "setPowerTakeOffState",
        Control.setPowerTakeOffState
    )
    SpecializationUtil.registerFunction(
        vehicleType,
        "stepPowerTakeOffMode",
        Control.stepPowerTakeOffMode
    )
    SpecializationUtil.registerFunction(
        vehicleType,
        "adjustPowerTakeOffThrottle",
        Control.adjustPowerTakeOffThrottle
    )
    SpecializationUtil.registerFunction(
        vehicleType,
        "resetPowerTakeOffThrottle",
        Control.resetPowerTakeOffThrottle
    )
    SpecializationUtil.registerFunction(
        vehicleType,
        "refreshPowerTakeOffRequirements",
        Control.refreshPowerTakeOffRequirements
    )
end

function Control.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", Control)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", Control)
    SpecializationUtil.registerEventListener(vehicleType, "onPostAttachImplement", Control)
    SpecializationUtil.registerEventListener(vehicleType, "onPostDetachImplement", Control)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", Control)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", Control)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", Control)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", Control)
    SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", Control)
    SpecializationUtil.registerEventListener(vehicleType, "saveToXMLFile", Control)
end

function Control:onLoad(savegame)
    self[Control.SPEC_TABLE] = self[Control.SPEC_TABLE] or {}
    local spec = self[Control.SPEC_TABLE]

    spec.enabled = enabledByConfig()
    spec.hasPtoOutput = spec.enabled
        and Resolver.vehicleHasOutputPto(self) or false
    spec.capability = Resolver.resolveCapability(self)
    spec.availableModes = spec.capability.modes
    spec.mode = firstAvailableMode(spec.capability)
    spec.handThrottlePercent = 0
    spec.requirements = {
        items = {},
        hasPtoConsumer = false,
        conflict = false,
        requiredRpm = nil,
        unknownCount = 0
    }
    spec.publicState = {}
    spec.revision = 0
    spec.actionEvents = {}
    spec.dirtyFlag = type(self.getNextDirtyFlag) == "function"
        and self:getNextDirtyFlag() or 0

    if spec.hasPtoOutput then
        refreshRequirements(self, spec)
    else
        refreshPublicState(self, spec)
    end
end

function Control:onPostLoad(savegame)
    local spec = getSpec(self)
    if spec == nil or spec.enabled ~= true then return end

    if savegame ~= nil and savegame.xmlFile ~= nil then
        local modName = tostring(g_currentModName or "FS25_RealismExtensions")
        local key = savegame.key .. "." .. modName .. "." .. Control.SPEC_NAME
        local xml = savegame.xmlFile

        local mode = nil
        local throttle = nil
        if type(xml.getValue) == "function" then
            mode = xml:getValue(key .. "#mode")
            throttle = xml:getValue(key .. "#handThrottle")
        else
            if type(xml.getInt) == "function" then
                mode = xml:getInt(key .. "#mode")
            end
            if type(xml.getFloat) == "function" then
                throttle = xml:getFloat(key .. "#handThrottle")
            end
        end

        mode = mode ~= nil and Model.normalizeMode(mode) or spec.mode
        if isAvailable(spec, mode) then spec.mode = mode end
        if throttle ~= nil then
            spec.handThrottlePercent = Model.clampThrottle(throttle)
        end
    end

    refreshRequirements(self, spec)
end

function Control:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = getSpec(self)
    if spec == nil or spec.enabled ~= true then return end

    local modName = tostring(g_currentModName or "FS25_RealismExtensions")
    local specKey = key .. "." .. modName .. "." .. Control.SPEC_NAME

    if type(xmlFile.setValue) == "function" then
        xmlFile:setValue(specKey .. "#mode", spec.mode)
        xmlFile:setValue(
            specKey .. "#handThrottle",
            spec.handThrottlePercent or 0
        )
    else
        if type(xmlFile.setInt) == "function" then
            xmlFile:setInt(specKey .. "#mode", spec.mode)
        end
        if type(xmlFile.setFloat) == "function" then
            xmlFile:setFloat(
                specKey .. "#handThrottle",
                spec.handThrottlePercent or 0
            )
        end
    end
end

function Control.getPublicState(vehicle)
    local spec = getSpec(vehicle)
    if spec == nil or spec.enabled ~= true or spec.hasPtoOutput ~= true then
        return nil
    end
    return spec.publicState
end

function Control:setPowerTakeOffState(mode, throttle, noEventSend, replicated)
    local spec = getSpec(self)
    if spec == nil or spec.enabled ~= true or spec.hasPtoOutput ~= true then
        return false
    end

    mode = Model.normalizeMode(mode)
    throttle = Model.clampThrottle(throttle)

    if replicated ~= true then
        if not isAvailable(spec, mode) then
            count("rejectedUnsupported")
            notifyOperator(
                "PTO: rotação "
                .. tostring(Model.getModeToken(mode))
                .. " indisponível neste trator"
            )
            if RealismExtensionsDiagnostics ~= nil then
                RealismExtensionsDiagnostics.verbose(
                    "PTO operator rejected | vehicle="
                    .. vehicleLabel(self)
                    .. " reason=unsupported mode="
                    .. tostring(Model.getModeToken(mode))
                )
            end
            return false
        end
        if mode ~= spec.mode and Resolver.isPtoEngaged(self) then
            count("rejectedEngaged")
            notifyOperator(
                "PTO engatada: desengate antes de alterar a rotação"
            )
            if RealismExtensionsDiagnostics ~= nil then
                RealismExtensionsDiagnostics.verbose(
                    "PTO operator rejected | vehicle="
                    .. vehicleLabel(self)
                    .. " reason=PTO engaged mode="
                    .. tostring(Model.getModeToken(mode))
                )
            end
            return false
        end
    end

    local modeChanged = spec.mode ~= mode
    local throttleChanged = math.abs(
        (spec.handThrottlePercent or 0) - throttle
    ) >= 0.0001

    if not modeChanged and not throttleChanged then
        count("noops")
        return true
    end

    spec.mode = mode
    spec.handThrottlePercent = throttle
    refreshPublicState(self, spec)

    count("stateChanges")
    if modeChanged then count("modeChanges") end
    if throttleChanged then count("throttleChanges") end
    if replicated ~= true then
        logOperatorState(
            self,
            spec,
            modeChanged and "mode" or "handThrottle"
        )

        if modeChanged then
            notifyOperator(
                "PTO: " .. tostring(Model.getModeToken(spec.mode))
            )
        elseif throttleChanged then
            local minRpm, maxRpm = getMotorBounds(self)
            local handRpm = Model.handThrottleRpm(
                spec.handThrottlePercent,
                minRpm,
                maxRpm
            )
            if handRpm > 0 then
                notifyOperator(
                    "Acelerador manual PTO: "
                    .. tostring(math.floor(handRpm + 0.5))
                    .. " RPM"
                )
            else
                notifyOperator("Acelerador manual PTO: ROAD")
            end
        end
    end

    if self.isServer == true
        and spec.dirtyFlag ~= 0
        and type(self.raiseDirtyFlags) == "function" then
        self:raiseDirtyFlags(spec.dirtyFlag)
    end

    if noEventSend ~= true
        and RealismExtensionsPTOStateEvent ~= nil
        and type(RealismExtensionsPTOStateEvent.send) == "function" then
        RealismExtensionsPTOStateEvent.send(
            self,
            spec.mode,
            spec.handThrottlePercent
        )
    end

    return true
end

function Control:stepPowerTakeOffMode(direction)
    local spec = getSpec(self)
    if spec == nil or spec.enabled ~= true then return false end

    local nextMode = Model.stepAvailableMode(
        spec.mode,
        spec.availableModes,
        direction
    )
    if nextMode == spec.mode then
        count("noops")
        local token = Model.getModeToken(spec.mode)
        notifyOperator(
            "PTO: sem outra rotação disponível neste perfil (" .. token .. ")"
        )
        if RealismExtensionsDiagnostics ~= nil then
            RealismExtensionsDiagnostics.verbose(
                "PTO operator no-op | vehicle="
                .. vehicleLabel(self)
                .. " reason=no alternate mode current="
                .. tostring(token)
                .. " capability="
                .. tostring(spec.capability ~= nil and spec.capability.source or "?")
            )
        end
        return false
    end
    return Control.setPowerTakeOffState(
        self,
        nextMode,
        spec.handThrottlePercent,
        false,
        false
    )
end

function Control:adjustPowerTakeOffThrottle(deltaRpm)
    local spec = getSpec(self)
    if spec == nil or spec.enabled ~= true then return false end

    local delta = tonumber(deltaRpm) or 0
    if math.abs(delta) < 0.001 then return true end

    local minRpm, maxRpm = getMotorBounds(self)
    local currentTarget = Model.handThrottleRpm(
        spec.handThrottlePercent,
        minRpm,
        maxRpm
    )
    local target = Model.stepHandThrottleRpm(
        currentTarget,
        delta > 0 and 1 or -1,
        minRpm,
        maxRpm,
        getCurrentEngineRpm(self),
        math.abs(delta)
    )
    local value = Model.handThrottlePercentForRpm(
        target,
        minRpm,
        maxRpm
    )
    return Control.setPowerTakeOffState(
        self,
        spec.mode,
        value,
        false,
        false
    )
end

function Control:resetPowerTakeOffThrottle()
    local spec = getSpec(self)
    if spec == nil or spec.enabled ~= true then return false end
    return Control.setPowerTakeOffState(
        self,
        spec.mode,
        0,
        false,
        false
    )
end

function Control:refreshPowerTakeOffRequirements()
    local spec = getSpec(self)
    if spec == nil then return end
    refreshRequirements(self, spec)
end

function Control:onPostAttachImplement(attachable, inputJointDescIndex, jointDescIndex)
    Control.refreshPowerTakeOffRequirements(self)
end

function Control:onPostDetachImplement(implementIndex)
    Control.refreshPowerTakeOffRequirements(self)
end

local function actionName(name)
    return InputAction ~= nil and InputAction[name] or name
end

local function addAction(vehicle, spec, name, callback, text)
    local action = actionName(name)
    local eventId = nil
    local collisionBypass = false

    -- FS25 vehicle actions can collide with bindings registered by other
    -- specializations/mods. The exact Dynamic PTO source uses the optional
    -- ignore-collisions argument for these combo bindings. Preserve that
    -- robust registration behavior without taking ownership of the other
    -- action: both bindings remain eligible to fire.
    local ok, _, id = pcall(
        vehicle.addActionEvent,
        vehicle,
        spec.actionEvents,
        action,
        vehicle,
        callback,
        false,
        true,
        false,
        true,
        nil,
        nil,
        true
    )
    if ok and id ~= nil then
        eventId = id
        collisionBypass = true
    else
        local fallbackOk, _, fallbackId = pcall(
            vehicle.addActionEvent,
            vehicle,
            spec.actionEvents,
            action,
            vehicle,
            callback,
            false,
            true,
            false,
            true
        )
        if fallbackOk then eventId = fallbackId end
    end

    if eventId == nil then
        count("actionEventsFailed")
        if RealismExtensionsDiagnostics ~= nil then
            RealismExtensionsDiagnostics.warn(
                "PTO input registration failed: " .. tostring(name)
            )
        end
        return
    end

    count("actionEventsRegistered")
    if collisionBypass then count("actionEventsCollisionBypass") end

    if g_inputBinding == nil then return end
    if type(g_inputBinding.setActionEventActive) == "function" then
        g_inputBinding:setActionEventActive(eventId, true)
    end
    if type(g_inputBinding.setActionEventText) == "function" then
        g_inputBinding:setActionEventText(eventId, text)
    end
    if type(g_inputBinding.setActionEventTextPriority) == "function" then
        g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_HIGH or 2)
    end
    if type(g_inputBinding.setActionEventTextVisibility) == "function" then
        g_inputBinding:setActionEventTextVisibility(eventId, true)
    end
end

function Control:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    local spec = getSpec(self)
    if spec == nil or spec.enabled ~= true or spec.hasPtoOutput ~= true then
        return
    end
    if self.isClient ~= true or not isActiveForInputIgnoreSelection then
        return
    end

    self:clearActionEventsTable(spec.actionEvents)

    addAction(
        self,
        spec,
        "RE_PTO_MODE_NEXT",
        Control.actionModeNext,
        "PTO: próxima rotação"
    )
    addAction(
        self,
        spec,
        "RE_PTO_MODE_PREV",
        Control.actionModePrev,
        "PTO: rotação anterior"
    )
    addAction(
        self,
        spec,
        "RE_PTO_THROTTLE_UP",
        Control.actionThrottleUp,
        "Acelerador manual PTO +100 RPM"
    )
    addAction(
        self,
        spec,
        "RE_PTO_THROTTLE_DOWN",
        Control.actionThrottleDown,
        "Acelerador manual PTO -100 RPM"
    )
    addAction(
        self,
        spec,
        "RE_PTO_THROTTLE_RESET",
        Control.actionThrottleReset,
        "Acelerador manual PTO: liberar (ROAD)"
    )
end

function Control.actionModeNext(self)
    count("actionModeNext")
    Control.stepPowerTakeOffMode(self, 1)
end

function Control.actionModePrev(self)
    count("actionModePrev")
    Control.stepPowerTakeOffMode(self, -1)
end

function Control.actionThrottleUp(self)
    count("actionThrottleUp")
    Control.adjustPowerTakeOffThrottle(self, HAND_THROTTLE_RPM_STEP)
end

function Control.actionThrottleDown(self)
    count("actionThrottleDown")
    Control.adjustPowerTakeOffThrottle(self, -HAND_THROTTLE_RPM_STEP)
end

function Control.actionThrottleReset(self)
    count("actionThrottleReset")
    local spec = getSpec(self)
    local wasReleased = spec == nil
        or (tonumber(spec.handThrottlePercent) or 0) <= 0.0001
    Control.resetPowerTakeOffThrottle(self)
    if wasReleased then
        -- Give explicit operator feedback even when ROAD was already active.
        -- This also makes a successful reset binding distinguishable from a
        -- key-binding failure during runtime testing.
        notifyOperator("Acelerador manual PTO: ROAD")
    end
end

function Control:onWriteStream(streamId, connection)
    local spec = getSpec(self)
    local mode = spec ~= nil and spec.mode or Model.MODE.RPM_540
    local throttle = spec ~= nil and spec.handThrottlePercent or 0

    streamWriteUIntN(streamId, mode, 3)
    streamWriteFloat32(streamId, throttle)
end

function Control:onReadStream(streamId, connection)
    local spec = getSpec(self)
    local mode = streamReadUIntN(streamId, 3)
    local throttle = streamReadFloat32(streamId)
    if spec == nil then return end

    if isAvailable(spec, mode) then spec.mode = Model.normalizeMode(mode) end
    spec.handThrottlePercent = Model.clampThrottle(throttle)
    refreshPublicState(self, spec)
end

function Control:onWriteUpdateStream(streamId, connection, dirtyMask)
    local spec = getSpec(self)
    if spec == nil then
        streamWriteBool(streamId, false)
        return
    end

    local dirty = true
    if bitAND ~= nil and spec.dirtyFlag ~= 0 then
        dirty = bitAND(dirtyMask, spec.dirtyFlag) ~= 0
    end

    if streamWriteBool(streamId, dirty) then
        streamWriteUIntN(streamId, spec.mode, 3)
        streamWriteFloat32(streamId, spec.handThrottlePercent or 0)
    end
end

function Control:onReadUpdateStream(streamId, timestamp, connection)
    local spec = getSpec(self)
    if not streamReadBool(streamId) then return end

    local mode = streamReadUIntN(streamId, 3)
    local throttle = streamReadFloat32(streamId)
    if spec == nil then return end

    self:setPowerTakeOffState(mode, throttle, true, true)
end

function Control.getDiagnostics()
    local out = {}
    for key, value in pairs(Control.stats or {}) do
        out[key] = value
    end
    return out
end

function Control.resetDiagnostics()
    resetStats()
end

resetStats()
return Control
