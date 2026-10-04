-- TerrainRecovery R2 monotonic causal-fill harness.
RealismExtensionsConfig = {
    modules = {TerrainDeformation=true,TerrainRecovery=true,SoilMassTransport=false}
}

local enqueued,cells,physicalDeficit = {},{},{}
local exactRecoveryDepth=0
local callbackMode="NORMAL"
local function hkey(x,z) return string.format("%.2f:%.2f",x,z) end
local function seedHistory(list)
    cells,physicalDeficit={},{}
    exactRecoveryDepth=0
    for _,v in ipairs(list or {}) do
        local key=hkey(v.x,v.z)
        cells[key]={x=v.x,z=v.z,rutDepthM=v.rutDepthM,deformationExposure=1.0}
        physicalDeficit[key]=v.physicalDeficitM or v.rutDepthM or 0
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
    table.sort(out,function(a,b) return a.x<b.x end)
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
    exactRecoveryDepth=exactRecoveryDepth+applied
    return applied
end

local writer={}
function writer:measureRecoveryAt(x,z,probeRadius)
    local d=math.max(0,physicalDeficit[hkey(x,z)] or 0)
    return {
        centerY=10-d,referenceCenterY=10,centerDeficitM=d,centerResidualM=-d,
        roughnessM=d*0.25,reliefRangeM=d,valleyDepthM=d,peakHeightM=0,
        meanY=10,boundaryInlierRatio=1,planeAx=0,planeAz=0
    }
