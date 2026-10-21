-- Dedicated read-only FS25 terrain-height diagnostic probe.
-- The 0.125m stride is dense sampling of the SAME 1m main terrain API:
-- it MUST NOT be misrepresented as direct high-res displacement access.
local log, registered, removed = {}, {}, {}
print = function(msg) log[#log+1]=tostring(msg) end
addConsoleCommand = function(name, _, method, receiver)
    registered[name] = {method=method, receiver=receiver}
end
removeConsoleCommand = function(name) removed[name]=true end

local base=123.0
local variation=0
g_server={}
g_currentMission={
    terrainRootNode=99,
    player={rootNode=50}
}
getWorldTranslation=function(node)
    assert(node==50)
    return 10,0,20
end
getTerrainHeightmapUnitSize=function(node)
    assert(node==99)
    return 1
end
getTerrainHeightAtWorldPos=function(node,x,_,z)
    assert(node==99)
    local sample=base+0.01*x+0.02*z
    if math.abs(x-10)<=0.25 and math.abs(z-20)<=0.25 then
        sample=sample+variation
    end
    return sample
end
local written=false
setTerrainHeightAtWorldPos=function()
    written=true;error("READ ONLY MUST NEVER WRITE")
end
RealismExtensionsTerrainRuntime={history={
    get=function(self,x,z)
        if math.abs(x-10)<0.001 and math.abs(z-20)<0.001 then
            return {rutDepthM=0.04,preDeformHeightM=124}
        end
    end
}}

dofile("scripts/terrain/TerrainGeometryProbe.lua")
local p=assert(RealismExtensionsTerrainGeometryProbe)
assert(p.installCommands()==true)
assert(registered.reGeoMark and registered.reGeoSnap)
assert(p:consoleMark():find("MARK"))
assert(p.position.x==10 and p.position.z==20)
local before=assert(p.capture("before"))
assert(before.fine.count==289 and before.main.count==25)
assert(before.unitM==1 and before.rutDepthM==0.04)
assert(before.preDeformHeightM==124)
variation=0.055
local after=assert(p.capture("after"))
assert(after.x==before.x and after.z==before.z)
local foundMain=false
local foundDense=false
for _,line in ipairs(log) do
    if line:find("DELTA") and line:find("grid=1m") then
        foundMain=true
        assert(line:find("maxRaise=0.0550m"))
    end
    if line:find("DELTA") and line:find("grid=0.125m") then
        foundDense=true
        assert(line:find("289"))
    end
end
assert(foundMain and foundDense and not written)

p:consoleMark("5.5","6.25")
assert(p.position.x==5.5 and p.position.z==6.25)
assert(p.previous==nil)
assert(p.capture("fresh")~=nil)
p.uninstallCommands()
assert(removed.reGeoMark and removed.reGeoSnap)
assert(p.position==nil and p.previous==nil)
assert(not written)
io.write("terrain_geometry_probe_harness: OK\n")
