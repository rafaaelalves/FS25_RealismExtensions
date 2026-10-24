-- No GIANTS runtime needed; validate physical state ownership on native grid.
dofile("scripts/terrain/TerrainGeometryJournal.lua")
local API=RealismExtensionsTerrainGeometryJournal
local heights={}
local function key(x,z) return string.format("%.2f,%.2f",x,z) end
local function sample(x,z) return heights[key(x,z)] or 100 end
local function set(x,z,y) heights[key(x,z)]=y end
-- GIANTS must never receive nil as a native handle during loadMap.
local calls=0
getTerrainHeightmapUnitSize=function(node)
    assert(node~=nil)
    calls=calls+1
    -- This harness supplies a per-instance unit; native retrieval is deliberately
    -- unavailable for fake node 999 so incompatible fallback units stay testable.
    return nil
end
local unready=API.new(nil)
assert(unready.unitM==nil and calls==0)
local j=API.new(999,{unitM=1,sample=sample})
assert(j.unitM==1)
local verts=j:enumerateVertices(0,0,0.3)
assert(#verts>=1 and #verts<=9)

local t=assert(j:begin("wheel-one",0,0,0.3))
assert(j.pendingCount==1)
assert(j:begin("wheel-one",0,0,0.3)==nil)
local overlap,reason=j:begin("wheel-two",0.4,0,0.3)
assert(overlap==nil and reason=="OVERLAPPING_RE_WRITE")
assert(j.observations["0:0"]==nil) -- queued is not physical
local fail=assert(j:complete(t,false))
assert(fail.success==false and j.pendingCount==0)
assert(j.observations["0:0"]==nil)
assert(j:complete(t,true)==nil) -- double callback must not mutate

local p=assert(j:begin("wheel-one",0,0,0.3))
set(0,0,99.98)
local r=assert(j:complete(p,true))
assert(r.movedVertices==1 and r.loweredVertices==1)
assert(math.abs(r.maxLowerM-0.02)<0.00001)
assert(j.observations["0:0"].owned==true)
assert(j.observations["0:0"].preREHeightM==100)
assert(j.observations["0:0"].observedHeightM==99.98)

local again=assert(j:begin("wheel-one",0,0,0.3))
set(0,0,99.97)
assert(j:complete(again,true).maxLowerM>0)
assert(j.observations["0:0"].preREHeightM==100) -- immutable first touch
local noop=assert(j:begin("wheel-one",0,0,0.3))
assert(j:complete(noop,true).movedVertices==0)
assert(j.stats.noEffect==1)

-- Terrain changed WITHOUT RE writer: invalidate old baseline before new edit.
set(0,0,99.50)
local externallyChanged=assert(j:begin("wheel-one",0,0,0.3))
assert(j.observations["0:0"].owned==false)
assert(j:complete(externallyChanged,false).success==false)
-- A fresh later downward change must not resurrect old provenance.
local afterExternal=assert(j:begin("wheel-one",0,0,0.3))
set(0,0,99.49)
assert(j:complete(afterExternal,true).loweredVertices==1)
assert(j.observations["0:0"].owned==false)
assert(j.observations["0:0"].preREHeightM==100)

-- A successful native brush can raise instead; that is not a RE rut debt.
local raised=assert(j:begin("raise-test",10,10,0.3))
set(10,10,100.2)
assert(j:complete(raised,true).raisedVertices==1)
assert(j.observations["10:10"].owned==false)

-- Failing a post-read does not create a false result or leave a lock.
local failRead=false
local j2=API.new(999,{unitM=1,sample=function(x,z)
    if failRead then return nil end
    return sample(x,z)
end})
local pending=assert(j2:begin("x",5,5,0.3))
failRead=true
local result,why=j2:complete(pending,true)
assert(result==nil and why=="POST_HEIGHT_UNAVAILABLE")
assert(j2.pendingCount==0)
assert(j2:begin("x",5,5,0.3)==nil) -- sampling still unavailable
local snap=assert(j:exportSnapshot())
assert(snap.version==1 and snap.unitM==1)
local restored=API.new(999,{unitM=1,sample=sample})
local ok,number,bad=restored:importSnapshot(snap)
assert(ok and number>=2 and bad==0)
assert(restored.observations["0:0"].owned==false)
local badUnit=API.new(999,{unitM=2,sample=sample})
assert(badUnit:importSnapshot(snap)==false)
set(0,0,98.90)
local changed=API.new(999,{unitM=1,sample=sample})
local loaded,restoredCount,rejected=changed:importSnapshot(snap)
assert(loaded and rejected>=1 and restoredCount<number)
assert(changed.observations["0:0"]==nil)
-- Reject further RE rut digging in inherited/unknown deep hollows while
-- preserving a clean naturally sloping plane (opposite samples cancel).
local slope=API.new(999,{unitM=1,sample=function(x,z)
    return 100+0.22*x+0.11*z
end})
local room=assert(slope:getLoweringBudget(0,0,0.25,0.10,0.12))
assert(math.abs(room-0.10)<0.000001)
local oldHollow=API.new(999,{unitM=1,sample=function(x,z)
    if x==30 and z==0 then return 99.70 end
    return 100
end})
local noRoom,whyNo=oldHollow:getLoweringBudget(30,0,0.3,0.10,0.12)
assert(noRoom==0 and whyNo=="DEEP_EXISTING_HOLLOW")
local capped=API.new(999,{unitM=1,sample=sample})
local capBrush=assert(capped:begin("wheel:cap",50,0,0.3))
set(50,0,99.88)
assert(capped:complete(capBrush,true).loweredVertices==1)
local capRoom,capReason=capped:getLoweringBudget(50,0,0.3,0.10,0.12)
assert(capRoom==0 and capReason=="DEPTH_CAP")
local untrusted=API.new(999,{unitM=1,sample=sample})
local editBrush=assert(untrusted:begin("wheel:edit",60,0,0.3))
set(60,0,99.98)
assert(untrusted:complete(editBrush,true).loweredVertices==1)
set(60,0,99.93)
local blockRoom,blockReason=untrusted:getLoweringBudget(60,0,0.3,0.10,0.12)
assert(blockRoom==0 and blockReason=="EXTERNAL_EDIT")
assert(untrusted.observations["60:0"].owned==false)

-- A GIANTS TARGET brush that affects an adjacent native vertex must
-- invalidate its own repeated-repair authority instead of doing 20 more passes.
local rut=assert(j:begin("wheel:collateral",20,0,0.3))
set(20,0,99.8)
assert(j:complete(rut,true).loweredVertices==1)
local p20=assert(j:getRecoverablePoint(20,0,0.004))
local repair=assert(j:beginRecovery(p20,0.56))
set(20,0,99.9)
set(21,0,100.02) -- native side effect outside target vertex
local outcome=assert(j:finishRecovery(repair,true))
assert(outcome.collateral>=1 and outcome.safe==false)
assert(j.observations["20:0"].owned==false)
assert(j:getRecoverablePoint(20,0,0.004)==nil)
j:reset()
assert(j.pendingCount==0 and next(j.observations)==nil)
print("terrain_geometry_journal_harness: OK")
