-- Mock-only: a protected single-vertex absolute-height prototype.
-- NOT evidence that GIANTS live height writes, collision or save sync work.
dofile("scripts/terrain/TerrainGeometryJournal.lua")
dofile("scripts/terrain/TerrainQuantizedHeightBudget.lua")
dofile("scripts/terrain/TerrainAbsoluteVertexCandidate.lua")
dofile("scripts/terrain/TerrainAbsoluteHeightExperimentalBackend.lua")
local B=RealismExtensionsTerrainAbsoluteHeightExperimentalBackend
local J=RealismExtensionsTerrainGeometryJournal
local q=255/65535
local h={}
local function key(x,z)return tostring(x)..":"..tostring(z)end
local base=36000*q
local function read(x,z)return h[key(x,z)] or base end
local journal=J.new(999,{unitM=1,sample=read})
local writer={nativeCausalPending=false,getQueueSize=function()return 0 end}
local runtime={geometryJournal=journal,nativeDamageQuarantined=false}
g_server={}
g_currentMission={missionInfo={isMultiplayer=false},
    missionDynamicInfo={isMultiplayer=false}}
assert(B.new({})==nil)
assert(B.new({explicitResearchPermission=true,
    disposableSaveConfirmed=true,quantumM=q,
    journal=journal,writer=writer,runtime=runtime})==nil)

local calls=0
local function set(x,z,target)
    calls=calls+1
    h[key(x,z)]=math.floor(target/q+0.5)*q
end
local opts={
    explicitResearchPermission=true,disposableSaveConfirmed=true,
    quantumVerified=true,quantumM=q,toleranceM=0.00005,
    journal=journal,writer=writer,runtime=runtime,
    nativeSetter=set
}
local adapter=assert(B.new(opts))
local res,reason=adapter:applyOnce(20,30,q)
assert(res~=nil and res.verified==true and reason==nil)
assert(calls==1 and adapter.consumed==true)
assert(adapter.confirmed==1 and runtime.nativeDamageQuarantined==false)
assert(math.abs(read(20,30)-(base-q))<0.00005)
assert(journal.pendingCount==0)
assert(journal.observations["20:30"].owned==false)
assert(adapter:applyOnce(20,30,q)==nil)
assert(calls==1)

-- Adapter checks idle writer, not just native setter availability.
local journal2=J.new(999,{unitM=1,sample=read})
local runtime2={geometryJournal=journal2,nativeDamageQuarantined=false}
local busy={nativeCausalPending=true,getQueueSize=function()return 0 end}
opts.journal=journal2;opts.runtime=runtime2;opts.writer=busy
local blocked=assert(B.new(opts))
assert(blocked:applyOnce(40,40,q)==nil)
assert(blocked.consumed==false and calls==1)
busy.nativeCausalPending=false
g_currentMission.missionDynamicInfo.isMultiplayer=true
assert(blocked:applyOnce(40,40,q)==nil)
g_currentMission.missionDynamicInfo.isMultiplayer=false
-- Fail false return as unusable even if no Lua error.
opts.nativeSetter=function()calls=calls+1;return false end
local fails=assert(B.new(opts))
local outcome,why=fails:applyOnce(50,50,q)
assert(outcome~=nil and outcome.verified==false)
assert(runtime2.nativeDamageQuarantined==true)
assert(fails.quarantined==true and journal2.pendingCount==0)
assert(journal2.observations["50:50"]~=nil)
assert(journal2.observations["50:50"].owned==false)

-- Confirm documented five-argument GIANTS binding is not guessed from
-- a four-argument wrapper. This is an injected mock, not a native call.
local original=setTerrainHeightAtWorldPos
local args
setTerrainHeightAtWorldPos=function(...)
    args={...}
end
local setter=assert(B.makeNativeSetter(999))
setter(1,2,3)
assert(#args==5 and args[1]==999 and args[2]==1
    and args[3]==0 and args[4]==2 and args[5]==3)
setTerrainHeightAtWorldPos=original
print("terrain_absolute_height_experimental_backend_harness: OK")
