RealismExtensionsPTOResolver = RealismExtensionsPTOResolver or {}
local Resolver = RealismExtensionsPTOResolver
local Model = RealismExtensionsPTOModel
local Profiles = RealismExtensionsPTOProfiles

Resolver.VERSION = 1

local function tableHasEntries(value)
    if type(value) ~= "table" then return false end
    for _ in pairs(value) do return true end
    return false
end

local function getMotor(vehicle)
    if vehicle == nil then return nil end
    if type(vehicle.getMotor) == "function" then
        local ok, motor = pcall(vehicle.getMotor, vehicle)
        if ok and motor ~= nil then return motor end
    end
    return vehicle.spec_motorized ~= nil
        and vehicle.spec_motorized.motor or nil
end

local function getNativeRatio(motor)
    if motor == nil then return nil end
    if type(motor.getPtoMotorRpmRatio) == "function" then
        local ok, value = pcall(motor.getPtoMotorRpmRatio, motor)
        if ok and tonumber(value) ~= nil and tonumber(value) > 0 then
            return tonumber(value)
        end
    end
    local value = tonumber(motor.ptoMotorRpmRatio)
    return value ~= nil and value > 0 and value or nil
end

local function getMinMaxRpm(motor)
    if motor == nil then return 850, 2200 end
    local minRpm = tonumber(motor.minRpm) or 850
    local maxRpm = tonumber(motor.maxRpm) or 2200
    if maxRpm < minRpm then maxRpm = minRpm end
    return minRpm, maxRpm
end

function Resolver.vehicleHasOutputPto(vehicle)
    if vehicle == nil then return false end

    -- For Large Tractors a brochure's optional PTO is not enough. It must be
    -- physically represented by GIANTS output PowerTakeOffs on this vehicle.
    local profile = Profiles.findTractor(vehicle)
    if profile ~= nil and profile.requiresOutputPto == true then
        if type(vehicle.getOutputPowerTakeOffs) == "function" then
            local ok, outputs = pcall(vehicle.getOutputPowerTakeOffs, vehicle)
            if ok and tableHasEntries(outputs) then return true end
        end
        local spec = vehicle.spec_powerTakeOffs
        return spec ~= nil and (
            tableHasEntries(spec.outputPowerTakeOffs)
            or tableHasEntries(spec.outputs)
        ) or false
    end

    if type(vehicle.getOutputPowerTakeOffs) == "function" then
        local ok, outputs = pcall(vehicle.getOutputPowerTakeOffs, vehicle)
        if ok and tableHasEntries(outputs) then return true end
    end

    local spec = vehicle.spec_powerTakeOffs
    if spec ~= nil then
        if tableHasEntries(spec.outputPowerTakeOffs)
            or tableHasEntries(spec.outputs)
            or tableHasEntries(spec.powerTakeOffs) then
            return true
        end
        -- The GIANTS specialization can populate output tables after onLoad.
        return true
    end

    return Profiles.findTractor(vehicle) ~= nil
end

function Resolver.resolveCapability(vehicle)
    local motor = getMotor(vehicle)
    local nativeRatio = getNativeRatio(motor)
    local minRpm, maxRpm = getMinMaxRpm(motor)
    local profile = Profiles.findTractor(vehicle)

    local result = {
        source = profile ~= nil and "PROFILE" or "NATIVE_FALLBACK",
        profileId = profile ~= nil and profile.id or nil,
        nativeMotorRatio = nativeRatio,
        minEngineRpm = minRpm,
        maxEngineRpm = maxRpm,
        economyEngineFactor = profile ~= nil
            and profile.economyEngineFactor or nil,
        modes = {}
    }

    if profile ~= nil and profile.requiresOutputPto == true
        and not Resolver.vehicleHasOutputPto(vehicle) then
        -- Explicit negative hardware evidence: no installed rear PTO output.
        -- Never expose 540 just because the tractor has a large engine.
        result.source = "PROFILE_OUTPUT_UNVERIFIED"
    elseif profile ~= nil then
        for mode, entry in pairs(profile.modes or {}) do
            local normalized = Model.normalizeMode(mode)
            result.modes[normalized] = {
                motorRatio = entry.motorRatio,
                engineRpm = entry.engineRpm
            }
        end
    else
        -- Unknown equipment stays conservative. A native FS25 tractor is
        -- treated as 540 only until an evidence-backed capability profile is
        -- added; horsepower is never used as a proxy for 1000/Economy support.
        result.modes[Model.MODE.RPM_540] = {
            motorRatio = nativeRatio
        }
    end

    for mode, entry in pairs(result.modes) do
        entry.shaftRpm = Model.getShaftRpm(mode)
        entry.economy = Model.isEconomy(mode)
        entry.effectiveMotorRatio = Model.resolveMotorRatio(
            mode,
            result,
            nativeRatio,
            maxRpm
        )
    end

    return result
