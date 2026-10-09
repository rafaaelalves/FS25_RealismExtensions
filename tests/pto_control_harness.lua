RealismExtensionsConfig={modules={PTOControl=true}}
RealismExtensionsPTO={API_VERSION=1}

SpecializationUtil={
    hasSpecialization=function() return true end,
    registerFunction=function() end,
    registerEventListener=function() end
}
Motorized={}
Drivable={}
AttacherJoints={}

dofile("scripts/pto/PTOModel.lua")
dofile("scripts/pto/PTOProfiles.lua")
dofile("scripts/pto/PTOResolver.lua")

local sent=0
RealismExtensionsPTOStateEvent={
    send=function(vehicle,mode,throttle)
        sent=sent+1
    end
}

dofile("scripts/pto/PTOControl.lua")

local M=RealismExtensionsPTOModel
local C=RealismExtensionsPTOControl

local motor={
    minRpm=800,
    maxRpm=2200,
    lastRealMotorRpm=845,
    getLastRealMotorRpm=function(self) return self.lastRealMotorRpm end,
    getPtoMotorRpmRatio=function() return 4.0 end
}

local engaged=false
local chipper={
    configFileName="/mods/hm10500KF.xml",
    spec_powerConsumer={ptoRpm=540},
    spec_powerTakeOffs={inputPowerTakeOffs={{}}},
    getIsPowerTakeOffActive=function() return engaged end,
    getIsTurnedOn=function() return engaged end,
    getAttachedImplements=function() return {} end
}

local dirty=0
local registeredActions=0
local activeEvents=0
local collisionBypassArgs=0

