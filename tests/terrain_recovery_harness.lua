-- TerrainRecovery v14 behavior harness.
RealismExtensionsConfig = { modules={TerrainDeformation=true,TerrainRecovery=true} }

local appliedRecovery = 0
local enqueued = {}
local candidateSet = {
    {key="1:1",x=0.20,z=0.20,rutDepthM=0.10},
    {key="2:1",x=0.40,z=0.20,rutDepthM=0.06},
    {key="8:1",x=1.60,z=0.20,rutDepthM=0.04}
}

RealismExtensionsTerrainRuntime = {
    history = {
        getRecoveryCandidatesParallelogram=function(self,xs,zs,xw,zw,xh,zh,options)
            assert(options.maxCells > 0)
            assert(options.minRutM > 0)
            return candidateSet
        end,
        applyRecoveryAt=function(self,x,z,raiseM,options)
            assert(raiseM > 0)
            appliedRecovery = appliedRecovery + raiseM
            return raiseM
        end
    },
    writer = {
        enqueue=function(self,brush)
            enqueued[#enqueued+1]=brush
            assert(brush.mode=="SMOOTH")
            assert(brush.source=="RECOVERY")
            assert(brush.smoothAmountM>0)
            assert(brush.radiusM>0)
            assert(brush.strength>0 and brush.strength<=1)
            brush.onApplied(1,0.004,1.000,1.004,0.01)
            return true
        end
    }
}

local perfBegins,perfFinishes=0,0
RealismExtensionsTerrainPerformance = {
    begin=function() perfBegins=perfBegins+1 return perfBegins end,
    finish=function(name,started)
        assert(name=="recovery")
        assert(started~=nil)
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

dofile("scripts/terrain/TerrainRecovery.lua")

local vehicle={spec_cultivator={useDeepMode=false}}
local workArea={start=101,width=102,height=103}
local function workedSuper(self,wa,dt) return 12,12 end

local real,area=RealismExtensionsTerrainRecovery.processCultivatorArea(
    vehicle,workedSuper,workArea,16
)
assert(real==12 and area==12)
assert(#enqueued>=2)
assert(appliedRecovery>0)
assert(perfBegins==1 and perfFinishes==1)

local d=RealismExtensionsTerrainRecovery.getDiagnostics()
assert(d.workAreaCalls==1)
assert(d.workedAreaCalls==1)
assert(d.candidateCells==3)
assert(d.selectedCells==#enqueued)
assert(d.brushesEnqueued==#enqueued)
assert(d.callbacks==#enqueued)
assert(d.physicalChanged==#enqueued)
assert(d.physicalRaisedSamples==#enqueued)
assert(d.historyRecoveredCells==#enqueued)
assert(d.historyRecoveredDepthM>0)

-- A successful smoothing callback that does not move the terrain must not
-- reconcile logical rut history.
candidateSet={{key="20:1",x=4.0,z=0.2,rutDepthM=0.10}}
RealismExtensionsTerrainRuntime.writer.enqueue=function(self,brush)
    enqueued[#enqueued+1]=brush
    brush.onApplied(1,0.0,1.0,1.0,0)
    return true
end
local beforeApplied=appliedRecovery
RealismExtensionsTerrainRecovery.processCultivatorArea(
    vehicle,workedSuper,workArea,16
)
assert(appliedRecovery==beforeApplied)
d=RealismExtensionsTerrainRecovery.getDiagnostics()
assert(d.physicalNoChange>=1)

-- Smoothing may lower a ridge; that is physical work but not rut healing.
candidateSet={{key="21:1",x=4.2,z=0.2,rutDepthM=0.10}}
RealismExtensionsTerrainRuntime.writer.enqueue=function(self,brush)
    enqueued[#enqueued+1]=brush
    brush.onApplied(1,-0.003,1.0,0.997,0)
    return true
end
beforeApplied=appliedRecovery
RealismExtensionsTerrainRecovery.processCultivatorArea(
    vehicle,workedSuper,workArea,16
)
assert(appliedRecovery==beforeApplied)
d=RealismExtensionsTerrainRecovery.getDiagnostics()
assert(d.physicalLoweredSamples>=1)

-- Base cultivator rejection means recovery does no work and is not timed.
local beforeEnqueued=#enqueued
local beforePerf=perfBegins
local function rejectedSuper(self,wa,dt) return 0,12 end
RealismExtensionsTerrainRecovery.processCultivatorArea(
    vehicle,rejectedSuper,workArea,16
)
assert(#enqueued==beforeEnqueued)
assert(perfBegins==beforePerf)

print("terrain_recovery_harness: OK")
