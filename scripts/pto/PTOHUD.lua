RealismExtensionsPTOHUD = RealismExtensionsPTOHUD or {}
local HUD = RealismExtensionsPTOHUD

HUD.VERSION = 3
HUD.enabled = true
HUD.modDirectory = tostring(g_currentModDirectory or "")
HUD.installRetryMs = 250
HUD._installElapsedMs = HUD.installRetryMs
HUD._hookedHud = nil
HUD._overlayManager = nil
HUD._textureConfigRegistered = false
HUD._icon = nil
HUD._cacheVehicle = nil
HUD._cacheRevision = nil
HUD._cacheModeText = nil
HUD._cacheMismatch = false
HUD.stats = HUD.stats or {}

-- Independent palette chosen to visually sit beside the RMS dashboard without
-- depending on RMS globals or APIs. The active/critical hues intentionally
-- follow the same instrument-cluster language used by RMS.
HUD.COLOR_OFF = {1.0, 1.0, 1.0, 0.62}
HUD.COLOR_ACTIVE = {1.0, 0.4287, 0.0006, 1.0}
HUD.COLOR_CRITICAL = {0.8069, 0.0097, 0.0097, 1.0}

local DEFAULT_LAYOUT = {
    -- Lower-left corner of the icon relative to the vanilla speed-gauge
    -- centre. RMS anchors its own dashboard indicators to the same point.
    offsetXPx = -68,
    offsetYPx = 49,
    iconWidthPx = 30,
    iconHeightPx = 18.75,
    modeTextSizePx = 9,
    modeTextGapPx = 5,
    transportWarningKph = 25,
    warningBlinkIntervalMs = 600
}

local function count(name)
    HUD.stats[name] = (HUD.stats[name] or 0) + 1
end

local function resetStats()
    HUD.stats = {
        hookInstalls = 0,
        hookUnavailable = 0,
        drawCalls = 0,
        rendered = 0,
        graphicalRendered = 0,
        fallbackRendered = 0,
        hidden = 0,
        noVehicle = 0,
        noState = 0,
        noSpeedMeter = 0,
        overlayInitFailures = 0,
        warningFrames = 0
    }
    HUD._lastMode = nil
    HUD._lastEngaged = false
    HUD._lastMismatch = false
    HUD._lastTransportWarning = false
    HUD._lastSpeedKph = 0
    HUD._lastActualRpm = nil
end

local function getHudConfig()
    local cfg = RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.ptoHud or nil
    return type(cfg) == "table" and cfg or DEFAULT_LAYOUT
end

local function cfgNumber(name)
    local cfg = getHudConfig()
    local value = tonumber(cfg[name])
    if value == nil then value = DEFAULT_LAYOUT[name] end
    return value
end

local function isHudEnabled()
    local cfg = getHudConfig()
    return HUD.enabled and cfg.enabled ~= false
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

local function getVehicleSpeedKph(vehicle)
    if vehicle ~= nil and type(vehicle.getLastSpeed) == "function" then
        local ok, speed = pcall(vehicle.getLastSpeed, vehicle)
        speed = ok and tonumber(speed) or nil
        if speed ~= nil and speed == speed then
            return math.abs(speed)
        end
    end
    return 0
end

local function getActualPtoRpm(vehicle, state, engaged)
    if not engaged then return nil end
    local ratio = tonumber(state ~= nil and state.effectiveMotorRatio or nil)
    if ratio == nil or ratio <= 0 then return nil end

    local engineRpm = getEngineRpm(getMotor(vehicle))
    if engineRpm == nil or engineRpm < 0 then return nil end
    return engineRpm / ratio
end

local function getDisplayState(vehicle)
    if not isHudEnabled()
        or RealismExtensionsPTO == nil
        or type(RealismExtensionsPTO.getVehicleState) ~= "function" then
        return nil, nil, false
    end

    local state = RealismExtensionsPTO.getVehicleState(vehicle)
    if type(state) ~= "table" then return nil, nil, false end

    local revision = tonumber(state.revision) or 0
    if HUD._cacheVehicle ~= vehicle
        or HUD._cacheRevision ~= revision then
        HUD._cacheVehicle = vehicle
        HUD._cacheRevision = revision
        HUD._cacheModeText = tostring(
            state.modeToken or state.shaftRpm or "?"
        )
        HUD._cacheMismatch = state.mismatch == true
            or state.requirementConflict == true
    end

    return state, HUD._cacheModeText, HUD._cacheMismatch
end

local function shouldDraw()
    if not isHudEnabled() or g_currentMission == nil then return false end
    local missionHud = g_currentMission.hud
    if missionHud == nil then return false end
    if missionHud.isVisible == false then return false end
    if g_gui ~= nil and type(g_gui.getIsGuiVisible) == "function"
        and g_gui:getIsGuiVisible() then
        return false
    end
    return true
end

