dofile("scripts/terrain/TerrainGeometryJournal.lua")
dofile("scripts/terrain/TerrainAbsoluteHeightPlanner.lua")
dofile("scripts/terrain/TerrainQuantizedHeightBudget.lua")
dofile("scripts/terrain/TerrainAbsoluteVertexCandidate.lua")
dofile("scripts/terrain/TerrainMainPatchReconciliation.lua")
local J=RealismExtensionsTerrainGeometryJournal
local P=RealismExtensionsTerrainAbsoluteHeightPlanner
local B=RealismExtensionsTerrainQuantizedHeightBudget
local D=RealismExtensionsTerrainAbsoluteVertexCandidate
local R=RealismExtensionsTerrainMainPatchReconciliation
local q=255/65535
local heights={}
local function key(x,z)return tostring(x)..":"..tostring(z) end
local function sample(x,z)return heights[key(x,z)] or 36000*q end
local function fresh()
    heights={}
    local j=J.new(999,{unitM=1,sample=sample})
    local b=assert(B.new({quantumM=q}))
    local p=assert(P.new({unitM=1}))
    function p:projectMain(x,z)
        return {researchTargetM=x==0 and z==0 and 2*q or nil,
            broadModeledCoverage01=1,inspectedMembers=1}
    end
    return p,j,b
end
local p,j,b=fresh()
local a=assert(R.capture(p,j,0,0,1,q,0.02,b))
assert(a.state=="FRESH_RESEARCH_ANCHOR" and #a.points==25)
local n=assert(R.previewNext(a,j,b))
assert(n.remainingSteps==2 and n.nextStep.key=="0:0")
assert(j.observationCount==0 and next(b.entries)==nil)
local candidate=assert(D.new({journal=j,budget=b,explicitWrite=true,
    verifyExclusive=function()return true end,
    writeHeight=function(x,z,target)
        heights[key(x,z)]=math.floor(target/q+0.5)*q
    end}))
assert(candidate:applyOne(0,0,n.nextStep.cumulativeTargetM,"CUMULATIVE").verified)
n=assert(R.previewNext(a,j,b))
assert(n.paidSteps==1 and n.remainingSteps==1)
-- A new projection cannot silently adopt that paid depth.
local owned=assert(R.capture(p,j,0,0,1,q,0.02,b))
assert(owned.state=="REFERENCE_BLOCKED" and owned.ownedCount==1)
assert(R.previewNext(owned,j,b)==nil)
assert(j.observations["0:0"].owned==true)
-- Actual readback with slightly greater quantum may withhold final step.
if n.nextStep then
    assert(candidate:applyOne(0,0,n.nextStep.cumulativeTargetM,"CUMULATIVE").verified)
    assert(R.previewNext(a,j,b).state=="TARGET_OBSERVED")
else assert(n.state=="NO_ADMISSIBLE_NEXT_STEP") end
-- A changed outer halo blocks the entire next preview.
heights["2:2"]=sample(2,2)-q
assert(R.previewNext(a,j,b)==nil)
p,j,b=fresh()
a=assert(R.capture(p,j,0,0,1,q,0.02,b))
heights["0:0"]=sample(0,0)-q
assert(R.previewNext(a,j,b)==nil)
p,j,b=fresh()
j.recoveryFences["2:2"]={trusted=true,accounted=true}
assert(R.capture(p,j,0,0,1,q,0.02,b).state=="REFERENCE_BLOCKED")
p,j,b=fresh()
b.entries["0:0"]={mode="TARGET",committedM=q}
assert(R.capture(p,j,0,0,1,q,0.02,b).state=="REFERENCE_BLOCKED")
p,j,b=fresh()
a=assert(R.capture(p,j,0,0,1,q,0.02,b))
j.pendingCount=1
assert(R.previewNext(a,j,b)==nil)
p,j,b=fresh()
heights["0:0"]=sample(0,0)-0.13
a=assert(R.capture(p,j,0,0,1,q,0.02,b))
assert(R.previewNext(a,j,b).state=="NO_ADMISSIBLE_NEXT_STEP")
print("terrain_main_patch_reconciliation_harness: OK")
