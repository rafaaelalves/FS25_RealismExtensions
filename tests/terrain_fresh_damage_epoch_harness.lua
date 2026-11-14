-- Post-recovery NEW wheel-source admission. Pure Lua, no FS25 native writes.
-- Tested geometry edits below occur only in a mocked MAIN grid.
dofile("scripts/terrain/TerrainGeometryJournal.lua")
dofile("scripts/terrain/TerrainQuantizedHeightBudget.lua")
dofile("scripts/terrain/TerrainAbsoluteVertexCandidate.lua")
local J=RealismExtensionsTerrainGeometryJournal
local B=RealismExtensionsTerrainQuantizedHeightBudget
local C=RealismExtensionsTerrainAbsoluteVertexCandidate
local q=255/65535
local base=q*36000
local heights={}
local now=100
local writes=0
local function key(x,z)return tostring(x)..":"..tostring(z)end
local function read(x,z)
    local v=heights[key(x,z)]
    return v~=nil and v or base
end
local function set(x,z,y) heights[key(x,z)]=y end
local journal=J.new(999,{unitM=1,sample=read})
local budget=assert(B.new({quantumM=q,clock=function()return now end}))
local candidate=assert(C.new({
    journal=journal,budget=budget,explicitWrite=true,
    verifyExclusive=function()return true end,
    writeHeight=function(x,z,target)
        writes=writes+1
        -- Mock the independent FS25 Nov-11 readback at ~59nm under q.
        set(x,z,math.floor(target/q+0.5)*q+0.00000005937)
        return true
    end
}))
local function seedOwnedRut(x,z)
    assert(assert(candidate:applyOne(x,z,q,"CUMULATIVE")).verified)
    assert(assert(candidate:applyOne(x,z,2*q,"CUMULATIVE")).verified)
    assert(journal.observations[key(x,z)].owned==true)
