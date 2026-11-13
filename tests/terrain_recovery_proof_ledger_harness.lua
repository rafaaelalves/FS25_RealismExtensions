-- MAIN geometry, recovery receipt, and cumulative target ledger are
-- separate. No physical restoration may silently erase paid depth or
-- re-submit stale wheel demand in the same gameplay session.
dofile("scripts/terrain/TerrainGeometryJournal.lua")
dofile("scripts/terrain/TerrainQuantizedHeightBudget.lua")
dofile("scripts/terrain/TerrainAbsoluteVertexCandidate.lua")
local J=RealismExtensionsTerrainGeometryJournal
local B=RealismExtensionsTerrainQuantizedHeightBudget
local C=RealismExtensionsTerrainAbsoluteVertexCandidate
local q=255/65535
local base=q*36000
local h={}
local function key(x,z)return tostring(x)..":"..tostring(z)end
local function read(x,z)
    local v=h[key(x,z)]
    return v~=nil and v or base
end
local function set(x,z,y)h[key(x,z)]=y end
local j=J.new(999,{unitM=1,sample=read})
local budget=assert(B.new({quantumM=q}))
local calls=0
local down=assert(C.new({
    budget=budget,journal=j,explicitWrite=true,
    verifyExclusive=function()return true end,
    writeHeight=function(x,z,target)
        calls=calls+1
        set(x,z,math.floor(target/q+0.5)*q)
        return true
    end
}))
local function lowerTo(x,z,cumulative)
    local result,why=down:applyOne(x,z,cumulative,"CUMULATIVE")
    assert(result and result.verified, tostring(why))
end
lowerTo(10,10,q)
lowerTo(10,10,2*q)
assert(calls==2)
assert(math.abs(read(10,10)-(base-2*q))<1e-8)
assert(j.observations["10:10"].owned)
assert(math.abs(budget.entries["10:10"].committedM-2*q)<1e-8)

-- Native recovery issued from a trusted journal, NOT from a model value.
local point=assert(j:getRecoverablePoint(10,10))
local token=assert(j:beginRecovery(point,0.56,true))
assert(#token.points==9 and token.recoveryProofRequested==true)
set(10,10,base-q)
local halfway=assert(j:finishRecovery(token,true))
assert(halfway.safe and not halfway.completed)
assert(halfway.recoveryProof~=nil)
local synced,complete=budget:syncVerifiedRecovery(j,halfway.recoveryProof)
assert(synced and complete==false)
assert(math.abs(budget.entries["10:10"].committedM-q)<1e-8)
assert(budget:getDebt("10:10")==0)
assert(budget.stats.recoveryProofsApplied==1)
local result,why=down:applyOne(10,10,2*q,"CUMULATIVE")
assert(result==nil and why=="NEW_DAMAGE_EPOCH_REQUIRED_AFTER_RECOVERY")
assert(calls==2)
assert(j.observations["10:10"].owned==true)
assert(select(1,budget:syncVerifiedRecovery(j,halfway.recoveryProof))==false)
assert(budget.quarantined==true)
-- A duplicate receipt must fail closed, never allow a replay.
budget.quarantined=false

-- Another real recovery q -> original, only journal-verified receipt
-- with fully restored native height may close the old target.
local again=assert(j:getRecoverablePoint(10,10))
local t2=assert(j:beginRecovery(again,0.56,true))
set(10,10,base)
local closed=assert(j:finishRecovery(t2,true))
assert(closed.safe and closed.completed)
assert(closed.recoveryProof~=nil)
assert(j.observations["10:10"]==nil)
local retired,done=budget:retireTarget("10:10",j,closed.recoveryProof)
assert(retired and done==true)
assert(budget:getDebt("10:10")==0)
assert(budget.entries["10:10"].recoveryEpochPending==true)
assert(select(2,budget:requestTarget("10:10",2*q,0.1))==
    "NEW_DAMAGE_EPOCH_REQUIRED_AFTER_RECOVERY")
assert(calls==2)
assert(math.abs(read(10,10)-base)<1e-8)

-- A wrong external callback cannot forge a journal receipt.
local fake=assert(B.new({quantumM=q}))
assert(fake:seedOwnedTarget("x",q))
local forged={key="x",completed=true,beforeY=base-q,
    afterY=base,originalY=base}
local valid,whyFake=fake:syncVerifiedRecovery(j,forged)
assert(valid==false and whyFake=="NO_JOURNAL_RECOVERY_PROOF")
assert(fake.quarantined)

-- No receipt from a recovery whose brush did not truly move soil.
local other=J.new(999,{unitM=1,sample=read})
local e=assert(other:begin("DAMAGE:20:20",20,20,0.3))
set(20,20,base-2*q)
assert(other:complete(e,true).loweredVertices==1)
local p=assert(other:getRecoverablePoint(20,20))
local noMotion=assert(other:beginRecovery(p,0.56,true))
local no=assert(other:finishRecovery(noMotion,true))
assert(no.safe and not no.completed and no.gainM==0)
assert(no.recoveryProof==nil)
assert(other.recoveryProofs["20:20"]==nil)
print("terrain_recovery_proof_ledger_harness: OK")
