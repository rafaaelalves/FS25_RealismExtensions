-- Research-only MAIN-height witness, with in-memory fake XMLFile.
-- No native GIANTS setter, no filesystem, no real savegame modification.
dofile("scripts/terrain/TerrainGeometryJournal.lua")
dofile("scripts/terrain/TerrainAbsolutePersistenceWitness.lua")
local J=RealismExtensionsTerrainGeometryJournal
local W=RealismExtensionsTerrainAbsolutePersistenceWitness

local files={}
local function handler(path,record)
    return {
        setInt=function(self,key,value)record[key]=value end,
        setFloat=function(self,key,value)record[key]=value end,
        setString=function(self,key,value)record[key]=value end,
        getInt=function(self,key,default)
            return record[key]~=nil and record[key] or default
        end,
        getFloat=function(self,key,default)
            return record[key]~=nil and record[key] or default
        end,
        getString=function(self,key,default)
            return record[key]~=nil and record[key] or default
        end,
        save=function(self)files[path]=record end,
        delete=function(self)end
    }
end
XMLFile={
    create=function(_,path,root)
        return handler(path,{})
    end,
    load=function(_,path)
        if files[path]==nil then return nil end
        return handler(path,files[path])
    end
}
fileExists=function(path)return files[path]~=nil end
g_server={}
local info={savegameDirectory="/disposableClone",isValid=true,mapId="SaoCarlos"}
local original={}
local function key(x,z)return tostring(x)..":"..tostring(z)end
local function originalHeight(x,z) return 150+0.05*x-0.02*z end
local function read(x,z)
    if original[key(x,z)]~=nil then return original[key(x,z)] end
    return originalHeight(x,z)
end
local j=J.new(999,{unitM=1,sample=read})
local token=assert(j:begin("ABS:10:20",10,20,0.70))
assert(#token.points==9)
-- No movement is not valid proof of native setter effect.
assert(W.capture(j,token,10,20,0.0015,info)==nil)
original[key(10,20)]=read(10,20)-0.003891
local record,why=W.capture(j,token,10,20,0.0015,info)
assert(record~=nil and why==nil and #record.points==9)
assert(record.mapId=="SaoCarlos" and record.unitM==1)
-- The visual 1.5mm request must not permit archiving a 100mm crater as
-- a "verified persistence experiment"; the actual map step is unverified.
local violentToken=assert(j:begin("ABS:30:30",30,30,0.70))
original[key(30,30)]=read(30,30)-0.10
local bad,whyBad=W.capture(j,violentToken,30,30,0.0015,info)
assert(bad==nil and whyBad=="WITNESS_EXCESSIVE_CENTER_LOWERING")
assert(select(1,j:complete(violentToken,false)).success==false)
original[key(30,30)]=nil
assert(record.version==W.VERSION)
assert(select(1,j:complete(token,false)).success==false)
-- Opt-in cal code controls WHETHER save is called; this function itself
-- refuses absent authoritative save context.
g_server=nil
local x,blocked=W.save(info,record,j)
assert(x==false and blocked=="WITNESS_SAVE_CONTEXT_UNAVAILABLE")
g_server={}
local saved,path=W.save(info,record,j)
assert(saved==true and path==W.path(info))
assert(files[path]~=nil)
local verified,status,details=W.verifyReload(info,j)
assert(verified==true and status=="MAIN_HEIGHT_MATCHES_SAVED_WITNESS")
assert(details.matchedVertices==9)
assert(math.abs(details.centerDeltaM+0.003891)<0.000001)
assert(details.provesCollision==false)
assert(details.provesNativeFinePersistence==false)
assert(details.provesReloadOccurred==false)
-- Changed geometry after the saved witness must not be mistaken for
-- persistence of the exact original native edit.
original[key(10,20)]=read(10,20)-0.003891
verified,status,details=W.verifyReload(info,j)
assert(verified==false and status=="RELOAD_HEIGHT_MISMATCH")
assert(details.centerChanged==1)
original[key(10,20)]=record.points[5].afterY -- relies on center iteration order? verify below
local centerValue
for _,p in ipairs(record.points) do
    if p.x==10 and p.z==20 then centerValue=p.afterY end
end
original[key(10,20)]=centerValue
original[key(11,21)]=read(11,21)+0.01
verified,status,details=W.verifyReload(info,j)
assert(verified==false and status=="RELOAD_HEIGHT_MISMATCH")
assert(details.neighborsChanged==1)
local notSaved,saveReason=W.save(info,record,j)
assert(notSaved==false and saveReason=="WITNESS_CHANGED_BEFORE_SAVE")
original[key(11,21)]=nil
local wrongMap={savegameDirectory="/disposableClone",isValid=true,mapId="AnotherMap"}
assert(select(1,W.verifyReload(wrongMap,j))==false)
local otherUnit=J.new(999,{unitM=0.5,sample=read})
assert(select(1,W.verifyReload(info,otherUnit))==false)
local notHere={savegameDirectory="/otherClone",isValid=true,mapId="SaoCarlos"}
assert(select(1,W.verifyReload(notHere,j))==false)
-- A copied witness with malformed count or missing point cannot silently
-- validate an unrelated patch after save/reload.
local root=W.ROOT
files[path][root.."#vertexCount"]=8
assert(select(1,W.verifyReload(info,j))==false)
print("terrain_absolute_persistence_witness_harness: OK")
