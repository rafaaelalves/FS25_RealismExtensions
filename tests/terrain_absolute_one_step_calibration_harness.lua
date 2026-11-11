-- Isolated gameplay-like acceptance harness; NOT live FS25 proof.
-- One candidate 16-bit quantum on a disposable simulated save.
-- No native physics, no real map or current player's save modified.
dofile("scripts/terrain/TerrainGeometryJournal.lua")
dofile("scripts/terrain/TerrainQuantizedHeightBudget.lua")
dofile("scripts/terrain/TerrainAbsoluteVertexCandidate.lua")
dofile("scripts/terrain/TerrainAbsolutePersistenceWitness.lua")
dofile("scripts/terrain/TerrainAbsoluteSetterCalibration.lua")
local J=RealismExtensionsTerrainGeometryJournal
local C=RealismExtensionsTerrainAbsoluteSetterCalibration
local q=255/65535
local base=q*36000
local saved={}
local function xmlHandle(path,record)
    return {
        setInt=function(_,k,v)record[k]=v end,
        setFloat=function(_,k,v)record[k]=v end,
        setString=function(_,k,v)record[k]=v end,
        getInt=function(_,k,v)if record[k]==nil then return v end return record[k] end,
        getFloat=function(_,k,v)if record[k]==nil then return v end return record[k] end,
        getString=function(_,k,v)if record[k]==nil then return v end return record[k] end,
        save=function() saved[path]=record end,
        delete=function()end
    }
end
XMLFile={
    create=function(_,path) return xmlHandle(path,{}) end,
    load=function(_,path)
        return saved[path]~=nil and xmlHandle(path,saved[path]) or nil
    end
}
fileExists=function(path) return saved[path]~=nil end
local heights={}
local function key(x,z) return tostring(x)..":"..tostring(z) end
local function getHeight(x,z)
    return heights[key(x,z)] or base
end
local function freshJournal()
    return J.new(999,{unitM=1,sample=getHeight})
end
local journal=freshJournal()
local writer={nativeCausalPending=false,getQueueSize=function()return 0 end}
local runtime={geometryJournal=journal,writer=writer,
    nativeDamageQuarantined=false}
RealismExtensionsTerrainRuntime=runtime
RealismExtensionsConfig={modules={
    TerrainPermanentActuator="SHADOW",
    TerrainControlledWriteTrial=true
}}
RealismExtensionsTerrainControlledWriteTrial={
    armed=false,pending=false,reserved=nil,
    isSinglePlayer=function()
        return g_server~=nil and
            g_currentMission.missionInfo.isMultiplayer~=true
    end
}
RealismExtensionsTerrainNativeQueueProbe={
    owner={},pollIntegrity=function()return true end
}
RealismExtensionsTerrainNativeSpatialProbe={
    owner={},checkIntegrity=function()return true end
}
RealismExtensionsTerrainGeometryProbe={
    position={x=10.11,z=20.12},
    previous={x=10.11,z=20.12,label="beforeAbsolute"}
}
g_server={}
local info={mapId="SaoCarlos",isValid=true,
    savegameDirectory="/genuinely-disposable-clone",
    isMultiplayer=false}
g_currentMission={time=10000,missionInfo=info}
local overlaps=false
RealismExtensionsLoadedContactRegistry={
    overlapsCircle=function(x,z,radius,now)
        assert(x==10 and z==20 and radius>=1.60)
        return overlaps
    end
}
local writes=0
setTerrainHeightAtWorldPos=function(terrain,x,y,z,target)
    writes=writes+1
    assert(terrain==999 and x==10 and y==0 and z==20)
    heights[key(x,z)]=math.floor(target/q+0.5)*q
    return true
end

-- No destructive action without independent quantizer candidate and
-- explicit disposable-save acknowledgement.
assert(select(1,C.runOneStep(q,"WRONG"))==false)
assert(select(1,C.runOneStep("none","COPY"))==false)
assert(select(1,C.runOneStep(0.02,"COPY"))==false)
assert(writes==0 and not C.used)
overlaps=true
assert(select(1,C.runOneStep(q,"COPY"))==false)
assert(writes==0 and not C.used)
overlaps=false

local ok,why=C.runOneStep(tostring(q),"COPY")
assert(ok==true and why=="ONE_STEP_MATCHED_NOT_PERSISTED")
assert(writes==1 and C.used==true)
assert(runtime.nativeDamageQuarantined==true)
assert(math.abs((base-getHeight(10,20))-q)<1e-9)
assert(getHeight(11,20)==base and getHeight(11,21)==base)
assert(journal.pendingCount==0)
assert(journal.observations["10:20"].owned==false)
assert(C.pendingWitness~=nil)
assert(C.witnessOriginDirectory==info.savegameDirectory)
assert(select(1,C.runOneStep(q,"COPY"))==false)
assert(writes==1)
local witnessPath=RealismExtensionsTerrainAbsolutePersistenceWitness.path(info)
assert(saved[witnessPath]==nil)
assert(select(1,C.verifyReload())==false)
assert(select(1,C.armPersistence("COPY"))==true)
assert(select(1,C.saveWitness(info))==true)
assert(saved[witnessPath]~=nil)
assert(select(1,C.verifyReload())==false) -- same mission
local previousMission=g_currentMission
g_currentMission={time=20000,missionInfo={
    mapId=info.mapId,isValid=true,
    savegameDirectory=info.savegameDirectory,
    isMultiplayer=false
}}
runtime.geometryJournal=freshJournal()
local match,status,details=C.verifyReload()
assert(match==true and status=="MAIN_HEIGHT_MATCHES_SAVED_WITNESS")
assert(details.matchedVertices==9)
g_currentMission=previousMission

-- Simulated engine overshoot: center moves 20um too deep, *within*
-- broad 50um quantum-matching tolerance, but this exceeds authorization.
C.used=false
runtime.nativeDamageQuarantined=false
runtime.geometryJournal=freshJournal()
journal=runtime.geometryJournal
heights={}
C.pendingWitness=nil
setTerrainHeightAtWorldPos=function(terrain,x,y,z,target)
    writes=writes+1
    heights[key(x,z)]=getHeight(x,z)-(q+0.00002)
    return true
end
local pass,err=C.runOneStep(q,"COPY")
assert(pass==false and err=="OBSERVED_LOWERING_EXCEEDS_DEBT")
assert(runtime.nativeDamageQuarantined==true)
assert(C.used==true and C.pendingWitness==nil)
assert(journal.observations["10:20"].owned==false)
assert(select(1,C.armPersistence("COPY"))==false)

-- A correct central step plus microscopic 20um collateral must fail.
C.used=false
runtime.nativeDamageQuarantined=false
runtime.geometryJournal=freshJournal()
journal=runtime.geometryJournal
heights={}
setTerrainHeightAtWorldPos=function(terrain,x,y,z,target)
    writes=writes+1
    heights[key(x,z)]=math.floor(target/q+0.5)*q
    heights[key(x+1,z)]=base-0.00002
    return true
end
local pass2,err2=C.runOneStep(q,"COPY")
assert(pass2==false and err2=="UNTRUSTED_NATIVE_SIDE_EFFECT")
assert(runtime.nativeDamageQuarantined==true)
assert(C.pendingWitness==nil)
assert(journal.pendingCount==0)
assert(journal.observations["10:20"].owned==false)
assert(journal.observations["11:20"].owned==false)
print("terrain_absolute_one_step_calibration_harness: OK")
