-- Experimental release guard: only the V2 reference selector is changed.
-- Every previous R1/R7 TARGET safety check and capacity profile stays intact.
dofile("scripts/Config.lua")
assert(RealismExtensionsConfig.releaseChannel == "experimental-terrain-pto")
assert(RealismExtensionsConfig.modules.TerrainDeformation == true)
assert(RealismExtensionsConfig.modules.TerrainRecovery == true)
assert(RealismExtensionsConfig.modules.TerrainRecoveryReferenceV2 == false,
    "R5 reference control unexpectedly switched back to V2")
assert(RealismExtensionsConfig.modules.SoilMassTransport == false,
    "Do not mix R5 comparison with mass-transport changes")

dofile("scripts/terrain/RecoverySurfaceEstimator.lua")
dofile("scripts/terrain/RecoveryReferenceV2.lua")
dofile("scripts/terrain/TerrainWriter.lua")
g_currentMission = { terrainRootNode = 50 }
getTerrainHeightAtWorldPos = function(_, x, _, z)
    -- A 10 cm rut in a gently sloped patch; classic R5 single-ring support.
    local baseline = 25.0 + 0.04 * x - 0.02 * z
    return baseline - 0.10 * math.exp(-0.5 * (x / 0.25)^2)
end
local writer = RealismExtensionsTerrainWriter.new()
local observation = assert(writer:measureRecoveryAt(0, 0, 1.2, {}))
assert(observation.referenceV2 ~= true)
assert(observation.centerDeficitM > 0.02,
    "R5 fallback failed to identify synthetic rut")
print("terrain_r5_reference_ab_harness: OK")