local function scalePixelVector(speedMeter, x, y)
    if speedMeter ~= nil
        and type(speedMeter.scalePixelValuesToScreenVector) == "function" then
        local ok, sx, sy = pcall(
            speedMeter.scalePixelValuesToScreenVector,
            speedMeter,
            x,
            y
        )
        if ok and sx ~= nil and sy ~= nil then return sx, sy end
    end

    if type(getNormalizedScreenValues) == "function" then
        return getNormalizedScreenValues(x, y)
    end

    return (tonumber(x) or 0) / 1920, (tonumber(y) or 0) / 1080
end

local function scalePixelHeight(speedMeter, value)
    if speedMeter ~= nil
        and type(speedMeter.scalePixelToScreenHeight) == "function" then
        local ok, result = pcall(
            speedMeter.scalePixelToScreenHeight,
            speedMeter,
            value
        )
        if ok and result ~= nil then return result end
    end
    local _, h = scalePixelVector(speedMeter, 0, value)
    return h
end

local function getDashboardAnchor()
    local missionHud = g_currentMission ~= nil
        and g_currentMission.hud or nil
    local speedMeter = missionHud ~= nil and missionHud.speedMeter or nil
    if speedMeter == nil or speedMeter.speedBg == nil
        or type(speedMeter.speedBg.getPosition) ~= "function" then
        return nil
    end

    local ok, speedBgX, speedBgY = pcall(
        speedMeter.speedBg.getPosition,
        speedMeter.speedBg
    )
    if not ok or speedBgX == nil or speedBgY == nil then return nil end

    return speedMeter,
        speedBgX + (tonumber(speedMeter.speedGaugeCenterOffsetX) or 0),
        speedBgY + (tonumber(speedMeter.speedGaugeCenterOffsetY) or 0)
end

local function ensureIcon()
    if HUD._icon ~= nil then return true end
    if g_overlayManager == nil then
        count("overlayInitFailures")
        return false
    end

    if HUD._overlayManager ~= g_overlayManager then
        HUD._overlayManager = g_overlayManager
        HUD._textureConfigRegistered = false
    end

    if not HUD._textureConfigRegistered then
        local configPath = HUD.modDirectory
            .. "scripts/pto/ui/pto_dashboardHud.xml"
        local ok = pcall(
            g_overlayManager.addTextureConfigFile,
            g_overlayManager,
            configPath,
            "re_PTODashboardHud"
        )
        if not ok then
            count("overlayInitFailures")
            return false
        end
        HUD._textureConfigRegistered = true
    end

    local ok, icon = pcall(
        g_overlayManager.createOverlay,
        g_overlayManager,
        "re_PTODashboardHud.pto",
        0,
        0,
        0,
        0
    )
    if not ok or icon == nil then
        count("overlayInitFailures")
        return false
    end

    HUD._icon = icon
    return true
end

local function applyColor(target, color)
    if target ~= nil and type(target.setColor) == "function" then
        target:setColor(color[1], color[2], color[3], color[4])
    end
end

local function getWarningColor()
    local interval = math.max(
        100,
        cfgNumber("warningBlinkIntervalMs")
    )
    local now = (g_currentMission ~= nil and g_currentMission.time)
        or g_time or 0
    local phase = math.floor(math.max(tonumber(now) or 0, 0) / interval)
    if phase % 2 == 0 then
        return HUD.COLOR_CRITICAL
    end
    return HUD.COLOR_ACTIVE
end

