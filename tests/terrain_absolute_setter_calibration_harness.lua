-- Standalone mock test of a deliberately destructive one-shot diagnostic.
-- Not proof of the real FS25 native setter, map quantization or save sync.
dofile("scripts/terrain/TerrainGeometryJournal.lua")
dofile("scripts/terrain/TerrainAbsolutePersistenceWitness.lua")
-- The witness is written through the ordinary cloned-save callback only
-- after an explicit separate confirmation. Simulate XML in memory.
local witnessFiles={}
local function xmlHandle(path,record)
    return {
        setInt=function(_,k,v)record[k]=v end,
        setFloat=function(_,k,v)record[k]=v end,
        setString=function(_,k,v)record[k]=v end,
        getInt=function(_,k,d)if record[k]==nil then return d end return record[k] end,
        getFloat=function(_,k,d)if record[k]==nil then return d end return record[k] end,
        getString=function(_,k,d)if record[k]==nil then return d end return record[k] end,
        save=function() witnessFiles[path]=record end,
        delete=function() end
    }
end
XMLFile={
    create=function(_,path) return xmlHandle(path,{}) end,
    load=function(_,path)
        local r=witnessFiles[path]
        if r==nil then return nil end
        return xmlHandle(path,r)
    end
}
fileExists=function(path)return witnessFiles[path]~=nil end
dofile("scripts/terrain/TerrainAbsoluteSetterCalibration.lua")
local J=RealismExtensionsTerrainGeometryJournal
local C=RealismExtensionsTerrainAbsoluteSetterCalibration
local rt
local h={}
local function key(x,z) return tostring(x)..":"..tostring(z) end
local function height(x,z) return h[key(x,z)] or 100 end
local journal=J.new(999,{unitM=1,sample=height})
local writer={nativeCausalPending=false,getQueueSize=function()return 0 end}
rt={geometryJournal=journal,writer=writer,nativeDamageQuarantined=false}
RealismExtensionsTerrainRuntime=rt
RealismExtensionsConfig={modules={TerrainPermanentActuator="SHADOW",
    TerrainControlledWriteTrial=true}}
local trial={armed=false,pending=false,reserved=nil,
    isSinglePlayer=function()return g_server~=nil
        and not (g_currentMission.missionInfo or {}).isMultiplayer end}
RealismExtensionsTerrainControlledWriteTrial=trial
RealismExtensionsTerrainGeometryProbe={
    position={x=10.11,z=20.12},
    previous={x=10.11,z=20.12,label="beforeAbsolute"}
}
local mark=RealismExtensionsTerrainGeometryProbe
RealismExtensionsTerrainNativeQueueProbe={
    owner={},pollIntegrity=function()return true end
}
RealismExtensionsTerrainNativeSpatialProbe={
    owner={},checkIntegrity=function()return true end
}
g_server={}
g_currentMission={time=10000,missionInfo={isMultiplayer=false,
    isValid=true,mapId="SaoCarlos",savegameDirectory="/copy"}}
local blocked=false
RealismExtensionsLoadedContactRegistry={
    overlapsCircle=function(x,z,radius,clock)
        assert(x==10 and z==20 and radius>1.5 and clock==10000)
        return blocked
    end
}
local calls=0
setTerrainHeightAtWorldPos=function(terrain,x,y,z,target)
    calls=calls+1
    assert(terrain==999 and x==10 and y==0 and z==20)
    h[key(x,z)]=target
end
local witnessPath=RealismExtensionsTerrainAbsolutePersistenceWitness.path(
    g_currentMission.missionInfo)
