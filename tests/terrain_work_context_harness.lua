-- TerrainWorkContext semantic harness.
getWorldTranslation = function(node)
    if node == 101 then return 0,0,0 end
    if node == 102 then return 8,0,0 end
    if node == 103 then return 0,0,4 end
    error("unexpected node " .. tostring(node))
end

dofile("scripts/terrain/TillageRecoveryProfiles.lua")
dofile("scripts/terrain/TerrainWorkContext.lua")

local root = {
    typeName = "tractor",
    getName = function() return "Test Tractor" end
}
local implement = {
    typeName = "cultivator",
    spec_cultivator = {
        isEnabled = true,
        isWorking = false,
        isSubsoiler = false,
        isPowerHarrow = false,
        useDeepMode = true
    },
    getRootVehicle = function() return root end,
    getLastSpeed = function() return 8 end,
    getName = function() return "Test Implement" end
}

assert(RealismExtensionsTerrainWorkContext.getCombinationRoot(implement) == root)
assert(RealismExtensionsTerrainWorkContext.getVehicleLabel(root) == "Test_Tractor")
assert(RealismExtensionsTerrainWorkContext.getVehicleLabel(implement) == "Test_Implement")
assert(RealismExtensionsTerrainWorkContext.getSpeedKph(implement) == 8)

local g = RealismExtensionsTerrainWorkContext.getWorkAreaGeometry({
    start=101,width=102,height=103
})
assert(g ~= nil)
assert(math.abs(g.widthM - 8) < 0.000001)
assert(math.abs(g.depthM - 4) < 0.000001)

local pre = RealismExtensionsTerrainWorkContext.captureCultivatorPre(implement,1000)
assert(pre.rootVehicle == root)
assert(pre.enabled == true)
assert(pre.potentiallyWorking == true)
assert(pre.toolProfile ~= nil and pre.toolProfile.id == "CULTIVATOR")

-- First pass: field state changes.
implement.spec_cultivator.isWorking = true
local first = RealismExtensionsTerrainWorkContext.captureCultivatorPost(
    implement,{start=101,width=102,height=103},12,12,1000,pre
)
assert(first.physicallyWorking == true)
assert(first.changedArea == 12)
assert(first.processedArea == 12)
assert(first.isRepeatPass == false)
assert(first.geometry ~= nil)
assert(first.toolProfile.id == "CULTIVATOR")

-- Repeated physical pass: no agricultural-state change, still real work.
local repeatPass = RealismExtensionsTerrainWorkContext.captureCultivatorPost(
    implement,{start=101,width=102,height=103},0,12,1100,pre
)
assert(repeatPass.physicallyWorking == true)
assert(repeatPass.changedArea == 0)
assert(repeatPass.processedArea == 12)
assert(repeatPass.isRepeatPass == true)

-- Lifted/inactive semantics.
implement.spec_cultivator.isWorking = false
local inactive = RealismExtensionsTerrainWorkContext.captureCultivatorPost(
    implement,{start=101,width=102,height=103},0,0,1200,pre
)
assert(inactive.physicallyWorking == false)
assert(inactive.processedArea == 0)

-- Root fallback through attacher chain.
local chainedRoot = { typeName="root" }
local mid = {
    getAttacherVehicle=function() return chainedRoot end
}
local child = {
    getAttacherVehicle=function() return mid end
}
assert(RealismExtensionsTerrainWorkContext.getCombinationRoot(child) == chainedRoot)

print("terrain_work_context_harness: OK")


-- Engine semantics resolve distinct Cultivator modes without relying on names.
implement.spec_cultivator.useDeepMode = false
assert(
    RealismExtensionsTerrainWorkContext.captureCultivatorPre(implement,1300)
        .toolProfile.id == "SHALLOW_DISC"
)
implement.spec_cultivator.useDeepMode = true
implement.spec_cultivator.isPowerHarrow = true
assert(
    RealismExtensionsTerrainWorkContext.captureCultivatorPre(implement,1400)
        .toolProfile.id == "POWER_HARROW"
)
implement.spec_cultivator.isSubsoiler = true
assert(
    RealismExtensionsTerrainWorkContext.captureCultivatorPre(implement,1500)
        .toolProfile.id == "SUBSOILER"
)

-- Plow is a first-class recovery operation rather than being disguised as a
-- cultivator. Repeated plowing remains physically valid when changedArea=0.
local plow = {
    typeName = "plow",
    spec_plow = { isWorking = false },
    getRootVehicle = function() return root end,
    getLastSpeed = function() return 7 end
}
local plowPre =
    RealismExtensionsTerrainWorkContext.capturePlowPre(plow,1600)
assert(plowPre.enabled == true)
assert(plowPre.potentiallyWorking == true)
assert(plowPre.toolProfile.id == "PLOW")
plow.spec_plow.isWorking = true
local plowPost =
    RealismExtensionsTerrainWorkContext.capturePlowPost(
        plow,{start=101,width=102,height=103},0,10,1600,plowPre
    )
assert(plowPost.physicallyWorking == true)
assert(plowPost.isRepeatPass == true)
assert(plowPost.toolProfile.id == "PLOW")

local packer = {
    spec_cultivator = {
        isEnabled=true,isWorking=true,useDeepMode=true,
        isSubsoiler=false,isPowerHarrow=false
    },
    spec_plow = {isWorking=true},
    spec_plowPacker = {},
    getRootVehicle=function() return root end,
    getLastSpeed=function() return 7 end
}
assert(
    RealismExtensionsTerrainWorkContext.captureCultivatorPre(packer,1700)
        .toolProfile.id == "PLOW_PACKER"
)
assert(
    RealismExtensionsTerrainWorkContext.capturePlowPre(packer,1700)
        .toolProfile.id == "PLOW_PACKER"
)

print("terrain_work_context_tillage_profiles_harness: OK")

