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
    spec_powerConsumer = { ptoRpm = 400, neededMinPtoPower = 2, neededMaxPtoPower = 12 },
    mrLastNeededPtoPower = 7.25,
    getConsumedPtoTorque = function() return ptoActive and 0.12 or 0 end,
    mrPtoCurrentRpm = 296, mrPtoCurrentRpmRatio = 0.74,
    mrPowerConsumerForcePtoRpm = true, mrBalerLastNeededPower = 19,
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
    requiredGearboxFamilyRpm = nil, gearCompatibility = "UNKNOWN",
    knownRequirementCount = 0, unknownRequirementCount = 1,
    handThrottleRpm = 0, effectiveMotorRatio = 4,
    driveEvidenceStatus = "NATIVE_PTO_INPUT",
    attachedImplementCount = 1,
    nativeInputImplementCount = 1,
    profiledImplementCount = 0,
    unlinkedPowerConsumerCount = 0
}
RealismExtensionsPTO = {
    getVehicleState = function(v) assert(v==vehicle); return state end
}
dofile("scripts/pto/PTOModel.lua")
dofile("scripts/pto/PTOProfiles.lua")
dofile("scripts/pto/PTOResolver.lua")
RealismExtensionsPTOResolver.isPtoEngaged = function(v)
    assert(v==vehicle)
    return ptoActive,"native"
end
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
assert(report[1]:find("nominalFamily=-",1,true))
assert(report[1]:find("gearCompatibility=UNKNOWN",1,true))
assert(report[1]:find("known=0 unknown=1",1,true))
assert(report[1]:find("driveEvidence=NATIVE_PTO_INPUT",1,true))
assert(report[1]:find("nativeInputs=1",1,true))
assert(report[1]:find("unlinkedPower=0",1,true))
assert(report[2]:find("maxPtoDemand=400",1,true))
assert(report[2]:find("mrMinPtoRot=125",1,true))
assert(report[3]:find("inputPto=1",1,true))
assert(report[3]:find("connectedInput=1",1,true))
-- A single connectedVehicle pointer did not establish reciprocal linkage.
assert(report[3]:find("ptoLink=UNKNOWN",1,true))
assert(report[3]:find("verifiedLinks=0",1,true))
assert(report[3]:find("uncertainLinks=1",1,true))
local input=tool.spec_powerTakeOffs.inputPowerTakeOffs[1]
local nativeOutput={connectedInput=input,connectedVehicle=tool}
input.connectedOutput=nativeOutput
report=I.snapshot(vehicle)
assert(report[3]:find("ptoLink=LINKED",1,true))
assert(report[3]:find("verifiedLinks=1",1,true))
-- Link state is sampled afresh; nothing needs an attach/detach callback.
input.connectedOutput=nil
input.connectedVehicle=nil
report=I.snapshot(vehicle)
assert(report[3]:find("ptoLink=DECLARED_UNLINKED",1,true))
assert(report[3]:find("unlinkedInputs=1",1,true))
input.connectedOutput=nativeOutput
input.connectedVehicle={}
assert(report[3]:find("connectedInput=1",1,true)==nil)
assert(report[3]:find("rawConsumerRPM=400",1,true))
assert(report[3]:find("liveConsumerRPM=0",1,true))
assert(report[3]:find("mrPtoCurrentRPM=296",1,true))
assert(report[3]:find("mrPtoRpmRatio=0.74",1,true))
assert(report[3]:find("forcePtoRpm=true",1,true))
assert(report[3]:find("mrBalerPowerKW=19",1,true))
assert(report[3]:find("turnedOn=false",1,true))
assert(report[3]:find("powerMinKW=2",1,true))
assert(report[3]:find("powerMaxKW=12",1,true))
assert(report[3]:find("mrLoadKW=7.25",1,true))
assert(report[3]:find("mrTorqueKNm=0",1,true))
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
assert(report[3]:find("mrTorqueKNm=0.12",1,true))
-- Optional MR fields absent on vanilla/mod equipment must not break read-only reports.
tool.mrPtoCurrentRpm=nil
tool.mrPtoCurrentRpmRatio=nil
tool.mrPowerConsumerForcePtoRpm=nil
tool.mrBalerLastNeededPower=nil
tool.mrLastNeededPtoPower=nil
tool.getConsumedPtoTorque=nil
report=I.snapshot(vehicle)
assert(report[3]:find("mrPtoRpmRatio=-",1,true))
assert(report[3]:find("mrBalerPowerKW=-",1,true))
assert(report[3]:find("mrLoadKW=-",1,true))
assert(report[3]:find("mrTorqueKNm=-",1,true))
-- Horsch-style non-mechanical auxiliary power is still visible to the
-- inspector without classifying it as a physical PTO shaft.
tool.configFileName="MoreRealistic/data/overriding/vehicles/horsch/avatar1225.xml"
tool.spec_powerConsumer={ptoRpm=340,neededMaxPtoPower=22}
tool.mrLastNeededPtoPower=13.5
tool.getDoConsumePtoPower=function()return true end
report=I.snapshot(vehicle)
assert(report[3]:find("rawConsumerRPM=340",1,true))
assert(report[3]:find("powerMaxKW=22",1,true))
assert(report[3]:find("mrLoadKW=13.5",1,true))
state.driveEvidenceStatus="POWER_CONSUMER_NO_INPUT"
state.nativeInputImplementCount=0
state.unlinkedPowerConsumerCount=1
report=I.snapshot(vehicle)
assert(report[1]:find("driveEvidence=POWER_CONSUMER_NO_INPUT",1,true))
assert(report[1]:find("unlinkedPower=1",1,true))
-- Generic power consumer has no physical input; output must expose that.
tool.spec_powerTakeOffs.inputPowerTakeOffs={}
report=I.snapshot(vehicle)
assert(report[3]:find("inputPto=0",1,true))
assert(report[3]:find("connectedInput=0",1,true))
assert(report[3]:find("ptoLink=NO_INPUT",1,true))
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