assert(select(1,C.armPersistence("COPY"))==false)
assert(witnessFiles[witnessPath]==nil)
local ok=select(1,C.inspect())
assert(ok and calls==0 and C.used==false and journal.pendingCount==0)
mark.previous.label="beforeCal"
assert(select(1,C.inspect())==false)
assert(select(1,C.run())==false)
assert(calls==0)
mark.previous.label="beforeAbsolute"
blocked=true
assert(select(1,C.run())==false and calls==0)
assert(C.used==false)
blocked=false
g_currentMission.missionInfo.isMultiplayer=true
assert(select(1,C.run())==false and calls==0)
g_currentMission.missionInfo.isMultiplayer=false
journal.observations["10:20"]={
    x=10,z=20,preREHeightM=100,observedHeightM=100,owned=false
}
assert(select(1,C.run())==false and calls==0)
journal.observations["10:20"]=nil
assert(select(1,C.run())==true)
assert(calls==1 and C.used==true and rt.nativeDamageQuarantined==true)
assert(journal.pendingCount==0)
assert(journal.observations["10:20"]==nil)
assert(math.abs(height(10,20)-99.9985)<1e-9)
assert(C.pendingWitness~=nil and C.persistRequested==false)
assert(witnessFiles[witnessPath]==nil)
assert(select(1,C.verifyReload())==false) -- no witness saved
assert(select(1,C.armPersistence("wrong"))==false)
assert(witnessFiles[witnessPath]==nil)
-- The folder name alone does not prove this is the same save-session owner.
local genuineInfo=g_currentMission.missionInfo
g_currentMission.missionInfo={
    isMultiplayer=false,isValid=true,mapId="SaoCarlos",
    savegameDirectory="/copy"
}
assert(select(1,C.armPersistence("COPY"))==false)
g_currentMission.missionInfo=genuineInfo
assert(select(1,C.armPersistence("COPY"))==true)
assert(C.persistRequested==true)
assert(select(1,C.saveWitness(g_currentMission.missionInfo))==true)
assert(C.persistRequested==false and witnessFiles[witnessPath]~=nil)
assert(C.witnessSaveAttempted==true)
assert(select(1,C.armPersistence("COPY"))==false)
assert(select(1,C.saveWitness(g_currentMission.missionInfo))==false)
-- A sidecar that was saved *in this session* must NOT be misreported as
-- a successful reload (the old code accepted it as an immediate match).
local inMemoryMatch,inMemoryStatus=C.verifyReload()
assert(inMemoryMatch==false and inMemoryStatus=="RELOAD_NOT_YET_OBSERVED")
local originalMission=g_currentMission
local originalJournal=rt.geometryJournal
-- Emulate a fresh mission and fresh native journal reading persisted MAIN
-- coordinates. This mock does NOT itself prove GIANTS save persistence.
g_currentMission={time=20000,missionInfo={
    isMultiplayer=false,isValid=true,
    mapId="SaoCarlos",savegameDirectory="/copy"}}
rt.geometryJournal=J.new(999,{unitM=1,sample=height})
local matches,status,details=C.verifyReload()
assert(matches==true and status=="MAIN_HEIGHT_MATCHES_SAVED_WITNESS")
assert(details.matchedVertices==9 and details.provesReloadOccurred==false)
-- One different neighboring height after save must invalidate the witness,
-- but must not trigger a native reset/repair action.
h[key(11,21)]=100.02
assert(select(1,C.verifyReload())==false)
h[key(11,21)]=nil
g_currentMission=originalMission
rt.geometryJournal=originalJournal
assert(select(1,C.run())==false and calls==1)

-- Explicit GIANTS setter errors consume the one shot, release locks and
-- quarantine the session. No auto-retry can follow the exception.
C.used=false
rt.nativeDamageQuarantined=false
setTerrainHeightAtWorldPos=function()
    calls=calls+1
    error("native research setter simulated failure")
end
assert(select(1,C.run())==true)
assert(C.used and rt.nativeDamageQuarantined and calls==2)
assert(C.pendingWitness==nil and C.persistRequested==false)
assert(select(1,C.armPersistence("COPY"))==false)
assert(journal.pendingCount==0)
assert(select(1,C.run())==false and calls==2)
print("terrain_absolute_setter_calibration_harness: OK")
