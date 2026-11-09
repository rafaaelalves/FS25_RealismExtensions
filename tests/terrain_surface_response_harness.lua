g_terrainNode=42

local layers={
    [0]="asphalt",
    [1]="gravel",
    [2]="dirt",
    [3]="mud"
}
local activeLayer=1

function getTerrainNumOfLayers(node) return 4 end
function getTerrainLayerName(node,id) return layers[id] end
function getTerrainLayerAtWorldPos(node,id,x,y,z)
    return id==activeLayer and 1 or 0
end

dofile("scripts/terrain/SurfaceResponse.lua")
local S=RealismExtensionsTerrainSurfaceResponse

activeLayer=1
local ok,info=S.isMunicipalMaintenanceSurface(0,0)
assert(ok==true and info.category=="GRAVEL")

activeLayer=2
ok,info=S.isMunicipalMaintenanceSurface(0,0)
assert(ok==true and info.category=="DIRT")

activeLayer=0
ok,info=S.isMunicipalMaintenanceSurface(0,0)
assert(ok==false and info.category=="HARD")

activeLayer=3
ok,info=S.isMunicipalMaintenanceSurface(0,0)
assert(ok==false and info.category=="MUD")

print("terrain_surface_response_maintenance_harness: OK")