end
function writer:enqueue(brush)
    enqueued[#enqueued+1]=brush
    assert(brush.source=="RECOVERY" and brush.mode=="RAISE")
    assert(brush.raiseHeightM>0 and brush.raiseHeightM<=0.040001)
    assert(math.abs(brush.radiusM-0.35)<0.000001)
    assert(math.abs(brush.hardness-0.55)<0.000001)
    assert(math.abs(brush.strength-1.0)<0.000001)
    assert(brush.probeRadiusM>1.0)
    local key=hkey(brush.x,brush.z)
    local before=math.max(0,physicalDeficit[key] or 0)
    local delta
    if callbackMode=="LOWERING" then
        delta=-0.002
        physicalDeficit[key]=before+0.002
    else
        delta=math.min(before,brush.raiseHeightM)
        physicalDeficit[key]=math.max(0,before-delta)
    end
    local after=physicalDeficit[key]
    brush.onApplied(1,delta,10-before,10-before+delta,0.01,{
        centerDeficitBeforeM=before,centerDeficitAfterM=after,
        centerBeforeY=10-before,centerAfterY=10-after,
        referenceBeforeY=10,referenceAfterY=10,
        reliefBeforeM=before,reliefAfterM=after,
        roughnessBeforeM=before*0.25,roughnessAfterM=after*0.25,
        planeAxAfter=0,planeAzAfter=0
    })
    return true
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

-- 1. Shallow causal holes fill upward directly; no detector SMOOTH.
seedHistory({{x=0.40,z=0.40,rutDepthM=0.020},{x=1.20,z=0.40,rutDepthM=0.015}})
Recovery.resetRuntimeState()
callbackMode="NORMAL"
local before=#enqueued
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
assert(#enqueued==before+2)
for i=before+1,#enqueued do assert(enqueued[i].mode=="RAISE") end
local d=Recovery.getDiagnostics()
assert(d.structuralCompleted>=2)
assert(d.structuralCenterRaisedM>0.034)
assert(d.centerRaised>=2 and d.centerLowered==0)
assert(d.structuralLoweringViolations==0)
assert((historyApi:get(0.40,0.40).rutDepthM or 0)<0.003)
assert((historyApi:get(1.20,0.40).rutDepthM or 0)<0.003)

-- 2. realArea=0 but processed area remains physical work.
seedHistory({{x=0.40,z=0.40,rutDepthM=0.020}})
Recovery.resetRuntimeState()
g_currentMission.time=12000
before=#enqueued
Recovery.processCultivatorArea(vehicle,repeatSuper,workArea,16)
assert(#enqueued==before+1)
d=Recovery.getDiagnostics()
assert(d.repeatWorkAreaCalls>0 and d.physicalWorkAreaCalls>0)

-- 3. Deep rut converges with bounded upward pulses only.
seedHistory({{x=0.40,z=0.40,rutDepthM=0.090}})
Recovery.resetRuntimeState()
g_currentMission.time=14000
before=#enqueued
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
assert(#enqueued==before+1)
assert(math.abs(physicalDeficit[hkey(0.40,0.40)]-0.050)<0.000001)
assert(Recovery.getDiagnostics().deferredCount==1)
g_currentMission.time=14160
Recovery.update(16)
assert(#enqueued==before+2)
assert(math.abs(physicalDeficit[hkey(0.40,0.40)]-0.010)<0.000001)
g_currentMission.time=14320
Recovery.update(16)
assert(#enqueued==before+3)
d=Recovery.getDiagnostics()
assert(physicalDeficit[hkey(0.40,0.40)]<=0.003)
assert(d.deferredCount==0 and d.structuralCompleted>=1)
assert(d.structuralLoweringViolations==0)
assert((historyApi:get(0.40,0.40).rutDepthM or 0)<0.003)

-- 4. Stale logical debt with no physical low point retires without editing.
seedHistory({{x=0.40,z=0.40,rutDepthM=0.040,physicalDeficitM=0.001}})
Recovery.resetRuntimeState()
g_currentMission.time=16000
before=#enqueued
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
d=Recovery.getDiagnostics()
assert(#enqueued==before)
assert(d.structuralPreflightNoDeficit==1 and d.structuralCompleted==1)
assert((historyApi:get(0.40,0.40).rutDepthM or 0)<0.003)

-- 5. Any downward result is a hard safety violation and consumes no ownership.
seedHistory({{x=0.40,z=0.40,rutDepthM=0.040}})
Recovery.resetRuntimeState()
callbackMode="LOWERING"
g_currentMission.time=18000
before=#enqueued
local debtBefore=historyApi:get(0.40,0.40).rutDepthM
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
d=Recovery.getDiagnostics()
assert(#enqueued==before+1)
assert(d.structuralLoweringViolations==1 and d.centerLowered==1)
assert(d.deferredCount==0)
assert(math.abs(historyApi:get(0.40,0.40).rutDepthM-debtBefore)<0.000001)

-- 6. Loaded wheel defers; clearing it resumes same causal fill.
callbackMode="NORMAL"
seedHistory({{x=0.40,z=0.40,rutDepthM=0.020}})
Recovery.resetRuntimeState()
g_currentMission.time=20000
local blocked=true
RealismExtensionsLoadedContactRegistry={
    overlapsCircle=function(x,z,radius,nowMs)
        if blocked then return true,{loadN=32000} end
        return false,nil
    end
}
before=#enqueued
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
assert(#enqueued==before)
d=Recovery.getDiagnostics()
assert(d.deferredCount==1 and d.structuralScheduled>=1)
blocked=false
g_currentMission.time=20160
Recovery.update(16)
assert(#enqueued==before+1)
d=Recovery.getDiagnostics()
assert(d.deferredCount==0 and d.structuralCompleted>=1)

-- 7. No causal history => no arbitrary landscaping repair.
RealismExtensionsLoadedContactRegistry=nil
seedHistory({})
Recovery.resetRuntimeState()
g_currentMission.time=22000
before=#enqueued
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
assert(#enqueued==before)
d=Recovery.getDiagnostics()
assert(d.intentCandidateCells==0 and d.intentEmptyWorkAreas>0)

-- 8. Inactive work area remains inert.
seedHistory({{x=0.40,z=0.40,rutDepthM=0.020}})
Recovery.resetRuntimeState()
g_currentMission.time=24000
before=#enqueued
Recovery.processCultivatorArea(vehicle,rejectedSuper,workArea,16)
assert(#enqueued==before)
assert(perfBegins==perfFinishes)

print("terrain_recovery_r2_monotonic_fill_harness: OK")