end
local function recoverOne(x,z,full)
    local p=assert(journal:getRecoverablePoint(x,z))
    local t=assert(journal:beginRecovery(p,0.56,true))
    assert(#t.points==9)
    if full then
        set(x,z,base)
    else
        set(x,z,base-q+0.00000005937)
    end
    local recovery=assert(journal:finishRecovery(t,true))
    assert(recovery.success and recovery.safe and recovery.gainM>0)
    local ok,done=budget:syncVerifiedRecovery(journal,recovery.recoveryProof)
    assert(ok and done==full)
    return recovery
end
local function sample(overrides)
    local s={
        wheelKey="wheel-A",sequence=1,contactX=10,contactZ=10,
        freshCumulativeDamageM=0.020,
        grounded=true,pathContinuity=true,
        mainGeometryState="MAIN_RESEARCH_CANDIDATE"
    }
    for k,v in pairs(overrides or {}) do s[k]=v end
    return s
end

-- Existing independently verified geometry, followed by genuine physical
-- partial restitution. An old model request MUST NOT re-excavate it.
seedOwnedRut(10,10)
assert(writes==2)
recoverOne(10,10,false)
local remaining=budget.entries["10:10"].committedM
assert(remaining>0 and math.abs(remaining-q)<0.000001)
assert(budget.entries["10:10"].recoveryEpochPending==true)
assert(select(2,candidate:applyOne(10,10,2*q,"CUMULATIVE"))
    =="NEW_DAMAGE_EPOCH_REQUIRED_AFTER_RECOVERY")
assert(writes==2)

-- A frame, a fake receipt, a narrow footprint, and a reset path are NOT
-- proof of post-repair plastic damage.
assert(select(2,budget:observeFreshDamage("10:10",journal,sample()))
    =="FRESH_DAMAGE_SOURCE_NOT_VERIFIED")
now=101
assert(select(2,budget:observeFreshDamage("10:10",journal,
    sample({pathContinuity=false})))=="FRESH_DAMAGE_SOURCE_NOT_VERIFIED")
assert(select(2,budget:observeFreshDamage("10:10",journal,
    sample({mainGeometryState="FINE_ONLY_OR_UNREPRESENTABLE"})))
    =="FRESH_DAMAGE_SOURCE_NOT_VERIFIED")
assert(select(2,budget:observeFreshDamage("10:10",journal,sample()))
    =="POST_RECOVERY_SOURCE_BASELINE")
assert(select(2,budget:observeFreshDamage("10:10",journal,sample()))
    =="STALE_OR_DIFFERENT_WHEEL_SOURCE")
now=102
assert(select(2,budget:observeFreshDamage("10:10",journal,
    sample({sequence=2,wheelKey="wheel-B",contactX=10.3,
        freshCumulativeDamageM=0.020+2*q+0.000001})))
    =="STALE_OR_DIFFERENT_WHEEL_SOURCE")
assert(select(2,budget:observeFreshDamage("10:10",journal,
    sample({sequence=2,contactX=10.01,
        freshCumulativeDamageM=0.020+2*q+0.000001})))
    =="POST_RECOVERY_TRAVEL_NOT_PROVEN")
assert(select(2,budget:observeFreshDamage("10:10",journal,
    sample({sequence=2,contactX=10.3,
        freshCumulativeDamageM=0.020})))
    =="NO_POST_RECOVERY_DAMAGE_GROWTH")

-- Same post-recovery wheel, a later sequence and 0.3m measured travel:
-- only the NEW incremental damage above first post-repair baseline is
-- admitted. This is an internal research ticket, NOT production writer.
local ticket=assert(budget:observeFreshDamage("10:10",journal,
    sample({sequence=2,contactX=10.3,
        freshCumulativeDamageM=0.020+2*q+0.000001})))
local entry=budget.entries["10:10"]
assert(entry.recoveryEpochPending==false)
assert(entry.epochTicket==ticket)
assert(math.abs(entry.authorizedTargetM-(remaining+2*q+0.000001))<1e-9)
assert(budget.stats.freshEpochOpened==1)
local fake={id=ticket.id,key=ticket.key}
assert(select(2,budget:requestTarget("10:10",
    entry.authorizedTargetM,0.1,fake))
    =="NEW_DAMAGE_EPOCH_TICKET_REQUIRED")
assert(select(2,budget:requestTarget("10:10",
    entry.authorizedTargetM,0.1))
    =="NEW_DAMAGE_EPOCH_TICKET_REQUIRED")
assert(select(2,budget:requestTarget("10:10",2*q,0.1,ticket))
    =="NEW_DAMAGE_TARGET_NOT_PROVEN")
assert(writes==2)
local admitted=assert(candidate:applyOne(10,10,
    entry.authorizedTargetM,"CUMULATIVE",ticket))
assert(admitted.verified and writes==3)
-- Reusing exactly the same cumulative target cannot produce additional
-- excavation after the two legitimately funded quantums are settled.
assert(assert(candidate:applyOne(10,10,
    entry.authorizedTargetM,"CUMULATIVE",ticket)).verified)
assert(writes==4)
assert(select(1,candidate:applyOne(10,10,
    entry.authorizedTargetM,"CUMULATIVE",ticket))==nil)
assert(writes==4)
assert(math.abs(entry.committedM-(base-read(10,10)))<1e-9)

-- Now a second real recovery after new writes resets the old ticket and
-- establishes a distinct physically measured epoch.
local previousTicket=ticket
now=103
local p=assert(journal:getRecoverablePoint(10,10))
local token=assert(journal:beginRecovery(p,0.56,true))
set(10,10,base)
local done=assert(journal:finishRecovery(token,true))
assert(done.safe and done.completed)
assert(budget:syncVerifiedRecovery(journal,done.recoveryProof))
assert(entry.recoveryEpochPending and entry.epochTicket==nil)
assert(journal.observations["10:10"]==nil)
assert(select(2,budget:requestTarget("10:10",2*q,0.1,
    previousTicket))=="NEW_DAMAGE_EPOCH_REQUIRED_AFTER_RECOVERY")
now=104
assert(select(2,budget:observeFreshDamage("10:10",journal,sample()))
    =="POST_RECOVERY_SOURCE_BASELINE")
now=105
local freshAgain=assert(budget:observeFreshDamage("10:10",journal,
    sample({sequence=3,contactX=10.3,
        freshCumulativeDamageM=0.020+2*q+0.000001})))
assert(freshAgain~=previousTicket)
assert(math.abs(budget.entries["10:10"].authorizedTargetM
    -(2*q+0.000001))<1e-9)

-- Foreign geometry changes between recovery and a new source sample are
-- a HARD quarantine, not a reason to silently reset physical ownership.
seedOwnedRut(20,20)
now=106
local p2=assert(journal:getRecoverablePoint(20,20))
local t2=assert(journal:beginRecovery(p2,0.56,true))
set(20,20,base-q+0.00000005937)
local part=assert(journal:finishRecovery(t2,true))
assert(budget:syncVerifiedRecovery(journal,part.recoveryProof))
set(20,20,read(20,20)-0.00002)
now=107
assert(select(2,budget:observeFreshDamage("20:20",journal,
    sample({contactX=20,contactZ=20})))
    =="RECOVERY_EPOCH_HEIGHT_DRIFT")
assert(budget.quarantined)
assert(journal.observations["20:20"].owned==false)
assert(select(2,budget:requestTarget("20:20",0.01,0.10))
    =="QUARANTINED")
print("terrain_fresh_damage_epoch_harness: OK")
