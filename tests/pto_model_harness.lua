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
assert(M.clampThrottle(-1)==0)
assert(M.clampThrottle(2)==1)

print("pto_model_harness: OK")
