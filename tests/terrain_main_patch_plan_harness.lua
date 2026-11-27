-- Pure no-write patch geometry. No native API or career budget authority.
dofile("scripts/terrain/TerrainMainFootprintGate.lua")
dofile("scripts/terrain/TerrainAbsoluteHeightPlanner.lua")
local P=RealismExtensionsTerrainAbsoluteHeightPlanner
local q=255/65535
local gradient=0.02
local function fixture(caps)
    local p=assert(P.new({unitM=1}))
    function p:projectMain(x,z)
        local cap=caps[tostring(x)..":"..tostring(z)]
        return {researchTargetM=cap,broadModeledCoverage01=cap and 1 or 0,
            inspectedMembers=1}
    end
    return p
end
local function lookup(plan,x,z)
    for _,p in ipairs(plan.points) do
        if p.ix==x and p.iz==z then return p end
    end
end
-- A high isolated center cannot be made smoother by digging its neighbors.
local p=fixture({["0:0"]=0.10})
local plan=assert(p:planMainPatch(0,0,2,q,gradient))
assert(plan.wholeSteps==5 and plan.candidateVertices==1)
assert(plan.center.targetDepthM==5*q and plan.maxAddedGradient<=gradient)
assert(lookup(plan,1,0).targetDepthM==0)
assert(plan.authorizesMainWrite==false and plan.doesNotWrite)
assert(plan.slopeWithheldM>0 and plan.quantizationWithheldM>=0)
-- Full broad 5x5 patch with fixed zero halo: center deeper than boundary.
local caps={}
for x=-2,2 do for z=-2,2 do caps[x..":"..z]=0.10 end end
p=fixture(caps)
plan=assert(p:planMainPatch(0,0,2,q,gradient))
assert(plan.candidateVertices==25 and plan.center.steps==15)
assert(lookup(plan,2,0).steps==5 and lookup(plan,1,0).steps==10)
assert(lookup(plan,-2,-2).steps==5)
assert(plan.maxAddedGradient<=gradient and plan.sweeps<=26)
-- Low center forces a compatible profile around it; no invented volume.
caps["0:0"]=q*0.99
plan=assert(p:planMainPatch(0,0,2,q,gradient))
assert(plan.center.steps==0)
assert(lookup(plan,1,0).steps==5)
assert(lookup(plan,1,1).steps==7)
for _,v in ipairs(plan.points) do
    assert(v.targetDepthM<=v.rawTargetM and v.withheldM>=0)
end
-- Gradient below one quantum on an axial edge: conservative zero patch.
plan=assert(p:planMainPatch(0,0,2,q,q/2))
assert(plan.wholeSteps==0)
assert(p:planMainPatch(0,0,4,q,gradient)==nil)
assert(p:planMainPatch(0,0,2,0/0,gradient)==nil)
assert(p:planMainPatch(0,0,2,q,0)==nil)
-- Exact no-up-rounding, including just below one quantum.
plan=assert(fixture({["0:0"]=q-1e-10}):planMainPatch(0,0,1,q,gradient))
assert(plan.wholeSteps==0)
plan=assert(fixture({["0:0"]=q}):planMainPatch(0,0,1,q,gradient))
assert(plan.wholeSteps==1)
-- Real projection integration: full 25 cells, 20mm target, five q steps.
local real=assert(P.new({unitM=1,logicalCellSizeM=0.2}))
local wide={available=true,supportWidthM=2,footprintLengthM=2,
    dirX=1,dirZ=0,pathContinuity=true}
for x=-2,2 do
    for z=-2,2 do
        assert(real:observe(x..":"..z,x*0.2,z*0.2,0.02,0,nil,wide))
    end
end
plan=assert(real:planMainPatch(0,0,2,q,gradient))
assert(plan.center.steps==5 and plan.candidateVertices==1)
assert(real.sourceCount==25 and math.abs(real:getVertex(0,0).demandM-0.02)<1e-9)
local again=assert(real:planMainPatch(0,0,2,q,gradient))
assert(again.wholeSteps==plan.wholeSteps and again.plannedDepthSumM==plan.plannedDepthSumM)
-- Refusal of partial/invalid projections.
local bad=fixture({})
function bad:projectMain() return nil,"PROJECTION_MEMBER_LIMIT" end
assert(select(2,bad:planMainPatch(0,0,2,q,gradient))=="PROJECTION_MEMBER_LIMIT")
print("terrain_main_patch_plan_harness: OK")
