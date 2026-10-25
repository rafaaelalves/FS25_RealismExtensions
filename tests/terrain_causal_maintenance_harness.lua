-- Verifies that monthly world repairs use the existing territory policy,
-- a trusted native geometry journal, and NEVER the legacy TARGET-plane writer.
RealismExtensionsConfig={modules={
    TerrainDeformation=true,TerrainRecovery=true,
    TerrainGeometryJournal=true,TerrainCausalRecovery=true,
    TerrainMaintenance=false,TerrainCausalMaintenance=true
}}
g_server={}
g_currentMission={time=1000,getFarmId=function() return 7 end}
FarmlandManager={
    NO_OWNER_FARM_ID=0,NOT_BUYABLE_FARM_ID=255
}
local function landAt(x)
    if x<5 or x>=35 then return 3 end  -- neighbor NPC
    if x<15 then return 0 end          -- public dirt
    if x<25 then return 1 end          -- player
    return 4                           -- unowned buyable
end
local owners={[1]=7,[3]=0,[4]=0}
g_farmlandManager={
    getFarmlandIdAtWorldPosition=function(_,x,z) return landAt(x) end,
    getFarmlandOwner=function(_,id) return owners[id] or 0 end
}
g_fieldManager={farmlandIdFieldMapping={
    [3]={getHasOwner=function() return false end}
}}
MessageType={PERIOD_CHANGED=111}
local subs={}
g_messageCenter={
    subscribe=function(_,kind,callback,target)
        subs[kind]={callback=callback,target=target}
    end,
    unsubscribe=function(_,kind,target) subs[kind]=nil end
}
RealismExtensionsTerrainSurfaceResponse={
    isMunicipalMaintenanceSurface=function(x,z)
        return x>=5 and x<15
    end
}
dofile("scripts/terrain/TerrainMaintenancePolicy.lua")
dofile("scripts/terrain/SpatialHistory.lua")
local h=RealismExtensionsSpatialHistory.new({cellSizeM=0.2})
local function seed(x,depth)
    h:commit(x,0,{rutDepthM=depth,deformationExposure=1.0,
        maintenanceAgePeriods=0})
end
seed(2,0.06)   -- owned NPC
seed(10,0.05)  -- public
seed(20,0.05)  -- player
seed(30,0.05)  -- buyable unowned
seed(40,0.06)  -- NPC but native journal has no original baseline
local trusted={[2]=true,[10]=true,[20]=true,[30]=true}
local journal={
    unitM=1,
    getRecoverablePoint=function(self,ix,iz)
        if iz~=0 or trusted[ix]~=true then return nil end
        return {key=tostring(ix)..":"..tostring(iz),
            ix=ix,iz=iz,x=ix,z=iz,deficitM=0.06,originalY=100,
            beforeY=99.94}
    end
}
local queued={}
RealismExtensionsTerrainRuntime={history=h,geometryJournal=journal}
RealismExtensionsTerrainCausalRecovery={
    enabled=function() return true end,
    enqueueAuthorizedVertex=function(ix,iz,factor,cause,ttl)
        queued[#queued+1]={ix=ix,iz=iz,factor=factor,cause=cause,ttl=ttl}
        return true
    end
}
dofile("scripts/terrain/TerrainCausalMaintenance.lua")
local M=RealismExtensionsTerrainCausalMaintenance
assert(M.initialize()==true)
assert(subs[111]~=nil)
-- First month: neighbor becomes eligible, municipality still waits.
subs[111].callback(subs[111].target,2)
assert(#queued==1 and queued[1].ix==2
    and queued[1].cause=="NEIGHBOR")
assert(h:get(10,0).maintenanceAgePeriods==1)
assert(h:get(20,0).maintenanceAgePeriods==1)
assert(M.getDiagnostics().notTrusted>=1)
-- Second month: neighbor and municipal but NOT player/unowned.
subs[111].callback(subs[111].target,3)
assert(#queued==3)
assert(queued[2].ix==10 and queued[2].cause=="MUNICIPAL")
assert(queued[3].ix==2 and queued[3].cause=="NEIGHBOR")
assert(queued[1].factor>queued[2].factor)
-- The policy must not continue treating sold NPC farmland as neighbor land.
owners[3]=9
subs[111].callback(subs[111].target,4)
assert(#queued==4 and queued[4].cause=="MUNICIPAL")
-- Public road reclassified as non-maintained -> no municipal native target.
RealismExtensionsTerrainSurfaceResponse.isMunicipalMaintenanceSurface=
    function() return false end
subs[111].callback(subs[111].target,5)
assert(#queued==4)
assert(M.getDiagnostics().surfaceRejected>=1)
-- Avoid any runtime terrain work if the experimental flag is disabled.
RealismExtensionsConfig.modules.TerrainCausalMaintenance=false
subs[111].callback(subs[111].target,6)
assert(#queued==4)
M.shutdown()
assert(subs[111]==nil)
print("terrain_causal_maintenance_harness: OK")
