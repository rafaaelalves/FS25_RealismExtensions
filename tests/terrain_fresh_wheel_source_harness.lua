-- Source uses real ENGINE-shape server wheel context; no gameplay setter.
-- Native MAIN height below is mocked; this harness never edits a real map.
dofile("scripts/terrain/TerrainGeometryJournal.lua")
dofile("scripts/terrain/TerrainQuantizedHeightBudget.lua")
dofile("scripts/terrain/TerrainAbsoluteVertexCandidate.lua")
dofile("scripts/terrain/TerrainMainFootprintGate.lua")
dofile("scripts/terrain/TerrainPlasticYield.lua")
dofile("scripts/terrain/TerrainResponseModel.lua")
dofile("scripts/terrain/TerrainFreshWheelSource.lua")
local J=RealismExtensionsTerrainGeometryJournal
local B=RealismExtensionsTerrainQuantizedHeightBudget
local C=RealismExtensionsTerrainAbsoluteVertexCandidate
local Source=RealismExtensionsTerrainFreshWheelSource
local Response=RealismExtensionsTerrainResponseModel
local q=255/65535
local base=36000*q
local now=1000
local heights={}
local nativeWrites=0
local function k(x,z)return tostring(x)..":"..tostring(z)end
local function read(x,z)
    local v=heights[k(x,z)]
    return v~=nil and v or base
end
local function set(x,z,y) heights[k(x,z)]=y end
local j=J.new(999,{unitM=1,sample=read})
local budget=assert(B.new({quantumM=q,clock=function()return now end}))
local candidate=assert(C.new({
    journal=j,budget=budget,explicitWrite=true,
    verifyExclusive=function()return true end,
    writeHeight=function(x,z,target)
        nativeWrites=nativeWrites+1
        set(x,z,math.floor(target/q+0.5)*q+0.00000005937)
        return true
    end
}))
local function physicalRecovery()
    local p=assert(j:getRecoverablePoint(10,10))
    local token=assert(j:beginRecovery(p,0.56,true))
    set(10,10,base-q+0.00000005937)
    local res=assert(j:finishRecovery(token,true))
    assert(res.success and res.safe and not res.completed)
    assert(budget:syncVerifiedRecovery(j,res.recoveryProof))
end
g_server={}
local vehicle={isServer=true}
local wheel={}
local wheel2={}
local context={
    grounded=true,structuralRadiusM=0.45,
    physicalGroundWetness=0.85,groundMudPotential=0.7,
    hardFrozen=false,speedKph=4,wheelSurfaceSpeedMps=2.2,
    longitudinalSlip=0.30,lateralSlip=0.05,sinkDepthM=0.005
}
local wide={
    available=true,supportWidthM=1.20,footprintLengthM=1.20,
    groundPressurePa=170000,structuralRadiusM=0.45
}
local narrow={
    available=true,supportWidthM=0.30,footprintLengthM=0.25,
    groundPressurePa=170000,structuralRadiusM=0.45
}
local path={state="CONTINUOUS",completeCoverage=true}
local reset={state="RESET_ANCHOR",completeCoverage=false}
local options={plasticYieldEnabled=true,surfaceCategory="FIELD"}

-- Use the *actual* terramechanical model as one independent check:
-- its own nextHistory is needed to accumulate post-recovery exposure.
local response1=Response.compute(context,wide,nil,150,options)
assert(response1.available and response1.plasticYield01>0
    and response1.rutDepthM>0)
local response2=Response.compute(
    context,wide,response1.nextHistory,150,options)
assert(response2.available and response2.rutDepthM>=response1.rutDepthM)