InputAction={
    RE_PTO_MODE_NEXT="RE_PTO_MODE_NEXT",
    RE_PTO_MODE_PREV="RE_PTO_MODE_PREV",
    RE_PTO_THROTTLE_UP="RE_PTO_THROTTLE_UP",
    RE_PTO_THROTTLE_DOWN="RE_PTO_THROTTLE_DOWN",
    RE_PTO_THROTTLE_RESET="RE_PTO_THROTTLE_RESET"
}
GS_PRIO_HIGH=2
g_inputBinding={
    setActionEventText=function() end,
    setActionEventTextPriority=function() end,
    setActionEventTextVisibility=function() end,
    setActionEventActive=function(id,active)
        if active then activeEvents=activeEvents+1 end
    end
}
g_currentMission={
    warnings={},
    showBlinkingWarning=function(self,msg,duration)
        self.warnings[#self.warnings+1]=msg
    end
}

local vehicle={
    configFileName="/mods/fiat18090.xml",
    isServer=true,
    isClient=true,
    getName=function() return "Fiat 180-90 DT" end,
    getMotor=function() return motor end,
    getOutputPowerTakeOffs=function() return {rear={}} end,
    getAttachedImplements=function() return {{object=chipper}} end,
    getIsPowerTakeOffActive=function() return false end,
    getNextDirtyFlag=function() return 8 end,
    raiseDirtyFlags=function(self,flag) dirty=dirty+flag end,
    clearActionEventsTable=function(self,t) end,
    addActionEvent=function(self,t,action,target,callback,triggerUp,triggerDown,triggerAlways,startActive,callbackState,customIcon,ignoreCollisions)
        registeredActions=registeredActions+1
        if ignoreCollisions==true then collisionBypassArgs=collisionBypassArgs+1 end
        return true,registeredActions,nil
    end
}

C.onLoad(vehicle,nil)
C.onRegisterActionEvents(vehicle,true,true)
assert(registeredActions==5)
assert(activeEvents==5)
assert(collisionBypassArgs==5)

local spec=vehicle[C.SPEC_TABLE]
assert(spec~=nil)
assert(spec.enabled==true)
assert(spec.hasPtoOutput==true)
assert(spec.mode==M.MODE.RPM_540)
assert(spec.availableModes[M.MODE.RPM_1000]~=nil)

local state=C.getPublicState(vehicle)
assert(state~=nil)
assert(state.requiredShaftRpm==1000)
assert(state.mismatch==true)
assert(state.capabilitySource=="PROFILE")

-- Manual selector: operator action explicitly changes to 1000.
C.actionModeNext(vehicle)
assert(spec.mode==M.MODE.RPM_1000)
assert(sent==1)
assert(dirty==8)
state=C.getPublicState(vehicle)
assert(state.mismatch==false)
assert(state.effectiveMotorRatio~=nil)
assert(#g_currentMission.warnings==1)
assert(string.find(g_currentMission.warnings[1],"1000",1,true)~=nil)

-- Safety: selector cannot move while PTO is engaged.
engaged=true
assert(C.stepPowerTakeOffMode(vehicle,-1)==false)
assert(spec.mode==M.MODE.RPM_1000)
assert(sent==1)
assert(#g_currentMission.warnings==2)
assert(string.find(g_currentMission.warnings[2],"desengate",1,true)~=nil)
engaged=false

-- Hand throttle is an engine-RPM governor, not an abstract 5% nudge.
C.actionThrottleUp(vehicle)
state=C.getPublicState(vehicle)
assert(math.abs(state.handThrottleRpm-900)<0.000001)
assert(math.abs(spec.handThrottlePercent-(100/1400))<0.000001)
assert(sent==2)

C.actionThrottleUp(vehicle)
state=C.getPublicState(vehicle)
assert(math.abs(state.handThrottleRpm-1000)<0.000001)
assert(sent==3)

C.actionThrottleDown(vehicle)
state=C.getPublicState(vehicle)
assert(math.abs(state.handThrottleRpm-900)<0.000001)
assert(sent==4)

C.actionThrottleReset(vehicle)
assert(spec.handThrottlePercent==0)
assert(sent==5)
assert(C.getPublicState(vehicle).handThrottleRpm==0)
assert(string.find(g_currentMission.warnings[#g_currentMission.warnings],"ROAD",1,true)~=nil)

local diag=C.getDiagnostics()
assert(diag.actionModeNext==1)
assert(diag.actionThrottleUp==2)
assert(diag.actionThrottleDown==1)
assert(diag.actionThrottleReset==1)
assert(diag.modeChanges==1)
assert(diag.throttleChanges==4)
assert(diag.stateChanges==5)
assert(diag.rejectedEngaged==1)
assert(diag.actionEventsRegistered==5)
assert(diag.actionEventsFailed==0)
assert(diag.actionEventsCollisionBypass==5)

-- Requirement refresh is event-driven, not per-frame.
vehicle.getAttachedImplements=function() return {} end
local revisionBefore=C.getPublicState(vehicle).revision
C.refreshPowerTakeOffRequirements(vehicle)
state=C.getPublicState(vehicle)
assert(state.hasPtoConsumer==false)
assert(state.requiredShaftRpm==nil)
assert(state.revision>revisionBefore)

-- Save callbacks receive the specialization key already namespaced by GIANTS.
-- Writing the mod/spec namespace again would produce an invalid duplicated path.
spec.mode=M.MODE.RPM_1000
spec.handThrottlePercent=0.5
local written={}
local saveXml={
    setValue=function(self,key,value)
        written[key]=value
    end
}
local specializationSaveKey=
    "vehicles.vehicle(0).FS25_RealismExtensions.realismExtensionsPTO"
C.saveToXMLFile(vehicle,saveXml,specializationSaveKey,{})
assert(written[specializationSaveKey.."#mode"]==M.MODE.RPM_1000)
assert(math.abs(written[specializationSaveKey.."#handThrottle"]-0.5)<0.000001)
assert(written[
    specializationSaveKey
    ..".FS25_RealismExtensions.realismExtensionsPTO#mode"
]==nil)

-- onPostLoad receives the vehicle base key, so it must still resolve the
-- registered mod specialization namespace from that base key.
local readKeys={}
local loadXml={
    getValue=function(self,key)
        readKeys[#readKeys+1]=key
        if key==
            "vehicles.vehicle(0).FS25_RealismExtensions.realismExtensionsPTO#mode" then
            return M.MODE.RPM_540
        end
        if key==
            "vehicles.vehicle(0).FS25_RealismExtensions.realismExtensionsPTO#handThrottle" then
            return 0.25
        end
        return nil
    end
}
C.onPostLoad(vehicle,{
    key="vehicles.vehicle(0)",
    xmlFile=loadXml
})
assert(spec.mode==M.MODE.RPM_540)
assert(math.abs(spec.handThrottlePercent-0.25)<0.000001)
assert(#readKeys==2)

-- Event-based late native PTO output discovery. The forestry/telehandler
-- specialization can load its output after Control:onLoad, but before the
-- final onPostLoad. This must work without a per-frame polling controller.
local lateOutputs={}
local delayed={
    configFileName="data/vehicles/merlo/mf44_9CS/mf44_9CS.xml",
    getName=function()return "Merlo MF44.9CS-170-CVTRONIC" end,
    getMotor=function()return motor end,
    getOutputPowerTakeOffs=function()return lateOutputs end,
    getAttachedImplements=function()return {} end,
    getNextDirtyFlag=function()return 16 end
}
C.onLoad(delayed,nil)
local dl=delayed[C.SPEC_TABLE]
assert(dl~=nil and dl.hasPtoOutput==false)
assert(C.getPublicState(delayed)==nil)
assert(next(dl.capability.modes)==nil)
lateOutputs={{attacherJointIndices={[1]=true}}}
C.onPostLoad(delayed,nil)
assert(dl.hasPtoOutput==true)
assert(dl.capability.profileId=="merlo_multifarmer_mf44_9")
assert(dl.availableModes[M.MODE.RPM_540]~=nil)
assert(dl.availableModes[M.MODE.RPM_1000]~=nil)
assert(dl.availableModes[M.MODE.RPM_540_ECO]==nil)
assert(C.getPublicState(delayed).hasPtoOutput==true)
-- A previously loaded instance with physical output removed is fail-closed.
lateOutputs={}
C.onPostLoad(delayed,nil)
assert(dl.hasPtoOutput==false)
assert(next(dl.availableModes)==nil)
assert(C.getPublicState(delayed)==nil)


-- AI gears: a worker must switch to the exact implement shaft family before
-- engagement. MR owns the RPM governor, while saved manual preferences survive.
local originalCollect=RealismExtensionsPTOResolver.collectRequirements
local workerActive=false
vehicle.getIsAIActive=function() return workerActive end
vehicle.getAttachedImplements=function() return {{object=chipper}} end
C.onPostLoad(vehicle,nil)
spec.mode=M.MODE.RPM_540
spec.handThrottlePercent=0.6
C.refreshPowerTakeOffRequirements(vehicle)
assert(C.getPublicState(vehicle).requiredShaftRpm==1000)
local aiStartSent=sent
local messages={}
RealismExtensionsDiagnostics={
    info=function(message) messages[#messages+1]=message end,
    verbose=function() end
}
RealismExtensionsConfig.diagnostics={ptoWorkerEvents=true}
workerActive=true
C.onAIJobStarted(vehicle)
assert(spec.mode==M.MODE.RPM_1000)
assert(spec.aiOriginalMode==M.MODE.RPM_540)
assert(math.abs(spec.handThrottlePercent-0.6)<0.000001)
assert(C.getPublicState(vehicle).effectiveMotorRatio~=nil)
assert(sent==aiStartSent+1)
assert(#messages==1)
assert(messages[1]:find("PTO AI",1,true)~=nil)
assert(messages[1]:find("540 -> 1000",1,true)~=nil)
assert(messages[1]:find("required=1000",1,true)~=nil)
C.onAIFieldWorkerStart(vehicle)
assert(sent==aiStartSent+1) -- duplicate callbacks do not resend
assert(#messages==1) -- no duplicate diagnostic on same decision

-- A save in the middle of a worker's job must persist the OPERATOR gear.
local aiSave={}
C.saveToXMLFile(vehicle,{setValue=function(_,k,v) aiSave[k]=v end},
    specializationSaveKey,{})
assert(aiSave[specializationSaveKey.."#mode"]==M.MODE.RPM_540)
assert(math.abs(aiSave[specializationSaveKey.."#handThrottle"]-0.6)<0.000001)
assert(C.setPowerTakeOffState(vehicle,M.MODE.RPM_540,0.1)==false)
assert(spec.mode==M.MODE.RPM_1000)

-- Never restore physical gear while shaft is engaged. Only a short pending
-- release check is performed after the worker is done.
engaged=true
workerActive=false
C.onAIJobFinished(vehicle)
assert(spec.aiRestorePending==true)
assert(spec.mode==M.MODE.RPM_1000)
assert(#messages==2)
assert(messages[2]:find("restore-deferred",1,true)~=nil)
C.onUpdate(vehicle,16)
assert(spec.mode==M.MODE.RPM_1000)
engaged=false
C.onUpdate(vehicle,16)
assert(spec.mode==M.MODE.RPM_540)
assert(spec.aiOriginalMode==nil and spec.aiRestorePending==false)
assert(math.abs(spec.handThrottlePercent-0.6)<0.000001)
assert(#messages==3)
assert(messages[3]:find("decision=restored",1,true)~=nil)

-- AI must not round incompatible 750-rpm tools to 1000.
RealismExtensionsPTOResolver.collectRequirements=function()
    return {hasPtoConsumer=true, requiredRpm=750,
        conflict=false, unknownCount=0}
end
workerActive=true
C.onAIJobStarted(vehicle)
assert(spec.mode==M.MODE.RPM_540)
assert(spec.aiOriginalMode==nil)

-- Conflicting and unknown demand must never trigger a gear change.
RealismExtensionsPTOResolver.collectRequirements=function()
    return {hasPtoConsumer=true, requiredRpm=nil,
        conflict=true, unknownCount=0}
end
C.onAIJobStarted(vehicle)
assert(spec.mode==M.MODE.RPM_540)
RealismExtensionsPTOResolver.collectRequirements=function()
    return {hasPtoConsumer=true, requiredRpm=1000,
        conflict=false, unknownCount=1}
end
C.onAIJobStarted(vehicle)
assert(spec.mode==M.MODE.RPM_540)

-- Active PTO can't be shifted, even when another worker/job starts.
RealismExtensionsPTOResolver.collectRequirements=function()
    return {hasPtoConsumer=true, requiredRpm=1000,
        conflict=false, unknownCount=0}
end
engaged=true
C.onAIJobStarted(vehicle)
assert(spec.mode==M.MODE.RPM_540)
assert(spec.aiOriginalMode==nil)
engaged=false

-- Normal operator mode 1000 can also be retained by a worker without change.
spec.mode=M.MODE.RPM_1000
C.onAIJobStarted(vehicle)
assert(spec.mode==M.MODE.RPM_1000)
assert(spec.aiOriginalMode==nil)
workerActive=false
C.onAIJobFinished(vehicle)
assert(spec.mode==M.MODE.RPM_1000)
RealismExtensionsPTOResolver.collectRequirements=originalCollect

local aiDiag=C.getDiagnostics()
assert(aiDiag.aiModeSwitches==1)
assert(aiDiag.aiRestores==1)
assert(aiDiag.aiModeUnavailable>=1)
assert(aiDiag.aiUnsafeShiftSkipped>=1)
assert(aiDiag.aiDiagnosticEvents>=6)
-- A PTO-less operation and duplicate callbacks do not spam the log.
assert(#messages==aiDiag.aiDiagnosticEvents)
-- Tracing can be disabled without affecting automatic gear choice.
RealismExtensionsConfig.diagnostics.ptoWorkerEvents=false
local previouslyLogged=#messages
spec.mode=M.MODE.RPM_540
workerActive=true
C.onAIJobStarted(vehicle)
assert(#messages==previouslyLogged)
workerActive=false
C.onAIJobFinished(vehicle)

print("pto_control_harness: OK")
