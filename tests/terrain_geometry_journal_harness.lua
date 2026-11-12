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

-- A giant native jump measured during RE's callback is not proof of RE
-- ownership. Revoke every potentially affected heightmap vertex and keep
-- the old pre-RE reference immutable, but unavailable for automatic TARGET.
local giant=assert(j:begin("ambiguous-burst",60,60,0.3))
set(60,60,99.945)
local burst=assert(j:complete(giant,true))
assert(burst.maxLowerM>0.05)
assert(j.observations["60:60"].owned==true)
local revoked,revokedCount=j:invalidateCompletedFootprint(
    giant,"EXCESS_NATIVE_LOWERING")
assert(revoked==true and revokedCount>=1)
assert(j.observations["60:60"].owned==false)
assert(j:getRecoverablePoint(60,60)==nil)
assert(j.observations["60:60"].preREHeightM==100)
assert(j:invalidateCompletedFootprint(giant)==false)
assert(j:invalidateCompletedFootprint({id=999})==false)
assert(j.stats.anomalousCompletedFootprints==1)
assert(j.stats.anomalousOwnershipInvalidated>=1)

-- Saved v1 observations were collected BEFORE anomalous native deltas
-- were reliably invalidated. Import their heights, never their authority.
-- A v2 sidecar written by the corrected implementation retains ownership.
local trusted=API.new(999,{unitM=1,sample=sample})
local rt=assert(trusted:begin("versioned",80,80,0.3))
set(80,80,99.992)
assert(trusted:complete(rt,true).loweredVertices==1)
assert(trusted.observations["80:80"].owned==true)
local newSnapshot=assert(trusted:exportSnapshot())
assert(newSnapshot.version==2)
local newReader=API.new(999,{unitM=1,sample=sample})
assert(newReader:importSnapshot(newSnapshot)==true)
assert(newReader.observations["80:80"].owned==true)
assert(newReader.stats.reloadOwnershipDriftDowngraded==0)

-- A FLOAT32 / numeric-readback difference inside 10um can preserve a
-- v2 proven ownership record. But a real external 20um or full-q edit
-- between save/reload must NEVER be attributed to RE or authorize an
-- autonomous tillage/municipality repair against the stale baseline.
set(80,80,99.992+0.000005)
local tiny=API.new(999,{unitM=1,sample=sample})
assert(tiny:importSnapshot(newSnapshot)==true)
assert(tiny.observations["80:80"].owned==true)
assert(tiny.stats.reloadOwnershipDriftDowngraded==0)
set(80,80,99.992+0.00002)
local externalFine=API.new(999,{unitM=1,sample=sample})
local fineOk,fineRestored,fineRejected=
    externalFine:importSnapshot(newSnapshot)
assert(fineOk and fineRestored==1 and fineRejected==0)
assert(externalFine.observations["80:80"].owned==false)
assert(externalFine.stats.reloadOwnershipDriftDowngraded==1)
assert(externalFine:getRecoverablePoint(80,80)==nil)
local blocked,blockedWhy=externalFine:getLoweringBudget(
    80,80,0.3,0.10,0.12)
assert(blocked==0 and blockedWhy=="UNTRUSTED_EDIT")
assert(math.abs(externalFine.observations["80:80"].preREHeightM-100)
    <1e-9)
assert(sample(80,80)==99.992+0.00002)

-- The old 5mm "importable" tolerance spanned one 3.891mm MAIN step.
-- Keep the observation for diagnostics but do NOT regain ownership.
set(80,80,99.992-255/65535)
local externalStep=API.new(999,{unitM=1,sample=sample})
local stepOk,stepRestored,stepRejected=
    externalStep:importSnapshot(newSnapshot)
assert(stepOk and stepRestored==1 and stepRejected==0)
assert(externalStep.observations["80:80"].owned==false)
assert(externalStep.stats.reloadOwnershipDriftDowngraded==1)
assert(externalStep:getRecoverablePoint(80,80)==nil)
set(80,80,99.992)

