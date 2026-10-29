-- Standalone mock test of a deliberately destructive one-shot diagnostic.
-- Not proof of the real FS25 native setter, map quantization or save sync.
dofile("scripts/terrain/TerrainGeometryJournal.lua")
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
g_currentMission={missionInfo={isMultiplayer=false}}
local calls=0
setTerrainHeightAtWorldPos=function(terrain,x,y,z,target)
    calls=calls+1
    assert(terrain==999 and x==10 and y==0 and z==20)
    h[key(x,z)]=target
end
local ok=select(1,C.inspect())
assert(ok and calls==0 and C.used==false and journal.pendingCount==0)
mark.previous.label="beforeCal"
assert(select(1,C.inspect())==false)
assert(select(1,C.run())==false)
assert(calls==0)
mark.previous.label="beforeAbsolute"
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
assert(journal.pendingCount==0)
assert(select(1,C.run())==false and calls==2)
print("terrain_absolute_setter_calibration_harness: OK")
