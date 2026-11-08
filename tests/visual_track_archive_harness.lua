-- VISUAL TIRE TRACKS ONLY. Imported data must NEVER restore physical
-- terrain or call any GIANTS setter, regardless of deceptive source flags.
dofile("scripts/tracks/VisualTrackChunkStore.lua")
dofile("scripts/tracks/VisualTrackArchive.lua")
local S=RealismExtensionsVisualTrackChunkStore
local A=RealismExtensionsVisualTrackArchive
local function point(x,z)
    return {x=x,y=152,z=z,ux=1,uy=0,uz=0,
        r=0.1,g=0.2,b=0.3,dirtAmount=0.8,
        groundDepth=0.04,tireDirection=1,onTerrain=true,
        colorBlendWithTerrain=0.2,sessionTimeMs=1000}
end
local world={
    mapId="FS25_Estancia_Sao_Carlos",
    terrainFingerprint="TEST_I3D_FINGERPRINT_DO_NOT_ASSUME_REAL",
    terrainSizeM=2048,mainUnitM=1
}
local store=S.new({chunkSizeM=10,maxStoredChunks=2,
    maxStoredFragments=3,maxStoredPointReferences=50})
local track={logicalTrackId=10,widthM=0.55,
    atlasIndex=3,createdSessionTimeMs=1000}
local frag={sequence=2,closeReason="CUT",closed=true,
    points={point(1,1),point(9,1),point(11,1)}}
assert(store:addFragment(track,frag,"CURRENT_SESSION"))
assert(store:getStats().chunks==2)
assert(store:getStats().fragments==2)
assert(store:getStats().pointReferences==4)
local data,why=A.export(store,world)
assert(data~=nil and why==nil)
assert(data.version==1
    and data.channel=="NATIVE_TIRE_TRACK_VISUAL_ONLY")
assert(data.authorizesTerrainWrites==false
    and data.authorizesPhysicalReplay==false)
assert(data.totals.chunks==2
    and data.totals.fragments==2
    and data.totals.pointReferences==4)
local imported,reason=A.import(data,world)
assert(imported~=nil and reason==nil)
assert(imported~=store)
assert(imported:getStats().chunks==2
    and imported:getStats().fragments==2
    and imported:getStats().pointReferences==4)
local restored=assert(imported:getChunk(1,0))
assert(restored.fragments[1].origin=="ARCHIVED_VISUAL_ONLY")
assert(restored.fragments[1].points[1].x==9)
-- No alias between original storage, archive, and imported copy.
store:getChunk(0,0).fragments[1].points[1].x=1234
assert(data.chunks[1].fragments[1].points[1].x==1)
data.chunks[1].fragments[1].points[1].x=2
assert(imported:getChunk(0,0).fragments[1].points[1].x==1)

local function clone(t)
    if type(t)~="table" then return t end
    local out={}
    for k,v in pairs(t) do out[k]=clone(v) end
    return out
end
local function rejected(changed, expected)
    local out,why=A.import(changed,world)
    assert(out==nil and why==expected,why)
end
local alteredWorld=clone(world)
alteredWorld.mapId="anotherMap"
assert(select(1,A.import(data,alteredWorld))==nil)
alteredWorld=clone(world)
alteredWorld.terrainFingerprint="different-map-heightdata"
assert(select(1,A.import(data,alteredWorld))==nil)
alteredWorld=clone(world)
alteredWorld.mainUnitM=0.125
assert(select(1,A.import(data,alteredWorld))==nil)
alteredWorld=clone(world)
alteredWorld.terrainSizeM=4096
assert(select(1,A.import(data,alteredWorld))==nil)
assert(select(1,A.export(store,{mapId="map",terrainSizeM=2048,mainUnitM=1}))==nil)
local tampered=clone(data)
tampered.version=2
rejected(tampered,"INVALID_VISUAL_ARCHIVE")
tampered=clone(data)
tampered.channel="PHYSICAL_FINE_RUTS"
rejected(tampered,"INVALID_VISUAL_ARCHIVE")
tampered=clone(data)
tampered.authorizesTerrainWrites=true
rejected(tampered,"INVALID_VISUAL_ARCHIVE")
tampered=clone(data)
tampered.authorizesPhysicalReplay=true
rejected(tampered,"INVALID_VISUAL_ARCHIVE")
tampered=clone(data)
tampered.totals.pointReferences=100
rejected(tampered,"VISUAL_ARCHIVE_COUNT_MISMATCH")
tampered=clone(data)
tampered.chunks[2]=clone(tampered.chunks[1])
rejected(tampered,"DUPLICATE_VISUAL_CHUNK")
tampered=clone(data)
tampered.chunks[1].fragments[1].points[1].groundDepth=0/0
rejected(tampered,"NONFINITE_VISUAL_POINT")
tampered=clone(data)
tampered.chunks[1].fragments[1].points[1].x=200
rejected(tampered,"VISUAL_CHUNK_COORDINATE_MISMATCH")
tampered=clone(data)
tampered.chunks[1].fragments[1].points[1].onTerrain=false
rejected(tampered,"NON_TERRAIN_OR_INVALID_POINT")
tampered=clone(data)
tampered.chunkSizeM=0
rejected(tampered,"INVALID_VISUAL_ARCHIVE")
-- Enforcing a tight cap on source storage must never create a physical
-- rut or mutate a destination map; a whole imported snapshot is isolated.
setTerrainHeightAtWorldPos=function() error("PHYSICAL WRITE FORBIDDEN") end
setWheelShapeTerrainDisplacement=function()
    error("NATIVE WHEEL WRITE FORBIDDEN")
end
assert(A.import(data,world)~=nil)
print("visual_track_archive_harness: OK")
