-- Genuine work-area geometry selectively retires VOLATILE SHADOW history.
-- Native GIANTS principal heightmap and persisted SpatialHistory never write.
dofile("scripts/terrain/TerrainAbsoluteHeightPlanner.lua")
local P=RealismExtensionsTerrainAbsoluteHeightPlanner
local p=assert(P.new({unitM=1,logicalCellSizeM=0.2,maxSources=8,
    maxWorkedVertices=100}))
local function add(key,x,z,depth)
    return assert(p:observe(key,x,z,depth,0,{
        rutDepthM=depth,deformationExposure=0.05,
        longitudinalShearDistanceM=0.1,passCount=1
    }))
end
add("inside1",1,1,0.006)
add("inside2",1.2,1.2,0.004)
add("outside",3,1,0.009)
add("border",0.04,1,0.003)
assert(p.sourceCount==4)
local bad=p:onWorkedArea({xs=0,zs=0,ux=100000,uz=0,vx=0,vz=100000})
assert(bad==nil and p.sourceCount==4)
assert(p.stats.workAreaRejects==1)
local cleared=assert(p:onWorkedArea({
    xs=0,zs=0,ux=2,uz=0,vx=0,vz=2,
    widthM=2,depthM=2
}))
assert(cleared==2)
assert(p.sourceCount==2)
assert(p.sources.inside1==nil and p.sources.inside2==nil)
assert(p.sources.outside~=nil and p.sources.border~=nil)
assert(math.abs(p.stats.workAreaDemandClearedM-0.01)<1e-8)
assert(p:getVertex(1,1)==nil)
assert(p:getVertex(3,1).demandM==0.009)
assert(p:onWorkedArea({xs=0,zs=0,ux=2,uz=0,vx=0,vz=2})==0)
assert(p.sourceCount==2)

-- A new wheel after tillage starts with a fresh physical model epoch.
local before=p.stats.virtualHistoryReads
assert(p:getModelHistory("inside1",1,1,nil)==nil)
assert(p.stats.virtualHistoryReads==before)
local new=add("inside1",1,1,0.002)
assert(new.state=="QUANTUM_UNVERIFIED")
assert(p.sourceCount==3)
assert(p:getVertex(1,1).demandM==0.002)

-- A rotated, non-axis-aligned worked polygon must use the true inverse
-- parallelogram basis rather than its bounding rectangle.
local r=assert(P.new({unitM=1,maxSources=5}))
add= function(key,x,z,depth)
    return assert(r:observe(key,x,z,depth,0))
end
add("diamondCenter",10,10,0.005)
add("bboxOnly",10.95,10.95,0.005)
-- Central rotated 2.8m square (diamond), center x=10,z=10.
local g={xs=10,zs=8,ux=2,uz=2,vx=-2,vz=2}
assert(r:onWorkedArea(g)==1)
assert(r.sources.diamondCenter==nil)
assert(r.sources.bboxOnly~=nil)
print("terrain_absolute_height_workarea_harness: OK")