local function drawFallbackText(modeText, iconColor)
    if type(renderText) ~= "function" then return false end

    local size = type(getCorrectTextSize) == "function"
        and getCorrectTextSize(0.014) or 0.014
    if type(setTextAlignment) == "function"
        and RenderText ~= nil
        and RenderText.ALIGN_RIGHT ~= nil then
        setTextAlignment(RenderText.ALIGN_RIGHT)
    end
    if type(setTextBold) == "function" then setTextBold(true) end
    if type(setTextColor) == "function" then
        setTextColor(
            iconColor[1],
            iconColor[2],
            iconColor[3],
            iconColor[4]
        )
    end

    renderText(0.985, 0.235, size, "PTO " .. tostring(modeText))

    if type(setTextColor) == "function" then setTextColor(1, 1, 1, 1) end
    if type(setTextBold) == "function" then setTextBold(false) end
    if type(setTextAlignment) == "function"
        and RenderText ~= nil
        and RenderText.ALIGN_LEFT ~= nil then
        setTextAlignment(RenderText.ALIGN_LEFT)
    end
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

    local state, modeText, mismatch = getDisplayState(vehicle)
    if state == nil or modeText == nil then
        count("noState")
        return
    end

    local engaged = isEngaged(vehicle)
    local speedKph = getVehicleSpeedKph(vehicle)
    local transportWarning = engaged
        and speedKph > math.max(0, cfgNumber("transportWarningKph"))
    local activeWarning = engaged and (mismatch or transportWarning)
    local actualRpm = getActualPtoRpm(vehicle, state, engaged)

    HUD._lastMode = modeText
    HUD._lastEngaged = engaged
    HUD._lastMismatch = mismatch
    HUD._lastTransportWarning = transportWarning
    HUD._lastSpeedKph = speedKph
    HUD._lastActualRpm = actualRpm

    if activeWarning then count("warningFrames") end

    local iconColor = engaged and HUD.COLOR_ACTIVE or HUD.COLOR_OFF
    if activeWarning then iconColor = getWarningColor() end

    local textColor = iconColor
    if mismatch and not engaged then
        -- Preserve the important distinction: a white icon means PTO off.
        -- A red mode label warns about a bad selector/implement match without
        -- pretending the shaft is running.
        textColor = HUD.COLOR_CRITICAL
    end

    if type(new2DLayer) == "function" then new2DLayer() end

    local anchorSpeedMeter, centerX, centerY = getDashboardAnchor()
    if anchorSpeedMeter == nil then
        count("noSpeedMeter")
        if drawFallbackText(modeText, iconColor) then
            count("fallbackRendered")
            count("rendered")
        end
        return
    end

    if not ensureIcon() then
        if drawFallbackText(modeText, iconColor) then
            count("fallbackRendered")
            count("rendered")
        end
        return
    end

    local offsetX, offsetY = scalePixelVector(
        anchorSpeedMeter,
        cfgNumber("offsetXPx"),
        cfgNumber("offsetYPx")
    )
    local iconWidth, iconHeight = scalePixelVector(
        anchorSpeedMeter,
        cfgNumber("iconWidthPx"),
        cfgNumber("iconHeightPx")
    )

    local iconX = centerX + offsetX
    local iconY = centerY + offsetY

    HUD._icon:setDimension(iconWidth, iconHeight)
    HUD._icon:setPosition(iconX, iconY)
    applyColor(HUD._icon, iconColor)
    HUD._icon:render()

    if type(renderText) == "function" then
        local textSize = scalePixelHeight(
            anchorSpeedMeter,
            cfgNumber("modeTextSizePx")
        )
        local textGap = scalePixelHeight(
            anchorSpeedMeter,
            cfgNumber("modeTextGapPx")
        )
        local textX = iconX + iconWidth * 0.5
        local textY = iconY - textGap

        if type(setTextAlignment) == "function"
            and RenderText ~= nil
            and RenderText.ALIGN_CENTER ~= nil then
            setTextAlignment(RenderText.ALIGN_CENTER)
        end
        if type(setTextVerticalAlignment) == "function"
            and RenderText ~= nil
            and RenderText.VERTICAL_ALIGN_MIDDLE ~= nil then
            setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
        end
        if type(setTextBold) == "function" then setTextBold(true) end
        if type(setTextColor) == "function" then
            setTextColor(
                textColor[1],
                textColor[2],
                textColor[3],
                textColor[4]
            )
        end

        renderText(textX, textY, textSize, modeText)

        if type(setTextColor) == "function" then setTextColor(1, 1, 1, 1) end
        if type(setTextBold) == "function" then setTextBold(false) end
        if type(setTextAlignment) == "function"
            and RenderText ~= nil
            and RenderText.ALIGN_LEFT ~= nil then
            setTextAlignment(RenderText.ALIGN_LEFT)
        end
        if type(setTextVerticalAlignment) == "function"
            and RenderText ~= nil
            and RenderText.VERTICAL_ALIGN_BOTTOM ~= nil then
            setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BOTTOM)
        end
    end

    count("graphicalRendered")
    count("rendered")
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
            "PTO dashboard indicator attached to controlled-entity HUD"
        )
    end

    return true, "installed"
end

function HUD:loadMap()
    HUD._installElapsedMs = HUD.installRetryMs
    HUD._hookedHud = nil
    HUD._cacheVehicle = nil
    HUD._cacheRevision = nil
    HUD._cacheModeText = nil
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
    if HUD._icon ~= nil and type(HUD._icon.delete) == "function" then
        HUD._icon:delete()
    end
    HUD._icon = nil
    HUD._hookedHud = nil
    HUD._cacheVehicle = nil
    HUD._cacheRevision = nil
    HUD._cacheModeText = nil
    HUD._cacheMismatch = false
    HUD._installElapsedMs = HUD.installRetryMs
end

function HUD.getDiagnostics()
    local out = {}
    for key, value in pairs(HUD.stats or {}) do
        out[key] = value
    end
    out.installed = HUD._hookedHud ~= nil
    out.overlayReady = HUD._icon ~= nil
    out.lastMode = HUD._lastMode
    out.lastEngaged = HUD._lastEngaged
    out.lastMismatch = HUD._lastMismatch
    out.lastTransportWarning = HUD._lastTransportWarning
    out.lastSpeedKph = HUD._lastSpeedKph
    out.lastActualRpm = HUD._lastActualRpm
    return out
end

resetStats()
addModEventListener(HUD)

return HUD
