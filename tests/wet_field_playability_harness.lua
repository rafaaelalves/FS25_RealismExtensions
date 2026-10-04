g_terrainNode=42

local layers={
    [0]="asphalt",
    [1]="gravel",
    [2]="dirt",
    [3]="mud"
}
local activeLayer=3

function getTerrainNumOfLayers(node) return 4 end
function getTerrainLayerName(node,id) return layers[id] end
function getTerrainLayerAtWorldPos(node,id,x,y,z)
    return id==activeLayer and 1 or 0
end

dofile("scripts/terrain/SurfaceResponse.lua")
dofile("scripts/terrain/TerrainResponseModel.lua")

local S=RealismExtensionsTerrainSurfaceResponse
local M=RealismExtensionsTerrainResponseModel

local footprint={
    available=true,
    supportWidthM=0.60,
    structuralRadiusM=0.80,
    footprintLengthM=0.40,
    groundPressurePa=110000
}

local function context(profileName,soilContact,wet)
    return {
        grounded=true,
        soilContact=soilContact,
        groundProfileName=profileName,
        structuralRadiusM=0.80,
        supportWidthM=0.60,
        speedKph=7,
        wheelSurfaceSpeedMps=2.2,
        longitudinalSlip=0.266,
        lateralSlip=0.02,
        physicalGroundWetness=wet,
        groundMudPotential=0.75,
        hardFrozen=false,
        sinkDepthM=0.12
    }
end

local function response(ctx)
    local surface=S.resolve(ctx,0,0)
    assert(surface~=nil and surface.available==true)
    local options={
        absoluteMaxStaticRutDepthM=surface.maxStaticRutDepthM,
        absoluteMaxSlipRutDepthM=surface.maxSlipRutDepthM
    }
    for k,v in pairs(surface.modelOptions or {}) do options[k]=v end
    local r=M.compute(ctx,footprint,nil,250,options)
    assert(r~=nil and r.available==true)
    return surface,r
end

-- At ordinary "wet" conditions, mobility sink remains visible to Mud/MR but
-- only a small share is allowed to become permanent RE heightfield damage.
local firm75,rFirm75=response(context("Sown",true,0.75))
local field75,rField75=response(context("Generic Field",true,0.75))
local soft75,rSoft75=response(context("Cultivated",true,0.75))
local mud75,rMud75=response(context("",false,0.75))

assert(firm75.category=="FIELD_FIRM")
assert(field75.category=="FIELD")
assert(soft75.category=="FIELD_SOFT")
assert(mud75.category=="MUD")

assert(rFirm75.sinkPlasticTransfer01 < 0.08)
assert(rField75.sinkPlasticTransfer01 < 0.16)
assert(rSoft75.sinkPlasticTransfer01 < 0.26)
assert(rMud75.sinkPlasticTransfer01 > 0.50)

assert(rFirm75.sinkPlasticTransfer01
    < rField75.sinkPlasticTransfer01)
assert(rField75.sinkPlasticTransfer01
    < rSoft75.sinkPlasticTransfer01)
assert(rSoft75.sinkPlasticTransfer01
    < rMud75.sinkPlasticTransfer01)

-- Explicit surface caps keep normal fields out of the 15-18 cm rut regime.
assert(rFirm75.rutCapacityM <= 0.0750001)
assert(rField75.rutCapacityM <= 0.1000001)
assert(rSoft75.rutCapacityM <= 0.1300001)
assert(rMud75.rutCapacityM <= 0.1700001)

-- Reproduce the reported severe window approximately: 0.89 wetness, moderate
-- slip and 8 cm instantaneous sink. Ordinary FIELD should no longer convert
-- ~76% of that sink into permanent terrain while true MUD keeps the severe
-- scenario available.
local reportedField=context("Generic Field",true,0.89)
reportedField.sinkDepthM=0.08
local _,rf=response(reportedField)

local reportedMud=context("",false,0.89)
reportedMud.sinkDepthM=0.08
local _,rm=response(reportedMud)

assert(rf.sinkPlasticTransfer01 < 0.36)
assert(rf.persistentSinkDepthM < 0.030)
assert(rm.sinkPlasticTransfer01 > 0.70)
assert(rm.persistentSinkDepthM > rf.persistentSinkDepthM * 2)

print("wet_field_playability_harness: OK")

-- Branch CI sentinel: wet-field calibration must remain covered by full harness suite.
