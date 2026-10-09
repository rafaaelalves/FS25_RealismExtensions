-- PTO candidate must never silently re-enable experimental terrain.
dofile("scripts/Config.lua")
assert(RealismExtensionsConfig.modules.PTOControl==true)
assert(RealismExtensionsConfig.modules.TerrainDeformation==false)
assert(RealismExtensionsConfig.diagnostics.verbose==false)
assert(RealismExtensionsConfig.diagnostics.performanceTiming==false)

-- The normal RC provider remains supported even when terrain is disabled.
dofile("scripts/api/StateContract.lua")
assert(RealismExtensionsState.REQUIRED_PROVIDER_API_VERSION==2)
assert(RealismExtensionsState.REQUIRED_WHEEL_CONTEXT_VERSION==2)
print("pto_release_gate_harness: OK")
