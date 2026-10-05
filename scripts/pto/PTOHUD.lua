RealismExtensionsPTOHUD = RealismExtensionsPTOHUD or {}
local HUD = RealismExtensionsPTOHUD

HUD.VERSION = 2
HUD.enabled = true
HUD.installRetryMs = 250
HUD._installElapsedMs = HUD.installRetryMs
HUD._hookedHud = nil
HUD._cacheVehicle = nil
HUD._cacheRevision = nil
HUD._cacheBaseText = nil
HUD._cacheMismatch = false
HUD.stats = HUD.stats or {}

local function count(name)
    HUD.stats[name] = (HUD.stats[name] or 0) + 1
end

local function resetStats()
    HUD.stats = {
        hookInstalls = 0,
        hookUnavailable = 0,
        drawCalls = 0,
        rendered = 0,
        hidden = 0,
        noVehicle = 0,
        noState = 0
    }
end

local function getControlledVehicle()
    if g_localPlayer ~= nil
        and type(g_localPlayer.getCurrentVehicle) == "function" then
        local ok, vehicle = pcall(
            g_localPlayer.getCurrentVehicle,
            g_localPlayer
        )
        if ok and vehicle ~= nil then return vehicle end
    end

    if g_currentMission == nil then return nil end

    if g_currentMission.controlledVehicle ~= nil then
        return g_currentMission.controlledVehicle
    end

    if type(g_currentMission.getControlledVehicle) == "function" then
        local ok, vehicle = pcall(
            g_currentMission.getControlledVehicle,
            g_currentMission
        )
        if ok and vehicle ~= nil then return vehicle end
    end

    local speedMeter = g_currentMission.hud ~= nil
        and g_currentMission.hud.speedMeter or nil
    if speedMeter ~= nil and speedMeter.vehicle ~= nil then
        return speedMeter.vehicle
    end

    return nil
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

local function getEngineRpm(motor)
    if motor == nil then return nil end

    local getters = {
        "getLastRealMotorRpm",
        "getLastModRpm",
        "getNonClampedMotorRpm"
    }
    for _, name in ipairs(getters) do
        local fn = motor[name]
        if type(fn) == "function" then
            local ok, value = pcall(fn, motor)
            value = ok and tonumber(value) or nil
            if value ~= nil and value == value and value >= 0 then
                return value
            end
        end
    end

    local value = tonumber(motor.lastMotorRpm)
        or tonumber(motor.lastRealMotorRpm)
        or tonumber(motor.equalizedMotorRpm)
    return value
end

local function isEngaged(vehicle)
    if vehicle ~= nil
        and type(vehicle.getIsPowerTakeOffActive) == "function" then
        local ok, active = pcall(
            vehicle.getIsPowerTakeOffActive,
            vehicle
        )
        if ok then return active == true end
    end
    return false
end

local function buildBaseText(state)
    local text = "PTO " .. tostring(state.modeToken or state.shaftRpm or "?")

    local throttle = tonumber(state.handThrottlePercent) or 0
    if throttle > 0.001 then
        text = text .. string.format(
            " | hand %d%%",
            math.floor(throttle * 100 + 0.5)
        )
    end

    if state.requirementConflict == true then
        text = text .. " | ! conflict"
    elseif state.mismatch == true and state.requiredShaftRpm ~= nil then
        text = text .. " | ! requires " .. tostring(state.requiredShaftRpm)
    elseif state.requirementKnown == true and state.requiredShaftRpm ~= nil then
        text = text .. " | " .. tostring(state.requiredShaftRpm) .. " ok"
    elseif state.hasPtoConsumer == true then
        text = text .. " | req ?"
    end

    return text
end

local function getDisplayState(vehicle)
    if not HUD.enabled
        or RealismExtensionsPTO == nil
        or type(RealismExtensionsPTO.getVehicleState) ~= "function" then
        return nil, nil
    end

    local state = RealismExtensionsPTO.getVehicleState(vehicle)
    if type(state) ~= "table" then return nil, nil end

    local revision = tonumber(state.revision) or 0
    if HUD._cacheVehicle ~= vehicle
        or HUD._cacheRevision ~= revision then
        HUD._cacheVehicle = vehicle
        HUD._cacheRevision = revision
        HUD._cacheBaseText = buildBaseText(state)
        HUD._cacheMismatch = state.mismatch == true
            or state.requirementConflict == true
    end

    return state, HUD._cacheBaseText, HUD._cacheMismatch
end

