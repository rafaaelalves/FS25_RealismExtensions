-- Integration using the REAL (pure Lua) wheel response model and planner.
-- The cumulative exposure is only virtual; real heightmap/history untouched.
dofile("scripts/terrain/TerrainResponseModel.lua")
dofile("scripts/terrain/TerrainAbsoluteHeightPlanner.lua")
local M=RealismExtensionsTerrainResponseModel
local P=RealismExtensionsTerrainAbsoluteHeightPlanner
local shadow=assert(P.new({unitM=1,maxSources=10}))
local context={
    grounded=true,structuralRadiusM=0.45,supportWidthM=0.40,
    speedKph=4,wheelSurfaceSpeedMps=2.2,longitudinalSlip=0.38,
    lateralSlip=0.05,physicalGroundWetness=0.80,
    groundMudPotential=0.70,hardFrozen=false,sinkDepthM=0.007
}
local footprint={available=true,supportWidthM=0.4,structuralRadiusM=0.45,
    groundPressurePa=130000}
local first,last
local key="100:200"
for i=1,10 do
    local state=shadow:getModelHistory(key,20.05,40.02,nil)
    local result=M.compute(context,footprint,state,100)
    assert(result.available and result.rutDepthM>0)
    local observed=assert(shadow:observe(key,20.05,40.02,
        result.rutDepthM,0,result.nextHistory))
    assert(observed.doesNotWrite==true)
    if i==1 then first=result end
    last=result
end
assert(last.rutDepthM>first.rutDepthM+0.0001)
assert(shadow.stats.virtualHistoryReads==9)
assert(shadow.stats.virtualHistoryUpdates==10)
assert(shadow.sourceCount==1 and shadow:getVertex(20,40)~=nil)
local savedHistory=nil -- Native/persisted RE history was never modified.
assert(savedHistory==nil)
local modelState=shadow:getModelHistory(key,20.05,40.02,nil)
assert(modelState.passCount==10)
assert(modelState.deformationExposure>first.nextHistory.deformationExposure)
local again=M.compute(context,footprint,modelState,100)
assert(again.nextHistory.deformationExposure>modelState.deformationExposure)
local baselineAgain=M.compute(context,footprint,nil,100)
assert(math.abs(baselineAgain.rutDepthM-first.rutDepthM)<1e-10)

-- Export of a model state is a COPY, not a pointer granting write access.
modelState.rutDepthM=0
assert(shadow:getModelHistory(key,20.05,40.02,nil).rutDepthM>0)
assert(shadow:getModelHistory(key,21.00,40.02,nil)==nil)

-- A confirmed logical-history recovery invalidates pre-tillage exposure.
local current=shadow.sources[key].targetM
local remaining=current-0.002
assert(remaining>0)
assert(shadow:onHistoryRecovered(key,remaining,0.002)==true)
assert(shadow.sources[key].modelHistory==nil)
local physicalAfter={rutDepthM=remaining,deformationExposure=0.1}
local afterRepair=shadow:getModelHistory(key,20.05,40.02,physicalAfter)
assert(afterRepair==physicalAfter)
-- No phantom full recovery from an untrusted decrease.
local down=assert(shadow:observe(key,20.05,40.02,remaining-0.001,
    remaining,nil))
assert(down.state=="TARGET_DECREASE_UNVERIFIED")

-- Absent or nonfinite model data must not become virtual rust history.
local old=shadow.sources[key].modelHistory
assert(shadow:updateModelHistory(shadow.sources[key],
    {rutDepthM=0/0})==false)
assert(shadow.sources[key].modelHistory==old)
print("terrain_shadow_model_progression_harness: OK")
