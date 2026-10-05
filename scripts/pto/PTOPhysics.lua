RealismExtensionsPTOPhysics = RealismExtensionsPTOPhysics or {}
local Physics = RealismExtensionsPTOPhysics

Physics.VERSION = 1
Physics.installed = Physics.installed or false
Physics.reason = Physics.reason or nil
Physics.stats = Physics.stats or {
    ratioCalls = 0,
    ratioOverrides = 0,
    rpmRangeCalls = 0,
    rpmRangeOverrides = 0
}

local EXTERNAL_MOTOR_OWNERS = {
    "MoreRealistic"
}

local function count(name)
    Physics.stats[name] = (Physics.stats[name] or 0) + 1
end

local function externalMotorOwnerPresent()
    if type(g_modIsLoaded) ~= "table" then return false end
    for _, name in ipairs(EXTERNAL_MOTOR_OWNERS) do
        if g_modIsLoaded[name] == true then return true end
    end
    return false
end

local function stateForMotor(motor)
    if motor == nil or motor.vehicle == nil
        or RealismExtensionsPTO == nil
        or type(RealismExtensionsPTO.getVehicleState) ~= "function" then
        return nil
    end

    local state = RealismExtensionsPTO.getVehicleState(motor.vehicle)
    if type(state) ~= "table"
        or state.enabled ~= true
        or state.hasPtoOutput ~= true then
        return nil
    end
    return state
end

local function validPositive(value)
    value = tonumber(value)
    return value ~= nil
        and value == value
        and value > 0
        and value ~= math.huge
end

local function installRatioHook()
    if VehicleMotor == nil
        or type(VehicleMotor.getPtoMotorRpmRatio) ~= "function" then
        return false, "VehicleMotor.getPtoMotorRpmRatio"
    end

    if Physics._wrappedRatio ~= nil
        and VehicleMotor.getPtoMotorRpmRatio == Physics._wrappedRatio then
        return true
    end

    local previous = VehicleMotor.getPtoMotorRpmRatio
    local wrapped = function(motor, ...)
        count("ratioCalls")
        local state = stateForMotor(motor)
        local ratio = state ~= nil
            and tonumber(state.effectiveMotorRatio) or nil
        if validPositive(ratio) then
            count("ratioOverrides")
            return ratio
        end
        return previous(motor, ...)
    end

    VehicleMotor.getPtoMotorRpmRatio = wrapped
    Physics._wrappedRatio = wrapped
    return true
end

local function installRequiredRangeHook()
    if VehicleMotor == nil
        or type(VehicleMotor.getRequiredMotorRpmRange) ~= "function" then
        return false, "VehicleMotor.getRequiredMotorRpmRange"
    end

    if Physics._wrappedRange ~= nil
        and VehicleMotor.getRequiredMotorRpmRange == Physics._wrappedRange then
        return true
    end

    local previous = VehicleMotor.getRequiredMotorRpmRange
    local wrapped = function(motor, ...)
        count("rpmRangeCalls")
        local state = stateForMotor(motor)
        local ratio = state ~= nil
            and tonumber(state.effectiveMotorRatio) or nil

        -- GIANTS' base implementation reads the raw ptoMotorRpmRatio field
        -- internally rather than calling the getter. Scope the selected PTO
        -- gearbox ratio only around that native calculation and restore it
        -- immediately afterwards.
        local minRpm, maxRpm
        if validPositive(ratio) then
            local original = motor.ptoMotorRpmRatio
            motor.ptoMotorRpmRatio = ratio
            local ok, a, b = pcall(previous, motor, ...)
            motor.ptoMotorRpmRatio = original
            if not ok then error(a) end
            minRpm, maxRpm = a, b
            count("rpmRangeOverrides")
        else
            minRpm, maxRpm = previous(motor, ...)
        end

        local handThrottle = state ~= nil
            and tonumber(state.handThrottleRpm) or nil
        if validPositive(handThrottle) then
            minRpm = math.max(tonumber(minRpm) or 0, handThrottle)
            maxRpm = math.max(
                tonumber(maxRpm) or minRpm,
                minRpm
            )
        end

        return minRpm, maxRpm
    end

    VehicleMotor.getRequiredMotorRpmRange = wrapped
    Physics._wrappedRange = wrapped
    return true
end

function Physics.install()
    if Physics.installed then return true, Physics.reason end

    if externalMotorOwnerPresent() then
        Physics.reason = "external drivetrain owner active"
        return false, Physics.reason
    end

    local ok, reason = installRatioHook()
    if not ok then
        Physics.reason = reason
        return false, reason
    end

    ok, reason = installRequiredRangeHook()
    if not ok then
        Physics.reason = reason
        return false, reason
    end

    Physics.installed = true
    Physics.reason = "standalone GIANTS PTO adapter active"
    return true, Physics.reason
end

function Physics.getDiagnostics()
    local out = {}
    for key, value in pairs(Physics.stats or {}) do out[key] = value end
    out.installed = Physics.installed and 1 or 0
    out.reason = Physics.reason
    return out
end

return Physics