end

-- FS25 PowerTakeOffs tracks attached cardans through *both* sides:
-- input.connectedOutput / connectedVehicle, and the matching output's
-- connectedInput / connectedVehicle. These are connection evidence, not a
-- guarantee that the shaft is transmitting torque right now.
local function getNativeInputPowerTakeOffs(object)
    if object == nil then return nil end
    local methodInputs = nil
    if type(object.getInputPowerTakeOffs) == "function" then
        local ok, inputs = pcall(object.getInputPowerTakeOffs, object)
        if ok and type(inputs) == "table" then
            methodInputs = inputs
            if tableHasEntries(inputs) then return inputs end
        end
    end
    local spec = object.spec_powerTakeOffs
    if spec ~= nil and type(spec.inputPowerTakeOffs) == "table" then
        -- Preserve the v1.6 classification fallback: some mod methods
        -- expose an empty list even when the native spec has PTO inputs.
        if tableHasEntries(spec.inputPowerTakeOffs)
            or methodInputs == nil then
            return spec.inputPowerTakeOffs
        end
    end
    return methodInputs
end

local function hasInputPowerTakeOff(object)
    return tableHasEntries(getNativeInputPowerTakeOffs(object))
end

-- Read-only, deliberately *not* used to authorize gear changes or as a
-- substitute for GIANTS/Manual Attach on/off and physical torque semantics.
-- Nil/inconsistent native fields are UNKNOWN rather than a false claim that
-- a visible cardan is connected or disconnected.
function Resolver.getInputConnectionEvidence(object)
    local result = {
        declared = 0,
        linked = 0,
        unlinked = 0,
        uncertain = 0,
        status = "UNKNOWN"
    }
    local inputs = getNativeInputPowerTakeOffs(object)
    if inputs == nil then return result end

    for _, input in pairs(inputs) do
        result.declared = result.declared + 1
        if type(input) ~= "table" then
            result.uncertain = result.uncertain + 1
        else
            local vehicle = input.connectedVehicle
            local output = input.connectedOutput
            if vehicle == nil and output == nil then
                result.unlinked = result.unlinked + 1
            elseif vehicle ~= nil
                and type(output) == "table"
                and output.connectedInput == input
                and output.connectedVehicle == object then
                result.linked = result.linked + 1
            else
                -- Partial reference, stale reciprocal pointer, or a mod
                -- presenting a different connection lifecycle.
                result.uncertain = result.uncertain + 1
            end
        end
    end

    if result.declared == 0 then
        result.status = "NO_INPUT"
    elseif result.linked == result.declared then
        result.status = "LINKED"
    elseif result.unlinked == result.declared then
        result.status = "DECLARED_UNLINKED"
    elseif result.uncertain > 0 then
        result.status = "UNKNOWN"
    else
        result.status = "MIXED"
    end
    return result
end

local function readPtoRpm(object)
    if object == nil then return nil end

    local spec = object.spec_powerConsumer
    local rpm = spec ~= nil and tonumber(spec.ptoRpm) or nil
    if rpm ~= nil and rpm > 0 then return rpm end

    local xml = object.xmlFile
    if xml ~= nil and type(xml.getValue) == "function" then
        local ok, value = pcall(
            xml.getValue,
            xml,
            "vehicle.powerConsumer#ptoRpm"
        )
        value = ok and tonumber(value) or nil
        if value ~= nil and value > 0 then return value end
    end

    return nil
