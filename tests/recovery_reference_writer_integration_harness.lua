-- Writer-level in-process regression: real two-annulus terrain sampling,
-- real SpatialHistory-like queries, no GIANTS engine required.
dofile("scripts/terrain/RecoverySurfaceEstimator.lua")
dofile("scripts/terrain/RecoveryReferenceV2.lua")
dofile("scripts/terrain/TerrainWriter.lua")

RealismExtensionsConfig={modules={TerrainRecoveryReferenceV2=true}}
g_currentMission={terrainRootNode=50}
local Writer=RealismExtensionsTerrainWriter.new()
local shape
getTerrainHeightAtWorldPos=function(root,x,y,z)
    assert(root==50)
    return shape(x,z)
end
local function plane(x,z) return 20+.04*x-.02*z end
local function gaussian(x,c,s)
    local d=(x-c)/s
    return math.exp(-.5*d*d)
end
local lanes=function(x,z)
    return plane(x,z)-.12*math.max(
        gaussian(x,0,.28),gaussian(x,1.05,.28))
end
shape=lanes
local history={}
function history:getRecoveryCellsCircle(x,z,radius,options)
    local debt=plane(x,z)-lanes(x,z)
    if debt>=(options.minRutM or 0) then
        return {{rutDepthM=debt}}
    end
    return {}
end

local corrected=assert(Writer:measureRecoveryAt(0,0,1.2,history))
assert(corrected.referenceV2==true)
assert(math.abs(corrected.centerDeficitM-.12)<.025,
    string.format("v2 could not recover reference: %f",
        corrected.centerDeficitM))
RealismExtensionsConfig.modules.TerrainRecoveryReferenceV2=false
local legacy=assert(Writer:measureRecoveryAt(0,0,1.2,history))
assert(legacy.referenceV2~=true)
assert(corrected.centerDeficitM>legacy.centerDeficitM+.025,
    "V2 must detect more of the parallel-rut depth")
RealismExtensionsConfig.modules.TerrainRecoveryReferenceV2=true

shape=function(x,z)
    return plane(x,z)+.12*(x*x+z*z)/(1.2*1.2)
end
local none,reason=Writer:measureRecoveryAt(0,0,1.2,history)
-- Curved terrain has no debt in the target coordinates, so no anchor.
-- In real use, this is additionally gated on RE-owned rut debt.
assert(none==nil and reason=="CURVED_OR_INCONSISTENT",
    "must refuse curvature target instead of flattening natural terrain")
print(string.format(
    "recovery_reference_writer_integration_harness: legacy=%.4fm corrected=%.4fm OK",
    legacy.centerDeficitM,corrected.centerDeficitM))
