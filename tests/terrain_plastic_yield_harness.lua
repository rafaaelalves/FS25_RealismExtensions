-- Pure bearing-vs-demand test; no GIANTS state, no new compaction owner.
dofile("scripts/terrain/TerrainPlasticYield.lua")
dofile("scripts/terrain/TerrainResponseModel.lua")
local Y=RealismExtensionsTerrainPlasticYield
local M=RealismExtensionsTerrainResponseModel
local function copy(t)
    local o={}
    for k,v in pairs(t) do o[k]=v end
    return o
end
local function approx(a,b,eps)
    assert(math.abs(a-b)<=(eps or 0.00001), tostring(a).." != "..tostring(b))
end
local footprint={
    available=true,
    supportWidthM=0.55,
    footprintLengthM=0.40,
    structuralRadiusM=0.75,
    groundPressurePa=110000
}
local ordinary={
    grounded=true,
    physicalGroundWetness=0.35,
    structuralRadiusM=0.75,
    speedKph=12,
    wheelSurfaceSpeedMps=3.7,
    longitudinalSlip=0.05,
    lateralSlip=0.01,
    sinkDepthM=0.02,
    groundMudPotential=0.60
}
local opt={
    plasticYieldEnabled=true,
    surfaceCategory="FIELD_SOFT",
    absoluteMaxStaticRutDepthM=0.08,
    absoluteMaxSlipRutDepthM=0.18
}
local normal=Y.compute(ordinary,footprint,{category=opt.surfaceCategory})
assert(normal.available and normal.reason=="SUPPORTED")
assert(normal.plasticYield01==0 and normal.contactDemandPa==110000)
assert(normal.estimatedBearingPa>normal.contactDemandPa)
local response=M.compute(ordinary,footprint,nil,250,opt)
assert(response.available and response.plasticYield01==0)
assert(response.rutDepthM==0 and response.rutDepthDeltaM==0)
assert(response.deformationExposure==0)
assert(response.nextHistory.longitudinalShearDistanceM==0)
assert(response.nextHistory.slipExcavationDistanceM==0)
assert(response.persistentSinkDepthM==0)
-- Repeated normal dry seeder visits cannot accumulate *latent* plastic debt.
local history=nil
for _=1,120 do
    local r=M.compute(ordinary,footprint,history,250,opt)
    history=r.nextHistory
end
assert(history.deformationExposure==0 and history.rutDepthM==0)
assert(history.longitudinalShearDistanceM==0)
-- A field can contain legacy rut *exposure* from earlier wet operation.
-- Merely checking a dry contact must not turn that stale exposure into
-- newly visible terrain damage when pressure is below bearing capacity.
local historicNoRut={
    rutDepthM=0, deformationExposure=9.0,
    longitudinalShearDistanceM=0.5,
    slipExcavationDistanceM=0.5
}
local dryWithOldExposure=M.compute(ordinary,footprint,historicNoRut,250,opt)
assert(dryWithOldExposure.rutDepthM==0)
assert(dryWithOldExposure.rutDepthDeltaM==0)
-- It is still a valid contact for Mud and SoilCompaction, neither runs here.

local wet=copy(ordinary)
wet.physicalGroundWetness=0.95
wet.longitudinalSlip=0.55
wet.sinkDepthM=0.14
local yielding=Y.compute(wet,footprint,{category="FIELD_SOFT"})
assert(yielding.plasticYield01>0.8, yielding.plasticYield01)
local wetResult=M.compute(wet,footprint,history,250,opt)
assert(wetResult.rutDepthM>0 and wetResult.plasticYield01>0.8)
assert(wetResult.persistentSinkDepthM>0)
assert(wetResult.rutDepthM<=0.18+1e-7)
-- An already formed rut must not be "healed" just by checking dry conditions.
local existing={rutDepthM=0.008,deformationExposure=0.07}
local dryAfter=M.compute(ordinary,footprint,existing,100,opt)
assert(dryAfter.rutDepthDeltaM==0)
assert(dryAfter.nextHistory.rutDepthM>=existing.rutDepthM-1e-7)

local heavy=copy(footprint)
heavy.groundPressurePa=550000
local heavyDry=copy(ordinary)
heavyDry.longitudinalSlip=0.75
local extreme=Y.compute(heavyDry,heavy,{category="FIELD_SOFT"})
assert(extreme.plasticYield01>0)
assert(M.compute(heavyDry,heavy,nil,250,opt).rutDepthM>0)
-- Extra normal-load traffic must not rut the recently seeded surface,
-- without adding an arbitrary "seeder immune" exemption.
local plantedOpt=copy(opt)
plantedOpt.surfaceCategory="FIELD_FIRM"
local planted=M.compute(ordinary,footprint,nil,250,plantedOpt)
assert(planted.plasticYield01==0 and planted.rutDepthM==0)

-- Soil naturally changes regime across wetness/pressure, not by machine name.
local damp=copy(ordinary)
damp.physicalGroundWetness=0.67
local lightDamp=Y.compute(damp,footprint,{category="FIELD_SOFT"})
local overloaded=Y.compute(damp,heavy,{category="FIELD_SOFT"})
assert(lightDamp.plasticYield01==0)
assert(overloaded.plasticYield01>lightDamp.plasticYield01)
local frozen=copy(wet)
frozen.hardFrozen=true
assert(Y.compute(frozen,footprint,{category="FIELD_SOFT"}).plasticYield01==0)

-- Control: setting false reverts to the EXACT legacy R6 response path.
local legacy=M.compute(ordinary,footprint,nil,250,{plasticYieldEnabled=false})
local previous=M.compute(ordinary,footprint,nil,250,{})
approx(legacy.rutDepthM,previous.rutDepthM)
assert(legacy.rutDepthM>response.rutDepthM)
assert(legacy.plasticYield01==nil and previous.plasticYield01==nil)

-- Physical-distance/time subdivision should preserve plastic deformation.
local function traverse(speedKph,stepMs,meters)
    local w=copy(wet)
    w.sinkDepthM=0
    w.speedKph=speedKph
    w.wheelSurfaceSpeedMps=speedKph/3.6*1.55
    local rem=meters
    local h=nil
    local last=nil
    while rem>0.00000001 do
        local dm=math.min(rem,speedKph/3.6*stepMs/1000)
        last=M.compute(w,footprint,h,dm/(speedKph/3.6)*1000,opt)
        h=last.nextHistory
        rem=rem-dm
    end
    return last
end
local slow=traverse(3,250,2)
local fast=traverse(12,50,2)
approx(slow.rutDepthM,fast.rutDepthM,0.0005)

-- A malformed contract never authorizes persistent terrain writes.
local invalid=Y.compute(ordinary,{groundPressurePa=0},{category="FIELD"})
assert(not invalid.available)
local invalidResponse=M.compute(ordinary,{available=true,supportWidthM=0.5,
    structuralRadiusM=0.75,groundPressurePa=0},nil,250,opt)
assert(not invalidResponse.available)
print("terrain_plastic_yield_harness: OK")
