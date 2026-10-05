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
    raiseDirtyFlags=function(self,flag) dirty=dirty+flag end
}

C.onLoad(vehicle,nil)
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

-- Manual selector: operator explicitly changes to 1000.
assert(C.stepPowerTakeOffMode(vehicle,1)==true)
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
engaged=false

-- Hand throttle is independent operator state.
assert(C.adjustPowerTakeOffThrottle(vehicle,0.05)==true)
assert(math.abs(spec.handThrottlePercent-0.05)<0.000001)
assert(sent==2)
state=C.getPublicState(vehicle)
assert(state.handThrottleRpm>800)
assert(state.handThrottleRpm<2200)

assert(C.resetPowerTakeOffThrottle(vehicle)==true)
assert(spec.handThrottlePercent==0)
assert(sent==3)
assert(C.getPublicState(vehicle).handThrottleRpm==0)

-- Requirement refresh is event-driven, not per-frame.
vehicle.getAttachedImplements=function() return {} end
local revisionBefore=C.getPublicState(vehicle).revision
C.refreshPowerTakeOffRequirements(vehicle)
state=C.getPublicState(vehicle)
assert(state.hasPtoConsumer==false)
assert(state.requiredShaftRpm==nil)
assert(state.revision>revisionBefore)

print("pto_control_harness: OK")
