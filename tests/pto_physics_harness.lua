RealismExtensionsPTO={
    getVehicleState=function(vehicle)
        return vehicle._ptoState
    end
}
g_modIsLoaded={}

local aiActive=false
local vehicle={
    getIsAIActive=function() return aiActive end,
    getRootVehicle=function(self) return self end
}
local motor={
    vehicle=vehicle,
    ptoMotorRpmRatio=4.0,
    minRpm=800,
    maxRpm=2200,
    lastPtoRpm=800
}
vehicle.getMotor=function() return motor end
vehicle._ptoState={
    enabled=true,
    hasPtoOutput=true,
    hasPtoConsumer=true,
    requirementConflict=false,
    effectiveMotorRatio=2.2,
    handThrottleRpm=1600
}

local maxPtoCalls=0
PowerConsumer={}
function PowerConsumer.getMaxPtoRpm(subject)
    maxPtoCalls=maxPtoCalls+1
    return 540
end

VehicleMotor={}
function VehicleMotor.getPtoMotorRpmRatio(self)
    return self.ptoMotorRpmRatio
end
function VehicleMotor.getRequiredMotorRpmRange(self)
    -- Model the important GIANTS property: this native path reads the raw
    -- ptoMotorRpmRatio field, not getPtoMotorRpmRatio().
    local pto=PowerConsumer.getMaxPtoRpm(self.vehicle)
    if pto>0 then
        return pto*self.ptoMotorRpmRatio,2200
    end
    return self.minRpm,self.maxRpm
end
local updateObservedPto=nil
function VehicleMotor.update(self,dt)
    updateObservedPto=PowerConsumer.getMaxPtoRpm(self.vehicle)
    self.lastPtoRpm=updateObservedPto*self.ptoMotorRpmRatio
    return updateObservedPto
end

dofile("scripts/pto/PTOPhysics.lua")
local P=RealismExtensionsPTOPhysics

local ok,reason=P.install()
assert(ok==true,reason)

-- Getter exposes selected physical gearbox ratio without mutating the field.
assert(math.abs(VehicleMotor.getPtoMotorRpmRatio(motor)-2.2)<0.000001)
assert(math.abs(motor.ptoMotorRpmRatio-4.0)<0.000001)

-- Manual baseline: the PTO consumer no longer commands the engine RPM range.
-- Only the explicit RE hand throttle owns the lower bound.
local minRpm,maxRpm=VehicleMotor.getRequiredMotorRpmRange(motor)
assert(minRpm==1600)
assert(maxRpm==2200)
assert(math.abs(motor.ptoMotorRpmRatio-4.0)<0.000001)

-- ROAD releases the hand throttle all the way back to the engine's native
-- minimum instead of the implement's nominal PTO requirement.
vehicle._ptoState.handThrottleRpm=0
minRpm,maxRpm=VehicleMotor.getRequiredMotorRpmRange(motor)
assert(minRpm==800)
assert(maxRpm==2200)
assert(math.abs(motor.ptoMotorRpmRatio-4.0)<0.000001)

-- GIANTS VehicleMotor.update has a second automatic PTO-RPM clamp. It sees
-- zero only inside the scoped update for this root vehicle, then the original
-- PowerConsumer contract is restored immediately.
local before=maxPtoCalls
local observed=VehicleMotor.update(motor,16)
assert(observed==0)
assert(updateObservedPto==0)
assert(maxPtoCalls==before)
assert(PowerConsumer.getMaxPtoRpm(vehicle)==540)
assert(maxPtoCalls==before+1)

-- AI retains automatic PTO management. It sees the selected physical PTO
-- ratio in the required-RPM calculation and the native PowerConsumer value in
-- VehicleMotor.update.
aiActive=true
vehicle._ptoState.handThrottleRpm=1800
minRpm,maxRpm=VehicleMotor.getRequiredMotorRpmRange(motor)
assert(math.abs(minRpm-(540*2.2))<0.000001)
assert(maxRpm==2200)
observed=VehicleMotor.update(motor,16)
assert(observed==540)

-- Without a native RE PTO state every path is base-game behavior.
aiActive=false
vehicle._ptoState=nil
assert(math.abs(VehicleMotor.getPtoMotorRpmRatio(motor)-4.0)<0.000001)
minRpm,maxRpm=VehicleMotor.getRequiredMotorRpmRange(motor)
assert(minRpm==2160)
assert(maxRpm==2200)
observed=VehicleMotor.update(motor,16)
assert(observed==540)

assert(P.stats.ratioOverrides>=1)
assert(P.stats.rpmRangeOverrides>=1) -- AI selected-ratio automatic path.
assert(P.stats.manualRangeOverrides>=2)
assert(P.stats.motorUpdateScopes>=1)
assert(P.stats.maxPtoRpmSuppressions>=1)
assert(P.stats.aiBypasses>=1)

print("pto_physics_harness: OK")
