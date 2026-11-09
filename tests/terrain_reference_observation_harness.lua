-- Observational terrain-reference regression checks (no GIANTS engine needed).
-- This harness must never flatten/raise terrain or alter production settings.
dofile("scripts/terrain/SpatialHistory.lua")
dofile("scripts/terrain/RecoverySurfaceEstimator.lua")
dofile("scripts/terrain/RecoveryReferenceV2.lua")

local History = assert(RealismExtensionsSpatialHistory)
local Selector = assert(RealismExtensionsRecoveryReferenceV2)

local function check(ok, why)
    assert(ok, why)
end

local h = History.new({ cellSizeM = 0.2, maxCells = 50 })
h:commit(1.2, 2.6, {
    rutDepthM = 0.01,
    preDeformHeightM = 152.123456,
    longitudinalShearDistanceM = 0.20
})
check(math.abs(h:get(1.2, 2.6).preDeformHeightM - 152.123456) < 1e-9,
    "first-touch height missing")
local snap = h:exportSnapshot()
check(snap.version == 7, "new snapshot version")
check(math.abs(snap.cells[1].history.preDeformHeightM - 152.123456) < 1e-9,
    "pre-deformation height missing from export")
local restored = History.new({ cellSizeM = 0.2, maxCells = 50 })
local ok, reason = restored:importSnapshot(snap)
check(ok == true, tostring(reason))
check(math.abs(restored:get(1.2, 2.6).preDeformHeightM - 152.123456) < 1e-9,
    "pre-deformation height missing from import")

local legacy = {
    version = 6, cellSizeM = 0.2,
    cells = {{ix=6, iz=13, history={rutDepthM=0.01}}}
}
local oldHistory = History.new({ cellSizeM = 0.2 })
check(oldHistory:importSnapshot(legacy) == true, "old history import failed")
check(oldHistory:get(1.2, 2.6).preDeformHeightM == nil,
    "retroactively invented a baseline for an old rut")

local function makeSamples(curvature)
    local samples = {{dx=0, dz=0, y=152, center=true}}
    for _,ring in ipairs({"inner", "outer"}) do
        local radius = ring == "inner" and 1 or 1.7
        for i=0,15 do
            local theta = 2 * math.pi * i / 16
            local dx, dz = radius * math.cos(theta), radius * math.sin(theta)
            samples[#samples+1] = {
                dx=dx, dz=dz, y=152 + 0.02*dx - 0.03*dz
                    + curvature*(dx*dx+dz*dz),
                boundary=true, ring=ring, rutDebtM=0
            }
        end
    end
    return samples
end

local valid, noReason = Selector.measure(makeSamples(0), {innerRadiusM=1})
check(valid ~= nil and noReason == nil,
    "clean plane should produce a valid reference")

local invalid, rejection, measuredDrift =
    Selector.measure(makeSamples(0.08), {innerRadiusM=1})
check(invalid == nil and rejection == "CURVED_OR_INCONSISTENT",
    "curved sample should fail conservatively")
check(type(measuredDrift) == "number" and measuredDrift > 0.10,
    "rejected reference must expose measured annulus drift")

print("terrain_reference_observation_harness: PASS")
