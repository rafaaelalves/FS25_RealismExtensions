dofile("scripts/pto/PTOModel.lua")
dofile("scripts/pto/PTOProfiles.lua")
dofile("scripts/pto/PTOResolver.lua")

local M=RealismExtensionsPTOModel
local R=RealismExtensionsPTOResolver

local motor={
    minRpm=800,
    maxRpm=2200,
    getPtoMotorRpmRatio=function() return 4.0 end
}

local fiat={
    configFileName="/mods/fiat18090.xml",
    getName=function() return "Fiat 180-90 DT" end,
    getMotor=function() return motor end,
    getOutputPowerTakeOffs=function() return {rear={}} end,
    getAttachedImplements=function() return {} end
}

assert(R.vehicleHasOutputPto(fiat)==true)
local cap=R.resolveCapability(fiat)
assert(cap.source=="PROFILE")
assert(cap.modes[M.MODE.RPM_540]~=nil)
assert(cap.modes[M.MODE.RPM_1000]~=nil)
assert(cap.modes[M.MODE.RPM_540_ECO]==nil)

local johnDeere={
    configFileName="data/vehicles/johnDeere/series6R/series6RLarge.xml",
    getName=function() return "6R 155" end,
    getMotor=function() return motor end,
    getOutputPowerTakeOffs=function() return {rear={}} end,
    getAttachedImplements=function() return {} end
}
local jdCap=R.resolveCapability(johnDeere)
assert(jdCap.source=="PROFILE")
assert(jdCap.profileId=="john_deere_6r_155")
assert(jdCap.modes[M.MODE.RPM_540]~=nil)
assert(jdCap.modes[M.MODE.RPM_540_ECO]~=nil)
assert(jdCap.modes[M.MODE.RPM_1000]~=nil)
assert(jdCap.modes[M.MODE.RPM_1000_ECO]==nil)
assert(math.abs(
    jdCap.modes[M.MODE.RPM_540].effectiveMotorRatio-(1987/540)
)<0.000001)
assert(math.abs(
    jdCap.modes[M.MODE.RPM_540_ECO].effectiveMotorRatio-(1753/540)
)<0.000001)
assert(math.abs(
    jdCap.modes[M.MODE.RPM_1000].effectiveMotorRatio-2.0
)<0.000001)

local unknown={
    configFileName="/mods/unknownTractor.xml",
    getMotor=function() return motor end,
    getOutputPowerTakeOffs=function() return {rear={}} end,
    getAttachedImplements=function() return {} end
}
local fallback=R.resolveCapability(unknown)
assert(fallback.source=="NATIVE_FALLBACK")
assert(fallback.modes[M.MODE.RPM_540]~=nil)
assert(fallback.modes[M.MODE.RPM_1000]==nil)
assert(math.abs(fallback.modes[M.MODE.RPM_540].effectiveMotorRatio-4.0)<0.000001)

local chipperActive=false
local chipper={
    configFileName="/mods/hm10500KF.xml",
    spec_powerConsumer={ptoRpm=540},
    spec_powerTakeOffs={inputPowerTakeOffs={{}}},
    getIsPowerTakeOffActive=function() return chipperActive end,
    getIsTurnedOn=function() return chipperActive end,
    getAttachedImplements=function() return {} end
}
local mowerActive=false
local mower={
    configFileName="/mods/mower.xml",
    spec_powerConsumer={ptoRpm=540},
    spec_powerTakeOffs={inputPowerTakeOffs={{}}},
    getIsPowerTakeOffActive=function() return mowerActive end,
    getIsTurnedOn=function() return mowerActive end,
    getAttachedImplements=function() return {} end
}

fiat.getAttachedImplements=function()
    return {{object=chipper}}
end
local req=R.collectRequirements(fiat)
assert(req.hasPtoConsumer==true)
assert(req.requiredRpm==1000)
assert(req.conflict==false)
assert(req.primary.source=="PROFILE")

fiat.getAttachedImplements=function()
    return {{object=chipper},{object=mower}}
end
req=R.collectRequirements(fiat)
assert(req.conflict==true)
assert(req.requiredRpm==nil)

-- Tractor PowerTakeOffs itself reports false; active state lives on the
-- attached PTO-consuming implement specialization.
fiat.getIsPowerTakeOffActive=function() return false end
fiat.getAttachedImplements=function()
    return {{object=chipper}}
end
local engaged,source=R.isPtoEngaged(fiat)
assert(engaged==false)
assert(source=="NO_ACTIVE_CONSUMER")

chipperActive=true
engaged,source=R.isPtoEngaged(fiat)
assert(engaged==true)
assert(source=="IMPLEMENT_PTO_ACTIVE")

-- Fallback: a modded PTO consumer can expose only TurnOnVehicle state.
chipper.getIsPowerTakeOffActive=nil
engaged,source=R.isPtoEngaged(fiat)
assert(engaged==true)
assert(source=="IMPLEMENT_TURNED_ON")

chipperActive=false
engaged,source=R.isPtoEngaged(fiat)
assert(engaged==false)
assert(source=="NO_ACTIVE_CONSUMER")

print("pto_resolver_harness: OK")
