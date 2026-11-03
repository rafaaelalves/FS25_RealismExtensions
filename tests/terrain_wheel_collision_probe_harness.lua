-- Pure-GIANTS-mock collision probe: no native edit, no fine-mesh claim.
dofile("scripts/terrain/TerrainWheelCollisionProbe.lua")
local P=RealismExtensionsTerrainWheelCollisionProbe
local mode="LOCAL"
local origin={100,50,100}
local contactObject=999
local calls=0
local terrainCalls=0
g_server={}
getWorldTranslation=function(node)
    assert(node==101)
    return origin[1],origin[2],origin[3]
end
localToWorld=function(node,x,y,z)
    assert(node==101)
    return origin[1]+x,origin[2]+y,origin[3]+z
end
getWheelShapeContactPoint=function(node,shape)
    calls=calls+1
    assert(node==101 and shape==7)
    if mode=="NO_CONTACT" then return nil end
    if mode=="WORLD" then return 100,49.45,100,0.01 end
    if mode=="NONFINITE" then return 0,0/0,0 end
    return 0,-0.55,0,0.01
end
getWheelShapeContactObject=function(node,shape)
    assert(node==101 and shape==7)
    return contactObject,0
end
getTerrainHeightAtWorldPos=function(terrain,x,y,z)
    terrainCalls=terrainCalls+1
    assert(terrain==999 and y==0)
    assert(math.abs(x-100)<0.001 and math.abs(z-100)<0.001)
    return 49.5
end
local vehicle={isServer=true,isAddedToPhysics=true}
local wheel={node=101,physics={wheelShape=7,displacementScale=0.75}}
local s,why=P.sampleWheel(vehicle,wheel,999)
assert(s and not why)
assert(s.state=="TERRAIN_CONTACT_OBSERVED")
assert(s.terrainContact==true and s.frame=="LOCAL_INFERRED")
assert(math.abs(s.contact.y-49.45)<0.00001)
assert(math.abs(s.contactMinusMainM+0.05)<0.00001)
assert(s.skinWidthM==0.01 and s.physicsScale==0.75)
assert(s.authorizesTerrainWrite==false and s.provesFineSurfaceHeight==false)
assert(s.provesCollisionAgreement==false)
mode="WORLD"
s=P.sampleWheel(vehicle,wheel,999)
assert(s.frame=="WORLD_INFERRED")
assert(math.abs(s.contactMinusMainM+0.05)<0.00001)
mode="LOCAL"
contactObject=1000
local oldHeightCalls=terrainCalls
s=P.sampleWheel(vehicle,wheel,999)
assert(s.state=="NON_TERRAIN_CONTACT")
assert(s.terrainContact==false and s.contactMinusMainM==nil)
assert(terrainCalls==oldHeightCalls)
contactObject=999
mode="NO_CONTACT"
s=P.sampleWheel(vehicle,wheel,999)
assert(s.state=="NO_CONTACT" and s.terrainContact==false)
mode="NONFINITE"
assert(select(1,P.sampleWheel(vehicle,wheel,999))==nil)
mode="LOCAL"
origin={0,0,0}
s=P.sampleWheel(vehicle,wheel,999)
assert(s.state=="CONTACT_FRAME_UNVERIFIED")
assert(s.reason=="FRAME_AMBIGUOUS")
assert(s.contactMinusMainM==nil)
origin={100,50,100}
vehicle.isServer=false
assert(select(1,P.sampleWheel(vehicle,wheel,999))==nil)
vehicle.isServer=true
vehicle.isAddedToPhysics=false
assert(select(1,P.sampleWheel(vehicle,wheel,999))==nil)
vehicle.isAddedToPhysics=true
local bad={node=0,physics={wheelShape=7}}
assert(select(1,P.sampleWheel(vehicle,bad,999))==nil)
-- One-shot bounded vehicle scan, never 250ms per-wheel logging.
local mission={
    terrainRootNode=999,vehicles={vehicle}
}
vehicle.spec_wheels={wheels={wheel}}
local scan=assert(P.scanMark(mission,100,100,{radiusM=3}))
assert(scan.state=="READ_ONLY" and #scan.results==1)
assert(scan.results[1].wheelIndex==1)
assert(scan.provesFineSurfaceHeight==false)
assert(scan.authorizesTerrainWrite==false)
assert(scan.truncated==false)
scan=P.scanMark(mission,110,100,{radiusM=1})
assert(#scan.results==0)
assert(select(1,P.scanMark({terrainRootNode=999,vehicles={}},100,100))~=nil)
local old=getWheelShapeContactPoint
getWheelShapeContactPoint=nil
assert(select(1,P.sampleWheel(vehicle,wheel,999))==nil)
getWheelShapeContactPoint=old
g_currentMission=mission
RealismExtensionsTerrainGeometryProbe={position={x=100,z=100}}
local result,line=P.consoleAtMarkedArea()
assert(result==true and line:find("READ ONLY",1,true))
assert(line:find("Contact point coordinate frame inferred",1,true))
assert(calls>0)
print("terrain_wheel_collision_probe_harness: OK")
