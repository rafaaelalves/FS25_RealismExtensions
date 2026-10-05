RealismExtensionsPTOHUD = RealismExtensionsPTOHUD or {}
local HUD = RealismExtensionsPTOHUD

HUD.VERSION = 1
HUD.enabled = true
HUD._cacheVehicle = nil
HUD._cacheRevision = nil
HUD._cacheText = nil
HUD._cacheMismatch = false

local function getControlledVehicle()
    if g_currentMission == nil then return nil end
    if g_currentMission.controlledVehicle ~= nil then
        return g_currentMission.controlledVehicle
    end
    if type(g_currentMission.getControlledVehicle) == "function" then
        local ok, vehicle = pcall(
            g_currentMission.getControlledVehicle,
            g_currentMission
        )
        if ok then return vehicle end
    end
    return nil
end

local function buildText(state)
    local text = "PTO " .. tostring(state.modeToken or state.shaftRpm or "?")

    local throttle = tonumber(state.handThrottlePercent) or 0
    if throttle > 0.001 then
        text = text .. string.format(" | %d%%", math.floor(throttle * 100 + 0.5))
    end

    if state.requirementConflict == true then
        text = text .. " | ! conflito"
    elseif state.mismatch == true and state.requiredShaftRpm ~= nil then
        text = text .. " | ! requer " .. tostring(state.requiredShaftRpm)
    elseif state.requirementKnown == true and state.requiredShaftRpm ~= nil then
        text = text .. " | " .. tostring(state.requiredShaftRpm) .. " ok"
    end

    return text
end

local function getDisplayState()
    if not HUD.enabled
        or RealismExtensionsPTO == nil
        or type(RealismExtensionsPTO.getVehicleState) ~= "function" then
        return nil, nil
    end

    local vehicle = getControlledVehicle()
    if vehicle == nil then return nil, nil end

    local state = RealismExtensionsPTO.getVehicleState(vehicle)
    if type(state) ~= "table" then return nil, nil end

    local revision = tonumber(state.revision) or 0
    if HUD._cacheVehicle ~= vehicle
        or HUD._cacheRevision ~= revision then
        HUD._cacheVehicle = vehicle
        HUD._cacheRevision = revision
        HUD._cacheText = buildText(state)
        HUD._cacheMismatch = state.mismatch == true
            or state.requirementConflict == true
    end

    return HUD._cacheText, HUD._cacheMismatch
end

function HUD:draw()
    if type(renderText) ~= "function" then return end

    local text, mismatch = getDisplayState()
    if text == nil then return end

    local size = type(getCorrectTextSize) == "function"
        and getCorrectTextSize(0.015) or 0.015

    if type(setTextAlignment) == "function"
        and RenderText ~= nil
        and RenderText.ALIGN_RIGHT ~= nil then
        setTextAlignment(RenderText.ALIGN_RIGHT)
    end

    if type(setTextColor) == "function" then
        if mismatch then
            setTextColor(1.0, 0.45, 0.15, 1.0)
        else
            setTextColor(1.0, 1.0, 1.0, 0.92)
        end
    end

    renderText(0.985, 0.205, size, text)

    if type(setTextColor) == "function" then
        setTextColor(1, 1, 1, 1)
    end
    if type(setTextAlignment) == "function"
        and RenderText ~= nil
        and RenderText.ALIGN_LEFT ~= nil then
        setTextAlignment(RenderText.ALIGN_LEFT)
    end
end

function HUD:deleteMap()
    HUD._cacheVehicle = nil
    HUD._cacheRevision = nil
    HUD._cacheText = nil
    HUD._cacheMismatch = false
end

addModEventListener(HUD)

return HUD
