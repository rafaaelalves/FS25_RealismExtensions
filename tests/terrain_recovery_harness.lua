-- TerrainRecovery R3 closed-loop monotonic fill harness.
RealismExtensionsConfig = {
    modules = {TerrainDeformation=true,TerrainRecovery=true,SoilMassTransport=false}
}

local pending,cells,offsets = {},{},{}
local engineGain=40
local forceLower=false

local function hkey(x,z) return string.format("%.2f:%.2f",x,z) end
local function seedHistory(list)
    cells,offsets,pending={},{},{}
    for _,v in ipairs(list or {}) do
        local key=hkey(v.x,v.z)
        cells[key]={x=v.x,z=v.z,rutDepthM=v.rutDepthM,deformationExposure=1.0}
        -- Signed residual to the desired local plane: negative=hole, positive=mound.
        offsets[key]=-(v.physicalDeficitM or v.rutDepthM or 0)
    end
end

local historyApi={}
function historyApi:getRecoveryCandidatesParallelogram(xs,zs,xw,zw,xh,zh,options)
    local out={}
    for key,h in pairs(cells) do
        if (h.rutDepthM or 0)>=(options.minRutM or 0) then
            out[#out+1]={key=key,x=h.x,z=h.z,rutDepthM=h.rutDepthM}
        end
    end
    table.sort(out,function(a,b)
        if a.rutDepthM~=b.rutDepthM then return a.rutDepthM>b.rutDepthM end
        return a.x<b.x
    end)
    return out
end
function historyApi:get(x,z) return cells[hkey(x,z)] end
function historyApi:applyRecoveryAt(x,z,amount,options)
    local h=cells[hkey(x,z)]
    if h==nil then return 0 end
    local minRut=options~=nil and (options.minRutM or 0) or 0
    local rut=math.max(0,h.rutDepthM or 0)
    if rut<minRut then return 0 end
    local applied=math.min(rut,math.max(0,amount or 0))
    h.rutDepthM=rut-applied
    return applied
end

local writer={}
function writer:measureRecoveryAt(x,z,probeRadius)
    local residual=offsets[hkey(x,z)] or 0
    return {
        centerY=10+residual,
        referenceCenterY=10,
        centerDeficitM=math.max(0,-residual),
        centerResidualM=residual,
        roughnessM=math.abs(residual)*0.25,
        reliefRangeM=math.abs(residual),
        valleyDepthM=math.max(0,-residual),
        peakHeightM=math.max(0,residual),
        meanY=10,boundaryInlierRatio=1,planeAx=0,planeAz=0
    }
end
function writer:enqueue(brush)
    assert(brush.source=="RECOVERY" and brush.mode=="RAISE")
    assert(brush.raiseHeightM>=0.000019)
    assert(math.abs(brush.radiusM-0.30)<0.000001)
    pending[#pending+1]=brush
    return true
end

local function applyNext()
    assert(#pending>0)
    local brush=table.remove(pending,1)
    local key=hkey(brush.x,brush.z)
    local before=offsets[key] or 0
    local delta
    if forceLower then
        delta=-0.002
    else
        delta=brush.raiseHeightM*engineGain
    end
    local after=before+delta
    offsets[key]=after
    brush.onApplied(1,delta,10+before,10+after,0.01,{
        centerDeficitBeforeM=math.max(0,-before),
        centerDeficitAfterM=math.max(0,-after),
        centerResidualBeforeM=before,
        centerResidualAfterM=after,
        centerBeforeY=10+before,centerAfterY=10+after,
        referenceBeforeY=10,referenceAfterY=10,
        reliefBeforeM=math.abs(before),reliefAfterM=math.abs(after),
        roughnessBeforeM=math.abs(before)*0.25,
        roughnessAfterM=math.abs(after)*0.25,
        planeAxAfter=0,planeAzAfter=0
    })
end

RealismExtensionsTerrainRuntime={history=historyApi,writer=writer}
local perfBegins,perfFinishes=0,0
RealismExtensionsTerrainPerformance={
    begin=function() perfBegins=perfBegins+1 return perfBegins end,
    finish=function(name,started)
        assert(name=="recovery" and started~=nil)
        perfFinishes=perfFinishes+1
    end
}

g_currentMission={time=10000}
getWorldTranslation=function(node)
    if node==101 then return 0,0,0 end
    if node==102 then return 2,0,0 end
    if node==103 then return 0,0,1 end
    error("unexpected node")
end
Cultivator={}
SpecializationUtil={
    hasSpecialization=function() return true end,
    registerOverwrittenFunction=function() end
}
dofile("scripts/terrain/TerrainWorkContext.lua")
dofile("scripts/terrain/TerrainRecovery.lua")

local Recovery=RealismExtensionsTerrainRecovery
local rootVehicle={}
local vehicle={
    spec_cultivator={useDeepMode=false,isEnabled=true,isWorking=false},
    getRootVehicle=function(self) return rootVehicle end,
    getLastSpeed=function(self) return 8 end
}
local workArea={start=101,width=102,height=103}
local function workedSuper(self,wa,dt) self.spec_cultivator.isWorking=true return 12,12 end
local function repeatSuper(self,wa,dt) self.spec_cultivator.isWorking=true return 0,12 end
local function rejectedSuper(self,wa,dt) self.spec_cultivator.isWorking=false return 0,0 end

local function pump(limit)
    limit=limit or 200
    for _=1,limit do
        local d=Recovery.getDiagnostics()
        if d.deferredCount==0 and d.structuralInFlight==0 and #pending==0 then
            return
        end
        g_currentMission.time=g_currentMission.time+60
        Recovery.update(16)
        if #pending>0 then applyNext() end
    end
    error("pump did not converge")
end

-- 1. High-gain engine: two separate deep ruts converge without mounds.
seedHistory({
    {x=0.40,z=0.40,rutDepthM=0.090},
    {x=1.20,z=0.40,rutDepthM=0.070}
})
Recovery.resetRuntimeState()
engineGain=40
forceLower=false
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
assert(#pending==0)
assert(Recovery.getDiagnostics().deferredCount>=1)

g_currentMission.time=g_currentMission.time+60
Recovery.update(16)
assert(#pending==1)
local pendingBefore=#pending
Recovery.update(16)
assert(#pending==pendingBefore) -- globally serialized while callback is in flight
applyNext()
pump()

local d=Recovery.getDiagnostics()
assert(d.structuralCompleted>=2)
assert(d.structuralGainSamples>0)
assert(d.structuralObservedGainMax>30)
assert(d.structuralLoweringViolations==0)
assert(d.structuralMaxOvershootM<=0.004001)
assert((offsets[hkey(0.40,0.40)] or 0)<=0.004001)
assert((offsets[hkey(1.20,0.40)] or 0)<=0.004001)
assert((historyApi:get(0.40,0.40).rutDepthM or 0)<0.003)
assert((historyApi:get(1.20,0.40).rutDepthM or 0)<0.003)

-- 2. Close causal cells collapse into non-overlapping recovery centers.
seedHistory({
    {x=0.40,z=0.40,rutDepthM=0.050},
    {x=0.60,z=0.40,rutDepthM=0.045}
})
Recovery.resetRuntimeState()
g_currentMission.time=g_currentMission.time+1000
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
d=Recovery.getDiagnostics()
assert(d.intentCandidateCells==2)
assert(d.intentPoints==1)

-- 3. Stale logical debt on already-flat terrain retires with no actuator.
seedHistory({{x=0.40,z=0.40,rutDepthM=0.040,physicalDeficitM=0}})
Recovery.resetRuntimeState()
g_currentMission.time=g_currentMission.time+1000
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
pump()
d=Recovery.getDiagnostics()
assert(#pending==0)
assert(d.structuralPreflightNoDeficit==1)
assert(d.structuralCompleted==1)

-- 4. Any downward response remains a hard stop and consumes no continuation.
seedHistory({{x=0.40,z=0.40,rutDepthM=0.040}})
Recovery.resetRuntimeState()
forceLower=true
g_currentMission.time=g_currentMission.time+1000
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
g_currentMission.time=g_currentMission.time+60
Recovery.update(16)
assert(#pending==1)
applyNext()
d=Recovery.getDiagnostics()
assert(d.structuralLoweringViolations==1)
assert(d.deferredCount==0)
forceLower=false

-- 5. Loaded contact keeps the intent queued until the wheel clears.
seedHistory({{x=0.40,z=0.40,rutDepthM=0.030}})
Recovery.resetRuntimeState()
local blocked=true
RealismExtensionsLoadedContactRegistry={
    overlapsCircle=function(x,z,radius,nowMs)
        if blocked then return true,{loadN=32000} end
        return false,nil
    end
}
g_currentMission.time=g_currentMission.time+1000
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
g_currentMission.time=g_currentMission.time+60
Recovery.update(16)
assert(#pending==0 and Recovery.getDiagnostics().deferredCount==1)
blocked=false
pump()
assert((historyApi:get(0.40,0.40).rutDepthM or 0)<0.003)

-- 6. Repeat work remains valid; no causal history remains inert.
RealismExtensionsLoadedContactRegistry=nil
seedHistory({{x=0.40,z=0.40,rutDepthM=0.020}})
Recovery.resetRuntimeState()
g_currentMission.time=g_currentMission.time+1000
Recovery.processCultivatorArea(vehicle,repeatSuper,workArea,16)
assert(Recovery.getDiagnostics().repeatWorkAreaCalls>0)
pump()

seedHistory({})
Recovery.resetRuntimeState()
g_currentMission.time=g_currentMission.time+1000
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
assert(Recovery.getDiagnostics().intentCandidateCells==0)

-- 7. Inactive work area remains inert.
seedHistory({{x=0.40,z=0.40,rutDepthM=0.020}})
Recovery.resetRuntimeState()
g_currentMission.time=g_currentMission.time+1000
Recovery.processCultivatorArea(vehicle,rejectedSuper,workArea,16)
assert(Recovery.getDiagnostics().deferredCount==0)
assert(perfBegins==perfFinishes)

print("terrain_recovery_r3_closed_loop_harness: OK")
