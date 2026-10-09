dofile("scripts/pto/PTOModel.lua")
local M=RealismExtensionsPTOModel

assert(M.normalizeMode("540")==M.MODE.RPM_540)
assert(M.normalizeMode("540E")==M.MODE.RPM_540_ECO)
assert(M.normalizeMode("1000")==M.MODE.RPM_1000)
assert(M.normalizeMode("1000E")==M.MODE.RPM_1000_ECO)
assert(M.getShaftRpm(M.MODE.RPM_540_ECO)==540)
assert(M.getShaftRpm(M.MODE.RPM_1000_ECO)==1000)
assert(M.isEconomy(M.MODE.RPM_540_ECO)==true)
assert(M.sameFamily(M.MODE.RPM_540,M.MODE.RPM_540_ECO)==true)
assert(M.sameFamily(M.MODE.RPM_540,M.MODE.RPM_1000)==false)

local available={
    [M.MODE.RPM_540]={},
    [M.MODE.RPM_1000]={}
}
assert(M.stepAvailableMode(M.MODE.RPM_540,available,1)==M.MODE.RPM_1000)
assert(M.stepAvailableMode(M.MODE.RPM_1000,available,1)==M.MODE.RPM_540)
assert(M.stepAvailableMode(M.MODE.RPM_540,available,-1)==M.MODE.RPM_1000)

assert(math.abs(M.resolveMotorRatio(
    M.MODE.RPM_540,
    {modes={[M.MODE.RPM_540]={}}},
    4.0,
    2200
)-4.0)<0.000001)

local profile={
    modes={
        [M.MODE.RPM_1000]={engineRpm=2000},
        [M.MODE.RPM_540_ECO]={engineRpm=1600}
    }
}
assert(math.abs(M.resolveMotorRatio(
    M.MODE.RPM_1000,profile,4.0,2200
)-2.0)<0.000001)
assert(math.abs(M.resolveMotorRatio(
    M.MODE.RPM_540_ECO,profile,4.0,2200
)-(1600/540))<0.000001)

assert(M.handThrottleRpm(0,800,2200)==0)
assert(math.abs(M.handThrottleRpm(0.5,800,2200)-1500)<0.000001)
assert(math.abs(M.handThrottlePercentForRpm(1500,800,2200)-0.5)<0.000001)
assert(M.handThrottlePercentForRpm(0,800,2200)==0)

-- Released hand throttle captures the live engine neighbourhood on first +.
assert(M.stepHandThrottleRpm(0,1,800,2200,845,100)==900)
assert(M.stepHandThrottleRpm(900,1,800,2200,845,100)==1000)
assert(M.stepHandThrottleRpm(1000,-1,800,2200,845,100)==900)
assert(M.stepHandThrottleRpm(900,-1,800,2200,845,100)==0)
assert(M.stepHandThrottleRpm(2200,1,800,2200,845,100)==2200)

assert(M.clampThrottle(-1)==0)
assert(M.clampThrottle(2)==1)

-- Numeric PTO family matching may not disguise unsupported physical shaft
-- speeds as 540/1000; 540E and 1000E still differ by engine gearing only.
assert(M.modeForFamily(540,false)==M.MODE.RPM_540)
assert(M.modeForFamily(540,true)==M.MODE.RPM_540_ECO)
assert(M.modeForFamily(1000,false)==M.MODE.RPM_1000)
assert(M.modeForFamily(1000,true)==M.MODE.RPM_1000_ECO)
for _,rpm in ipairs({0,500,750,900,1300,1400,2000}) do
    assert(M.modeForFamily(rpm,false)==nil)
    assert(M.modeForFamily(rpm,true)==nil)
end

print("pto_model_harness: OK")
