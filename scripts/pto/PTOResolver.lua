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

local function hasInputPowerTakeOff(object)
    if object == nil then return false end

    if type(object.getInputPowerTakeOffs) == "function" then
        local ok, inputs = pcall(object.getInputPowerTakeOffs, object)
        if ok and tableHasEntries(inputs) then return true end
    end

    local spec = object.spec_powerTakeOffs
    return spec ~= nil and tableHasEntries(spec.inputPowerTakeOffs)
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

    -- A generic PowerConsumer is NOT evidence of a mechanical PTO.
    -- Draft/traction/hydraulic/electrical implements can legitimately expose
    -- spec_powerConsumer while having no PTO shaft at all. Connection hoses or
    -- electrical cables are likewise independent of PTO. Keep classification
    -- conservative and require one of:
    --   1. evidence-backed implement profile;
    --   2. an actual input PowerTakeOff;
    --   3. an explicit powerConsumer.ptoRpm.
    --
    -- This deliberately fails closed for unusual mod implements. If a real PTO
    -- machine exposes none of those contracts it belongs in Profiles rather
    -- than being guessed from generic power consumption.
    local usesPto = profile ~= nil or hasInput or rpm ~= nil
    if not usesPto then return nil end

    if profile ~= nil then
        return {
            object = object,
            usesPto = true,
            shaftRpm = tonumber(profile.shaftRpm),
            source = "PROFILE",
            profileId = profile.id,
            confidence = "EVIDENCE"
        }
    end

    if rpm ~= nil and rpm > 0 then
        return {
            object = object,
            usesPto = true,
            shaftRpm = rpm >= 750 and 1000 or 540,
            source = "POWER_CONSUMER_PTO_RPM",
            confidence = rpm >= 750 and "NATIVE_EXPLICIT" or "NATIVE_AMBIGUOUS"
        }
    end

    -- An input PTO with no explicit RPM is still a real PTO connection, but
    -- its family is unknown until evidence is available.
    return {
        object = object,
        usesPto = true,
        shaftRpm = nil,
        source = "INPUT_PTO",
        confidence = "NATIVE_CONNECTION"
    }
end

function Resolver.collectRequirements(vehicle)
    local items = {}

    local function walk(attacher)
        if attacher == nil or type(attacher.getAttachedImplements) ~= "function" then
            return
        end

        local ok, implements = pcall(attacher.getAttachedImplements, attacher)
        if not ok or type(implements) ~= "table" then return end

        for _, implement in pairs(implements) do
            local object = implement ~= nil and implement.object or nil
            if object ~= nil then
                local item = detectImplement(object)
                if item ~= nil then items[#items + 1] = item end
                walk(object)
            end
        end
    end

    walk(vehicle)

    local families = {}
    local knownCount = 0
    local unknownCount = 0
    local primary = nil

    for _, item in ipairs(items) do
        if item.shaftRpm ~= nil then
            families[item.shaftRpm] = true
            knownCount = knownCount + 1
            primary = primary or item
        else
            unknownCount = unknownCount + 1
        end
    end

    local familyCount = 0
    local requiredRpm = nil
    for family in pairs(families) do
        familyCount = familyCount + 1
        requiredRpm = family
    end

    if familyCount ~= 1 then requiredRpm = nil end

    return {
        items = items,
        primary = primary,
        hasPtoConsumer = #items > 0,
        knownCount = knownCount,
        unknownCount = unknownCount,
        conflict = familyCount > 1,
        requiredRpm = requiredRpm
    }
end

local function getObjectPtoActivity(object)
    if object == nil then return false, nil end

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
    local usesPto = Profiles.findImplement(object) ~= nil
        or hasInputPowerTakeOff(object)
        or readPtoRpm(object) ~= nil
    if usesPto and type(object.getIsTurnedOn) == "function" then
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
