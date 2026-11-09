-- Event-driven passive terrain maintenance integration harness.

RealismExtensionsConfig={
    modules={
        TerrainDeformation=true,
        TerrainRecovery=true,
        TerrainMaintenance=true
    }
}

g_server={}
g_currentMission={
    time=1000,
    getFarmId=function() return 7 end
}

FarmlandManager={
    NO_OWNER_FARM_ID=0,
    NOT_BUYABLE_FARM_ID=255
}

local function landAt(x,z)
    if x < 5 then return 3 end       -- NPC field
    if x < 15 then return 0 end      -- public world
    if x < 25 then return 1 end      -- player farm
    return 4                         -- unowned buyable
end

local owners={[1]=7,[3]=0,[4]=0}
g_farmlandManager={
    getFarmlandIdAtWorldPosition=function(self,x,z) return landAt(x,z) end,
    getFarmlandOwner=function(self,id) return owners[id] or 0 end
}
g_fieldManager={
    farmlandIdFieldMapping={
        [3]={getHasOwner=function() return false end}
    }
}

MessageType={PERIOD_CHANGED=101}
local subscriptions={}
g_messageCenter={
    subscribe=function(self,messageType,callback,target)
        subscriptions[messageType]={callback=callback,target=target}
    end,
    unsubscribe=function(self,messageType,target)
        if subscriptions[messageType]~=nil
            and subscriptions[messageType].target==target then
            subscriptions[messageType]=nil
        end
    end
}

RealismExtensionsLoadedContactRegistry={
    block=false,
    overlapsCircle=function(x,z,radius,nowMs)
        return RealismExtensionsLoadedContactRegistry.block,nil
    end
}

RealismExtensionsTerrainSurfaceResponse={
    isMunicipalMaintenanceSurface=function(x,z)
        -- Public x=10 is an eligible dirt/gravel road in this harness.
        return x >= 5 and x < 15,{category="DIRT",name="dirt"}
    end
}

dofile("scripts/terrain/SpatialHistory.lua")
dofile("scripts/terrain/TerrainMaintenancePolicy.lua")

local history=RealismExtensionsSpatialHistory.new({
    cellSizeM=0.20,
    maxCells=1000
})

local heights={}
local function hk(x,z)
    return string.format("%.1f:%.1f",x,z)
end
local function seed(x,z,rut,age)
    history:commit(x,z,{
        rutDepthM=rut,
        deformationExposure=1.0,
        maintenanceAgePeriods=age or 0
    })
    heights[hk(x,z)]=10-rut
end

-- NPC, public, player-owned, and unowned-buyable damage.
seed(0,0,0.030,0)
seed(10,0,0.025,1)
seed(20,0,0.040,5)
seed(30,0,0.050,5)

local writer={queued=0,applied={}}
function writer:getQueueSize() return self.queued end
function writer:measureRecoveryAt(x,z,radius)
    local y=heights[hk(x,z)] or 10
    local residual=y-10
    return {
        centerY=y,
        referenceCenterY=10,
        centerResidualM=residual,
        centerDeficitM=math.max(0,-residual),
        planeAx=0,
        planeAz=0,
        boundaryInlierRatio=1,
        roughnessM=math.abs(residual),
        reliefRangeM=math.abs(residual),
        valleyDepthM=math.max(0,-residual),
        peakHeightM=math.max(0,residual),
        meanY=10
    }
end
function writer:sampleHeightAt(x,z)
    return heights[hk(x,z)] or 10
end
function writer:enqueue(brush)
    assert(brush.mode=="TARGET")
    assert(brush.source=="MAINTENANCE")
    self.queued=self.queued+1
    self.applied[#self.applied+1]={x=brush.x,z=brush.z}
    local before=heights[hk(brush.x,brush.z)] or 10
    local after=brush.targetY
    heights[hk(brush.x,brush.z)]=after
    self.queued=self.queued-1
    brush.onApplied(
        1,
        after-before,
        before,
        after,
        0.01,
        {
            centerResidualAfterM=0,
            centerDeficitAfterM=0
        }
    )
    return true
end

RealismExtensionsTerrainRuntime={
    history=history,
    writer=writer
}
RealismExtensionsTerrainRecovery={
    getDiagnostics=function() return {structuralInFlight=0} end
}

dofile("scripts/terrain/TerrainMaintenance.lua")
local M=RealismExtensionsTerrainMaintenance

assert(M.initialize()==true)
assert(subscriptions[MessageType.PERIOD_CHANGED]~=nil)

-- Period 1:
-- NPC age 0->1 becomes eligible immediately.
-- Public age 1->2 becomes eligible.
-- Player/unowned cells age but are never queued.
subscriptions[MessageType.PERIOD_CHANGED].callback(
    subscriptions[MessageType.PERIOD_CHANGED].target,
    2
)

local d=M.getDiagnostics()
assert(d.periods==1)
assert(d.historyScanned==4)
assert(d.eligibleNeighborCells==1)
assert(d.eligibleMunicipalCells==1)
assert(d.pending==2)

-- Execute amortized tasks through ordinary update calls.
for i=1,10 do
    g_currentMission.time=g_currentMission.time+100
    M.update(16)
end

d=M.getDiagnostics()
assert(d.targetApplied==2)
assert(d.neighborCompleted==1)
assert(d.municipalCompleted==1)
assert(d.pending==0)
assert(history:get(0,0)==nil)
assert(history:get(10,0)==nil)

-- Player land and unowned buyable land remain untouched despite being older.
assert(history:get(20,0)~=nil)
assert(math.abs(history:get(20,0).rutDepthM-0.040)<0.000001)
assert(history:get(30,0)~=nil)
assert(math.abs(history:get(30,0).rutDepthM-0.050)<0.000001)

-- New traffic resets age; next period only increments it to one. Public
-- maintenance requires two periods, so it must not disappear immediately.
seed(10,0,0.020,0)
subscriptions[MessageType.PERIOD_CHANGED].callback(
    subscriptions[MessageType.PERIOD_CHANGED].target,
    3
)
d=M.getDiagnostics()
assert(d.eligibleMunicipalCells==1) -- cumulative; no new municipal eligibility
assert(history:get(10,0).maintenanceAgePeriods==1)

-- Loaded contact blocks an eligible NPC task instead of grading under a wheel.
seed(0,0,0.020,0)
subscriptions[MessageType.PERIOD_CHANGED].callback(
    subscriptions[MessageType.PERIOD_CHANGED].target,
    4
)
RealismExtensionsLoadedContactRegistry.block=true
local beforeBlocked=M.getDiagnostics().blockedContacts
g_currentMission.time=g_currentMission.time+100
M.update(16)
assert(M.getDiagnostics().blockedContacts==beforeBlocked+1)
assert(history:get(0,0)~=nil)
RealismExtensionsLoadedContactRegistry.block=false

-- The blocked task is delayed rather than busy-looped; once its retry delay
-- expires it may complete.
g_currentMission.time=g_currentMission.time+1000
for i=1,5 do M.update(16) end
assert(history:get(0,0)==nil)

M.shutdown()
assert(subscriptions[MessageType.PERIOD_CHANGED]==nil)
print("terrain_maintenance_harness: OK")
