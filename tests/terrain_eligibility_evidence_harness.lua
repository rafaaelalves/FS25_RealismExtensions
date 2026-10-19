-- Real work-area eligibility diagnostics: preserve candidate behavior and
-- explain why a PLOW or SHALLOW_DISC area contains zero authorized rut points.
-- No GIANTS terrain writes and no additional heightmap sampling.
dofile("scripts/terrain/SpatialHistory.lua")

local History = assert(RealismExtensionsSpatialHistory)
local history = History.new({ cellSizeM = 0.20, maxCells = 1000 })

-- Diamond footprint: corners (0,0), (1,1), (-1,1), (0,2).
-- One eligible rut, one tiny rut, one cooling-down rut and one rut in the
-- bounding rectangle but OUTSIDE the actually worked parallelogram.
history:commit(0.0, 1.0, {
    rutDepthM = 0.012, deformationExposure = 1.0
})
history:commit(0.2, 1.0, {
    rutDepthM = 0.001, deformationExposure = 1.0
})
history:commit(0.0, 1.2, {
    rutDepthM = 0.015, deformationExposure = 1.0,
    _lastRecoveryMs = 4900
})
history:commit(0.8, 0.0, {
    rutDepthM = 0.020, deformationExposure = 1.0
})

local args = {0,0,1,1,-1,1}
local options = {
    minRutM = 0.003, nowMs = 5000, cooldownMs = 500,
    maxCells = 128
}
local normal = history:getRecoveryCandidatesParallelogram(
    args[1],args[2],args[3],args[4],args[5],args[6],options
)
assert(#normal == 1, "legacy candidate selection must remain unchanged")

local evidence = {}
options.eligibilityEvidence = evidence
local sampled = history:getRecoveryCandidatesParallelogram(
    args[1],args[2],args[3],args[4],args[5],args[6],options
)
assert(#sampled == #normal and sampled[1].key == normal[1].key)
assert(evidence.historyInBBox == 4, "four observed history cells in bbox")
assert(evidence.historyInArea == 3, "outside bbox rut must be excluded")
assert(evidence.rutInBBox == 3, "three rut debts meet threshold in bbox")
assert(evidence.rutInArea == 2, "two rut debts meet threshold in footprint")
assert(evidence.belowThresholdInArea == 1, "tiny rut must be classified")
assert(evidence.cooldownBlockedInArea == 1, "cooldown reason must be classified")
assert(evidence.eligibleInArea == 1, "single physically authorized point")
assert(math.abs(evidence.maxRutInAreaM - 0.015) < 0.00001)
assert(evidence.truncated == false)

-- A similarly shaped region with *no history* must not invent restoration
-- authority from arbitrary depressions or inferred TerraFarm geometry.
local emptyEvidence = {}
local empty = history:getRecoveryCandidatesParallelogram(
    5,5,6,5,5,6,{
        minRutM = 0.003, nowMs = 5000, cooldownMs = 0,
        maxCells = 128, eligibilityEvidence = emptyEvidence
    }
)
assert(#empty == 0 and emptyEvidence.historyInArea == 0)
assert(emptyEvidence.eligibleInArea == 0)

-- Inside-area historical exposure without rut debt is not recovery authority.
local shearOnly = History.new()
shearOnly:commit(0.2,0.2,{
    rutDepthM = 0, lateralShearDistanceM = 0.05
})
local shearEvidence = {}
local result = shearOnly:getRecoveryCandidatesParallelogram(
    0,0,1,0,0,1,{
        minRutM = 0.003, nowMs = 5000, cooldownMs = 0,
        eligibilityEvidence = shearEvidence
    }
)
assert(#result == 0)
assert(shearEvidence.historyInArea == 1)
assert(shearEvidence.rutInArea == 0)
assert(shearEvidence.belowThresholdInArea == 1)

-- The sample is explicitly partial when maxCells stops the scan.
local cappedEvidence = {}
local capped = history:getRecoveryCandidatesParallelogram(
    args[1],args[2],args[3],args[4],args[5],args[6],{
        minRutM = 0.003, nowMs = 5000, cooldownMs = 500,
        maxCells = 1, eligibilityEvidence = cappedEvidence
    }
)
assert(#capped == 1 and cappedEvidence.truncated == true)
print("terrain_eligibility_evidence_harness: OK")
