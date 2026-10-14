-- Security regression: remote PTO requests must be bound to the network
-- connection that currently operates this exact tractor on the FS25 server.
-- Run with Lua 5.4; no engine or multiplayer session required.
Event = {
    new = function(mt) return setmetatable({}, mt) end
}
Class = function(class, base) return {__index=class} end
InitEventClass = function() end
RealismExtensionsPTOModel = {
    normalizeMode = function(value)
        value = tonumber(value) or 1
        return math.max(1, math.min(4, math.floor(value)))
    end,
    clampThrottle = function(value)
        value = tonumber(value) or 0
        if value ~= value then return 0 end
        return math.max(0, math.min(1, value))
    end
}

local clientA = {getIsServer=function() return false end}
local clientB = {getIsServer=function() return false end}
local serverConnection = {getIsServer=function() return true end}
local owner = clientA
local synchronized = true
local visible = true
local userIdFor = {[clientA]=101, [clientB]=102}
local operatorRejects = false
local applied = {}
local sent = {}
local server = {
    hasGhostObject = function(self, connection, object)
        return visible
    end,
    broadcastEvent = function(self, event, reliable, excludedConnection, vehicle)
        sent[#sent+1] = {
            event = event,
            reliable = reliable,
            excludedConnection = excludedConnection,
            vehicle = vehicle
        }
    end
}
local userManager = {
    getUserIdByConnection = function(self, connection)
        return userIdFor[connection]
    end
}
g_server = server
g_client = nil -- dedicated server topology, no local client
g_currentMission = {userManager=userManager}
local tractor = {
    isServer = true,
    controllerUserId = 101,
    getOwnerConnection = function(self) return owner end,
    getIsSynchronized = function(self) return synchronized end,
    setPowerTakeOffState = function(self, mode, throttle, noSend, replicated)
        applied[#applied+1] = {
            mode=mode, throttle=throttle,
            noSend=noSend, replicated=replicated
        }
        if operatorRejects then return false end
        self.mode = mode
        self.throttle = throttle
        return true
    end
}
RealismExtensionsPTO = {
    getVehicleState=function(object)
        return {
            mode=object.mode,
            handThrottlePercent=object.throttle
        }
    end
}

dofile("scripts/pto/PTOStateEvent.lua")
local E = RealismExtensionsPTOStateEvent
local function sendFrom(connection)
    E.new(tractor, 2, 0.4):run(connection)
end
local function assertDenied(reason, connection)
    local oldApplied = #applied
    local oldBroadcast = #sent
    local oldReason = E.getDiagnostics().rejectedReasons[reason] or 0
    sendFrom(connection or clientA)
    assert(#applied==oldApplied)
    assert(#sent==oldBroadcast)
    assert((E.getDiagnostics().rejectedReasons[reason] or 0)==oldReason+1,
        "expected denial: "..reason)
end
local function restore()
    owner=clientA
    synchronized=true
    visible=true
    userIdFor[clientA]=101
    userIdFor[clientB]=102
    g_server=server
    g_currentMission={userManager=userManager}
    tractor.isServer=true
    tractor.controllerUserId=101
    tractor.getIsSynchronized=function() return synchronized end
    tractor.getOwnerConnection=function() return owner end
    userManager.getUserIdByConnection=function(_,connection)
        return userIdFor[connection]
    end
    server.hasGhostObject=function() return visible end
    operatorRejects=false
end

-- A remote driver must be allowed to control its own tractor. The
-- server broadcasts its sanitized authoritative state excluding sender.
sendFrom(clientA)
assert(#applied==1 and #sent==1)
assert(applied[1].mode==2 and applied[1].throttle==0.4)
assert(applied[1].noSend==true and applied[1].replicated==false)
assert(sent[1].excludedConnection==clientA)
assert(sent[1].vehicle==tractor)
assert(sent[1].event.mode==2 and sent[1].event.throttle==0.4)
assert(E.getDiagnostics().acceptedClientRequests==1)

-- Another player from any farm cannot operate this controlled tractor.
assertDenied("not_vehicle_controller", clientB)

-- Never fall back to mere farm ownership, client identity, or shared machine
-- access when the controlling connection is missing.
owner=nil
assertDenied("not_vehicle_controller")
restore()
tractor.getOwnerConnection=nil
assertDenied("no_owner_api")
restore()
tractor.getOwnerConnection=function() error("engine owner API failed") end
assertDenied("not_vehicle_controller")
restore()

-- Vehicle owner connection must also correspond to the real controlling
-- user ID recorded by FS25, not a stale or spoofable client-sent farm ID.
tractor.controllerUserId=102
assertDenied("not_controller_user")
restore()
tractor.controllerUserId=nil
assertDenied("not_controller_user")
restore()
userIdFor[clientA]=nil
assertDenied("not_controller_user")
restore()
g_currentMission.userManager=nil
assertDenied("no_user_manager")
restore()
userManager.getUserIdByConnection=function() error("user lookup unavailable") end
assertDenied("not_controller_user")
restore()

-- Missing/delayed replication, invisible ghost or absent server must all
-- fail closed before the PTO setter can possibly run.
synchronized=false
assertDenied("not_synchronized")
restore()
tractor.getIsSynchronized=nil
assertDenied("no_sync_api")
restore()
visible=false
assertDenied("not_visible_to_client")
restore()
server.hasGhostObject=function() error("ghost lookup failed") end
assertDenied("not_visible_to_client")
restore()
tractor.isServer=false
assertDenied("not_server")
restore()
g_server=nil
assertDenied("not_server")
restore()

-- Even after authentication, the regular vehicle operator interlocks may
-- refuse a shift (e.g. engaged PTO or unavailable gearing): never broadcast.
operatorRejects=true
local beforeRejected=#sent
local beforeSetter=#applied
sendFrom(clientA)
assert(#applied==beforeSetter+1)
assert(#sent==beforeRejected)
restore()

-- Controller handoff: old driver rejected, new driver accepted.
owner=clientB
tractor.controllerUserId=102
assertDenied("not_vehicle_controller",clientA)
local beforeHandoff=#sent
sendFrom(clientB)
assert(#sent==beforeHandoff+1)
assert(sent[#sent].excludedConnection==clientB)
restore()

-- Incoming trusted server replication is a different direction: no owner
-- authorization is applied, and setter receives replicated=true.
local beforeReplication=#applied
E.new(tractor,3,0.8):run(serverConnection)
assert(#applied==beforeReplication+1)
assert(applied[#applied].replicated==true)
assert(applied[#applied].noSend==true)

-- No event should invoke a setter without a verifiable direction.
local beforeNil=#applied
E.new(tractor,1,0):run(nil)
assert(#applied==beforeNil)
E.new(tractor,1,0):run({})
assert(#applied==beforeNil)

-- Authoritative host/worker sends still work on a dedicated server without
-- g_client. Client-only sends still target its server connection.
local beforeHost=#sent
E.send(tractor,1,0.2)
assert(#sent==beforeHost+1)
assert(sent[#sent].excludedConnection==nil)
g_server=nil
local outgoing={}
g_client={
    getServerConnection=function()
        return {sendEvent=function(self,event) outgoing[#outgoing+1]=event end}
    end
}
E.send(tractor,4,0.7)
assert(#outgoing==1)
assert(outgoing[1].mode==4 and outgoing[1].throttle==0.7)

-- All the security checks above are executed in the real event:run entry
-- point, not only by calling a test-only predicate.
local stats=E.getDiagnostics()
assert(stats.acceptedClientRequests==3)
assert(stats.rejectedClientRequests>=14)
print("pto_state_event_harness: OK")
