-- Minimal GIANTS terrain-layer stubs for surface classification.
local layers = {
    [0] = "asphalt",
    [1] = "gravel",
    [2] = "dirt",
    [3] = "mud"
}
local activeLayer = nil
g_terrainNode = 42
g_currentMission = { terrainRootNode = g_terrainNode }

function getTerrainNumOfLayers(node) return 4 end
function getTerrainLayerName(node, id) return layers[id] end
function getTerrainLayerAtWorldPos(node, id, x, y, z)
    return id == activeLayer and 1 or 0
end

dofile("scripts/terrain/SurfaceResponse.lua")
local Surface = RealismExtensionsTerrainSurfaceResponse

local function context(overrides)
    local c = {
        soilContact = false,
        physicalGroundWetness = 0.8,
        longitudinalSlip = 0.5
    }
    for k,v in pairs(overrides or {}) do c[k]=v end
    return c
end

activeLayer = 0
local asphalt = Surface.resolve(context(), 0, 0)
assert(asphalt.available == true)
assert(asphalt.category == "HARD")
assert(asphalt.deformability01 == 0)

activeLayer = 1
local gravelNormal = Surface.resolve(context({physicalGroundWetness=0.5}), 0, 0)
assert(gravelNormal.category == "GRAVEL")
assert(gravelNormal.deformability01 == 0)

local gravelWet = Surface.resolve(context({physicalGroundWetness=0.9,longitudinalSlip=0.5}), 0, 0)
assert(gravelWet.category == "GRAVEL_WET")
assert(gravelWet.deformability01 > 0)
assert(gravelWet.maxSlipRutDepthM <= 0.0350001)

activeLayer = 2
local dirtNormal = Surface.resolve(context({physicalGroundWetness=0.5}), 0, 0)
assert(dirtNormal.category == "DIRT_COMPACTED")
assert(dirtNormal.deformability01 == 0)

local dirtWet = Surface.resolve(context({physicalGroundWetness=0.9,longitudinalSlip=0.5}), 0, 0)
assert(dirtWet.category == "DIRT_WET")
assert(dirtWet.deformability01 > gravelWet.deformability01)
assert(dirtWet.maxSlipRutDepthM <= 0.0500001)

activeLayer = 3
local mud = Surface.resolve(context(), 0, 0)
assert(mud.category == "MUD")
assert(mud.deformability01 > 0)

-- Field state outranks decorative terrain paint.
activeLayer = 0
local plowed = Surface.resolve(context({
    soilContact=true,
    groundProfileName="Plowed",
    physicalGroundWetness=0.9
}), 0, 0)
assert(plowed.category == "FIELD_SOFT")
assert(plowed.maxSlipRutDepthM == 0.18)

local grass = Surface.resolve(context({
    soilContact=true,
    groundProfileName="Grass",
    physicalGroundWetness=0.9
}), 0, 0)
assert(grass.category == "FIELD_FIRM")
assert(grass.maxSlipRutDepthM == 0.10)

print("surface_response_harness: OK")
