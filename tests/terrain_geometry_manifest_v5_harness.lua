-- V5 exact count/key-identity manifest + native readback fail closed.
-- Every height below is a simulation; NO GIANTS terrain setter is called.
local files={}
local function XML(path,values)
    values=values or {}
    local xml={data=values}
    function xml:setFloat(k,v) values[k]=v end
    function xml:setInt(k,v) values[k]=v end
    function xml:setString(k,v) values[k]=v end
    function xml:setBool(k,v) values[k]=v end
    function xml:getFloat(k,default)
        local v=values[k];return v~=nil and v or default
    end
    function xml:getInt(k,default)
        local v=values[k];return v~=nil and v or default
    end
    function xml:getString(k,default)
        local v=values[k];return v~=nil and v or default
    end
    function xml:getBool(k,default)
        local v=values[k];return v~=nil and v or default
    end
    function xml:iterate(prefix,callback)
        local matches={}
        local pattern="^"..prefix:gsub("%.","%%.").."%((%d+)%)#"
        for k in pairs(values) do
            local ix=k:match(pattern)
            if ix then matches[tonumber(ix)]=true end
        end
        local keys={}
        for ix in pairs(matches) do keys[#keys+1]=ix end
        table.sort(keys)
        for _,ix in ipairs(keys) do
            callback(ix,prefix.."("..ix..")")
        end
    end
    function xml:save()files[path]=values end
    function xml:delete()end
    return xml
end
XMLFile={
    create=function(_,path) return XML(path) end,
    load=function(_,path)
        if files[path]==nil then return nil end
        return XML(path,files[path])
    end
}
fileExists=function(path)return files[path]~=nil end
g_server={}
g_currentMission={missionInfo={
    mapId="manifest-a",savegameDirectory="/save",isValid=true
}}
local base=100
local heights={}
local function key(x,z)return tostring(x)..":"..tostring(z)end
local function get(x,z)
    local y=heights[key(x,z)]
    return y~=nil and y or base
end
local function set(x,z,y)heights[key(x,z)]=y end
g_terrainNode=99
getTerrainHeightAtWorldPos=function(_,x,_,z)return get(x,z)end
dofile("scripts/terrain/TerrainGeometryJournal.lua")
dofile("scripts/terrain/TerrainPersistence.lua")
local J=RealismExtensionsTerrainGeometryJournal
local P=RealismExtensionsTerrainPersistence
local function journal()return J.new(99,{unitM=1,sample=get})end
local original=journal()
local function lower(j,x,z,amount)
    local t=assert(j:begin("wheel:"..key(x,z),x,z,0.3))
    set(x,z,base-amount)
    assert(j:complete(t,true).loweredVertices==1)
end
lower(original,10,10,0.02)
lower(original,20,20,0.03)
local r=assert(original:beginRecovery(
    assert(original:getRecoverablePoint(10,10)),0.70,false))
set(10,10,base-0.01)
local p=assert(original:finishRecovery(r,true))
assert(p.safe and p.gainM>0)
assert(original:getRecoveryFence("10:10").trusted)
assert(not original:getRecoveryFence("10:10").accounted)
local saved=assert(original:exportSnapshot())
assert(saved.version==5 and saved.manifest.cellCount==2)
assert(saved.manifest.fenceCount==1)
assert(type(saved.manifest.cellKeys)=="string")
assert(type(saved.manifest.fenceKeys)=="string")
assert(saved.manifest.cellKeys~=saved.manifest.fenceKeys)
assert(P.saveGeometryJournal(g_currentMission.missionInfo,original))
local fresh=journal()
assert(P.loadGeometryJournal(g_currentMission.missionInfo,fresh))
assert(fresh.recoveryFenceCount==1 and fresh.observations["20:20"].owned)
assert(select(2,fresh:getLoweringBudget(10,10,0.7,0.10,0.12))
    =="UNACCOUNTED_RECOVERY_EPOCH")
local path=P.getGeometryPath(g_currentMission.missionInfo)
local root=P.GEOMETRY_ROOT

local function copy(src)
    local target={}
    for k,v in pairs(src) do target[k]=v end
    return target
end
local stored=copy(files[path])
-- One fence disappears from a partial GIANTS XML write. It MUST NOT be
-- seen as a smaller valid list, even if the heightmap itself is intact.
local truncated=copy(stored)
for k in pairs(truncated) do
    if k:find(".recoveryFences.fence(",1,true) then
        truncated[k]=nil
    end
end
files[path]=truncated
local broken=journal()
local ok,why=P.loadGeometryJournal(g_currentMission.missionInfo,broken)
assert(not ok and why=="GEOMETRY_JOURNAL_MANIFEST_MISMATCH")
assert(broken.quarantined)
assert(select(2,broken:begin("fresh",70,70,0.3))
    =="GEOMETRY_JOURNAL_QUARANTINED")
assert(select(2,broken:getLoweringBudget(70,70,0.5,0.10,0.12))
    =="GEOMETRY_JOURNAL_QUARANTINED")
assert(select(2,broken:exportSnapshot())
    =="GEOMETRY_JOURNAL_QUARANTINED")
assert(P.saveGeometryJournal(g_currentMission.missionInfo,broken)==false)
-- Refused save must NOT overwrite the original incomplete XML.
assert(files[path]==truncated)

-- Corrupt the same row count with a duplicate vertex: manifest catches
-- key substitution and cannot simply keep the first row and forget one.
local duplicate=copy(stored)
duplicate[root..".cells.cell(1)#x"]=10
duplicate[root..".cells.cell(1)#z"]=10
files[path]=duplicate
local duplicateJournal=journal()
local uniqueOk,uniqueWhy=P.loadGeometryJournal(
    g_currentMission.missionInfo,duplicateJournal)
assert(not uniqueOk and uniqueWhy=="GEOMETRY_JOURNAL_MANIFEST_MISMATCH")
assert(duplicateJournal.quarantined)

-- Header count alone also detects missing rows; key fingerprint detects
-- substitution when the number of records is identical.
local missingHeader=copy(stored)
missingHeader[root.."#fenceKeys"]=nil
files[path]=missingHeader
local noFingerprint=journal()
assert(P.loadGeometryJournal(g_currentMission.missionInfo,noFingerprint)
    ==false)
assert(noFingerprint.quarantined)

-- Revert to a valid sidecar. The GAME terrain changed outside of RE by
-- >5mm. V5 MUST retain the affected vertex in the denial map as
-- owned=false instead of silently dropping its old location.
files[path]=copy(stored)
set(20,20,base+0.06)
local foreign=journal()
local fOk,restored,rejected=P.loadGeometryJournal(
    g_currentMission.missionInfo,foreign)
assert(fOk and restored==2 and rejected==0)
assert(foreign.observations["20:20"]~=nil)
assert(foreign.observations["20:20"].owned==false)
assert(foreign.stats.importForeignHeightDowngrades>=1)
assert(select(2,foreign:getLoweringBudget(20,20,0.7,0.10,0.12))
    =="UNTRUSTED_EDIT")
assert(P.saveGeometryJournal(g_currentMission.missionInfo,foreign))
local reload=journal()
assert(P.loadGeometryJournal(g_currentMission.missionInfo,reload))
assert(reload.observations["20:20"].owned==false)

-- A sidecar from a foreign map, or one present but impossible to parse,
-- must globally quarantine the next automatic source, not reset it.
g_currentMission.missionInfo.mapId="other-map"
local mapWrong=journal()
assert(select(2,P.loadGeometryJournal(g_currentMission.missionInfo,mapWrong))
    =="geometry journal map identity mismatch")
assert(mapWrong.quarantined)
g_currentMission.missionInfo.mapId="manifest-a"
local beforeCorrupt=files[path]
XMLFile.load=function()return nil end
local xmlBad=journal()
assert(P.loadGeometryJournal(g_currentMission.missionInfo,xmlBad)==false)
assert(xmlBad.quarantined)
files[path]=beforeCorrupt

-- A brand-new save WITHOUT a journal is not evidence of corruption;
-- it can begin observation-only without borrowing provenance.
local empty=journal()
g_currentMission.missionInfo.savegameDirectory="/new-empty-save"
assert(select(2,P.loadGeometryJournal(g_currentMission.missionInfo,empty))
    =="no persisted geometry journal")
assert(not empty.quarantined)
print("terrain_geometry_manifest_v5_harness: OK")
