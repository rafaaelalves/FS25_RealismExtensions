-- TerrainPersistence harness: fake the narrow GIANTS XML surface used by RE.

local files = {}
local function newXml(path)
    local values = {}
    local xml = {}
    function xml:setInt(k,v) values[k]=v end
    function xml:setFloat(k,v) values[k]=v end
    function xml:setString(k,v) values[k]=v end
    function xml:getInt(k,d) local v=values[k]; if v==nil then return d end; return v end
    function xml:getFloat(k,d) local v=values[k]; if v==nil then return d end; return v end
    function xml:getString(k,d) local v=values[k]; if v==nil then return d end; return v end
    function xml:iterate(prefix, fn)
        local indices = {}
        for key in pairs(values) do
            local n = key:match("^" .. prefix:gsub("%.", "%%.") .. "%((%d+)%)#")
            if n ~= nil then indices[tonumber(n)] = true end
        end
        local ordered = {}
        for n in pairs(indices) do ordered[#ordered+1]=n end
        table.sort(ordered)
        for _,n in ipairs(ordered) do fn(n, prefix .. "(" .. n .. ")") end
    end
    function xml:save() files[path]=values end
    function xml:delete() end
    xml._values=values
    return xml
end

XMLFile = {}
function XMLFile.create(_,path,root) return newXml(path) end
function XMLFile.load(_,path)
    if files[path]==nil then return nil end
    local xml=newXml(path)
    xml._values=files[path]
    function xml:getInt(k,d) local v=self._values[k]; if v==nil then return d end; return v end
    function xml:getFloat(k,d) local v=self._values[k]; if v==nil then return d end; return v end
    function xml:getString(k,d) local v=self._values[k]; if v==nil then return d end; return v end
    function xml:iterate(prefix,fn)
        local indices={}
        for key in pairs(self._values) do
            local n=key:match("^"..prefix:gsub("%.","%%.").."%((%d+)%)#")
            if n~=nil then indices[tonumber(n)]=true end
        end
        local ordered={}; for n in pairs(indices) do ordered[#ordered+1]=n end; table.sort(ordered)
        for _,n in ipairs(ordered) do fn(n,prefix.."("..n..")") end
    end
    return xml
end
function fileExists(path) return files[path]~=nil end

g_server={}
g_terrainNode=42
local terrainHeights={}
function getTerrainHeightAtWorldPos(node,x,y,z)
    return terrainHeights[tostring(x)..":"..tostring(z)] or 100
end
g_currentMission={missionInfo={mapId="testMap",savegameDirectory="/save",isValid=true}}

dofile("scripts/terrain/SpatialHistory.lua")
dofile("scripts/terrain/TerrainPersistence.lua")

local h=RealismExtensionsSpatialHistory.new({cellSizeM=0.2,maxCells=100})
h:commit(1.0,2.0,{rutDepthM=0.03,longitudinalShearDistanceM=1.2,lateralShearDistanceM=0.2,slipExcavationDistanceM=2.5,passCount=7})
h:commit(-2.0,4.0,{rutDepthM=0.01,passCount=2})
terrainHeights["1.0:2.0"]=99.97
terrainHeights["-2.0:4.0"]=99.99

local ok,count=RealismExtensionsTerrainPersistence.save(g_currentMission.missionInfo,h)
assert(ok==true and count==2)

local restored=RealismExtensionsSpatialHistory.new({cellSizeM=0.2,maxCells=100})
local loaded,loadedCount=RealismExtensionsTerrainPersistence.load(g_currentMission.missionInfo,restored)
assert(loaded==true and loadedCount==2)
assert(restored.count==2)
assert(math.abs(restored:get(1.0,2.0).rutDepthM-0.03)<0.000001)
assert(restored:get(1.0,2.0).passCount==7)
assert(math.abs(restored:get(1.0,2.0).slipExcavationDistanceM-2.5)<0.000001)

-- If GIANTS reloads a flatter/different heightmap, the sidecar must not
-- restore rut/shear memory into visually incompatible terrain.
terrainHeights["1.0:2.0"]=100
terrainHeights["-2.0:4.0"]=100
local mismatched=RealismExtensionsSpatialHistory.new({cellSizeM=0.2,maxCells=100})
local geometryOk,geometryReason=RealismExtensionsTerrainPersistence.load(g_currentMission.missionInfo,mismatched)
assert(geometryOk==false)
assert(string.find(geometryReason,"geometry mismatch",1,true)~=nil)
assert(mismatched.count==0)

-- Restore saved geometry for the map-identity test.
terrainHeights["1.0:2.0"]=99.97
terrainHeights["-2.0:4.0"]=99.99

-- Same file must not leak spatial state into another map.
g_currentMission.missionInfo.mapId="otherMap"
local foreign=RealismExtensionsSpatialHistory.new({cellSizeM=0.2,maxCells=100})
local accepted,reason=RealismExtensionsTerrainPersistence.load(g_currentMission.missionInfo,foreign)
assert(accepted==false and reason=="map identity mismatch")
assert(foreign.count==0)

-- Clients never write authoritative history.
g_server=nil
local clientOk=RealismExtensionsTerrainPersistence.save(g_currentMission.missionInfo,h)
assert(clientOk==false)

print("terrain_persistence_harness: OK")
