-- Exact geometry recovery fences survive XML save/reload; no FS25 writer.
-- Loaded MAIN height is independently sampled, not reconstructed from XML.
local files={}
local function xmlFor(path,values)
    values=values or {}
    local xml={values=values}
    function xml:setInt(k,v) values[k]=v end
    function xml:setFloat(k,v) values[k]=v end
    function xml:setString(k,v) values[k]=v end
    function xml:setBool(k,v) values[k]=v end
    function xml:getInt(k,d) local v=values[k];return v~=nil and v or d end
    function xml:getFloat(k,d) local v=values[k];return v~=nil and v or d end
    function xml:getString(k,d) local v=values[k];return v~=nil and v or d end
    function xml:getBool(k,d) local v=values[k];return v~=nil and v or d end
    function xml:iterate(prefix,fn)
        local indexes={}
        local pattern="^"..prefix:gsub("%.","%%.").."%((%d+)%)#"
        for k in pairs(values) do
            local n=k:match(pattern)
            if n then indexes[tonumber(n)]=true end
        end
        local ordered={}
        for n in pairs(indexes) do ordered[#ordered+1]=n end
        table.sort(ordered)
        for _,n in ipairs(ordered) do fn(n,prefix.."("..n..")") end
    end
    function xml:save() files[path]=values end
    function xml:delete() end
    return xml
end
XMLFile={
    create=function(_,path) return xmlFor(path) end,
    load=function(_,path)
        if files[path]==nil then return nil end
        return xmlFor(path,files[path])
    end
}
fileExists=function(path)return files[path]~=nil end
g_server={}
g_terrainNode=999
g_currentMission={missionInfo={
    mapId="estancia-test-clone",savegameDirectory="/save",isValid=true
}}
local time=1000
local q=255/65535
local baseline=36000*q
local heights={}
local function key(x,z)return tostring(x)..":"..tostring(z)end
local function read(x,z)
    local y=heights[key(x,z)]
    return y~=nil and y or baseline
end
getTerrainHeightAtWorldPos=function(_,x,_,z)return read(x,z)end
local function set(x,z,y)heights[key(x,z)]=y end

dofile("scripts/terrain/TerrainGeometryJournal.lua")
dofile("scripts/terrain/TerrainQuantizedHeightBudget.lua")
dofile("scripts/terrain/TerrainPersistence.lua")
local J=RealismExtensionsTerrainGeometryJournal
local B=RealismExtensionsTerrainQuantizedHeightBudget
local P=RealismExtensionsTerrainPersistence
local j=J.new(999,{unitM=1,sample=read})
local t=assert(j:begin("wheel",10,10,0.30))
set(10,10,baseline-2*q)
assert(j:complete(t,true).loweredVertices==1)
assert(j:getRecoverablePoint(10,10)~=nil)
local paid=assert(B.new({quantumM=q,clock=function()return time end}))
assert(paid:seedOwnedTarget("10:10",2*q))
local first=assert(j:beginRecovery(
    assert(j:getRecoverablePoint(10,10)),0.56,true))
set(10,10,baseline-q)
local part=assert(j:finishRecovery(first,true))
assert(part.safe and part.gainM>0 and not part.completed)
-- Merely raising native MAIN isn't a paid-ledger reconciliation.
assert(j:getRecoveryFence("10:10").trusted==true)
assert(j.recoveryFences["10:10"].accounted==false)
assert(j.recoveryFences["10:10"].pendingProof==true)
assert(paid:syncVerifiedRecovery(j,part.recoveryProof))
assert(j:getRecoveryFence("10:10").trusted==true)
assert(j.recoveryFences["10:10"].accounted==true)
assert(j.recoveryFences["10:10"].completed==false)

local ok,n=P.saveGeometryJournal(g_currentMission.missionInfo,j)
assert(ok and n>=1)
local j2=J.new(999,{unitM=1,sample=read})
assert(P.loadGeometryJournal(g_currentMission.missionInfo,j2))
assert(j2.observations["10:10"].owned==true)
assert(j2:getRecoveryFence("10:10").trusted==true)
assert(j2.recoveryFences["10:10"].completed==false)
local budget=assert(B.new({quantumM=q,clock=function()return time end}))
assert(budget:seedPersistedRecovery(j2,"10:10"))
assert(budget.entries["10:10"].recoveryEpochPending)
assert(math.abs(budget.entries["10:10"].committedM-q)<1e-7)
assert(select(2,budget:requestTarget("10:10",
    2*q,0.10))=="NEW_DAMAGE_EPOCH_REQUIRED_AFTER_RECOVERY")
assert(select(2,budget:seedPersistedRecovery(j2,"10:10"))
    =="RECOVERY_TARGET_ALREADY_TRACKED")

-- Full recovery removes the owned depression, but the old-wheel replay
-- tombstone MUST remain on disk and must be independently verified.
local second=assert(j2:beginRecovery(
    assert(j2:getRecoverablePoint(10,10)),0.56,true))
set(10,10,baseline)
local done=assert(j2:finishRecovery(second,true))
assert(done.safe and done.completed)
assert(j2.observations["10:10"]==nil)
assert(j2:getRecoveryFence("10:10").trusted==true)
assert(j2:getRecoveryFence("10:10").accounted==false)
assert(budget:syncVerifiedRecovery(j2,done.recoveryProof))
assert(j2:getRecoveryFence("10:10").trusted==true)
assert(j2:getRecoveryFence("10:10").accounted==true)
assert(j2.recoveryFences["10:10"].completed==true)
assert(P.saveGeometryJournal(g_currentMission.missionInfo,j2))
local j3=J.new(999,{unitM=1,sample=read})
assert(P.loadGeometryJournal(g_currentMission.missionInfo,j3))
assert(j3.observations["10:10"]==nil)
assert(j3:getRecoveryFence("10:10").trusted==true)
local afterLoad=assert(B.new({quantumM=q,clock=function()return time end}))
assert(afterLoad:seedPersistedRecovery(j3,"10:10"))
assert(afterLoad.entries["10:10"].committedM==0)
assert(afterLoad.entries["10:10"].recoveryEpochPending)
assert(select(2,afterLoad:requestTarget("10:10",2*q,0.1))
    =="NEW_DAMAGE_EPOCH_REQUIRED_AFTER_RECOVERY")
assert(afterLoad:requestTarget("10:10",2*q,0.1,{key="10:10"})==nil)

-- Even a tiny foreign modification makes the saved fence permanently
-- UNTRUSTED. Do not rebase originalY onto the foreign height and
-- accidentally grant automatic recovery or fresh wheel excavation.
set(10,10,baseline-0.00002)
local j4=J.new(999,{unitM=1,sample=read})
assert(P.loadGeometryJournal(g_currentMission.missionInfo,j4))
assert(j4:getRecoveryFence("10:10").trusted==false)
assert(select(2,j4:getLoweringBudget(10,10,0.70,0.10,0.12))
    =="UNTRUSTED_RECOVERY_EPOCH")
local unsafe=assert(B.new({quantumM=q,clock=function()return time end}))
assert(select(2,unsafe:seedPersistedRecovery(j4,"10:10"))
    =="PERSISTED_RECOVERY_FENCE_UNTRUSTED")
assert(unsafe.quarantined==true)
-- Save the invalid marker. Reload must not forget this safety barrier.
assert(P.saveGeometryJournal(g_currentMission.missionInfo,j4))
local j5=J.new(999,{unitM=1,sample=read})
assert(P.loadGeometryJournal(g_currentMission.missionInfo,j5))
assert(j5.recoveryFences["10:10"].trusted==false)

print("terrain_recovery_epoch_persistence_harness: OK")
