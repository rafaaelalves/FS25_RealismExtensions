RealismExtensionsVisualTrackChunkStore =
    RealismExtensionsVisualTrackChunkStore or {}
local Store = RealismExtensionsVisualTrackChunkStore

Store.VERSION = 1
Store.DEFAULTS = {
    chunkSizeM = 64,
    maxQueryChunks = 256
}

local function validNumber(v)
    return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge
end

local function copyPoint(p)
    local out={}
    for k,v in pairs(p or {}) do out[k]=v end
    return out
end

function Store.new(options)
    options=options or {}
    local settings={}
    for k,v in pairs(Store.DEFAULTS) do settings[k]=v end
    for k,v in pairs(options) do settings[k]=v end
    local self={
        settings=settings,
        chunks={},
        chunkCount=0,
        fragmentCount=0,
        pointReferences=0
    }
    return setmetatable(self,{__index=Store})
end

function Store:getChunkCoordinates(x,z)
    local s=math.max(1,tonumber(self.settings.chunkSizeM) or 64)
    return math.floor(x/s),math.floor(z/s)
end

function Store:getChunkKey(ix,iz)
    return tostring(ix)..":"..tostring(iz)
end

function Store:_getOrCreate(ix,iz)
    local key=self:getChunkKey(ix,iz)
    local chunk=self.chunks[key]
    if chunk==nil then
        chunk={key=key,ix=ix,iz=iz,fragments={},revision=0}
        self.chunks[key]=chunk
        self.chunkCount=self.chunkCount+1
    end
    return chunk
end

local function makeChunkFragment(trackIndex,fragmentIndex,track)
    return {
        trackIndex=trackIndex,
        fragmentIndex=fragmentIndex,
        widthM=tonumber(track.widthM),
        atlasIndex=tonumber(track.atlasIndex),
        createdAtMs=tonumber(track.createdAtMs) or 0,
        points={}
    }
end

function Store:_appendFragment(chunk,fragment)
    if #(fragment.points or {})==0 then return false end
    chunk.fragments[#chunk.fragments+1]=fragment
    chunk.revision=(chunk.revision or 0)+1
    self.fragmentCount=self.fragmentCount+1
    self.pointReferences=self.pointReferences+#fragment.points
    return true
end

function Store:addFragment(trackIndex,fragmentIndex,track,sourceFragment)
    if type(track)~="table" or type(sourceFragment)~="table" then return false end
    local points=sourceFragment.points
    if type(points)~="table" or #points==0 then return false end

    local currentChunk,currentFragment=nil,nil
    local previousPoint=nil

    for _,point in ipairs(points) do
        if validNumber(point.x) and validNumber(point.z) then
            local ix,iz=self:getChunkCoordinates(point.x,point.z)
            local chunk=self:_getOrCreate(ix,iz)

            if currentChunk~=chunk then
                if currentChunk~=nil and currentFragment~=nil then
                    self:_appendFragment(currentChunk,currentFragment)
                end
                currentChunk=chunk
                currentFragment=makeChunkFragment(trackIndex,fragmentIndex,track)

                -- Duplicate one boundary point from the previous chunk so a
                -- renderer can reconnect the polyline without scanning a
                -- neighboring chunk for topology.
                if previousPoint~=nil then
                    currentFragment.points[#currentFragment.points+1]=
                        copyPoint(previousPoint)
                end
            end

            currentFragment.points[#currentFragment.points+1]=copyPoint(point)
            previousPoint=point
        end
    end

    if currentChunk~=nil and currentFragment~=nil then
        self:_appendFragment(currentChunk,currentFragment)
    end

    return true
end

function Store:rebuildFromJournalSnapshot(snapshot,options)
    options=options or {}
    self:clear()
    if type(snapshot)~="table" or type(snapshot.tracks)~="table" then
        return false,"invalid journal snapshot"
    end

    local includeOpen=options.includeOpen==true
    for ti,track in ipairs(snapshot.tracks) do
        for fi,fragment in ipairs(track.fragments or {}) do
            if fragment.closed==true or includeOpen then
                self:addFragment(ti,fi,track,fragment)
            end
        end
    end

    return true,nil
end

function Store:getChunk(ix,iz)
    return self.chunks[self:getChunkKey(ix,iz)]
end

function Store:queryCircle(x,z,radiusM)
    if not validNumber(x) or not validNumber(z)
        or not validNumber(radiusM) or radiusM<0 then
        return {}
    end

    local s=math.max(1,tonumber(self.settings.chunkSizeM) or 64)
    local minIx,minIz=self:getChunkCoordinates(x-radiusM,z-radiusM)
    local maxIx,maxIz=self:getChunkCoordinates(x+radiusM,z+radiusM)
    local maxChunks=math.max(
        1,
        math.floor(tonumber(self.settings.maxQueryChunks) or 256)
    )

    local out={}
    local radiusSq=(radiusM+s*0.75)*(radiusM+s*0.75)
    for ix=minIx,maxIx do
        for iz=minIz,maxIz do
            if #out>=maxChunks then return out end
            local chunk=self:getChunk(ix,iz)
            if chunk~=nil then
                local cx=(ix+0.5)*s
                local cz=(iz+0.5)*s
                local dx,dz=cx-x,cz-z
                if dx*dx+dz*dz<=radiusSq then
                    out[#out+1]=chunk
                end
            end
        end
    end
    return out
end

function Store:clear()
    self.chunks={}
    self.chunkCount=0
    self.fragmentCount=0
    self.pointReferences=0
end

function Store:getStats()
    return {
        chunks=self.chunkCount,
        fragments=self.fragmentCount,
        pointReferences=self.pointReferences,
        chunkSizeM=self.settings.chunkSizeM
    }
end

return Store
