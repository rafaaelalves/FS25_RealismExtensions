-- Physical restitution truthfulness: "one quantum still missing" is
-- NOT "repaired" on Estância's measured ~3.891mm MAIN lattice.
-- This is a synthetic Lua geometry journal test, not live GIANTS soil.
dofile("scripts/terrain/TerrainGeometryJournal.lua")
local J=RealismExtensionsTerrainGeometryJournal
local q=255/65535
local base=36000*q
local heights={}
local function key(x,z)return tostring(x)..":"..tostring(z)end
local function read(x,z)
    local v=heights[key(x,z)]
    return v~=nil and v or base
end
local function set(x,z,y)heights[key(x,z)]=y end
local j=J.new(999,{unitM=1,sample=read})
local function ownedRut(x,z,depthM)
    local token=assert(j:begin("RUT:"..key(x,z),x,z,0.3))
    set(x,z,base-depthM)
    local result=assert(j:complete(token,true))
    assert(result.loweredVertices==1)
    assert(j.observations[key(x,z)].owned==true)
    return assert(j:getRecoverablePoint(x,z,0.003))
end
local p=ownedRut(100,100,2*q)
assert(math.abs(p.deficitM-2*q)<1e-9)

-- Valid physical recovery raises only the chosen center and leaves its
-- neighbors untouched. First pass recovers one q but LEAVES one q hole.
local token=assert(j:beginRecovery(p,0.56))
set(100,100,base-q)
local half=assert(j:finishRecovery(token,true))
assert(half.success and half.safe and not half.completed)
assert(half.collateral==0 and half.gainM>0)
assert(math.abs(half.gainM-q)<1e-9)
assert(j.observations["100:100"].owned==true)
local remaining=assert(j:getRecoverablePoint(100,100,0.003))
assert(math.abs(remaining.deficitM-q)<1e-9)
assert(j.pendingCount==0)

-- Final q-sized pass actually restores the baseline, so the owned-rut
-- record may now be retired; it may NOT be retired one pass earlier.
local finish=assert(j:beginRecovery(remaining,0.56))
set(100,100,base)
local done=assert(j:finishRecovery(finish,true))
assert(done.success and done.safe and done.completed)
assert(done.gainM>0 and done.collateral==0)
assert(j.observations["100:100"]==nil)
assert(j:getRecoverablePoint(100,100)==nil)
assert(j.pendingCount==0)

-- A whole-cell center restoration WITH microscopic foreign neighbor
-- collateral is NOT a safe completed rut repair. Preserve evidence
-- as UNTRUSTED and refuse any further autonomous restitution.
local p2=ownedRut(200,200,2*q)
local withCollateral=assert(j:beginRecovery(p2,0.56))
set(200,200,base)
set(201,200,base+0.00002)
local out=assert(j:finishRecovery(withCollateral,true))
assert(out.success and out.safe==false and out.completed==false)
assert(out.collateral>=1)
assert(j.observations["200:200"]~=nil)
assert(j.observations["200:200"].owned==false)
assert(j:getRecoverablePoint(200,200)==nil)
assert(j.pendingCount==0)

-- Likewise raising a center one q ABOVE the trusted original must
-- not be called "recovered": the setter already ran, so quarantine
-- provenance, do NOT issue a speculative reverse height mutation.
local p3=ownedRut(300,300,2*q)
local tooHigh=assert(j:beginRecovery(p3,0.56))
set(300,300,base+q)
local over=assert(j:finishRecovery(tooHigh,true))
assert(over.success and over.safe==false and over.completed==false)
assert(j.observations["300:300"]~=nil)
assert(j.observations["300:300"].owned==false)
assert(j:getRecoverablePoint(300,300)==nil)

-- A no-effect native recovery callback never clears a valid rut.
local p4=ownedRut(400,400,2*q)
local noEffect=assert(j:beginRecovery(p4,0.56))
local noMotion=assert(j:finishRecovery(noEffect,true))
assert(noMotion.success and noMotion.safe and not noMotion.completed)
assert(noMotion.gainM==0)
assert(j.observations["400:400"].owned==true)
print("terrain_exact_recovery_completion_harness: OK")
