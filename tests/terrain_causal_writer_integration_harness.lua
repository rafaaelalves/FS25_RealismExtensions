-- Integrated causal tillage exercise through the *actual RE TerrainWriter*.
-- Fake native GIANTS TerrainDeformation uses a 1m vertex grid, not an
-- unrealistically effective arbitrary 0.20m logical cell writer.
local heights={}
local function key(x,z) return tostring(x)..":"..tostring(z) end
local function baseline(x,z) return 100+0.12*x+0.07*z end
local function get(x,z) return heights[key(x,z)] or baseline(x,z) end
local function set(x,z,y) heights[key(x,z)]=y end
g_currentMission={terrainRootNode=42,time=1000}
g_terrainNode=42
g_server={}
function getTerrainHeightmapUnitSize(node) assert(node==42);return 1 end
function getTerrainHeightAtWorldPos(node,x,y,z)
    assert(node==42)
    return get(x,z)
end

local nativeCalls={}
TerrainDeformation={STATE_SUCCESS=1,NO_TERRAIN_BRUSH=-1}
function TerrainDeformation.new(node)
    assert(node==42)
    local d={brushes={},deleted=false}
    function d:setAdditiveHeightChangeAmount(n) self.amount=n end
    function d:enableSetDeformationMode() self.targetMode=true end
    function d:enableSmoothingMode() self.smoothMode=true end
    function d:enableAdditiveDeformationMode() self.additive=true end
    function d:setHeightTarget(min,max,nx,ny,nz,distance)
        self.heightPlane={nx=nx,ny=ny,nz=nz,d=distance}
    end
    function d:setOutsideAreaConstraints(...) end
    function d:setBlockedAreaMaxDisplacement(...) end
    function d:setDynamicObjectCollisionMask(...) end
    function d:setDynamicObjectMaxDisplacement(...) end
    function d:addSoftCircleBrush(x,z,radius,hardness,strength,terrainBrush)
        table.insert(self.brushes,{x=x,z=z,radius=radius,
            hardness=hardness,strength=strength,terrainBrush=terrainBrush})
    end
    function d:apply(preview,callbackName,target)
        assert(preview==false and self.targetMode==true)
        local moved=0
        for _,brush in ipairs(self.brushes) do
            assert(brush.radius>0.5 and brush.radius<1)
            assert(brush.terrainBrush==-1)
            local nx=math.floor(brush.x+0.5)
            local nz=math.floor(brush.z+0.5)
            for x=nx-1,nx+1 do
                for z=nz-1,nz+1 do
                    local dist=math.sqrt((x-brush.x)^2+(z-brush.z)^2)
                    if dist<=brush.radius then
                        local pl=self.heightPlane
                        local intended=-(pl.nx*x+pl.nz*z+pl.d)/pl.ny
                        local old=get(x,z)
                        local new=old+(intended-old)*brush.strength
                        -- Native set mode may converge partially; the
                        -- callback must measure ACTUAL movement, not intent.
                        set(x,z,new)
                        moved=moved+1
                    end
                end
            end
        end
        table.insert(nativeCalls,moved)
        target[callbackName](target,1,0.01,nil)
        return true
    end
    function d:delete() self.deleted=true end
    return d
end

RealismExtensionsConfig={modules={
    TerrainDeformation=true,TerrainRecovery=true,
    TerrainGeometryJournal=true,TerrainCausalRecovery=true,
    SoilMassTransport=false
},diagnostics={verbose=false,expensiveGeometry=false}}
dofile("scripts/terrain/TerrainGeometryJournal.lua")
dofile("scripts/terrain/TerrainCausalRecovery.lua")
dofile("scripts/terrain/TerrainWriter.lua")
local j=RealismExtensionsTerrainGeometryJournal.new(42)
assert(j.unitM==1)
local w=RealismExtensionsTerrainWriter.new({
    maxJobsPerFrame=4,maxBrushesPerFrame=4,
    maxBrushesPerJob=4,coalesceDistanceFactor=0
})
RealismExtensionsTerrainRuntime={geometryJournal=j,writer=w,history=nil}
RealismExtensionsLoadedContactRegistry={overlapsCircle=function()return false end}
local C=RealismExtensionsTerrainCausalRecovery
local damage=assert(j:begin("wheel:0",0,0,0.30))
set(0,0,baseline(0,0)-0.20)
assert(j:complete(damage,true).loweredVertices==1)
assert(j.observations["0:0"].owned==true)
local area={xs=-0.6,zs=-0.6,ux=1.2,uz=0,vx=0,vz=1.2}
local profile={id="PLOW",surfaceRegrade01=0.9}
assert(C.observeWorkedArea(area,profile)==1)
C.update()
assert(C.inFlight~=nil)
local before=get(0,0)
local submitted,jobs=w:flush()
assert(submitted==1 and jobs==1 and #nativeCalls==1)
assert(C.inFlight==nil and C.stats.improved==1)
assert(get(0,0)>before)
assert(get(1,0)==baseline(1,0))
assert(get(0,1)==baseline(0,1))
-- Two actual writer-backed operations should approach the original contour;
-- zero made-up flattening of surrounding native vertices.
g_currentMission.time=2000
assert(C.observeWorkedArea(area,profile)==1)
C.update()
assert(C.inFlight~=nil)
w:flush()
assert(#nativeCalls==2 and C.stats.improved==2)
assert(get(0,0)>baseline(0,0)-0.04)
assert(get(1,0)==baseline(1,0))
assert(get(0,1)==baseline(0,1))
assert(j.observations["0:0"]~=nil)
-- No false completion without a real native-height match. With a
-- simulated engine that applies only 65% of the distance to every target,
-- additional real operations are necessary even when logic is correct.
for i=3,5 do
    g_currentMission.time=i*1000
    assert(C.observeWorkedArea(area,profile)==1)
    C.update();w:flush()
    if i<5 then assert(j.observations["0:0"]~=nil) end
end
assert(j.observations["0:0"]==nil)
assert(C.stats.completed==5)
print("terrain_causal_writer_integration_harness: OK")
