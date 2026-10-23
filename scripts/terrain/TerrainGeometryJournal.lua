-- Experimental, main-heightmap-unit geometry journal.
-- Unlike SpatialHistory's 0.20m mechanical model, these are observed positions
-- on the GIANTS MAIN terrain heightmap. This module NEVER writes terrain.
-- No promise is made about the separate fine tyre-track/displacement channel.
RealismExtensionsTerrainGeometryJournal =
    RealismExtensionsTerrainGeometryJournal or {}
local Journal = RealismExtensionsTerrainGeometryJournal

Journal.VERSION = 1

local function finite(v)
    return type(v) == "number" and v == v
        and v ~= math.huge and v ~= -math.huge
end

local function unitForTerrain(terrain, fallback)
    local v
    if type(getTerrainHeightmapUnitSize) == "function" then
        local ok, result = pcall(getTerrainHeightmapUnitSize, terrain)
        if ok then v = result end
    end
    if not finite(v) or v <= 0 then v = tonumber(fallback) end
    if not finite(v) or v <= 0 then return nil end
    return v
end

local function nativeHeight(terrain, x, z)
    if type(getTerrainHeightAtWorldPos) ~= "function" then return nil end
    local ok, v = pcall(getTerrainHeightAtWorldPos, terrain, x, 0, z)
    if ok and finite(v) then return v end
    return nil
end

function Journal.new(terrain, options)
    options = options or {}
    return setmetatable({
        terrain = terrain,
        unitM = unitForTerrain(terrain, options.unitM),
        sample = options.sample,
        observations = {},
        pendingByVertex = {},
        pendingByLogicalKey = {},
        pendingCount = 0,
        nextId = 0,
        stats = {
            requested = 0,started = 0,overlapRejected = 0,
            unavailable = 0,aborted = 0,completed = 0,
            movedVertices = 0,loweredVertices = 0,raisedVertices = 0,
            noEffect = 0,untrustedRise = 0
        }
    }, {__index=Journal})
end

function Journal:getHeight(x,z)
    if type(self.sample) == "function" then
        local v = self.sample(x,z)
        return finite(v) and v or nil
    end
    return nativeHeight(self.terrain,x,z)
end

