-- Explicit opt-in persistence witness for ONE GIANTS absolute-height test
-- on a disposable copy of a singleplayer save. NO terrain writes, NO recovery
-- authority, NO fine 0.125m mesh readback. Reads MAIN 3x3 only.
RealismExtensionsTerrainAbsolutePersistenceWitness =
    RealismExtensionsTerrainAbsolutePersistenceWitness or {}
local Witness=RealismExtensionsTerrainAbsolutePersistenceWitness
Witness.VERSION=2
-- Defensive cap for this 1.5mm single-vertex research command.
-- 12mm is NOT a universal map quantum nor a release acceptance criterion.
Witness.MAX_CENTER_LOWER_M=0.012
Witness.FILE_NAME="realismExtensionsAbsolutePersistenceWitness.xml"
Witness.ROOT="realismExtensionsAbsolutePersistenceWitness"
Witness.TOLERANCE_M=0.0005

local function finite(n)
    return type(n)=="number" and n==n
        and n~=math.huge and n~=-math.huge
end
local function mapId(info)
    if type(info)~="table" then return nil end
    local id=tostring(info.mapId or info.mapTitle or "")
    return id~="" and id or nil
end
function Witness.path(info)
    if type(info)~="table" or type(info.savegameDirectory)~="string"
        or info.savegameDirectory=="" then return nil end
    return info.savegameDirectory.."/"..Witness.FILE_NAME
end

local function validate(data)
    if type(data)~="table" or data.version~=Witness.VERSION
        or type(data.mapId)~="string" or data.mapId==""
        or not finite(data.unitM) or data.unitM<=0
        or not finite(data.x) or not finite(data.z)
        or not finite(data.requestedM) or data.requestedM<=0
        or type(data.points)~="table" or #data.points~=9 then
        return false,"INVALID_WITNESS"
    end
    -- Legacy exploratory 1.5mm trial retains its 0.5mm tolerance.
    -- A new one-quantum acceptance witness provides a tighter bound
    -- which must survive serialization and subsequent save/reload.
    local epsilon=data.maxReadbackDriftM or Witness.TOLERANCE_M
    if not finite(epsilon) or epsilon<0.0000001
        or epsilon>Witness.TOLERANCE_M then
        return false,"INVALID_WITNESS_READBACK_LIMIT"
    end
    local seen,centerCount={},0
    local u=data.unitM
    for _,p in ipairs(data.points) do
        if not finite(p.x) or not finite(p.z)
            or not finite(p.beforeY) or not finite(p.afterY) then
            return false,"INVALID_WITNESS_VERTEX"
        end
        local ix=math.floor((p.x-data.x)/u+0.5)
        local iz=math.floor((p.z-data.z)/u+0.5)
        if math.abs(p.x-(data.x+ix*u))>0.0001
            or math.abs(p.z-(data.z+iz*u))>0.0001
            or math.abs(ix)>1 or math.abs(iz)>1 then
            return false,"INVALID_WITNESS_GRID"
        end
        local key=tostring(ix)..":"..tostring(iz)
        if seen[key] then return false,"DUPLICATE_WITNESS_VERTEX" end
        seen[key]=true
        local delta=p.afterY-p.beforeY
        if ix==0 and iz==0 then
            centerCount=centerCount+1
            if delta>=-epsilon
                or -delta>Witness.MAX_CENTER_LOWER_M then
                return false,"UNTRUSTED_WITNESS_CENTER_AMPLITUDE"
            end
        elseif math.abs(delta)>epsilon then
            return false,"UNTRUSTED_WITNESS_COLLATERAL"
        end
    end
    if centerCount~=1 then return false,"NO_WITNESS_CENTER" end
    return true,nil
end

