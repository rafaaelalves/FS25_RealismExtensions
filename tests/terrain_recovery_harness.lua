-- TerrainRecovery v12 behavior harness.
RealismExtensionsConfig = { modules={TerrainDeformation=true,TerrainRecovery=true} }
RealismExtensionsTerrainRuntime = nil
RealismExtensionsTerrainPerformance = nil

local smoothCalls = 0
DensityMapHeightUtil = {
    getRoundedHeightValue=function(v) return v end,
    smoothAroundLine=function(node,width,radius,overlap,amount,raise)
        smoothCalls=smoothCalls+1
        assert(node==101)
        assert(width>0)
        assert(radius>0)
        assert(amount>0)
        assert(raise==true)
    end
}
getWorldTranslation=function(node)
    if node==101 then return 0,0,0 end
    if node==102 then return 4,0,0 end
    if node==103 then return 0,0,1 end
    error("unexpected node")
end
Cultivator={}
SpecializationUtil={
    hasSpecialization=function() return true end,
    registerOverwrittenFunction=function() end
}

dofile("scripts/terrain/TerrainRecovery.lua")

local vehicle={
    lastSpeedReal=2/3600,
    lastMovedDistance=0.10,
    spec_cultivator={useDeepMode=false}
}
local workArea={start=101,width=102,height=103}
local function workedSuper(self,wa,dt) return 12,12 end
local real,area=RealismExtensionsTerrainRecovery.processCultivatorArea(
    vehicle,workedSuper,workArea,16
)
assert(real==12 and area==12)
assert(smoothCalls==1)
local d=RealismExtensionsTerrainRecovery.getDiagnostics()
assert(d.workAreaCalls==1)
assert(d.workedAreaCalls==1)
assert(d.smoothingAttempts==1)
assert(d.smoothingCalls==1)
assert(d.smoothingErrors==0)

-- Native work rejection means no physical smoothing.
local function rejectedSuper(self,wa,dt) return 0,12 end
RealismExtensionsTerrainRecovery.processCultivatorArea(
    vehicle,rejectedSuper,workArea,16
)
assert(smoothCalls==1)
assert(RealismExtensionsTerrainRecovery.getDiagnostics().workedAreaCalls==1)

-- Below GIANTS-style movement threshold: work can occur, but no smoothing.
vehicle.lastSpeedReal=0.5/3600
RealismExtensionsTerrainRecovery.processCultivatorArea(
    vehicle,workedSuper,workArea,16
)
assert(smoothCalls==1)
assert(RealismExtensionsTerrainRecovery.getDiagnostics().workedAreaCalls==2)

print("terrain_recovery_harness: OK")
