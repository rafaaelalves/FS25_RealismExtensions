-- Real planner/reconciliation/candidate chain, with ONLY a fake native
-- lattice setter. Never exercises the actual FS25 engine or collision.
dofile("scripts/terrain/TerrainGeometryJournal.lua")
dofile("scripts/terrain/TerrainMainFootprintGate.lua")
dofile("scripts/terrain/TerrainAbsoluteHeightPlanner.lua")
dofile("scripts/terrain/TerrainQuantizedHeightBudget.lua")
dofile("scripts/terrain/TerrainAbsoluteVertexCandidate.lua")
dofile("scripts/terrain/TerrainMainPatchReconciliation.lua")
dofile("scripts/terrain/TerrainAbsoluteRecoveryCandidate.lua")
dofile("scripts/terrain/TerrainMainPatchExecutor.lua")
local J=RealismExtensionsTerrainGeometryJournal
local P=RealismExtensionsTerrainAbsoluteHeightPlanner
local E=RealismExtensionsTerrainMainPatchExecutor
local q=1/256 -- exactly representable for deterministic ordering assertions
local heights,calls,allow,mode
local function key(x,z)return tostring(x)..":"..tostring(z) end
local function height(x,z)return heights[key(x,z)] or 140 end
local function fixture(limit,behavior,quantizer)
    heights={};calls=0;allow=true;mode=behavior
    local j=J.new(999,{unitM=1,sample=height})
    local p=assert(P.new({unitM=1}))
    -- Two adjacent vertices, each two steps. Exercise the real envelope;
    -- the projection source fixture supplies exactly representable caps.
    function p:projectMain(x,z)
        return {researchTargetM=z==0 and (x==0 or x==1) and 2*q or nil,
            broadModeledCoverage01=1,inspectedMembers=1}
    end
    local options={liveJournal=j,planner=p,ix=0,iz=0,radius=1,
        quantumM=q,gradient=0.02,maxCalls=limit,
        explicitResearchPermission=true,disposableSaveConfirmed=true,
        verifyExclusive=function()return allow end,
        writeHeight=function(x,z,target)
            calls=calls+1
            if mode=="throw" then error("native simulated throw") end
            if mode=="noeffect" then return end
            heights[key(x,z)]=math.floor(target/q+(quantizer=="FLOOR" and 0 or 0.5))*q
            if mode=="far" then heights["-2:-2"]=140-q end
            if mode=="near" then heights["0:1"]=140-q end
            if mode=="stop" then allow=false end
        end}
    return assert(E.new(options)),j,options
end
for _,quantizer in ipairs({"FLOOR","NEAREST"}) do
    local e,j=fixture(4,nil,quantizer)
    local out=assert(e:run())
    assert(out.state=="COMPLETE" and out.calls==4 and out.verified==4)
    assert(out.receipts[1].key=="0:0" and out.receipts[2].key=="1:0")
    assert(out.receipts[3].key=="0:0" and out.receipts[4].key=="1:0")
    assert(height(0,0)==140-2*q and height(1,0)==140-2*q)
    assert(out.discardCopy and not out.authorizesProductionWrite)
    assert(j.observationCount==0 and j.pendingCount==0)
    assert(next(j.recoveryFences)==nil and e:run()==nil and calls==4)
end
local e,j=fixture(2)
local out=assert(e:run())
assert(out.state=="LIMIT_REACHED" and out.calls==2 and out.verified==2)
assert(out.remainingSteps==2 and e:run()==nil and calls==2)
for _,behavior in ipairs({"throw","noeffect","far","near","stop"}) do
    e,j=fixture(4,behavior)
    out=assert(e:run())
    assert(out.state=="FAILED" and calls==1 and out.calls==1,behavior)
    assert(out.verified==0 and out.discardCopy and e:run()==nil)
    assert(j.observationCount==0 and j.pendingCount==0)
end
e,j=fixture(4)
j.recoveryFences["-2:-2"]={trusted=true,accounted=true}
out=assert(e:run())
assert(out.state=="REFUSED" and calls==0)
e,j=fixture(4)
allow=false
assert(e:run().state=="REFUSED" and calls==0)
local options
e,j,options=fixture(4)
options.maxCalls=9
assert(E.new(options)==nil)
options.maxCalls=4
options.disposableSaveConfirmed=false
assert(E.new(options)==nil)
-- Reverse only the verified prefix, in exact opposite order. Both
-- quantizers must return the entire monitored area to its initial state.
for _,quantizer in ipairs({"FLOOR","NEAREST"}) do
    e,j,options=fixture(8,nil,quantizer)
    options.roundTrip=true
    e=assert(E.new(options))
    out=assert(e:run())
    assert(out.state=="RESTORED" and out.downState=="COMPLETE",tostring(out.reason))
    assert(out.calls==8 and out.verified==4 and out.recovered==4)
    assert(out.phase=="UP" and out.discardCopy)
    for i=1,4 do
        assert(out.recoveryReceipts[i].key==out.receipts[5-i].key)
        assert(out.recoveryReceipts[i].afterY==out.receipts[5-i].beforeY)
    end
    assert(height(0,0)==140 and height(1,0)==140)
    assert(j.observationCount==0 and next(j.recoveryFences)==nil)
    assert(e:run()==nil and calls==8)
end
e,j,options=fixture(5)
options.roundTrip=true
out=assert(assert(E.new(options)):run())
assert(out.state=="RESTORED" and out.downState=="LIMIT_REACHED")
assert(out.calls==4 and out.verified==2 and out.recovered==2)
assert(height(0,0)==140 and height(1,0)==140)
-- A failure during DOWN may have unknown geometry: never attempt rollback.
e,j,options=fixture(8,"far")
options.roundTrip=true
out=assert(assert(E.new(options)):run())
assert(out.state=="FAILED" and out.calls==1 and out.recovered==0)
-- A failure during UP stops immediately and cannot be retried.
for _,behavior in ipairs({"noeffect","throw","far","stop","overshoot"}) do
    e,j,options=fixture(8)
    options.roundTrip=true
    local writer=options.writeHeight
    options.writeHeight=function(x,z,target)
        if calls==4 then
            if behavior=="overshoot" then
                calls=calls+1
                heights[key(x,z)]=height(x,z)+2*q
                return
            end
            mode=behavior
        end
        return writer(x,z,target)
    end
    e=assert(E.new(options))
    out=assert(e:run())
    assert(out.state=="FAILED" and out.phase=="UP",behavior..":"..tostring(out.reason))
    assert(out.calls==5 and out.recovered==0 and e:run()==nil)
end
print("terrain_main_patch_executor_harness: OK")
