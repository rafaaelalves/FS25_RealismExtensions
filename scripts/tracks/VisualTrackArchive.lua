-- Strict, serializable VISUAL-ONLY archive for native TireTrack observations.
-- This module NEVER invokes GIANTS terrain/wheel setters, TireTrack replay,
-- XMLFile, or file I/O. A caller must provide a trustworthy map identity.
-- Captured TireTrack groundDepth is a visual input, NOT verified rut geometry.
RealismExtensionsVisualTrackArchive =
    RealismExtensionsVisualTrackArchive or {}
local Archive=RealismExtensionsVisualTrackArchive
Archive.VERSION=1
Archive.CHANNEL="NATIVE_TIRE_TRACK_VISUAL_ONLY"
Archive.MAX_CHUNKS=8192
Archive.MAX_FRAGMENTS=40000
Archive.MAX_POINT_REFS=160000

local POINT_NUMBERS={
    "x","y","z","ux","uy","uz","r","g","b",
    "dirtAmount","groundDepth","tireDirection",
    "colorBlendWithTerrain","sessionTimeMs"
}
local function finite(n)
    return type(n)=="number" and n==n
        and n~=math.huge and n~=-math.huge
end
local function positiveInt(n)
    return finite(n) and n>=1 and n==math.floor(n)
end
local function identity(world)
    if type(world)~="table"
        or type(world.mapId)~="string"
        or #world.mapId<1 or #world.mapId>128
        or type(world.terrainFingerprint)~="string"
        or #world.terrainFingerprint<1
        or #world.terrainFingerprint>128
        or not finite(world.terrainSizeM)
        or world.terrainSizeM<=0 or world.terrainSizeM>65536
        or not finite(world.mainUnitM)
        or world.mainUnitM<=0 or world.mainUnitM>32 then
        return nil,"MAP_IDENTITY_UNAVAILABLE"
    end
    return {
        mapId=world.mapId,
        terrainFingerprint=world.terrainFingerprint,
        terrainSizeM=world.terrainSizeM,
        mainUnitM=world.mainUnitM
    },nil
end
local function validSize(s)
    return finite(s) and s>=1 and s<=256
end
local function copyPoint(p)
    if type(p)~="table" or p.onTerrain~=true then
        return nil,"NON_TERRAIN_OR_INVALID_POINT"
    end
    local result={onTerrain=true}
    for _,field in ipairs(POINT_NUMBERS) do
        local n=p[field]
        if not finite(n) then return nil,"NONFINITE_VISUAL_POINT" end
        result[field]=n
    end
    if math.abs(result.x)>10000000
        or math.abs(result.y)>10000000
        or math.abs(result.z)>10000000
        or math.abs(result.groundDepth)>5 then
        return nil,"VISUAL_POINT_OUT_OF_BOUNDS"
    end
    return result,nil