end

local function detectImplement(object)
    if object == nil then return nil end
    local profile = Profiles.findImplement(object)
    local hasInput = hasInputPowerTakeOff(object)
    local rpm = readPtoRpm(object)

    -- Generic PowerConsumer is insufficient to prove mechanical PTO.
    -- Soil-draft tools can consume power without any driven shaft.
    if profile == nil and not hasInput then return nil end
    if profile ~= nil then
        return {
            object = object,
            usesPto = true,
            shaftRpm = rpm or tonumber(profile.shaftRpm),
            gearboxFamilyRpm = tonumber(profile.gearboxFamilyRpm
                or profile.shaftRpm),
            source = "PROFILE",
            profileId = profile.id,
            confidence = "EVIDENCE"
        }
    end

    -- ptoRpm encodes a native load/governor demand. Only exact 540/1000
    -- values WITH actual PTO input can provisionally identify a nominal
    -- family; 340/400/500 and unusual speeds must never be rounded.
    local nominal = rpm == 540 and 540
        or rpm == 1000 and 1000 or nil
    return {
        object = object,
        usesPto = true,
        shaftRpm = rpm,
        gearboxFamilyRpm = nominal,
        source = rpm ~= nil and "POWER_CONSUMER_PTO_RPM" or "INPUT_PTO",
        confidence = nominal ~= nil and "NATIVE_NOMINAL_INFERRED"
            or "UNKNOWN_GEAR_FAMILY"
    }
end

