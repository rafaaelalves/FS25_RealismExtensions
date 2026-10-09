RealismExtensionsPTOStateEvent = {}
local PTOStateEvent = RealismExtensionsPTOStateEvent
local PTOStateEvent_mt = Class(PTOStateEvent, Event)

InitEventClass(PTOStateEvent, "RealismExtensionsPTOStateEvent")

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

    if not connection:getIsServer() then
        -- Client -> server request. The server validates availability/safety
        -- before broadcasting the accepted state.
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
