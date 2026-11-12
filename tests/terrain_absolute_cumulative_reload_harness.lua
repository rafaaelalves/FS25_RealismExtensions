-- Two adjacent MAIN vertices, multiple authorized q steps and a
-- fresh mission journal/quantizer. Pure Lua only: NO FS25 engine writes.
-- Main release invariant: saved RE-owned height must seed the next ledger;
-- a restarted game must NOT excavate the same cumulative target twice.
dofile("scripts/terrain/TerrainGeometryJournal.lua")
dofile("scripts/terrain/TerrainQuantizedHeightBudget.lua")
dofile("scripts/terrain/TerrainAbsoluteVertexCandidate.lua")
local J=RealismExtensionsTerrainGeometryJournal
local B=RealismExtensionsTerrainQuantizedHeightBudget
local C=RealismExtensionsTerrainAbsoluteVertexCandidate
local q=255/65535
local base=36000*q
local heights={}
local function key(x,z)return tostring(x)..":"..tostring(z)end
local function read(x,z)
    local v=heights[key(x,z)]
    return v~=nil and v or base
end
local writerCalls=0
local function writeHeight(x,z,target)
    writerCalls=writerCalls+1
    heights[key(x,z)]=math.floor(target/q+0.5)*q
    return true
end
local function makeCandidate(journal)
    local budget=assert(B.new({quantumM=q,maxDebtM=0.10}))
    local candidate=assert(C.new({
        budget=budget,journal=journal,explicitWrite=true,
        verifyExclusive=function()return true end,
        writeHeight=writeHeight
    }))
    return candidate,budget
end
local j=J.new(999,{unitM=1,sample=read})
local candidate,budget=makeCandidate(j)
local first=assert(candidate:applyOne(10,10,q,"CUMULATIVE"))
assert(first.verified and writerCalls==1)
assert(math.abs(read(10,10)-(base-q))<0.000001)
assert(j.observations["10:10"].owned==true)
local again,why=candidate:applyOne(10,10,q,"CUMULATIVE")
assert(again==nil and why=="SUB_QUANTUM_DEBT" and writerCalls==1)
local neighbor=assert(candidate:applyOne(11,10,q,"CUMULATIVE"))
assert(neighbor.verified and writerCalls==2)
assert(j.observations["11:10"].owned==true)
assert(math.abs(read(10,10)-read(11,10))<1e-9)
local second=assert(candidate:applyOne(10,10,2*q,"CUMULATIVE"))
assert(second.verified and writerCalls==3)
assert(math.abs(read(10,10)-(base-2*q))<1e-7)
assert(math.abs(read(11,10)-(base-q))<1e-7)
assert(candidate:applyOne(10,10,2*q,"CUMULATIVE")==nil)
assert(writerCalls==3)
assert(math.abs(budget.entries["10:10"].committedM-2*q)<1e-8)
local snapshot=assert(j:exportSnapshot())
assert(#snapshot.cells>=2)
local postSaveHeights={at10=read(10,10),at11=read(11,10)}

-- A game restart has a new quantizer, but its MAIN geometry and the
-- validated v2 ownership sidecar survive. Seed committedM physically,
-- not from the replayed wheel target, to prevent duplicate digging.
local loaded=J.new(999,{unitM=1,sample=read})
local imported,n,bad=loaded:importSnapshot(snapshot)
assert(imported and n>=2 and bad==0)
assert(loaded.observations["10:10"].owned==true)
assert(loaded.observations["11:10"].owned==true)
local afterReload,rebootBudget=makeCandidate(loaded)
local redundant,reason=afterReload:applyOne(10,10,2*q,"CUMULATIVE")
assert(redundant==nil and reason=="SUB_QUANTUM_DEBT")
assert(writerCalls==3)
assert(rebootBudget.entries["10:10"]~=nil)
assert(math.abs(rebootBudget.entries["10:10"].committedM-2*q)<1e-8)
assert(rebootBudget.stats.ownedTargetSeeds==1)
local neighborRepeat,neighborReason=
    afterReload:applyOne(11,10,q,"CUMULATIVE")
assert(neighborRepeat==nil and neighborReason=="SUB_QUANTUM_DEBT")
assert(writerCalls==3 and rebootBudget.stats.ownedTargetSeeds==2)
assert(math.abs(read(10,10)-postSaveHeights.at10)<1e-12)
assert(math.abs(read(11,10)-postSaveHeights.at11)<1e-12)

-- Genuine NEW demand measured from the immutable, original pre-RE
-- height may consume precisely ONE additional q on exactly its vertex.
local third=assert(afterReload:applyOne(10,10,3*q,"CUMULATIVE"))
assert(third.verified==true and writerCalls==4)
assert(math.abs(read(10,10)-(base-3*q))<1e-7)
assert(math.abs(read(11,10)-(base-q))<1e-7)
assert(loaded.observations["10:10"].owned==true)
assert(math.abs(loaded.observations["10:10"].preREHeightM-base)<1e-9)
assert(afterReload:applyOne(10,10,3*q,"CUMULATIVE")==nil)
assert(writerCalls==4)

-- Same-session foreign edits larger than the 10um provenance tolerance
-- must not be laundered into the committed cumulative budget.
heights[key(10,10)]=read(10,10)-0.00002
local rejected,rejectedWhy=
    afterReload:applyOne(10,10,4*q,"CUMULATIVE")
assert(rejected==nil and rejectedWhy=="EXTERNAL_EDIT")
assert(writerCalls==4)
assert(loaded.observations["10:10"].owned==false)
assert(loaded:getRecoverablePoint(10,10)==nil)

-- An old journal can be loaded as observational metadata with one
-- full q external geometry difference, but NEVER as an RE-owned rut.
local newRead=J.new(999,{unitM=1,sample=read})
local ok,retained,discarded=newRead:importSnapshot(snapshot)
assert(ok and retained>=2 and discarded==0)
assert(newRead.observations["10:10"].owned==false)
local newCandidate,newBudget=makeCandidate(newRead)
local oldRequest,oldWhy=newCandidate:applyOne(
    10,10,4*q,"CUMULATIVE")
assert(oldRequest==nil and oldWhy=="UNTRUSTED_EDIT")
assert(writerCalls==4)
assert(newBudget.entries["10:10"]==nil)

-- A forged or inconsistent in-process committed ledger cannot silently
-- bind a new physical epoch to an older cumulative model demand.
local forged=assert(B.new({quantumM=q}))
assert(forged:seedOwnedTarget("a",q))
assert(select(1,forged:seedOwnedTarget("a",q+0.00002))==false)
assert(forged.quarantined and forged.stats.ownerLedgerDrift==1)
assert(select(1,forged:requestTarget("a",3*q,0.1))==nil)
print("terrain_absolute_cumulative_reload_harness: OK")