function Witness.capture(journal,token,x,z,requestedM,info,
    maxReadbackDriftM)
    if type(journal)~="table" or type(journal.getHeight)~="function"
        or not finite(journal.unitM)
        or type(token)~="table" or type(token.points)~="table"
        or #token.points~=9 then
        return nil,"WITNESS_CONTEXT_UNAVAILABLE"
    end
    local identity=mapId(info)
    if identity==nil then return nil,"WITNESS_MAP_ID_UNAVAILABLE" end
    local data={version=Witness.VERSION,mapId=identity,
        unitM=journal.unitM,x=x,z=z,requestedM=requestedM,points={},
        maxReadbackDriftM=maxReadbackDriftM}
    local epsilon=maxReadbackDriftM or Witness.TOLERANCE_M
    if not finite(epsilon) or epsilon<0.0000001
        or epsilon>Witness.TOLERANCE_M then
        return nil,"INVALID_WITNESS_READBACK_LIMIT"
    end
    local changed=0
    for _,p in ipairs(token.points) do
        local after=journal:getHeight(p.x,p.z)
        if not finite(after) or not finite(p.beforeY) then
            return nil,"WITNESS_HEIGHT_UNAVAILABLE"
        end
        local delta=after-p.beforeY
        local isCenter=p.x==x and p.z==z
        if isCenter then
            if delta>=-epsilon then
                return nil,"WITNESS_NO_MEASURABLE_CENTER_LOWERING"
            end
            if -delta>Witness.MAX_CENTER_LOWER_M then
                return nil,"WITNESS_EXCESSIVE_CENTER_LOWERING"
            end
            changed=changed+1
        elseif math.abs(delta)>epsilon then
            return nil,"WITNESS_COLLATERAL_VERTEX_MOVEMENT"
        end
        data.points[#data.points+1]={
            x=p.x,z=p.z,beforeY=p.beforeY,afterY=after
        }
    end
    if changed~=1 then return nil,"WITNESS_CENTER_UNAVAILABLE" end
    local valid,reason=validate(data)
    if not valid then return nil,reason end
    return data,nil
end

-- Saves are triggered solely by explicit Cal.armPersistence("COPY") and the
-- normal GIANTS save callback. We never store a "witness" for a failed or
-- collateral-moving experimental setter. Recheck every point at save time.
function Witness.save(info,data,journal)
    if g_server==nil or info==nil or info.isValid~=true
        or type(XMLFile)~="table" or type(XMLFile.create)~="function" then
        return false,"WITNESS_SAVE_CONTEXT_UNAVAILABLE"
    end
    local valid,reason=validate(data)
    if not valid then return false,reason end
    if mapId(info)~=data.mapId then return false,"WITNESS_MAP_CHANGED" end
    local path=Witness.path(info)
    if path==nil then return false,"WITNESS_SAVE_PATH_UNAVAILABLE" end
    if type(journal)~="table" or journal.unitM~=data.unitM
        or type(journal.getHeight)~="function" then
        return false,"WITNESS_GRID_CHANGED"
    end
    local epsilon=data.maxReadbackDriftM or Witness.TOLERANCE_M
    for _,p in ipairs(data.points) do
        local y=journal:getHeight(p.x,p.z)
        if not finite(y) or math.abs(y-p.afterY)>epsilon then
            return false,"WITNESS_CHANGED_BEFORE_SAVE"
        end
    end
    local xml=XMLFile.create(Witness.ROOT,path,Witness.ROOT)
    if xml==nil then return false,"WITNESS_XML_UNAVAILABLE" end
    local root=Witness.ROOT
    xml:setInt(root.."#version",data.version)
    xml:setString(root.."#mapId",data.mapId)
    xml:setFloat(root.."#unitM",data.unitM)
    xml:setFloat(root.."#x",data.x)
    xml:setFloat(root.."#z",data.z)
    xml:setFloat(root.."#requestedM",data.requestedM)
    if data.maxReadbackDriftM~=nil then
        xml:setFloat(root.."#maxReadbackDriftM",
            data.maxReadbackDriftM)
    end
    xml:setInt(root.."#vertexCount",9)
    for i,p in ipairs(data.points) do
        local key=string.format("%s.points.point(%d)",root,i-1)
        xml:setFloat(key.."#x",p.x)
        xml:setFloat(key.."#z",p.z)
        xml:setFloat(key.."#beforeY",p.beforeY)
        xml:setFloat(key.."#afterY",p.afterY)
    end
    xml:save()
    xml:delete()
    return true,path
