-- A genuine MAIN-height recovery is NOT automatically a paid-ledger
-- recovery. Cover interruption, mismatch, v3 migration, and bounded fences.
-- No GIANTS game writes: all geometry readbacks below are fake.
dofile("scripts/terrain/TerrainGeometryJournal.lua")
dofile("scripts/terrain/TerrainQuantizedHeightBudget.lua")
local J=RealismExtensionsTerrainGeometryJournal
local B=RealismExtensionsTerrainQuantizedHeightBudget
local q=255/65535
local base=36000*q
local grid={}
local function id(x,z)return tostring(x)..":"..tostring(z)end
local function get(x,z)return grid[id(x,z)] or base end
local function put(x,z,y)grid[id(x,z)]=y end
local function makeJournal(limit)
    return J.new(999,{unitM=1,sample=get,maxRecoveryFences=limit})
end
local function damage(j,x,z)
    local t=assert(j:begin("damage-"..id(x,z),x,z,0.30))
    put(x,z,base-2*q)
    assert(j:complete(t,true).loweredVertices==1)
end
local function recovery(j,x,z,proof)
    local p=assert(j:getRecoverablePoint(x,z))
    local t=assert(j:beginRecovery(p,0.70,proof))
    put(x,z,base-q)
    local r=assert(j:finishRecovery(t,true))
    assert(r.safe and r.gainM>q-0.000001)
    return r
end
local function budget()
    return assert(B.new({quantumM=q,clock=function()return 100 end}))
end

-- A caller that *claims* an old committed q for a physical rut of 2q
-- must not consume its one-use receipt and publish "paid recovery".
local wrong=makeJournal()
damage(wrong,5,5)
local insufficient=budget()
assert(insufficient:seedOwnedTarget("5:5",q))
local proof=recovery(wrong,5,5,true)
local f=assert(wrong:getRecoveryFence("5:5"))
assert(f.trusted and not f.accounted and f.pendingProof)
assert(proof.recoveryProof~=nil)
assert(select(2,wrong:getLoweringBudget(5,5,0.70,0.10,0.12))
    =="UNACCOUNTED_RECOVERY_EPOCH")
local m=assert(wrong:verifyRecoveryProof(proof.recoveryProof))
assert(math.abs(m.beforeDepthM-2*q)<1e-8)
assert(wrong.recoveryProofs["5:5"]==proof.recoveryProof)
local synced,why=insufficient:syncVerifiedRecovery(wrong,proof.recoveryProof)
assert(not synced and why=="RECOVERY_LEDGER_OR_DEPTH_MISMATCH")
assert(insufficient.quarantined)
assert(wrong.recoveryProofs["5:5"]==proof.recoveryProof)
assert(not wrong:getRecoveryFence("5:5").accounted)
assert(wrong.stats.recoveryProofsReconciled==0)
local snap=assert(wrong:exportSnapshot())
assert(snap.version==5 and snap.fences[1].accounted==false)
local reload=makeJournal()
assert(reload:importSnapshot(snap))
local refused=budget()
assert(select(2,refused:seedPersistedRecovery(reload,"5:5"))
    =="PERSISTED_RECOVERY_NOT_ACCOUNTED")
assert(refused.quarantined)
assert(select(2,refused:requestTarget("5:5",2*q,0.10))
    =="QUARANTINED")

-- An independently correct physical paid ledger *can* reconcile the
-- still-pending receipt. It must do so BEFORE the fence is export-trusted.
local correct=budget()
assert(correct:seedOwnedTarget("5:5",2*q))
assert(correct:syncVerifiedRecovery(wrong,proof.recoveryProof))
assert(wrong:getRecoveryFence("5:5").accounted==true)
local permitted,permittedWhy=wrong:getLoweringBudget(
    5,5,0.70,0.10,0.12)
assert(permitted~=nil and permitted>0 and permittedWhy==nil)
assert(wrong.recoveryProofs["5:5"]==nil)
assert(wrong.stats.recoveryProofsReconciled==1)
local paidSnapshot=assert(wrong:exportSnapshot())
assert(paidSnapshot.fences[1].accounted==true)
local replay=makeJournal()
assert(replay:importSnapshot(paidSnapshot))
assert(replay:getRecoveryFence("5:5").accounted)
local protected=budget()
assert(protected:seedPersistedRecovery(replay,"5:5"))
assert(select(2,protected:requestTarget("5:5",2*q,0.10))
    =="NEW_DAMAGE_EPOCH_REQUIRED_AFTER_RECOVERY")

