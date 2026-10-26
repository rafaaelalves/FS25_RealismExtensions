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
    -- Deliberately do NOT provide g_currentMission.player: the real-game
    -- regression was hidden by an invalid harness-only mission.player.
}
local vehicle=nil
g_localPlayer={
    getPosition=function() return 10,0,20 end,
    getCurrentVehicle=function() return vehicle end
}
getWorldTranslation=function(node)
    assert(node==77)
    return 14,0,22
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
    end,
    getRecoveryCellsCircle=function(self,x,z,radius,opts)
        assert(radius==1.5)
        assert(opts.maxCells==256)
        if math.abs(x-10)<0.001 and math.abs(z-20)<0.001 then
            return {{x=10,z=20,rutDepthM=0.04},{x=10.2,z=20,rutDepthM=0.06}}
        end
        return {}
    end
}}

dofile("scripts/terrain/TerrainGeometryProbe.lua")
local p=assert(RealismExtensionsTerrainGeometryProbe)
assert(p.installCommands()==true)
assert(registered.reGeoMark and registered.reGeoSnap)
assert(p:consoleMark():find("MARK"))
assert(p.position.x==10 and p.position.z==20)
assert(log[#log]:find("origin=player%-position"))
local before=assert(p.capture("before"))
assert(before.fine.count==289 and before.main.count==25)
assert(before.unitM==1 and before.rutDepthM==0.04)
assert(before.preDeformHeightM==124)
-- Wheel attribution on the marked patch must be explicit, not inferred
-- from global movement counters. Context and actual soil eligibility differ.
p.observeWheelContact(10.3,20.4,"context")
p.observeWheelContact(10.3,20.4,"eligible")
p.observeWheelContact(12.7,20,"context")
p.observeWheelContact(30,50,"context")
assert(p.contactEvents.context.total==3)
assert(p.contactEvents.context.near2m==1)
assert(p.contactEvents.context.near4m==2)
assert(p.contactEvents.eligible.total==1)
assert(p.contactEvents.eligible.near2m==1)
-- Writer callback associations are spatially bounded and are NOT assumed
-- to be exact native vertex ownership. Cover both nested rectangles.
p.observeWriterCallback({x=10.1,z=20.1,radiusM=0.20},"LOWER",nil,-0.030)
p.observeWriterCallback({x=10,z=21.2,radiusM=0.40},"TARGET","RECOVERY",0.025)
p.observeWriterCallback({x=11.75,z=20,radiusM=0.20},"LOWER",nil,-0.015)
p.observeWriterCallback({x=15,z=20,radiusM=0.20},"TARGET","RECOVERY",0.030)
assert(p.writeEvents.near2m.lower==1)
assert(p.writeEvents.near2m.target==1)
assert(p.writeEvents.near4m.lower==2)
assert(p.writeEvents.near4m.target==1)
variation=0.055
local after=assert(p.capture("after"))
assert(p.writeEvents.near2m.lower==0 and p.writeEvents.near4m.target==0)
assert(p.contactEvents.context.total==0 and p.contactEvents.eligible.total==0)
local combined=table.concat(log,"\n")
assert(combined:find("WHEEL_CONTACT interval=before%->after stage=context total=3 near2m=1 near4m=2"))
assert(combined:find("WHEEL_CONTACT interval=before%->after stage=eligible total=1 near2m=1 near4m=1"))
assert(table.concat(log,"\n"):find("HISTORY_NEAR radius=1.5m cells=2"))
assert(table.concat(log,"\n"):find("WRITER_NEAR interval=before%->after area=near2m wheelLower=1"))
assert(table.concat(log,"\n"):find("WRITER_NEAR interval=before%->after area=near4m wheelLower=2"))
assert(table.concat(log,"\n"):find("SHAPE from=before to=after"))
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
-- Zero-contact snapshots must still emit the explicit absence of contact.
assert(p.capture("still")~=nil)
assert(table.concat(log,"\n"):find("WHEEL_CONTACT interval=after%->still stage=context total=0 near2m=0 near4m=0 nearest=none"))

-- Driver position should be the occupied vehicle, not the stale player's
-- last foot position.
vehicle={rootNode=77}
assert(p:consoleMark():find("origin=vehicle%-root"))
assert(p.position.x==14 and p.position.z==22)
vehicle={rootNode=0}
assert(p:consoleMark():find("vehicle%-position%-unavailable"))
-- Failure must not erase a previous successful snapshot.
assert(p.position.x==14 and p.position.z==22)
vehicle=nil
-- Wrong/partial explicit coordinates fail closed, never mark implicitly.
assert(p:consoleMark("5.5"):find("Invalid coordinates"))
assert(p.position.x==14)
p:consoleMark("5.5","6.25")
assert(p.position.x==5.5 and p.position.z==6.25)
assert(p.previous==nil)
assert(p.capture("fresh")~=nil)

-- Both documented positional fallbacks are supported without relying on
-- g_currentMission.player.
g_localPlayer={
    getMapPositionAndLookYaw=function() return 3,4,0 end
}
assert(p:consoleMark():find("origin=player%-map%-position"))
assert(p.position.x==3 and p.position.z==4)
g_localPlayer={rootNode=77}
assert(p:consoleMark():find("origin=player%-root"))
assert(p.position.x==14 and p.position.z==22)
g_localPlayer=nil
assert(p:consoleMark():find("no%-local%-player"))
p.uninstallCommands()
assert(removed.reGeoMark and removed.reGeoSnap)
assert(p.position==nil and p.previous==nil)
assert(not written)
io.write("terrain_geometry_probe_harness: OK\n")