local function shouldDraw()
    if not HUD.enabled or g_currentMission == nil then return false end
    local missionHud = g_currentMission.hud
    if missionHud == nil then return false end
    if missionHud.isVisible == false then return false end
    return true
end

function HUD:drawControlledVehicle()
    count("drawCalls")

    if not shouldDraw() then
        count("hidden")
        return
    end

    local vehicle = getControlledVehicle()
    if vehicle == nil then
        count("noVehicle")
        return
    end

    local state, baseText, mismatch = getDisplayState(vehicle)
    if state == nil or baseText == nil then
        count("noState")
        return
    end

    local text = baseText
    local engaged = isEngaged(vehicle)
    local ratio = tonumber(state.effectiveMotorRatio)
    local engineRpm = getEngineRpm(getMotor(vehicle))
    if engaged and ratio ~= nil and ratio > 0
        and engineRpm ~= nil and engineRpm >= 0 then
        local shaftRpm = engineRpm / ratio
        text = text .. string.format(
            " | %d rpm",
            math.floor(shaftRpm + 0.5)
        )
    elseif state.hasPtoConsumer == true then
        text = text .. " | PTO off"
    end

    if type(renderText) ~= "function" then return end
    if type(new2DLayer) == "function" then new2DLayer() end

    local size = type(getCorrectTextSize) == "function"
        and getCorrectTextSize(0.015) or 0.015

    if type(setTextAlignment) == "function"
        and RenderText ~= nil
        and RenderText.ALIGN_RIGHT ~= nil then
        setTextAlignment(RenderText.ALIGN_RIGHT)
    end

    if type(setTextBold) == "function" then
        setTextBold(true)
    end

    if type(setTextColor) == "function" then
        if mismatch then
            setTextColor(1.0, 0.45, 0.15, 1.0)
        else
            setTextColor(1.0, 1.0, 1.0, 0.96)
        end
    end

    -- Draw after the controlled-entity HUD chain (including RMS when present)
    -- and keep the temporary line above the speedometer cluster.
    renderText(0.985, 0.235, size, text)
    count("rendered")

    if type(setTextColor) == "function" then
        setTextColor(1, 1, 1, 1)
    end
    if type(setTextBold) == "function" then
        setTextBold(false)
    end
    if type(setTextAlignment) == "function"
        and RenderText ~= nil
        and RenderText.ALIGN_LEFT ~= nil then
        setTextAlignment(RenderText.ALIGN_LEFT)
    end
end

function HUD.installFromMission()
    local mission = g_currentMission
    local missionHud = mission ~= nil and mission.hud or nil
    if missionHud == nil
        or type(missionHud.drawControlledEntityHUD) ~= "function" then
        count("hookUnavailable")
        return false, "controlled HUD unavailable"
    end

    if HUD._hookedHud == missionHud then
        return true, "already installed"
    end

    missionHud.drawControlledEntityHUD = Utils.appendedFunction(
        missionHud.drawControlledEntityHUD,
        function()
            HUD:drawControlledVehicle()
        end
    )

    HUD._hookedHud = missionHud
    count("hookInstalls")

    if RealismExtensionsDiagnostics ~= nil then
        RealismExtensionsDiagnostics.info(
            "PTO HUD attached to controlled-entity HUD"
        )
    end

    return true, "installed"
end

function HUD:loadMap()
    HUD._installElapsedMs = HUD.installRetryMs
    HUD._hookedHud = nil
    HUD._cacheVehicle = nil
    HUD._cacheRevision = nil
    HUD._cacheBaseText = nil
    HUD._cacheMismatch = false
    resetStats()
end

function HUD:update(dt)
    if HUD._hookedHud ~= nil then return end

    HUD._installElapsedMs = (HUD._installElapsedMs or 0)
        + math.max(tonumber(dt) or 0, 0)
    if HUD._installElapsedMs < HUD.installRetryMs then return end

    HUD._installElapsedMs = 0
    HUD.installFromMission()
end

function HUD:deleteMap()
    HUD._hookedHud = nil
    HUD._cacheVehicle = nil
    HUD._cacheRevision = nil
    HUD._cacheBaseText = nil
    HUD._cacheMismatch = false
    HUD._installElapsedMs = HUD.installRetryMs
end

function HUD.getDiagnostics()
    local out = {}
    for key, value in pairs(HUD.stats or {}) do
        out[key] = value
    end
    out.installed = HUD._hookedHud ~= nil
    return out
end

resetStats()
addModEventListener(HUD)

return HUD
