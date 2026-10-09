-- Targeted read-only inspection; no engine hooks, no polling.
local logs = {}
RealismExtensionsDiagnostics = {
    info = function(message) logs[#logs + 1] = message end
}
local calls = {}
function addConsoleCommand(name, desc, method, obj)
    calls[name] = {method=method, obj=obj}
end
function removeConsoleCommand(name) calls[name] = nil end
function addModEventListener() end

local powerDemand = 400
PowerConsumer = {
    getMaxPtoRpm = function(vehicle) return powerDemand end
}
local engine = {
    lastRealMotorRpm = 1800,
    mrLastMinRotForPTO = 125,
    mrLastMinRotForPTOidle = 125,
}
local ptoActive = false
local tool = {
    configFileName = "data/vehicles/johnDeere/r975i/r975i.xml",
    spec_powerConsumer = { ptoRpm = 400, neededMaxPtoPower = 12 },
    spec_powerTakeOffs = {
        inputPowerTakeOffs = { {connectedVehicle = {}} }
    },
    getName = function() return "R975i PowrSpray" end,
    getPtoRpm = function() return ptoActive and 400 or 0 end,
    getDoConsumePtoPower = function() return ptoActive end,
    getIsTurnedOn = function() return ptoActive end,
    getIsPowerTakeOffActive = function() return ptoActive end,
    getAttachedImplements = function() return {} end
}
local attached = { {object=tool} }
local vehicle = {
    getName = function() return "Fiat 180-90 DT" end,
    getMotor = function() return engine end,
    getIsAIActive = function() return false end,
    getAttachedImplements = function() return attached end
}
local state = {
    modeToken = "540", shaftRpm = 540, requiredShaftRpm = 400,
    requirementConflict = false, hasPtoConsumer = true,
    handThrottleRpm = 0, effectiveMotorRatio = 4
}
RealismExtensionsPTO = {
    getVehicleState = function(v) assert(v==vehicle); return state end
}
RealismExtensionsPTOResolver = {
    isPtoEngaged = function(v) assert(v==vehicle); return ptoActive,"native" end
}
g_localPlayer = {
    getCurrentVehicle = function() return vehicle end
}
dofile("scripts/pto/PTOInspection.lua")
local I = RealismExtensionsPTOInspection
I:loadMap()
assert(calls.rePTOInspect ~= nil)
local report=I.snapshot(vehicle)
assert(#report==3)
assert(report[1]:find("hasConsumer=true",1,true))
assert(report[1]:find("required=400",1,true))
assert(report[2]:find("maxPtoDemand=400",1,true))
assert(report[2]:find("mrMinPtoRot=125",1,true))
assert(report[3]:find("inputPto=1",1,true))
assert(report[3]:find("connectedInput=1",1,true))
assert(report[3]:find("rawConsumerRPM=400",1,true))
assert(report[3]:find("liveConsumerRPM=0",1,true))
assert(report[3]:find("turnedOn=false",1,true))
assert(report[3]:find("powerKW=12",1,true))
local response=I:consoleCommandInspect()
assert(response:find("3 line",1,true))
assert(#logs==3)
assert(logs[3]:find("PTO INSPECT | TOOL",1,true))
ptoActive=true
tool.spec_powerConsumer.ptoRpm=500
state.requiredShaftRpm=500
powerDemand=500
report=I.snapshot(vehicle)
assert(report[1]:find("engaged=true",1,true))
assert(report[3]:find("rawConsumerRPM=500",1,true))
assert(report[3]:find("liveConsumerRPM=400",1,true))
assert(report[3]:find("activePto=true",1,true))
-- Generic power consumer has no physical input; output must expose that.
tool.spec_powerTakeOffs.inputPowerTakeOffs={}
report=I.snapshot(vehicle)
assert(report[3]:find("inputPto=0",1,true))
assert(report[3]:find("connectedInput=0",1,true))
-- Cycle/corrupt tree does not loop indefinitely or mutate equipment.
tool.getAttachedImplements=function() return {{object=vehicle}} end
assert(#I.snapshot(vehicle)==3)
-- Fail closed if no controlled vehicle, logging method and optional globals.
g_localPlayer.getCurrentVehicle=function() return nil end
g_currentMission=nil
assert(I:consoleCommandInspect():find("1 line",1,true))
assert(#logs==4)
I:deleteMap()
assert(calls.rePTOInspect==nil)
print("pto_inspection_harness: OK")
