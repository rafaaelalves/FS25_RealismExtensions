-- TerrainRecovery v22 physical-work-state harness.
RealismExtensionsConfig = { modules={TerrainDeformation=true,TerrainRecovery=true,SoilMassTransport=false} }

local enqueued = {}
local historyCells, historyDepth = 0, 0
RealismExtensionsTerrainRuntime = {
    history = {
        applyRecoveryCircle=function(self,x,z,radius,amount,fraction,options)
            assert(radius > 0 and amount > 0 and fraction > 0)
            historyCells = historyCells + 2
            historyDepth = historyDepth + amount
            return 2, amount
        end
    },
    writer = {
        enqueue=function(self,brush)
            enqueued[#enqueued+1]=brush
            assert(brush.mode=="SMOOTH" and brush.source=="RECOVERY")
            assert(math.abs(brush.smoothAmountM-0.05)<0.000001)
            assert(math.abs(brush.radiusM-2.0)<0.000001)
            assert(math.abs(brush.hardness-0.20)<0.000001)
            assert(math.abs(brush.strength-0.50)<0.000001)
            assert(brush.probeRadiusM>0)
            brush.onApplied(1,-0.002,1.0,0.998,0,{
                roughnessBeforeM=0.020,
                roughnessAfterM=0.012,
                roughnessDeltaM=0.008
            })
            return true
        end
    }
}

local perfBegins,perfFinishes=0,0
RealismExtensionsTerrainPerformance = {
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

dofile("scripts/terrain/TerrainRecovery.lua")
local rootVehicle={}
local vehicle={
    spec_cultivator={useDeepMode=false,isEnabled=true,isWorking=false},
    getRootVehicle=function(self) return rootVehicle end,
    getLastSpeed=function(self) return 8 end
}
local workArea={start=101,width=102,height=103}
local function workedSuper(self,wa,dt)
    self.spec_cultivator.isWorking=true
    return 12,12
end
local function repeatSuper(self,wa,dt)
    self.spec_cultivator.isWorking=true
    return 0,12
end

RealismExtensionsTerrainRecovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
assert(#enqueued > 0)
local firstCount=#enqueued
local d=RealismExtensionsTerrainRecovery.getDiagnostics()
assert(d.coveragePoints >= firstCount)
assert(d.roughnessImproved == firstCount)
assert(d.centerLowered == firstCount)
assert(d.historyRecoveredCells > 0 and d.historyRecoveredDepthM > 0)
assert(d.protectedCellsMarked > 0)
assert(d.activeCombinationMarks > 0)
assert(RealismExtensionsTerrainRecovery.isRutGenerationSuppressed(rootVehicle,10000)==true)
assert(RealismExtensionsTerrainRecovery.isRutGenerationSuppressed(rootVehicle,11501)==false)
assert(RealismExtensionsTerrainRecovery.isRecentlyCultivated(1.0,0.5,10000)==true)
assert(RealismExtensionsTerrainRecovery.isRecentlyCultivated(1.0,0.5,19001)==false)

-- Repeated pass over already-cultivated ground reports realArea=0 but
-- area>0. It must still mark the combination active and keep recovery alive.
g_currentMission.time=10800
local beforeRepeat=#enqueued
RealismExtensionsTerrainRecovery.processCultivatorArea(vehicle,repeatSuper,workArea,16)
assert(#enqueued > beforeRepeat)
d=RealismExtensionsTerrainRecovery.getDiagnostics()
assert(d.repeatWorkAreaCalls > 0)
assert(d.areaPositiveCalls > 0)
assert(d.physicalWorkAreaCalls > 0)
assert(d.preSuperActiveMarks > 0)
assert(d.processedAreaUnits >= 24)
assert(d.changedAreaUnits == 12)
assert(d.repeatAreaUnits >= 12)
assert(RealismExtensionsTerrainRecovery.isRutGenerationSuppressed(rootVehicle,10800)==true)

-- Same immediate physical patch must still obey the stamp cooldown.
local repeatCount=#enqueued
RealismExtensionsTerrainRecovery.processCultivatorArea(vehicle,repeatSuper,workArea,16)
assert(#enqueued == repeatCount)
d=RealismExtensionsTerrainRecovery.getDiagnostics()
assert(d.stampSkips > 0)

-- A later pass can work the same ground again, but worsening relief never
-- reconciles logical rut history.
g_currentMission.time=16000
local beforeHistory=historyDepth
RealismExtensionsTerrainRuntime.writer.enqueue=function(self,brush)
    enqueued[#enqueued+1]=brush
    brush.onApplied(1,-0.001,1.0,0.999,0,{
        roughnessBeforeM=0.012,
        roughnessAfterM=0.015,
        roughnessDeltaM=-0.003
    })
    return true
end
RealismExtensionsTerrainRecovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
assert(#enqueued > firstCount)
assert(historyDepth == beforeHistory)
d=RealismExtensionsTerrainRecovery.getDiagnostics()
assert(d.roughnessWorsened > 0)

local beforeEnqueued=#enqueued
local function rejectedSuper(self,wa,dt)
    self.spec_cultivator.isWorking=false
    return 0,0
end
RealismExtensionsTerrainRecovery.processCultivatorArea(vehicle,rejectedSuper,workArea,16)
assert(#enqueued==beforeEnqueued)
assert(perfBegins==perfFinishes)
print("terrain_recovery_v22_physical_work_state_harness: OK")
