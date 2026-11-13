-- Isolated, explicit ONE-quantum MAIN height restitution.
-- This synthetic harness cannot prove GIANTS physical wheel rut recovery.
dofile("scripts/terrain/TerrainGeometryJournal.lua")
dofile("scripts/terrain/TerrainAbsoluteRecoveryCandidate.lua")
local J=RealismExtensionsTerrainGeometryJournal
local A=RealismExtensionsTerrainAbsoluteRecoveryCandidate
local q=255/65535
local base=q*36000
local h={}
local function key(x,z)return tostring(x)..":"..tostring(z)end
local function read(x,z)
    local y=h[key(x,z)]
    return y~=nil and y or base
end
local function set(x,z,y)h[key(x,z)]=y end
local j=J.new(999,{unitM=1,sample=read})
local function own(x,z,depthM)
    local token=assert(j:begin("damage:"..key(x,z),x,z,0.30))
    set(x,z,base-depthM)
    local outcome=assert(j:complete(token,true))
    assert(outcome.loweredVertices==1)
    assert(j.observations[key(x,z)].owned)
end
local count=0
local mode="FLOOR"
local function writer(x,z,target)
    count=count+1
    local nativeLevel
    if mode=="FLOOR" then
        nativeLevel=math.floor(target/q)*q
    else
        nativeLevel=math.floor(target/q+0.5)*q
    end
    set(x,z,nativeLevel)
    return true
end
local function candidate(quantum, setter)
    return A.new({
        journal=j,quantumM=quantum or q,
        explicitResearchPermission=true,
        disposableSaveConfirmed=true,
        verifyExclusive=function()return true end,
        writeHeight=setter or writer
    })
end
assert(A.new({journal=j,quantumM=q})==nil)
assert(A.new({journal=j,quantumM=0.001,
    explicitResearchPermission=true,
    disposableSaveConfirmed=true})==nil)
assert(A.new({journal=j,quantumM=q,
    explicitResearchPermission=true,
    disposableSaveConfirmed=false})==nil)

-- The prior brush could leave a q-sized hole and claim complete.
-- Recover 2q -> 1q -> 0 via EXACT physically measured steps instead.
for _,quantizer in ipairs({"FLOOR","NEAREST"}) do
    mode=quantizer
    local x=quantizer=="FLOOR" and 100 or 200
    own(x,100,2*q)
    local first=assert(candidate())
    local s1,err1=first:applyOnce(x,100)
    assert(s1~=nil and err1==nil and s1.verified)
    assert(s1.completed==false)
    assert(math.abs(s1.actualRaiseM-q)<0.00000001)
    assert(math.abs(read(x,100)-(base-q))<0.00000001)
    assert(j.observations[key(x,100)].owned)
    assert(first:applyOnce(x,100)==nil and first.consumed)
    assert(j:getRecoverablePoint(x,100,0.003)~=nil)

    local second=assert(candidate())
    local s2,err2=second:applyOnce(x,100)
    assert(s2~=nil and err2==nil and s2.verified)
    assert(s2.completed==true)
    assert(math.abs(read(x,100)-base)<0.00000001)
    assert(j.observations[key(x,100)]==nil)
    assert(j.pendingCount==0)
    assert(second:applyOnce(x,100)==nil)
end
assert(count==4)

-- No RE-owned physical lowering means no recovery authority.
local blank=assert(candidate())
assert(select(2,blank:applyOnce(300,300))==
    "RECOVERY_FULL_QUANTUM_NOT_AVAILABLE")
assert(blank.consumed==false and count==4)

-- A q-sized center raising plus 20um diagonal collateral must fail.
own(400,400,2*q)
local corner=assert(candidate(q,function(x,z,target)
    count=count+1
    set(x,z,base-q)
    set(x+1,z+1,base+0.00002)
    return true
end))
local altered,alteredWhy=corner:applyOnce(400,400)
assert(altered~=nil and altered.verified==false)
assert(alteredWhy=="UNTRUSTED_RECOVERY_QUANTUM_OR_COLLATERAL")
assert(altered.footprint.collateral==1)
assert(j.observations["400:400"].owned==false)
assert(j:getRecoverablePoint(400,400)==nil)
assert(j.pendingCount==0 and corner.quarantined==true)

-- A native setter that actually RAISES TWO q must be rejected, even
-- if this amount happens to restore the center to the original.
own(500,500,2*q)
local excessive=assert(candidate(q,function(x,z,target)
    count=count+1
    set(x,z,base)
    return true
end))
local tooFar,reason=excessive:applyOnce(500,500)
assert(tooFar~=nil and tooFar.verified==false)
assert(reason=="UNTRUSTED_RECOVERY_QUANTUM_OR_COLLATERAL")
assert(j.observations["500:500"]~=nil
    and j.observations["500:500"].owned==false)
assert(excessive.quarantined and j.pendingCount==0)

-- A false return/exception after physical change must quarantine; no
-- reverse setter may be invoked against unknown engine side effects.
own(600,600,2*q)
local falseSetter=assert(candidate(q,function(x,z,target)
    count=count+1
    set(x,z,base-q)
    return false
end))
local invalid,reasonFalse=falseSetter:applyOnce(600,600)
assert(invalid~=nil and not invalid.verified)
assert(reasonFalse=="RECOVERY_NATIVE_SETTER_FAILED")
assert(j.observations["600:600"].owned==false)
assert(falseSetter.consumed and falseSetter.quarantined)
assert(j.pendingCount==0)

-- A stale pre-submit geometry edit must cause ZERO native setters.
own(700,700,2*q)
local drift=J.new(999,{unitM=1,sample=read})
-- This deliberate injection operates on the SAME journal as the
-- currently owned target, so the callback checks the geometry epoch.
local originalPreflight=j.validateBeforeSubmit
local injected=false
j.validateBeforeSubmit=function(self,token,limit)
    assert(limit<=0.00001)
    if not injected then
        injected=true
        set(701,701,read(701,701)+0.00002)
    end
    return originalPreflight(self,token,limit)
end
local beforeCalls=count
local competing=assert(candidate())
local refused,refusal=competing:applyOnce(700,700)
assert(refused==nil and refusal=="QUEUED_GEOMETRY_DRIFT")
assert(count==beforeCalls and competing.quarantined)
assert(j.pendingCount==0)
j.validateBeforeSubmit=originalPreflight
print("terrain_absolute_recovery_candidate_harness: OK")