function Resolver.collectRequirements(vehicle)
    local items, visited = {}, {}
    -- Observed evidence only; declared PowerConsumer demand is NOT proof of
    -- mechanical PTO input or of the actual operating power drawn.
    local attachedCount, inputCount, profileCount, unlinkedPowerCount = 0, 0, 0, 0
    local rootAttachmentListObserved = false
    local function walk(attacher, depth)
        if attacher == nil or visited[attacher] or depth > 12
            or type(attacher.getAttachedImplements) ~= "function" then
            return
        end
        visited[attacher] = true
        local ok, attached = pcall(attacher.getAttachedImplements, attacher)
        if depth == 0 then
            rootAttachmentListObserved = ok and type(attached) == "table"
        end
        if not ok or type(attached) ~= "table" then return end
        for _, implement in pairs(attached) do
            local object = implement ~= nil and implement.object or nil
            if object ~= nil and not visited[object] then
                attachedCount = attachedCount + 1
                local item = detectImplement(object)
                if item ~= nil then
                    items[#items + 1] = item
                    if hasInputPowerTakeOff(object) then
                        inputCount = inputCount + 1
                    else
                        -- Only an explicit, separately curated profile
                        -- authorizes mechanical classification here.
                        profileCount = profileCount + 1
                    end
                else
                    local consumer = object.spec_powerConsumer or {}
                    local rpm = readPtoRpm(object)
                    local declaredPower = tonumber(consumer.neededMaxPtoPower)
                        or tonumber(consumer.neededMinPtoPower) or 0
                    if (rpm ~= nil and rpm > 0) or declaredPower > 0 then
                        unlinkedPowerCount = unlinkedPowerCount + 1
                    end
                end
                walk(object, depth + 1)
            end
        end
    end
    walk(vehicle, 0)

    local families, demands = {}, {}
    local knownCount, unknownCount = 0, 0
    for _, item in ipairs(items) do
        if item.shaftRpm ~= nil then demands[item.shaftRpm] = true end
        if item.gearboxFamilyRpm ~= nil then
            families[item.gearboxFamilyRpm] = true
            knownCount = knownCount + 1
        else
            unknownCount = unknownCount + 1
        end
    end
    local familyCount, familyRpm = 0, nil
    for family in pairs(families) do
        familyCount = familyCount + 1
        familyRpm = family
    end
    local demandCount, rawRpm = 0, nil
    for rpm in pairs(demands) do
        demandCount = demandCount + 1
        rawRpm = rpm
    end
    local driveEvidenceStatus = "UNKNOWN"
    if inputCount > 0 then
        driveEvidenceStatus = "NATIVE_PTO_INPUT"
    elseif profileCount > 0 then
        driveEvidenceStatus = "PROFILED_PTO"
    elseif unlinkedPowerCount > 0 then
        driveEvidenceStatus = "POWER_CONSUMER_NO_INPUT"
    elseif attachedCount > 0 then
        driveEvidenceStatus = "NO_PTO_INPUT_DETECTED"
    elseif rootAttachmentListObserved then
        driveEvidenceStatus = "NO_ATTACHMENT"
    end
    return {
        items = items,
        primary = items[1],
        driveEvidenceStatus = driveEvidenceStatus,
        attachedImplementCount = attachedCount,
        nativeInputImplementCount = inputCount,
        profiledImplementCount = profileCount,
        unlinkedPowerConsumerCount = unlinkedPowerCount,
        hasPtoConsumer = #items > 0,
        knownCount = knownCount,
        unknownCount = unknownCount,
        conflict = familyCount > 1,
        requiredRpm = demandCount == 1 and rawRpm or nil,
        -- Unknown family with another attached tool cannot authorize AI.
        requiredGearboxFamilyRpm =
            familyCount == 1 and unknownCount == 0
                and familyRpm or nil
    }
end

local function getObjectPtoActivity(object)
    if object == nil then return false, nil end

    -- Native PowerTakeOffs activation can also be exposed by generic
    -- TurnOnVehicle/PowerConsumer tools. Mechanical engagement requires
    -- separate evidence of a shaft input or curated implement PTO profile.
    -- Never display a working Horsch turbine as a connected cardan solely
    -- because its generic getIsPowerTakeOffActive() returned true.
    local usesPto = Profiles.findImplement(object) ~= nil
        or hasInputPowerTakeOff(object)
    if not usesPto then return false, nil end

    -- GIANTS' base PowerTakeOffs implementation on a tractor returns false.
    -- PTO-consuming implement specializations (TurnOnVehicle, Dischargeable,
    -- FillUnit, BaleLoader, etc.) overwrite this method with their real
    -- operating state, so engagement must be queried on the attached consumer.
    if type(object.getIsPowerTakeOffActive) == "function" then
        local ok, active = pcall(
            object.getIsPowerTakeOffActive,
            object
        )
        if ok and active == true then
            return true, "IMPLEMENT_PTO_ACTIVE"
        end
    end

    -- Defensive fallback for mod implements that consume PTO but implement only
    -- TurnOnVehicle semantics and do not participate correctly in the
    -- getIsPowerTakeOffActive overwrite chain.
    if type(object.getIsTurnedOn) == "function" then
        local ok, active = pcall(object.getIsTurnedOn, object)
        if ok and active == true then
            return true, "IMPLEMENT_TURNED_ON"
        end
    end

    return false, nil
end

function Resolver.isPtoEngaged(vehicle)
    if vehicle == nil then return false, "NO_VEHICLE" end

    local seen = {}

    local function walk(attacher)
        if attacher == nil or seen[attacher] then return false, nil end
        seen[attacher] = true

        if type(attacher.getAttachedImplements) ~= "function" then
            return false, nil
        end

        local ok, implements = pcall(
            attacher.getAttachedImplements,
            attacher
        )
        if not ok or type(implements) ~= "table" then
            return false, nil
        end

        for _, implement in pairs(implements) do
            local object = implement ~= nil and implement.object or nil
            if object ~= nil then
                local active, source = getObjectPtoActivity(object)
                if active then return true, source end

                local childActive, childSource = walk(object)
                if childActive then return true, childSource end
            end
        end

        return false, nil
    end

    local active, source = walk(vehicle)
    if active then return true, source end
    return false, "NO_ACTIVE_CONSUMER"
end

function Resolver.getMotor(vehicle)
    return getMotor(vehicle)
end

return Resolver
