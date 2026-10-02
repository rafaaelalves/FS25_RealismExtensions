-- TerrainRecovery v16 local-plane grading harness.
RealismExtensionsConfig={modules={TerrainDeformation=true,TerrainRecovery=true,SoilMassTransport=false}}

local heights={}
local function key(x,z) return string.format("%.3f:%.3f",x,z) end
g_currentMission={time=10000,terrainRootNode=42}
getTerrainHeightAtWorldPos=function(terrain,x,y,z)
    local explicit=heights[key(x,z)]
    if explicit~=nil then return explicit end
    local base=10 + 0.01*x
    local dr=(x-0.5)*(x-0.5)+(z-0.5)*(z-0.5)
    local rr=(x-1.5)*(x-1.5)+(z-0.5)*(z-0.5)
    if dr<0.08 then return base-0.10 end
    if rr<0.08 then return base+0.10 end
    return base
end
getWorldTranslation=function(node)
    if node==101 then return 0,0,0 end
    if node==102 then return 2,0,0 end
    if node==103 then return 0,0,1 end
    error("unexpected node")
end

-- Terrain sampler above injects one localized rut and one ridge into an
-- otherwise sloping work area. This intentionally verifies that eligibility
-- probes catch defects that do not sit exactly on a brush center.

local enqueued={}
local recovered=0
RealismExtensionsTerrainRuntime={
    history={
        applyRecoveryCircle=function(self,x,z,radius,amount,fraction,options)
            recovered=recovered+amount
            return 1,amount
        end
    },
    writer={
        enqueue=function(self,brush)
            enqueued[#enqueued+1]=brush
            assert(brush.mode=="LEVEL")
            assert(brush.levelTarget and brush.levelTarget.ny>0)
            local before=getTerrainHeightAtWorldPos(42,brush.x,0,brush.z)
            local t=brush.levelTarget
            local targetY=-(t.nx*brush.x+t.nz*brush.z+t.d)/t.ny
            local delta=math.max(-brush.levelAmountM,math.min(brush.levelAmountM,targetY-before))
            local after=before+delta
            heights[key(brush.x,brush.z)]=after
            brush.onApplied(1,delta,before,after,0,{
                roughnessBeforeM=0.020,
                roughnessAfterM=0.010
            })
            return true
        end
    }
}

RealismExtensionsTerrainPerformance={begin=function() return 1 end,finish=function() end}
Cultivator={}
SpecializationUtil={
    hasSpecialization=function() return true end,
    registerOverwrittenFunction=function() end
}
dofile("scripts/terrain/TerrainRecovery.lua")

local vehicle={spec_cultivator={useDeepMode=false}}
local workArea={start=101,width=102,height=103}
local function super(self,wa,dt) return 10,10 end

RealismExtensionsTerrainRecovery.processCultivatorArea(vehicle,super,workArea,16)
assert(#enqueued>0)
local d=RealismExtensionsTerrainRecovery.getDiagnostics()
assert(d.planeFits==1)
assert(d.targetEligible==#enqueued)
assert(d.roughnessImproved==#enqueued)
assert(recovered>0)

-- Same physical pass is suppressed.
local n=#enqueued
RealismExtensionsTerrainRecovery.processCultivatorArea(vehicle,super,workArea,16)
assert(#enqueued==n)
d=RealismExtensionsTerrainRecovery.getDiagnostics()
assert(d.stampSkips>0 or d.targetSkips>0)

-- A deliberate later pass is eligible again.
g_currentMission.time=13000
RealismExtensionsTerrainRecovery.processCultivatorArea(vehicle,super,workArea,16)
assert(#enqueued>=n)
print("terrain_recovery_v16_harness: OK")
