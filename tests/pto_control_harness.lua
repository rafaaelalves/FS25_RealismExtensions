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
    getPtoMotorRpmRatio=function() return 4.0 end
}

local chipper={
    configFileName="/mods/hm10500KF.xml",
    spec_powerConsumer={ptoRpm=540},
    spec_powerTakeOffs={inputPowerTakeOffs={{}}}
}

local engaged=false
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
    getIsPowerTakeOffActive=function() return engaged end,
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

-- Safety: selector cannot move while PTO is engaged.
engaged=true
assert(C.stepPowerTakeOffMode(vehicle,-1)==false)
assert(spec.mode==M.MODE.RPM_1000)
assert(sent==1)
assert(#g_currentMission.warnings==1)
assert(string.find(g_currentMission.warnings[1],"desengate",1,true)~=nil)
engaged=false

-- Hand throttle is independent operator state.
C.actionThrottleUp(vehicle)
assert(math.abs(spec.handThrottlePercent-0.05)<0.000001)
assert(sent==2)
state=C.getPublicState(vehicle)
assert(state.handThrottleRpm>800)
assert(state.handThrottleRpm<2200)

C.actionThrottleReset(vehicle)
assert(spec.handThrottlePercent==0)
assert(sent==3)
assert(C.getPublicState(vehicle).handThrottleRpm==0)

local diag=C.getDiagnostics()
assert(diag.actionModeNext==1)
assert(diag.actionThrottleUp==1)
assert(diag.actionThrottleReset==1)
assert(diag.modeChanges==1)
assert(diag.throttleChanges==2)
assert(diag.stateChanges==3)
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

print("pto_control_harness: OK")
