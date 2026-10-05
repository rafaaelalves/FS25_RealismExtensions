RealismExtensionsPTO={
    getVehicleState=function(vehicle)
        return vehicle._ptoState
    end
}
g_modIsLoaded={}

local vehicle={}
local motor={
    vehicle=vehicle,
    ptoMotorRpmRatio=4.0
}
vehicle.getMotor=function() return motor end
vehicle._ptoState={
    enabled=true,
    hasPtoOutput=true,
    effectiveMotorRatio=2.2,
    handThrottleRpm=1600
}

VehicleMotor={}
function VehicleMotor.getPtoMotorRpmRatio(self)
    return self.ptoMotorRpmRatio
end
function VehicleMotor.getRequiredMotorRpmRange(self)
    -- Model the important GIANTS property: this native path reads the raw
    -- ptoMotorRpmRatio field, not getPtoMotorRpmRatio().
    return 540*self.ptoMotorRpmRatio,2200
end

dofile("scripts/pto/PTOPhysics.lua")
local P=RealismExtensionsPTOPhysics

local ok,reason=P.install()
assert(ok==true,reason)

-- Getter exposes selected physical gearbox ratio without mutating the field.
assert(math.abs(VehicleMotor.getPtoMotorRpmRatio(motor)-2.2)<0.000001)
assert(math.abs(motor.ptoMotorRpmRatio-4.0)<0.000001)

-- Native required-range calculation temporarily sees 2.2, then hand throttle
-- floors it to 1600. Raw motor state is restored immediately.
local minRpm,maxRpm=VehicleMotor.getRequiredMotorRpmRange(motor)
assert(minRpm==1600)
assert(maxRpm==2200)
assert(math.abs(motor.ptoMotorRpmRatio-4.0)<0.000001)

vehicle._ptoState.handThrottleRpm=0
minRpm,maxRpm=VehicleMotor.getRequiredMotorRpmRange(motor)
assert(math.abs(minRpm-(540*2.2))<0.000001)
assert(math.abs(motor.ptoMotorRpmRatio-4.0)<0.000001)

vehicle._ptoState=nil
assert(math.abs(VehicleMotor.getPtoMotorRpmRatio(motor)-4.0)<0.000001)
minRpm,maxRpm=VehicleMotor.getRequiredMotorRpmRange(motor)
assert(minRpm==2160)
assert(maxRpm==2200)

assert(P.stats.ratioOverrides>=1)
assert(P.stats.rpmRangeOverrides>=1)

print("pto_physics_harness: OK")
