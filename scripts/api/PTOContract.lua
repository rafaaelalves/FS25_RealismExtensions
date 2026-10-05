RealismExtensionsPTO = RealismExtensionsPTO or {}
local API = RealismExtensionsPTO

API.API_VERSION = 1
API.enabled = false
API.reason = "not initialized"

function API.setRuntimeStatus(enabled, reason)
    API.enabled = enabled == true
    API.reason = reason
end

function API.getRuntimeStatus()
    return API.enabled, API.reason, API.API_VERSION
end

function API.getVehicleState(vehicle)
    if not API.enabled or vehicle == nil then return nil end
    local control = RealismExtensionsPTOControl
    if control == nil or type(control.getPublicState) ~= "function" then
        return nil
    end
    return control.getPublicState(vehicle)
end

function API.getVehicleRevision(vehicle)
    local state = API.getVehicleState(vehicle)
    return state ~= nil and (state.revision or 0) or 0
end

return API
