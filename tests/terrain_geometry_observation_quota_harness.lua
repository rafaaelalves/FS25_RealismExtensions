-- Bounded MAIN journal cardinality: reserve all possible native
-- footprint vertices before a queued job, never evict old ownership.
-- Simulated heights only; no actual GIANTS terrain mutation.
dofile("scripts/terrain/TerrainGeometryJournal.lua")
local J=RealismExtensionsTerrainGeometryJournal
local heights={}
local function k(x,z)return tostring(x)..":"..tostring(z) end
local function read(x,z)
    local y=heights[k(x,z)]
    return y~=nil and y or 100
end
local function set(x,z,y)heights[k(x,z)]=y end
local function journal(max)
    return J.new(42,{unitM=1,sample=read,
        maxObservations=max or 10,maxRecoveryFences=8})
end
local j=journal(10)
local a=assert(j:begin("a",0,0,0.30))
assert(#a.points==5 and a.observationReservation==5)
assert(j.observationCount==0 and j.reservedObservationSlots==5)
local b=assert(j:begin("b",10,10,0.30))
assert(#b.points==5 and b.observationReservation==5)
assert(j.observationCount==0 and j.reservedObservationSlots==10)
local refused,reason=j:begin("c",20,20,0.30)
assert(refused==nil and reason=="GEOMETRY_OBSERVATION_CAPACITY")
assert(j.stats.observationCapacityRefusals==1)
assert(j.pendingCount==2 and j.reservedObservationSlots==10)
-- Aborting a native callback frees only its own reservations, not
-- unrelated pending vertices and not durable observations.
assert(j:complete(b,false).success==false)
assert(j.reservedObservationSlots==5 and j.observationCount==0)
local again=assert(j:begin("c",20,20,0.30))
assert(j.reservedObservationSlots==10)
set(0,0,99.99)
assert(j:complete(a,true).loweredVertices==1)
assert(j.observationCount==1 and j.reservedObservationSlots==5)
assert(j.observations["0:0"].owned==true)
-- 1 owned observation + one 5-vertex reservation cannot fit
-- another 5-vertex footprint until queued work settles.
local denied,why=j:begin("d",30,30,0.30)
assert(denied==nil and why=="GEOMETRY_OBSERVATION_CAPACITY")
set(20,20,99.98)
assert(j:complete(again,true).loweredVertices==1)
assert(j.observationCount==2 and j.reservedObservationSlots==0)
assert(j.observations["20:20"].owned==true)
local nextJob=assert(j:begin("d",30,30,0.30))
assert(j.reservedObservationSlots==5)
assert(j:complete(nextJob,false).success==false)
assert(j.reservedObservationSlots==0 and j.observationCount==2)
-- Repeat a known footprint reserves only the UNSEEN corners.
local revisit=assert(j:begin("repeat",0,0,0.30))
assert(revisit.observationReservation==4)
assert(j:complete(revisit,false).success==false)
assert(j.observationCount==2)

-- A recovery spans a full 3x3, and MUST reserve possible collateral
-- observations, even when the eventual native setter only raises center.
local point=assert(j:getRecoverablePoint(0,0))
local recovery=assert(j:beginRecovery(point,0.56,false))
assert(#recovery.points==9 and recovery.observationReservation==8)
assert(j.reservedObservationSlots==8)
set(0,0,100)
local finished=assert(j:finishRecovery(recovery,true))
assert(finished.safe and finished.completed and finished.gainM>0)
assert(j.observations["0:0"]==nil)
assert(j.observationCount==1)
assert(j.reservedObservationSlots==0)
assert(j.recoveryFenceCount==1)
assert(j.recoveryFences["0:0"].trusted==true)
-- Even after the owned observation disappears, its recovery tombstone
-- must continue blocking old epochs and survive a save.
local snap=assert(j:exportSnapshot())
assert(snap.manifest.cellCount==1 and snap.manifest.fenceCount==1)
assert(snap.cells[1].x==20 and snap.fences[1].x==0)
local imported=journal(10)
assert(imported:importSnapshot(snap))
assert(imported.observationCount==1
    and imported.recoveryFenceCount==1)
assert(imported:getRecoveryFence("0:0")~=nil)
local cap=journal(1)
local ok,capWhy=cap:importSnapshot(snap)
assert(ok==false and capWhy=="GEOMETRY_OBSERVATION_IMPORT_CAPACITY")
assert(cap.quarantined and cap.observationCount==0)
assert(select(2,cap:begin("blocked",40,40,0.30))
    =="GEOMETRY_JOURNAL_QUARANTINED")
assert(select(2,cap:exportSnapshot())
    =="GEOMETRY_JOURNAL_QUARANTINED")
-- This is a refusal, NEVER a prune of the older owned observation.
assert(j.observations["20:20"].owned==true)
assert(j.stats.observationCapacityRefusals==2)

-- At a full physical quota, a native writer must refuse BEFORE
-- calling any setter, even if it only intends to alter the center.
local full=journal(5)
local t=assert(full:begin("full-a",50,50,0.30))
assert(t.observationReservation==5)
set(50,50,99.96)
assert(full:complete(t,true).loweredVertices==1)
assert(full.observationCount==1)
local u=assert(full:begin("full-b",60,60,0.30))
assert(u.observationReservation==5)
assert(full.observationCount==1 and full.reservedObservationSlots==5)
-- This last assertion demonstrates why a reservation cannot be admitted:
-- future state can NEVER exceed maxObservations.
error("unreachable")
