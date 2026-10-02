-- TerrainRecovery v13 behavior harness.
RealismExtensionsConfig = { modules={TerrainDeformation=true,TerrainRecovery=true} }

local relaxedCalls = 0
RealismExtensionsTerrainRuntime = {
    history = {
        recoverParallelogram=function(self,xs,zs,xw,zw,xh,zh,options,callback)
            relaxedCalls=relaxedCalls+1
            assert(options.maxRaiseM>0)
            callback(0,0,math.min(0.005,options.maxRaiseM))
            return 1,math.min(0.005,options.maxRaiseM)
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

local smoothCalls = 0
local terrainHeight = 1.0
DensityMapHeightUtil = {
    getRoundedHeightValue=function(v) return v end,
    smoothAroundLine=function(node,width,radius,overlap,amount,...)
        smoothCalls=smoothCalls+1
        assert(node==101)
        assert(math.abs(width-4.0)<0.000001)
        assert(radius>0)
        assert(amount>0)
        assert(select("#",...)==0)
        terrainHeight=terrainHeight+0.002
    end
}
g_currentMission={terrainRootNode=999,time=10000}
getTerrainHeightAtWorldPos=function(terrain,x,y,z)
    assert(terrain==999)
    return terrainHeight
end
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
assert(relaxedCalls==1)
assert(perfBegins==1 and perfFinishes==1)
local d=RealismExtensionsTerrainRecovery.getDiagnostics()
assert(d.workAreaCalls==1)
assert(d.workedAreaCalls==1)
assert(d.smoothingAttempts==1)
assert(d.smoothingCalls==1)
assert(d.smoothingErrors==0)
assert(d.physicalProbeCalls==1)
assert(d.physicalProbeSamples==5)
assert(d.physicalChangedCalls==1)
assert(d.physicalNoChangeCalls==0)
assert(d.physicalUnverifiedCalls==0)
assert(d.physicalChangedSamples==5)
assert(d.physicalMaxDeltaM>0.0019)

-- Native call success without a height change is not physical recovery and
-- must not relax the RE history.
DensityMapHeightUtil.smoothAroundLine=function(node,width,radius,overlap,amount)
    smoothCalls=smoothCalls+1
end
RealismExtensionsTerrainRecovery.processCultivatorArea(
    vehicle,workedSuper,workArea,16
)
assert(smoothCalls==2)
assert(relaxedCalls==1)
d=RealismExtensionsTerrainRecovery.getDiagnostics()
assert(d.physicalChangedCalls==1)
assert(d.physicalNoChangeCalls==1)
assert(perfBegins==2 and perfFinishes==2)

-- Native work rejection means no physical smoothing and no RE perf sample.
local function rejectedSuper(self,wa,dt) return 0,12 end
RealismExtensionsTerrainRecovery.processCultivatorArea(
    vehicle,rejectedSuper,workArea,16
)
assert(smoothCalls==2)
assert(RealismExtensionsTerrainRecovery.getDiagnostics().workedAreaCalls==2)
assert(perfBegins==2 and perfFinishes==2)

-- Below GIANTS-style movement threshold: work can occur, but no smoothing.
vehicle.lastSpeedReal=0.5/3600
RealismExtensionsTerrainRecovery.processCultivatorArea(
    vehicle,workedSuper,workArea,16
)
assert(smoothCalls==2)
assert(RealismExtensionsTerrainRecovery.getDiagnostics().workedAreaCalls==3)
assert(perfBegins==3 and perfFinishes==3)

print("terrain_recovery_harness: OK")
