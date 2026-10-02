RealismExtensionsTerrainWorkContext = RealismExtensionsTerrainWorkContext or {}
local Work = RealismExtensionsTerrainWorkContext

Work.VERSION = 1
Work.DEFAULTS = {
    minWorkingSpeedKph = 0.5
}

function Work.getCombinationRoot(vehicle)
    if vehicle == nil then return nil end

    if type(vehicle.getRootVehicle) == "function" then
        local ok, root = pcall(vehicle.getRootVehicle, vehicle)
        if ok and root ~= nil then return root end
    end

    local current = vehicle
    local seen = {}
    for _ = 1, 8 do
        if current == nil or seen[current] == true then break end
        seen[current] = true
        if type(current.getAttacherVehicle) ~= "function" then break end
        local ok, parent = pcall(current.getAttacherVehicle, current)
        if not ok or parent == nil or parent == current then break end
        current = parent
    end

    return current
end

function Work.getVehicleLabel(vehicle)
    if vehicle == nil then return "nil" end

    local name = nil
    if type(vehicle.getName) == "function" then
        local ok, value = pcall(vehicle.getName, vehicle)
        if ok and type(value) == "string" and value ~= "" then
            name = value
        end
    end

    if name == nil and type(vehicle.configFileName) == "string" then
        name = vehicle.configFileName:match("([^/\\]+)%.xml$")
            or vehicle.configFileName
    end

    return tostring(name or vehicle.typeName or "vehicle")
        :gsub("[^%w_%-]", "_")
end

function Work.getSpeedKph(vehicle)
    if vehicle ~= nil and type(vehicle.getLastSpeed) == "function" then
        local ok, value = pcall(vehicle.getLastSpeed, vehicle)
        if ok and type(value) == "number" then
            return math.abs(value)
        end
    end
    return 0
end

function Work.getWorkAreaGeometry(workArea)
    if workArea == nil or workArea.start == nil
        or workArea.width == nil or workArea.height == nil then
        return nil
    end

    local okS, xs, _, zs = pcall(getWorldTranslation, workArea.start)
    local okW, xw, _, zw = pcall(getWorldTranslation, workArea.width)
    local okH, xh, _, zh = pcall(getWorldTranslation, workArea.height)
    if not okS or not okW or not okH then return nil end

    local ux, uz = xw - xs, zw - zs
    local vx, vz = xh - xs, zh - zs
    local widthM = math.sqrt(ux * ux + uz * uz)
    local depthM = math.sqrt(vx * vx + vz * vz)
    if widthM < 0.05 or depthM < 0.05 then return nil end

    return {
        xs = xs,
        zs = zs,
        ux = ux,
        uz = uz,
        vx = vx,
        vz = vz,
        widthM = widthM,
        depthM = depthM
    }
end

function Work.captureCultivatorPre(vehicle, nowMs)
    local spec = vehicle ~= nil and vehicle.spec_cultivator or nil
    local speedKph = Work.getSpeedKph(vehicle)
    local enabled = spec ~= nil and spec.isEnabled ~= false

    return {
        vehicle = vehicle,
        rootVehicle = Work.getCombinationRoot(vehicle),
        nowMs = tonumber(nowMs) or 0,
        speedKph = speedKph,
        enabled = enabled,
        potentiallyWorking = enabled
            and speedKph > Work.DEFAULTS.minWorkingSpeedKph
    }
end

function Work.captureCultivatorPost(vehicle, workArea, realArea, area, nowMs, pre)
    local spec = vehicle ~= nil and vehicle.spec_cultivator or nil
    local changedArea = math.max(0, tonumber(realArea) or 0)
    local processedArea = math.max(0, tonumber(area) or 0)
    local enabled = spec ~= nil and spec.isEnabled ~= false
    local physicallyWorking = enabled
        and spec ~= nil
        and spec.isWorking == true

    return {
        vehicle = vehicle,
        rootVehicle = pre ~= nil and pre.rootVehicle
            or Work.getCombinationRoot(vehicle),
        nowMs = tonumber(nowMs) or 0,
        speedKph = pre ~= nil and pre.speedKph or Work.getSpeedKph(vehicle),
        enabled = enabled,
        physicallyWorking = physicallyWorking,
        changedArea = changedArea,
        processedArea = processedArea,
        isRepeatPass = physicallyWorking
            and processedArea > 0
            and changedArea <= 0,
        geometry = Work.getWorkAreaGeometry(workArea),
        workArea = workArea
    }
end

return Work