local inputs={}
local fakeModel={
    compute=function(ctx,foot,history,dt,opts)
        inputs[#inputs+1]=history==nil and "NONE" or history
        local previous=history~=nil and history.rutDepthM or 0
        local depth=previous+q+0.000005
        return {available=true,plasticYield01=1,
            rutDepthM=depth,
            nextHistory={rutDepthM=depth,deformationExposure=depth}}
    end
}
local source=assert(Source.new({
    journal=j,getBudget=function()return budget end,
    model=fakeModel,maxSources=10
}))
local function sample(w,ctx,fp,x,z,evidence,veh)
    return source:observeServerWheel(
        veh or vehicle,w or wheel,ctx or context,fp or wide,
        x or 10,z or 10,150,options,1,0,evidence or path)
end

-- An ordinary grounded wheel before physical restoration may NEVER
-- start a new post-recovery damage epoch.
assert(select(2,sample(wheel,context,wide,10,10))
    =="NO_VERIFIED_RECOVERY_AT_VERTEX")
assert(#inputs==0)
assert(assert(candidate:applyOne(10,10,q,"CUMULATIVE")).verified)
assert(assert(candidate:applyOne(10,10,2*q,"CUMULATIVE")).verified)
assert(nativeWrites==2)
physicalRecovery()
assert(budget.entries["10:10"].recoveryEpochPending)

-- Caller must be the SERVER's actual wheel specialization path.
g_server=nil
assert(select(2,sample(wheel,context,wide,10,10))
    =="SERVER_WHEEL_REQUIRED")
g_server={}
assert(select(2,sample(wheel,context,wide,10,10,path,{isServer=false}))
    =="SERVER_WHEEL_REQUIRED")
assert(select(2,sample(wheel,context,narrow,10,10))
    =="CONTACT_NARROWER_THAN_MAIN_SUPPORT")
assert(select(2,sample(wheel,context,wide,10,10,reset))
    =="NO_BOUNDED_MEASURED_PATH")
assert(#inputs==0)

now=1001
local baseline=select(2,sample(wheel,context,wide,10,10))
assert(baseline=="POST_RECOVERY_SOURCE_BASELINE",tostring(baseline))
assert(#inputs==1)
-- No earlier legacy history was ever supplied to the fresh source.
assert(inputs[1]=="NONE")
assert(nativeWrites==2)

-- A later real wheel context for a different wheel cannot replay the
-- original wheel's baseline; it can only seed its OWN independent epoch.
now=1002
local other=select(2,sample(wheel2,context,wide,10,10))
assert(other=="STALE_OR_DIFFERENT_WHEEL_SOURCE")
now=1003
local ticket,why=sample(wheel,context,wide,10.3,10)
assert(ticket~=nil,tostring(why))
assert(ticket.doesNotWrite and ticket.vertexKey=="10:10")
assert(type(ticket.ticket)=="table")
assert(math.abs(ticket.targetM
    -(budget.entries["10:10"].committedM+q+0.000005))<1e-9)
assert(#inputs==3)
assert(inputs[3]~=nil and inputs[3].rutDepthM>0)
assert(nativeWrites==2)
assert(select(2,budget:requestTarget("10:10",
    ticket.targetM,0.10))=="NEW_DAMAGE_EPOCH_TICKET_REQUIRED")
assert(select(2,budget:requestTarget("10:10",
    ticket.targetM,0.10,{id=ticket.ticket.id,key=ticket.ticket.key}))
    =="NEW_DAMAGE_EPOCH_TICKET_REQUIRED")

-- The observation produces a ticket but NEVER turns it into a heightmap
-- write. The preexisting separate research setter still requires
-- explicit opt-in and its own 3x3 native checks.
local denied=assert(C.new({
    journal=j,budget=budget,explicitWrite=false,
    writeHeight=function()error("must never be called")end,
    verifyExclusive=function()return true end
}))
assert(select(2,denied:applyOne(10,10,ticket.targetM,
    "CUMULATIVE",ticket.ticket))=="RESEARCH_WRITER_DISABLED")
assert(nativeWrites==2)

-- A new independent source is bounded, and the old virtual model is
-- never inserted. Clearing observation state does NOT clear the paid
-- recovery ledger or issue an epoch ticket.
source:clear()
assert(source.sourceCount==0 and next(source.sources)==nil)
assert(nativeWrites==2)

-- A new process gets only the persisted v3 geometry/recovery epoch, not
-- this old in-memory quantizer or old per-wheel model history. The first
-- actual server wheel sample bootstraps the blocked epoch WITHOUT
-- automatically authorizing a write.
local snapshot=assert(j:exportSnapshot())
local reloaded=J.new(999,{unitM=1,sample=read})
assert(reloaded:importSnapshot(snapshot))
assert(reloaded:getRecoveryFence("10:10").trusted)
local afterReloadBudget=assert(B.new({
    quantumM=q,clock=function()return now end
}))
local afterReloadSource=assert(Source.new({
    journal=reloaded,getBudget=function()return afterReloadBudget end,
    model=fakeModel
}))
local function reloadedSample(x)
    return afterReloadSource:observeServerWheel(
        vehicle,wheel,context,wide,x,10,150,options,1,0,path)
end
now=1004
assert(select(2,reloadedSample(10))
    =="PERSISTED_RECOVERY_FENCE_BOOTSTRAPPED")
assert(afterReloadBudget.entries["10:10"].recoveryEpochPending)
assert(select(2,afterReloadBudget:requestTarget("10:10",2*q,0.10))
    =="NEW_DAMAGE_EPOCH_REQUIRED_AFTER_RECOVERY")
now=1005
assert(select(2,reloadedSample(10))
    =="POST_RECOVERY_SOURCE_BASELINE")
now=1006
local postReloadTicket=assert(reloadedSample(10.3))
assert(postReloadTicket.doesNotWrite)
assert(afterReloadBudget.entries["10:10"].recoveryEpochPending==false)
assert(nativeWrites==2)

print("terrain_fresh_wheel_source_harness: OK")