end
local function copyFragment(f)
    if type(f)~="table"
        or not positiveInt(f.logicalTrackId)
        or not positiveInt(f.fragmentSequence)
        or not finite(f.widthM) or f.widthM<=0 or f.widthM>20
        or (f.atlasIndex~=nil and
            (not finite(f.atlasIndex) or f.atlasIndex<0))
        or (f.createdSessionTimeMs~=nil
            and (not finite(f.createdSessionTimeMs)
                or f.createdSessionTimeMs<0))
        or (f.closeReason~=nil and
            (type(f.closeReason)~="string"
                or #f.closeReason>80))
        or type(f.points)~="table"
        or #f.points<1
        or #f.points>Archive.MAX_POINT_REFS then
        return nil,"INVALID_VISUAL_FRAGMENT"
    end
    local out={
        logicalTrackId=f.logicalTrackId,
        fragmentSequence=f.fragmentSequence,
        widthM=f.widthM,
        atlasIndex=f.atlasIndex,
        createdSessionTimeMs=f.createdSessionTimeMs,
        closeReason=f.closeReason,
        origin="ARCHIVED_VISUAL_ONLY",
        points={}
    }
    for i,p in ipairs(f.points) do
        local copy,reason=copyPoint(p)
        if copy==nil then return nil,reason end
        out.points[i]=copy
    end
    return out,nil
end
local function copyChunk(chunk,chunkSize)
    if type(chunk)~="table"
        or not finite(chunk.ix)
        or not finite(chunk.iz)
        or chunk.ix~=math.floor(chunk.ix)
        or chunk.iz~=math.floor(chunk.iz)
        or type(chunk.key)~="string"
        or chunk.key~=tostring(chunk.ix)..":"..tostring(chunk.iz)
        or type(chunk.fragments)~="table"
        or #chunk.fragments==0 then
        return nil,"INVALID_VISUAL_CHUNK"
    end
    local out={
        ix=chunk.ix,iz=chunk.iz,key=chunk.key,fragments={}
    }
    local pointCount=0
    for i,f in ipairs(chunk.fragments) do
        local cf,reason=copyFragment(f)
        if cf==nil then return nil,reason end
        -- Imported points may include ONE boundary carry from the prior
        -- chunk; reject arbitrary distant fragments or mislabeled keys.
        for _,p in ipairs(cf.points) do
            local maxOffset=chunkSize*2
            if p.x < chunk.ix*chunkSize-maxOffset
                or p.x > (chunk.ix+1)*chunkSize+maxOffset
                or p.z < chunk.iz*chunkSize-maxOffset
                or p.z > (chunk.iz+1)*chunkSize+maxOffset then
                return nil,"VISUAL_CHUNK_COORDINATE_MISMATCH"
            end
        end
        out.fragments[i]=cf
        pointCount=pointCount+#cf.points
    end
    return out,pointCount
end

-- Emits ONLY plain Lua values. No disk writes and no authority to mutate
-- heightmaps or to replay a physical native wheel displacement.
function Archive.export(store,world)
    local id,why=identity(world)
    if id==nil then return nil,why end
    if type(store)~="table"
        or type(store.getStats)~="function"
        or type(store.chunks)~="table"
        or type(store.settings)~="table"
        or not validSize(store.settings.chunkSizeM) then
        return nil,"VISUAL_STORE_UNAVAILABLE"
    end
    local stats=store:getStats()
    if not finite(stats.chunks) or stats.chunks>Archive.MAX_CHUNKS
        or not finite(stats.fragments)
        or stats.fragments>Archive.MAX_FRAGMENTS
        or not finite(stats.pointReferences)
        or stats.pointReferences>Archive.MAX_POINT_REFS then
        return nil,"VISUAL_ARCHIVE_BUDGET_EXCEEDED"
    end
    local archive={
        version=Archive.VERSION,
        channel=Archive.CHANNEL,
        authorizesTerrainWrites=false,
        authorizesPhysicalReplay=false,
        world=id,
        chunkSizeM=store.settings.chunkSizeM,
        chunks={},
        totals={chunks=0,fragments=0,pointReferences=0}
    }
    local keys={}
    for key in pairs(store.chunks) do keys[#keys+1]=key end
    table.sort(keys)
    for _,key in ipairs(keys) do
        local chunk=store.chunks[key]
        if chunk.key~=key then return nil,"CHUNK_KEY_MISMATCH" end
        local cc,points=copyChunk(chunk,archive.chunkSizeM)
        if cc==nil then return nil,points end
        archive.chunks[#archive.chunks+1]=cc
        archive.totals.chunks=archive.totals.chunks+1
        archive.totals.fragments=
            archive.totals.fragments+#cc.fragments
        archive.totals.pointReferences=
            archive.totals.pointReferences+points
        if archive.totals.chunks>Archive.MAX_CHUNKS
            or archive.totals.fragments>Archive.MAX_FRAGMENTS
            or archive.totals.pointReferences>Archive.MAX_POINT_REFS then
            return nil,"VISUAL_ARCHIVE_BUDGET_EXCEEDED"
        end
    end
    if archive.totals.chunks~=stats.chunks
        or archive.totals.fragments~=stats.fragments
        or archive.totals.pointReferences~=stats.pointReferences then
        return nil,"VISUAL_STORE_COUNT_DRIFT"
    end
    return archive,nil
end

-- Allocate a NEW, isolated chunk store. Reject malformed, oversize,
-- wrong-map or suspicious data before any visual data is made available.
-- Does NOT touch the caller's existing store or the GIANTS engine.
function Archive.import(snapshot,world)
    local id,why=identity(world)
    if id==nil then return nil,why end
    if type(snapshot)~="table"
        or snapshot.version~=Archive.VERSION
        or snapshot.channel~=Archive.CHANNEL
        or snapshot.authorizesTerrainWrites~=false
        or snapshot.authorizesPhysicalReplay~=false
        or type(snapshot.world)~="table"
        or type(snapshot.chunks)~="table"
        or type(snapshot.totals)~="table"
        or not validSize(snapshot.chunkSizeM) then
        return nil,"INVALID_VISUAL_ARCHIVE"
    end
    for key,value in pairs(id) do
        if snapshot.world[key]~=value then
            return nil,"VISUAL_ARCHIVE_MAP_MISMATCH"
        end
    end
    local n=#snapshot.chunks
    if n>Archive.MAX_CHUNKS then
        return nil,"VISUAL_ARCHIVE_BUDGET_EXCEEDED"
    end
    local expected=snapshot.totals
    if not finite(expected.chunks)
        or not finite(expected.fragments)
        or not finite(expected.pointReferences)
        or expected.chunks~=n
        or expected.fragments<0
        or expected.fragments>Archive.MAX_FRAGMENTS
        or expected.pointReferences<0
        or expected.pointReferences>Archive.MAX_POINT_REFS then
        return nil,"INVALID_VISUAL_ARCHIVE_COUNTS"
    end
    local Store=RealismExtensionsVisualTrackChunkStore
    if type(Store)~="table"
        or type(Store.new)~="function" then
        return nil,"CHUNK_STORE_CLASS_UNAVAILABLE"
    end
    local out=Store.new({
        chunkSizeM=snapshot.chunkSizeM,
        maxStoredChunks=Archive.MAX_CHUNKS,
        maxStoredFragments=Archive.MAX_FRAGMENTS,
        maxStoredPointReferences=Archive.MAX_POINT_REFS
    })
    local fragmentCount,pointCount=0,0
    local seen={}
    for _,c in ipairs(snapshot.chunks) do
        local copy,points=copyChunk(c,snapshot.chunkSizeM)
        if copy==nil then return nil,points end
        if seen[copy.key] then
            return nil,"DUPLICATE_VISUAL_CHUNK"
        end
        seen[copy.key]=true
        local chunk=out:_getOrCreate(copy.ix,copy.iz)
        for _,f in ipairs(copy.fragments) do
            if not out:_appendFragment(chunk,f) then
                return nil,"VISUAL_ARCHIVE_IMPORT_REFUSED"
            end
            fragmentCount=fragmentCount+1
            pointCount=pointCount+#f.points
            if fragmentCount>Archive.MAX_FRAGMENTS
                or pointCount>Archive.MAX_POINT_REFS
                or out.evictedFragments>0
                or out.overflowRefusals>0 then
                return nil,"VISUAL_ARCHIVE_BUDGET_EXCEEDED"
            end
        end
    end
    local stats=out:getStats()
    if stats.chunks~=expected.chunks
        or fragmentCount~=expected.fragments
        or pointCount~=expected.pointReferences
        or stats.fragments~=fragmentCount
        or stats.pointReferences~=pointCount then
        return nil,"VISUAL_ARCHIVE_COUNT_MISMATCH"
    end
    return out,nil
end
return Archive
