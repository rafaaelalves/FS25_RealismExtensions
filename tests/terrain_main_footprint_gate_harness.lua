-- Pure-Lua contact geometry; these cases NEVER touch GIANTS terrain.
dofile("scripts/terrain/TerrainMainFootprintGate.lua")
local G=RealismExtensionsTerrainMainFootprintGate
local function check(base,overrides)
    local o={}
    for k,v in pairs(base) do o[k]=v end
    for k,v in pairs(overrides or {}) do o[k]=v end
    return G.evaluate(o)
end
local full={unitM=1,vertexX=10,vertexZ=20,contactX=10,contactZ=20,
    supportWidthM=1,footprintLengthM=1,dirX=1,dirZ=0,
    footprintAvailable=true}
local a=check(full)
assert(a.state=="MAIN_RESEARCH_CANDIDATE" and a.coverage01>0.999)
assert(a.authorizesMainWrite==false and a.doesNotWrite==true)
-- Typical 35cm tyre is not a safe 1m heightmap rut, even on grid center.
local thin=check(full,{supportWidthM=0.35})
assert(thin.state=="FINE_ONLY_OR_UNREPRESENTABLE")
assert(thin.reason=="CONTACT_NARROWER_THAN_MAIN_SUPPORT")
assert(thin.coverage01>0.3 and thin.coverage01<0.4)
-- Moving the exact same contact to a grid-cell seam reduces support.
local seam=check(full,{contactX=10.45})
assert(seam.state=="FINE_ONLY_OR_UNREPRESENTABLE")
assert(seam.reason=="INSUFFICIENT_MAIN_CELL_COVERAGE")
assert(seam.coverage01<0.75)
-- Confinement uses true polygon intersection, including rotation.
local diagonal=check(full,{dirX=1,dirZ=1})
assert(diagonal.coverage01>0 and diagonal.coverage01<1)
local directionScale=check(full,{dirX=100,dirZ=100})
assert(math.abs(diagonal.coverage01-directionScale.coverage01)<1e-9)
local opposite=check(full,{dirX=-1,dirZ=-1})
assert(math.abs(diagonal.coverage01-opposite.coverage01)<1e-9)
-- Stationary wheelspin may cause mechanical yield but does not establish
-- a swept orientation or license to cut a coarse terrain vertex.
assert(check(full,{dirX=0,dirZ=0}).state=="GEOMETRY_UNKNOWN")
assert(check(full,{dirX=0/0}).state=="GEOMETRY_UNKNOWN")
assert(check(full,{unitM=0}).state=="GEOMETRY_UNKNOWN")
assert(check(full,{isCrawler=true}).state=="GEOMETRY_UNKNOWN")
-- Two parallel thin tracks do not become one wide impression just because
-- both 20cm logical samples map to the same coarse native vertex.
local left=check(full,{contactZ=19.8,supportWidthM=0.35})
local right=check(full,{contactZ=20.2,supportWidthM=0.35})
assert(left.state=="FINE_ONLY_OR_UNREPRESENTABLE")
assert(right.state=="FINE_ONLY_OR_UNREPRESENTABLE")
-- Scale by verified local main unit; never hardcode 1m globally.
local half=check(full,{unitM=0.5,vertexX=10,vertexZ=20,
    supportWidthM=0.5,footprintLengthM=0.5})
assert(half.state=="MAIN_RESEARCH_CANDIDATE")
-- Absolute world height and apparent slope are not input parameters:
-- they cannot grant unsupported geometry access.
local sloped=check(full,{elevationM=125,slope=0.3})
assert(sloped.coverage01==a.coverage01)
print("terrain_main_footprint_gate_harness: OK")