-- Coordinate/vertex ownership is deliberately explicit. 0.20m RE history
-- cells are NOT presumed to correspond to 1.00m main heightmap vertices.
-- The conservative radius+half-unit envelope covers interpolated soft brushes.
function Journal:enumerateVertices(x,z,radius)
    local unit = self.unitM
    if not finite(unit) or not finite(x) or not finite(z)
        or not finite(radius) or radius <= 0 then return nil end
    local reach = radius + unit * 0.75
    local fromX,toX = math.floor((x-reach)/unit),math.ceil((x+reach)/unit)
    local fromZ,toZ = math.floor((z-reach)/unit),math.ceil((z+reach)/unit)
    local out={}
    for ix=fromX,toX do
        for iz=fromZ,toZ do
            local vx,vz=ix*unit,iz*unit
            if (vx-x)^2+(vz-z)^2 <= reach^2 then
                out[#out+1]={key=tostring(ix)..":"..tostring(iz),x=vx,z=vz}
            end
        end
    end
    return out
end

function Journal:begin(logicalKey,x,z,radiusM)
    self.stats.requested=self.stats.requested+1
    local verts = self:enumerateVertices(x,z,radiusM)
    if verts == nil or #verts == 0 or logicalKey == nil
        or self.pendingByLogicalKey[logicalKey] ~= nil then
        self.stats.unavailable=self.stats.unavailable+1
        return nil,"NO_VERTICES_OR_PENDING_LOGICAL"
    end
    local before={}
    for _,v in ipairs(verts) do
        if self.pendingByVertex[v.key] ~= nil then
            self.stats.overlapRejected=self.stats.overlapRejected+1
            return nil,"OVERLAPPING_RE_WRITE"
        end
        local y=self:getHeight(v.x,v.z)
        if not finite(y) then
            self.stats.unavailable=self.stats.unavailable+1
            return nil,"HEIGHT_UNAVAILABLE"
        end
        before[#before+1]={key=v.key,x=v.x,z=v.z,beforeY=y}
    end
    -- Any unexpected geometry edit between two RE writes ends ownership
    -- of the old baseline at that native vertex. Do not overwrite baseline.
    -- This guard is conservative and is not an attribution of the external
    -- writer; it protects deliberate TerraFarm/Construction edits.
    for _,p in ipairs(before) do
        local entry=self.observations[p.key]
        if entry~=nil and math.abs(entry.observedHeightM-p.beforeY)>0.002 then
            entry.owned=false
            entry.observedHeightM=p.beforeY
        end
    end
    self.nextId=self.nextId+1
    local token={id=self.nextId,key=logicalKey,points=before,active=true}
    for _,p in ipairs(before) do self.pendingByVertex[p.key]=token end
    self.pendingByLogicalKey[logicalKey]=token
    self.pendingCount=self.pendingCount+1
    self.stats.started=self.stats.started+1
    return token,nil
end

function Journal:complete(token,successful)
    if type(token)~="table" or token.active~=true
        or self.pendingByLogicalKey[token.key]~=token then
        return nil,"STALE_OR_INVALID_TOKEN"
    end
    -- Release ALL locks even if the engine failed.
    token.active=false
    for _,p in ipairs(token.points) do
        if self.pendingByVertex[p.key]==token then
            self.pendingByVertex[p.key]=nil
        end
    end
    self.pendingByLogicalKey[token.key]=nil
    self.pendingCount=math.max(0,self.pendingCount-1)

    if not successful then
        self.stats.aborted=self.stats.aborted+1
        return {success=false,movedVertices=0,maxLowerM=0,maxRaiseM=0}
    end

    -- First read the entire affected footprint. Partial reads never certify
    -- ownership of an operation; the old baseline is not silently overwritten.
    local after={}
    for i,p in ipairs(token.points) do
        local y=self:getHeight(p.x,p.z)
        if not finite(y) then
            self.stats.unavailable=self.stats.unavailable+1
            return nil,"POST_HEIGHT_UNAVAILABLE"
        end
        after[i]=y
    end

    local result={
        success=true,movedVertices=0,loweredVertices=0,raisedVertices=0,
        maxLowerM=0,maxRaiseM=0,deltaSumM=0,unitM=self.unitM,
        sampledVertices=#token.points
    }
    for i,p in ipairs(token.points) do
        local y=after[i]
        local delta=y-p.beforeY
        if math.abs(delta)>0.00005 then
            result.movedVertices=result.movedVertices+1
            result.deltaSumM=result.deltaSumM+delta
            local entry=self.observations[p.key]
            if delta<0 then
                local lowering=-delta
                result.loweredVertices=result.loweredVertices+1
                result.maxLowerM=math.max(result.maxLowerM,lowering)
                if entry==nil then
                    entry={x=p.x,z=p.z,preREHeightM=p.beforeY,observedHeightM=y,owned=true}
                else
                    -- Once provenance was invalidated, track subsequent known
                    -- geometry changes WITHOUT resurrecting the old reference.
                    entry.observedHeightM=y
                end
            else
                result.raisedVertices=result.raisedVertices+1
                result.maxRaiseM=math.max(result.maxRaiseM,delta)
                if entry==nil then
                    entry={x=p.x,z=p.z,preREHeightM=p.beforeY,observedHeightM=y,owned=false}
                else
                    entry.observedHeightM=y
                    entry.owned=false
                end
                self.stats.untrustedRise=self.stats.untrustedRise+1
            end
            self.observations[p.key]=entry
        end
    end
    self.stats.completed=self.stats.completed+1
    if result.movedVertices==0 then self.stats.noEffect=self.stats.noEffect+1 end
    self.stats.movedVertices=self.stats.movedVertices+result.movedVertices
    self.stats.loweredVertices=self.stats.loweredVertices+result.loweredVertices
    self.stats.raisedVertices=self.stats.raisedVertices+result.raisedVertices
    return result,nil
end

-- Snapshot is a geometry provenance sidecar, not a replacement for
-- GIANTS native heightmap persistence. Never serialize an in-flight job as if
-- the terrain result were confirmed, and never retroactively reconstruct an
-- unknown original from the observed rut.
function Journal:exportSnapshot()
    if self.pendingCount>0 then return nil,"PENDING_NATIVE_WRITES" end
    local cells={}
    local unknown=0
    for key,entry in pairs(self.observations) do
        local current=self:getHeight(entry.x,entry.z)
        if finite(current) and math.abs(current-entry.observedHeightM)<=0.002 then
            cells[#cells+1]={
                key=key,x=entry.x,z=entry.z,
                preREHeightM=entry.preREHeightM,
                observedHeightM=current,owned=entry.owned==true
            }
        else
            -- The ground moved without a verified RE callback. Do not save
            -- stale recovery authority for that cell.
            unknown=unknown+1
        end
    end
    table.sort(cells,function(a,b)return a.key<b.key end)
    return {version=Journal.VERSION,unitM=self.unitM,cells=cells,unknown=unknown}
end

function Journal:importSnapshot(snapshot)
    if self.pendingCount>0 then return false,"PENDING_NATIVE_WRITES" end
    if type(snapshot)~="table" or snapshot.version~=Journal.VERSION
        or not finite(snapshot.unitM) or not finite(self.unitM)
        or math.abs(snapshot.unitM-self.unitM)>0.00001
        or type(snapshot.cells)~="table" then
        return false,"GEOMETRY_JOURNAL_FORMAT_OR_UNIT_MISMATCH"
    end
    local restored,rejected=0,0
    local loaded={}
    for _,cell in ipairs(snapshot.cells) do
        if type(cell)=="table" and finite(cell.x) and finite(cell.z)
            and finite(cell.preREHeightM) and finite(cell.observedHeightM) then
            local ix=math.floor(cell.x/self.unitM+0.5)
            local iz=math.floor(cell.z/self.unitM+0.5)
            local x,z=ix*self.unitM,iz*self.unitM
            local current=self:getHeight(x,z)
            if finite(current) and math.abs(current-cell.observedHeightM)<=0.005
                and math.abs(x-cell.x)<=0.00001
                and math.abs(z-cell.z)<=0.00001 then
                loaded[tostring(ix)..":"..tostring(iz)]={
                    x=x,z=z,preREHeightM=cell.preREHeightM,
                    observedHeightM=current,owned=cell.owned==true
                }
                restored=restored+1
            else
                rejected=rejected+1
            end
        else
            rejected=rejected+1
        end
    end
    self.observations=loaded
    return true,restored,rejected
end

function Journal:reset()
    self.observations={}
    self.pendingByVertex={}
    self.pendingByLogicalKey={}
    self.pendingCount=0
end

return Journal
