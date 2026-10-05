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

local chipper={
    configFileName="/mods/hm10500KF.xml",
    spec_powerConsumer={ptoRpm=540},
    spec_powerTakeOffs={inputPowerTakeOffs={{}}}
}
local mower={
    configFileName="/mods/mower.xml",
    spec_powerConsumer={ptoRpm=540},
    spec_powerTakeOffs={inputPowerTakeOffs={{}}}
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

fiat.getIsPowerTakeOffActive=function() return true end
assert(R.isPtoEngaged(fiat)==true)
fiat.getIsPowerTakeOffActive=function() return false end
assert(R.isPtoEngaged(fiat)==false)

print("pto_resolver_harness: OK")
