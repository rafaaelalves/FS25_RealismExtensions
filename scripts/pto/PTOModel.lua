RealismExtensionsPTOModel = RealismExtensionsPTOModel or {}
local Model = RealismExtensionsPTOModel

Model.VERSION = 1

Model.MODE = {
    RPM_540 = 1,
    RPM_540_ECO = 2,
    RPM_1000 = 3,
    RPM_1000_ECO = 4
}

Model.MODES = {
    [Model.MODE.RPM_540] = {
        id = Model.MODE.RPM_540,
        token = "540",
        shaftRpm = 540,
        economy = false
    },
    [Model.MODE.RPM_540_ECO] = {
        id = Model.MODE.RPM_540_ECO,
        token = "540E",
        shaftRpm = 540,
        economy = true
    },
    [Model.MODE.RPM_1000] = {
        id = Model.MODE.RPM_1000,
        token = "1000",
        shaftRpm = 1000,
        economy = false
    },
    [Model.MODE.RPM_1000_ECO] = {
        id = Model.MODE.RPM_1000_ECO,
        token = "1000E",
        shaftRpm = 1000,
        economy = true
    }
}

local TOKEN_TO_MODE = {
    ["540"] = Model.MODE.RPM_540,
    ["540E"] = Model.MODE.RPM_540_ECO,
    ["540_ECO"] = Model.MODE.RPM_540_ECO,
    ["1000"] = Model.MODE.RPM_1000,
    ["1000E"] = Model.MODE.RPM_1000_ECO,
    ["1000_ECO"] = Model.MODE.RPM_1000_ECO
}

local function clamp01(v)
    v = tonumber(v) or 0
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

function Model.normalizeMode(mode)
    if type(mode) == "string" then
        local token = string.upper(mode)
        mode = TOKEN_TO_MODE[token]
    end

    mode = math.floor(tonumber(mode) or Model.MODE.RPM_540)
    if Model.MODES[mode] == nil then
        return Model.MODE.RPM_540
    end
    return mode
end

function Model.getMode(mode)
    return Model.MODES[Model.normalizeMode(mode)]
end

function Model.getModeToken(mode)
    return Model.getMode(mode).token
end

function Model.getShaftRpm(mode)
    return Model.getMode(mode).shaftRpm
end

function Model.isEconomy(mode)
    return Model.getMode(mode).economy == true
end

function Model.sameFamily(a, b)
    return Model.getShaftRpm(a) == Model.getShaftRpm(b)
end

function Model.modeForFamily(shaftRpm, economy)
    shaftRpm = tonumber(shaftRpm) or 0
    if shaftRpm >= 750 then
        return economy and Model.MODE.RPM_1000_ECO
            or Model.MODE.RPM_1000
    end
    if shaftRpm > 0 then
        return economy and Model.MODE.RPM_540_ECO
            or Model.MODE.RPM_540
    end
    return nil
end

function Model.sortedModes(available)
    local result = {}
    for mode = Model.MODE.RPM_540, Model.MODE.RPM_1000_ECO do
        if available ~= nil and available[mode] ~= nil then
            result[#result + 1] = mode
        end
    end
    return result
end

function Model.stepAvailableMode(currentMode, available, direction)
    local modes = Model.sortedModes(available)
    if #modes == 0 then return Model.MODE.RPM_540 end

    direction = tonumber(direction) or 1
    if direction == 0 then return Model.normalizeMode(currentMode) end

    local current = Model.normalizeMode(currentMode)
    local index = 1
    for i, mode in ipairs(modes) do
        if mode == current then
            index = i
            break
        end
    end

    if direction > 0 then
        index = index + 1
        if index > #modes then index = 1 end
    else
        index = index - 1
        if index < 1 then index = #modes end
    end

    return modes[index]
end

function Model.resolveMotorRatio(mode, capability, nativeRatio, maxEngineRpm)
    local modeDef = Model.getMode(mode)
    local entry = capability ~= nil
        and capability.modes ~= nil
        and capability.modes[modeDef.id]
        or nil

    if entry ~= nil then
        local direct = tonumber(entry.motorRatio)
        if direct ~= nil and direct > 0 then return direct end

        local engineRpm = tonumber(entry.engineRpm)
        if engineRpm ~= nil and engineRpm > 0 then
            return engineRpm / modeDef.shaftRpm
        end
    end

    -- Unknown tractors intentionally support only their native 540 mode.
    -- Reusing the GIANTS ratio preserves the original physical contract.
    if modeDef.id == Model.MODE.RPM_540 then
        nativeRatio = tonumber(nativeRatio)
        if nativeRatio ~= nil and nativeRatio > 0 then return nativeRatio end
    end

    -- Evidence-backed profiles may omit the exact engine target. In that case
    -- use rated/max engine speed for standard mode and a profile-specific
    -- economy factor for economy mode.
    maxEngineRpm = tonumber(maxEngineRpm)
    if capability ~= nil and maxEngineRpm ~= nil and maxEngineRpm > 0 then
        local factor = 1
        if modeDef.economy then
            factor = tonumber(capability.economyEngineFactor) or 0.78
        end
        return (maxEngineRpm * factor) / modeDef.shaftRpm
    end

    return nil
end

function Model.handThrottleRpm(percent, minRpm, maxRpm)
    percent = clamp01(percent)
    if percent <= 0.0001 then return 0 end

    minRpm = tonumber(minRpm) or 850
    maxRpm = tonumber(maxRpm) or math.max(minRpm, 2200)
    if maxRpm < minRpm then maxRpm = minRpm end

    return minRpm + (maxRpm - minRpm) * percent
end

function Model.clampThrottle(percent)
    return clamp01(percent)
end

return Model