-- In-session unknown changes must be rejected BEFORE any physical
-- maintenance/tillage recovery, not just at the next game reload.
local runtimeOwned=API.new(999,{unitM=1,sample=sample})
assert(runtimeOwned:importSnapshot(newSnapshot)==true)
set(80,80,99.992-0.00002)
assert(runtimeOwned:getRecoverablePoint(80,80)==nil)
assert(runtimeOwned.observations["80:80"].owned==false)
assert(runtimeOwned.stats.runtimeOwnershipDriftDowngraded==1)
set(80,80,99.992)
assert(runtimeOwned:getRecoverablePoint(80,80)==nil)

local writeOwned=API.new(999,{unitM=1,sample=sample})
assert(writeOwned:importSnapshot(newSnapshot)==true)
set(80,80,99.992-0.00002)
local remaining,whyRemaining=writeOwned:getLoweringBudget(
    80,80,0.3,0.10,0.12)
assert(remaining==0 and whyRemaining=="EXTERNAL_EDIT")
assert(writeOwned.stats.runtimeOwnershipDriftDowngraded==1)
assert(writeOwned.observations["80:80"].owned==false)
set(80,80,99.992)

-- A regular save *before* reload previously laundered changes of
-- 20um..2mm by refreshing observedHeightM while keeping owned=true.
-- Revoking ownership on export is essential, not optional.
local presave=API.new(999,{unitM=1,sample=sample})
assert(presave:importSnapshot(newSnapshot)==true)
set(80,80,99.992+0.00002)
local exported=assert(presave:exportSnapshot())
assert(exported.cells[1].owned==false)
assert(presave.stats.preSaveOwnershipDriftDowngraded==1)
assert(presave.observations["80:80"].owned==false)
assert(math.abs(exported.cells[1].observedHeightM-(99.992+0.00002))
    <1e-9)
local reloadedAgain=API.new(999,{unitM=1,sample=sample})
assert(reloadedAgain:importSnapshot(exported)==true)
assert(reloadedAgain.observations["80:80"].owned==false)
assert(reloadedAgain:getRecoverablePoint(80,80)==nil)
set(80,80,99.992)

local oldSnapshot={
    version=1,unitM=newSnapshot.unitM,cells=newSnapshot.cells
}
local legacyReader=API.new(999,{unitM=1,sample=sample})
assert(legacyReader:importSnapshot(oldSnapshot)==true)
assert(legacyReader.observations["80:80"].owned==false)
assert(legacyReader:getRecoverablePoint(80,80)==nil)
assert(legacyReader.stats.legacyProvenanceDowngraded==1)
assert(sample(80,80)==99.992) -- data migration does not regrade terrain

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
assert(snap.version==2 and snap.unitM==1)
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
-- A wheel may sit in the writer queue after journal:begin(). Reject the
-- native operation if a third party changed geometry during that wait.
local preflight=API.new(999,{unitM=1,sample=sample})
local queued=assert(preflight:begin("queued-wheel",200,0,0.3))
set(200,0,99.97)
local canSubmit,whySubmit=preflight:validateBeforeSubmit(queued)
assert(canSubmit==false and whySubmit=="QUEUED_GEOMETRY_DRIFT")
assert(preflight.stats.submitDriftRejected==1)
assert(preflight:complete(queued,false).success==false)
assert(preflight.pendingCount==0)
assert(preflight.observations["200:0"]==nil)

-- No drift: the baseline is refreshed just before native submission.
local fresh=assert(preflight:begin("fresh-wheel",210,0,0.3))
local ready,whyReady=preflight:validateBeforeSubmit(fresh)
assert(ready==true and whyReady==nil and fresh.submissionValidated==true)
set(210,0,99.996109)
local measured=assert(preflight:complete(fresh,true))
assert(math.abs(measured.maxLowerM-0.003891)<0.00001)
assert(measured.maxLowerPoint.key=="210:0")
assert(math.abs(measured.maxLowerPoint.beforeY-100)<0.00001)
assert(math.abs(measured.maxLowerPoint.afterY-99.996109)<0.00001)
assert(preflight.stats.submitChecks==2)

j:reset()
assert(j.pendingCount==0 and next(j.observations)==nil)
print("terrain_geometry_journal_harness: OK")
