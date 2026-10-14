RealismExtensionsPTOStateEvent = {}
local PTOStateEvent = RealismExtensionsPTOStateEvent
local PTOStateEvent_mt = Class(PTOStateEvent, Event)

InitEventClass(PTOStateEvent, "RealismExtensionsPTOStateEvent")

PTOStateEvent.stats = PTOStateEvent.stats or {
    acceptedClientRequests = 0,
    rejectedClientRequests = 0,
    rejectedReasons = {}
}

local function rejectClientRequest(reason)
    local stats = PTOStateEvent.stats
    stats.rejectedClientRequests = stats.rejectedClientRequests + 1
    stats.rejectedReasons[reason] =
        (stats.rejectedReasons[reason] or 0) + 1
    return false, reason
end

-- A farm permission or vehicle ownership alone does not authorize a remote
-- user to operate a tractor somebody else is driving. GIANTS sets the owner
-- connection and controllerUserId on the server during vehicle entry; both
-- must match the untrusted event's actual sender. No client-sent farm/user ID
-- is accepted, and absent runtime APIs fail closed.
local function isAuthorizedClientRequest(vehicle, connection)
    if g_server == nil or vehicle.isServer ~= true then
        return rejectClientRequest("not_server")
    end

    if type(vehicle.getIsSynchronized) ~= "function" then
        return rejectClientRequest("no_sync_api")
    end
    local ok, synchronized =
        pcall(vehicle.getIsSynchronized, vehicle)
    if not ok or synchronized ~= true then
        return rejectClientRequest("not_synchronized")
    end

    if type(vehicle.getOwnerConnection) ~= "function" then
        return rejectClientRequest("no_owner_api")
    end
    local ownerOk, ownerConnection =
        pcall(vehicle.getOwnerConnection, vehicle)
    if not ownerOk or ownerConnection ~= connection then
        return rejectClientRequest("not_vehicle_controller")
    end

    -- GIANTS' vehicle-enter requests require a ghosted object before
    -- granting control. Preserve that invariant if the server exposes it.
    if type(g_server.hasGhostObject) == "function" then
        local ghostOk, hasGhost =
            pcall(g_server.hasGhostObject, g_server, connection, vehicle)
        if not ghostOk or hasGhost ~= true then
            return rejectClientRequest("not_visible_to_client")
        end
    end

    local mission = g_currentMission
    local userManager = mission ~= nil and mission.userManager or nil
    if userManager == nil
        or type(userManager.getUserIdByConnection) ~= "function" then
        return rejectClientRequest("no_user_manager")
    end
    local userOk, userId =
        pcall(userManager.getUserIdByConnection, userManager, connection)
    if not userOk or userId == nil
        or vehicle.controllerUserId == nil
        or userId ~= vehicle.controllerUserId then
        return rejectClientRequest("not_controller_user")
    end

    PTOStateEvent.stats.acceptedClientRequests =
        PTOStateEvent.stats.acceptedClientRequests + 1
    return true
end

function PTOStateEvent.getDiagnostics()
    local stats = PTOStateEvent.stats
    local reasons = {}
    for key, value in pairs(stats.rejectedReasons) do
        reasons[key] = value
    end
    return {
        acceptedClientRequests = stats.acceptedClientRequests,
        rejectedClientRequests = stats.rejectedClientRequests,
        rejectedReasons = reasons
    }
end

function PTOStateEvent.emptyNew()
    return Event.new(PTOStateEvent_mt)
end

function PTOStateEvent.new(vehicle, mode, throttle)
    local self = PTOStateEvent.emptyNew()
    self.vehicle = vehicle
    self.mode = RealismExtensionsPTOModel.normalizeMode(mode)
    self.throttle = RealismExtensionsPTOModel.clampThrottle(throttle)
    return self
end

function PTOStateEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.mode = streamReadUIntN(streamId, 3)
    self.throttle = streamReadFloat32(streamId)
    self:run(connection)
end

function PTOStateEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteUIntN(
        streamId,
        RealismExtensionsPTOModel.normalizeMode(self.mode),
        3
    )
    streamWriteFloat32(
        streamId,
        RealismExtensionsPTOModel.clampThrottle(self.throttle)
    )
end

function PTOStateEvent:run(connection)
    local vehicle = self.vehicle
    if vehicle == nil
        or type(vehicle.setPowerTakeOffState) ~= "function" then
        return
    end

    if connection == nil
        or type(connection.getIsServer) ~= "function" then
        return
    end

    if not connection:getIsServer() then
        -- Client -> server: validate the actual network connection BEFORE
        -- any setter is invoked. Gear/safety rules are still enforced by
        -- Control:setPowerTakeOffState on the authoritative server.
        if not isAuthorizedClientRequest(vehicle, connection) then
            return
        end
        local applied = vehicle:setPowerTakeOffState(
            self.mode,
            self.throttle,
            true,
            false
        )
        if applied and g_server ~= nil then
            local state = RealismExtensionsPTO ~= nil
                and RealismExtensionsPTO.getVehicleState(vehicle) or nil
            g_server:broadcastEvent(
                PTOStateEvent.new(
                    vehicle,
                    state ~= nil and state.mode or self.mode,
                    state ~= nil and state.handThrottlePercent
                        or self.throttle
                ),
                nil,
                connection,
                vehicle
            )
        end
    else
        -- Server -> client replication is authoritative.
        vehicle:setPowerTakeOffState(
            self.mode,
            self.throttle,
            true,
            true
        )
    end
end

function PTOStateEvent.send(vehicle, mode, throttle)
    if vehicle == nil then return end

    local event = PTOStateEvent.new(vehicle, mode, throttle)
    if g_server ~= nil then
        g_server:broadcastEvent(event, nil, nil, vehicle)
    elseif g_client ~= nil
        and type(g_client.getServerConnection) == "function" then
        g_client:getServerConnection():sendEvent(event)
    end
end

return PTOStateEvent
