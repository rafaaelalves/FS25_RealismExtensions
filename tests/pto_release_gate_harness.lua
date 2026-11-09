-- Keep the PTO production gate strict, but permit an explicitly marked
-- experimental integration build to exercise both PTO and terrain.
dofile("scripts/Config.lua")
local config = RealismExtensionsConfig
assert(config.modules.PTOControl == true)
local experimental = config.releaseChannel == "experimental-terrain-pto"
if experimental then
    assert(config.modules.TerrainDeformation == true)
    assert(config.modules.TerrainRecovery == true)
    assert(config.modules.TerrainPlasticYield == true)
    assert(config.modules.SoilMassTransport == false)
    assert(config.ptoHud.enabled == true)
else
    -- Production main cannot silently ship active experimental terrain.
    assert(config.releaseChannel == nil)
    assert(config.modules.TerrainDeformation == false)
    assert(config.diagnostics.verbose == false)
    assert(config.diagnostics.performanceTiming == false)
end

dofile("scripts/api/StateContract.lua")
if experimental then
    assert(RealismExtensionsState.SUPPORTED_PROVIDER_API_VERSIONS[2] == true)
    assert(RealismExtensionsState.SUPPORTED_WHEEL_CONTEXT_VERSIONS[2] == true)
else
    assert(RealismExtensionsState.REQUIRED_PROVIDER_API_VERSION == 2)
    assert(RealismExtensionsState.REQUIRED_WHEEL_CONTEXT_VERSION == 2)
end
print("pto_release_gate_harness: OK")