-- Older v3 readbacks include genuinely recovered geometry but had no
-- independently persisted "accounted" bit. A v3 file never gains one
-- retroactively just because its native height and originalY still match.
local v3={
    version=3,unitM=paidSnapshot.unitM,cells=paidSnapshot.cells,
    fences={{x=5,z=5,originalY=base,observedHeightM=base-q,
        trusted=true,completed=false}}
}
local old=makeJournal()
assert(old:importSnapshot(v3))
assert(old:getRecoveryFence("5:5").trusted)
assert(old:getRecoveryFence("5:5").accounted==false)
assert(select(2,old:getLoweringBudget(5,5,0.70,0.10,0.12))
    =="UNACCOUNTED_RECOVERY_EPOCH")
local legacy=budget()
assert(select(2,legacy:seedPersistedRecovery(old,"5:5"))
    =="PERSISTED_RECOVERY_NOT_ACCOUNTED")

-- No quantized ledger in the callback: valid geometry may be retained,
-- but it is not legal to translate old physical recovery into new
-- after-reload wheel funding.
local withoutLedger=makeJournal()
damage(withoutLedger,10,10)
recovery(withoutLedger,10,10,false)
assert(withoutLedger:getRecoveryFence("10:10").trusted)
assert(not withoutLedger:getRecoveryFence("10:10").accounted)
local noLedgerBudget=budget()
assert(select(2,noLedgerBudget:seedPersistedRecovery(
    withoutLedger,"10:10"))=="PERSISTED_RECOVERY_NOT_ACCOUNTED")

-- Capacity is a hard stop BEFORE another native recovery mutation, not
-- an LRU eviction of a past recovery-epoch deny marker.
local capped=makeJournal(1)
damage(capped,20,20)
recovery(capped,20,20,false)
assert(capped.recoveryFenceCount==1)
damage(capped,30,30)
local vertex=assert(capped:getRecoverablePoint(30,30))
assert(select(2,capped:beginRecovery(vertex,0.70,false))
    =="RECOVERY_FENCE_CAPACITY")
assert(capped.recoveryFenceCount==1)
assert(capped.stats.recoveryFenceCapacityRefusals==1)
assert(get(30,30)==base-2*q)
local cappedSnap=assert(capped:exportSnapshot())
assert(#cappedSnap.fences==1)
local tooMany=makeJournal(1)
assert(select(1,tooMany:importSnapshot(paidSnapshot))==true)
local duplicate={version=4,unitM=1,cells={},
    fences={
        {x=20,z=20,originalY=base,observedHeightM=base-q,
            trusted=true,accounted=true,completed=false},
        {x=30,z=30,originalY=base,observedHeightM=base-2*q,
            trusted=true,accounted=true,completed=false}
    }}
local tooManyOk,tooManyWhy=tooMany:importSnapshot(duplicate)
assert(not tooManyOk and tooManyWhy=="RECOVERY_FENCE_IMPORT_CAPACITY")
-- Keep existing RAM records, but revoke ALL trust on a malformed
-- sidecar; never partially import a smaller subset as a fresh ledger.
assert(tooMany.quarantined)
assert(tooMany.recoveryFenceCount==1)
assert(tooMany.recoveryFences["5:5"].trusted==false)
assert(select(2,tooMany:getLoweringBudget(5,5,0.70,0.10,0.12))
    =="GEOMETRY_JOURNAL_QUARANTINED")

-- An anomalous native write anywhere in the 3x3 monitored footprint
-- revokes RECOVERY authority, not only old rut-observation ownership.
-- A no-effect fake write is used here to avoid actual geometry mutation;
-- caller explicitly flags its whole completed transaction as untrusted.
local anomaly=assert(replay:begin("anomalous-native",5,5,0.70))
assert(replay:complete(anomaly,true).success==true)
assert(replay:invalidateCompletedFootprint(anomaly,
    "EXTERNAL_QUEUE_SIDE_EFFECT"))
local af=assert(replay:getRecoveryFence("5:5"))
assert(af.trusted==false and af.accounted==false)
local anomalyBudget=budget()
assert(select(2,anomalyBudget:seedPersistedRecovery(replay,"5:5"))
    =="PERSISTED_RECOVERY_FENCE_UNTRUSTED")
assert(anomalyBudget.quarantined==true)
print("terrain_recovery_accounting_fence_harness: OK")