end

local function read(info)
    local path=Witness.path(info)
    if path==nil or type(fileExists)~="function"
        or fileExists(path)~=true then
        return nil,"NO_WITNESS_SAVED_IN_THIS_COPY"
    end
    if type(XMLFile)~="table" or type(XMLFile.load)~="function" then
        return nil,"WITNESS_XML_LOADER_UNAVAILABLE"
    end
    local xml=XMLFile.load(Witness.ROOT,path)
    if xml==nil then return nil,"WITNESS_XML_UNAVAILABLE" end
    local root=Witness.ROOT
    local d={version=xml:getInt(root.."#version",-1),
        mapId=xml:getString(root.."#mapId",""),
        unitM=xml:getFloat(root.."#unitM",-1),
        x=xml:getFloat(root.."#x"),z=xml:getFloat(root.."#z"),
        requestedM=xml:getFloat(root.."#requestedM"),
        maxReadbackDriftM=xml:getFloat(root.."#maxReadbackDriftM"),
        points={}}
    local count=xml:getInt(root.."#vertexCount",-1)
    if count==9 then
        for i=0,8 do
            local key=string.format("%s.points.point(%d)",root,i)
            d.points[#d.points+1]={
                x=xml:getFloat(key.."#x"),
                z=xml:getFloat(key.."#z"),
                beforeY=xml:getFloat(key.."#beforeY"),
                afterY=xml:getFloat(key.."#afterY")
            }
        end
    end
    xml:delete()
    local valid,reason=validate(d)
    if not valid then return nil,reason end
    return d,nil
end

function Witness.verifyReload(info,journal)
    local data,why=read(info)
    if data==nil then return false,why end
    if mapId(info)~=data.mapId then return false,"WITNESS_MAP_MISMATCH" end
    if type(journal)~="table" or journal.unitM~=data.unitM
        or type(journal.getHeight)~="function" then
        return false,"WITNESS_MAIN_GRID_MISMATCH"
    end
    local epsilon=data.maxReadbackDriftM or Witness.TOLERANCE_M
    local centerMoved,neighborsMoved,maxDrift=0,0,0
    local centerDelta=nil
    for _,p in ipairs(data.points) do
        local y=journal:getHeight(p.x,p.z)
        if not finite(y) then return false,"RELOAD_MAIN_HEIGHT_UNAVAILABLE" end
        local drift=y-p.afterY
        maxDrift=math.max(maxDrift,math.abs(drift))
        if p.x==data.x and p.z==data.z then
            centerDelta=y-p.beforeY
            if math.abs(drift)>epsilon then centerMoved=1 end
        elseif math.abs(drift)>epsilon then
            neighborsMoved=neighborsMoved+1
        end
    end
    if centerMoved>0 or neighborsMoved>0 then
        return false,"RELOAD_HEIGHT_MISMATCH",{
            centerChanged=centerMoved,neighborsChanged=neighborsMoved,
            maxDriftM=maxDrift,centerDeltaM=centerDelta
        }
    end
    return true,"MAIN_HEIGHT_MATCHES_SAVED_WITNESS",{
        matchedVertices=9,centerDeltaM=centerDelta,maxDriftM=maxDrift,
        -- We do not know from Lua whether this is a fresh game session;
        -- the user must actually reload the copied save before claiming it.
        provesNativeFinePersistence=false,provesCollision=false,
        provesAgronomicRecovery=false,provesReloadOccurred=false
    }
end
return Witness
