-- TerrainRecovery R5 bounded local target-plane harness.
RealismExtensionsConfig = {
    modules = {TerrainDeformation=true,TerrainRecovery=true,SoilMassTransport=false}
}

local pending,cells,residuals = {},{},{}
local targetFraction=0.80
local forceTargetNoop=false
local targetCalls=0
local seenTargetAmounts={}

local function hkey(x,z) return string.format("%.2f:%.2f",x,z) end
local function seedHistory(list)
    cells,residuals,pending={},{},{}
    targetCalls=0
    seenTargetAmounts={}
    for _,v in ipairs(list or {}) do
        local key=hkey(v.x,v.z)
        cells[key]={x=v.x,z=v.z,rutDepthM=v.rutDepthM,deformationExposure=1.0}
        residuals[key]=v.residualM ~= nil
            and v.residualM
            or -(v.physicalDeficitM or v.rutDepthM or 0)
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
    local residual=residuals[hkey(x,z)] or 0
    return {
        centerY=10+residual,
        referenceCenterY=10,
        centerDeficitM=math.max(0,-residual),
        centerResidualM=residual,
        roughnessM=math.abs(residual)*0.25,
        reliefRangeM=math.abs(residual),
        valleyDepthM=math.max(0,-residual),
        peakHeightM=math.max(0,residual),
        meanY=10,
        boundaryInlierRatio=1,
        planeAx=0.015,
        planeAz=-0.010
    }
end
function writer:enqueue(brush)
    assert(brush.source=="RECOVERY")
    assert(brush.mode=="TARGET")
    assert(math.abs(brush.targetY-10)<0.000001)
    assert(math.abs(brush.targetPlaneAx-0.015)<0.000001)
    assert(math.abs(brush.targetPlaneAz+0.010)<0.000001)
    assert(brush.targetAmount>=0.75 and brush.targetAmount<=1.000001)
    assert(math.abs(brush.radiusM-0.40)<0.000001)
    assert(math.abs(brush.hardness-0.20)<0.000001)
    assert(math.abs(brush.strength-0.35)<0.000001)
    pending[#pending+1]=brush
    seenTargetAmounts[#seenTargetAmounts+1]=brush.targetAmount
    return true
end

local function applyNext()
    assert(#pending>0)
    local brush=table.remove(pending,1)
    local key=hkey(brush.x,brush.z)
    local before=residuals[key] or 0
    local delta=0
    if not forceTargetNoop then
        -- Set-target semantics: move toward zero residual and never cross it.
        delta=-before*targetFraction
    end
    local after=before+delta
    residuals[key]=after
    targetCalls=targetCalls+1
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
        peakBeforeM=math.max(0,before),
        peakAfterM=math.max(0,after),
        planeAxAfter=0.015,planeAzAfter=-0.010
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
    limit=limit or 500
    for _=1,limit do
        local d=Recovery.getDiagnostics()
        if d.deferredCount==0 and d.structuralInFlight==0 and #pending==0 then
            return
        end
        g_currentMission.time=g_currentMission.time+100
        Recovery.update(16)
        if #pending>0 then applyNext() end
    end
    error("pump did not converge")
end

-- 1. Deep causal rut converges to the current local sloped reference plane
-- using TARGET only; no additive raise/smooth state is required.
seedHistory({{x=0.40,z=0.40,rutDepthM=0.090}})
Recovery.resetRuntimeState()
targetFraction=0.80
forceTargetNoop=false
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
pump()
local d=Recovery.getDiagnostics()
assert(targetCalls>=2)
assert(d.targetPlaneApplied==targetCalls)
assert(d.targetPlaneCompleted>=1)
assert(d.targetPlaneImproved>=1)
assert(d.targetPlaneWorsened==0)
assert(d.targetPlaneMaxAbsAfterM < d.targetPlaneMaxAbsBeforeM)
assert(math.abs(residuals[hkey(0.40,0.40)] or 0)<=0.004001)
assert((historyApi:get(0.40,0.40).rutDepthM or 0)<0.003)

-- 2. An initial positive mound with stale rut history is not touched. Positive
-- correction is only allowed after a target sequence started from a causal rut.
seedHistory({{x=0.40,z=0.40,rutDepthM=0.030,residualM=0.020}})
Recovery.resetRuntimeState()
g_currentMission.time=g_currentMission.time+1000
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
pump()
d=Recovery.getDiagnostics()
assert(targetCalls==0)
assert(d.targetPlaneInitialPositiveSkips==1)
assert(math.abs((residuals[hkey(0.40,0.40)] or 0)-0.020)<0.000001)

-- 3. A target no-op escalates actuator intensity from TerraFarm's 0.75 toward
-- 1.0 rather than switching back to additive RAISE.
seedHistory({{x=0.40,z=0.40,rutDepthM=0.030}})
Recovery.resetRuntimeState()
g_currentMission.time=g_currentMission.time+1000
forceTargetNoop=true
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
g_currentMission.time=g_currentMission.time+100
Recovery.update(16)
assert(#pending==1)
applyNext()
forceTargetNoop=false
pump()
d=Recovery.getDiagnostics()
assert(d.targetPlaneNoop>=1)
assert(#seenTargetAmounts>=2)
assert(seenTargetAmounts[2]>seenTargetAmounts[1])
assert(d.targetPlaneCompleted>=1)

-- 4. Loaded wheel keeps the causal patch queued until contact clears.
seedHistory({{x=0.40,z=0.40,rutDepthM=0.020}})
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
g_currentMission.time=g_currentMission.time+100
Recovery.update(16)
assert(#pending==0 and Recovery.getDiagnostics().deferredCount==1)
blocked=false
pump()

-- 5. Repeat work remains valid; no causal history remains inert.
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

-- 6. Inactive work area remains inert.
seedHistory({{x=0.40,z=0.40,rutDepthM=0.020}})
Recovery.resetRuntimeState()
g_currentMission.time=g_currentMission.time+1000
Recovery.processCultivatorArea(vehicle,rejectedSuper,workArea,16)
assert(Recovery.getDiagnostics().deferredCount==0)
assert(perfBegins==perfFinishes)

print("terrain_recovery_r5_target_plane_harness: OK")
