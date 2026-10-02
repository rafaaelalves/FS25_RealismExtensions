dofile("scripts/terrain/SpatialHistory.lua")

local h = RealismExtensionsSpatialHistory.new({ cellSizeM = 0.2, maxCells = 3 })

assert(h:get(0, 0) == nil)
h:commit(0.01, 0.01, { rutDepthM = 0.02 })
local a = h:get(0.02, 0.02)
assert(a ~= nil and a.rutDepthM == 0.02)

-- Nearby points quantize to the same spatial cell.
h:commit(0.04, 0.03, { rutDepthM = 0.03 })
assert(h.count == 1)
assert(h:get(0.01, 0.01).rutDepthM == 0.03)

-- Distinct cells are bounded with least-recently-used pruning.
h:commit(1.0, 0, { passCount = 1 })
h:commit(2.0, 0, { passCount = 2, deformationExposure = 1.75 })
assert(h.count == 3)

-- Touch the first cell so the 1.0 cell becomes oldest.
assert(h:get(0, 0) ~= nil)
h:commit(3.0, 0, { passCount = 3 })
assert(h.count == 3)
assert(h:get(0, 0) ~= nil)
assert(h:get(1.0, 0) == nil)
assert(h:get(2.0, 0) ~= nil)
assert(h:get(3.0, 0) ~= nil)

-- Snapshot round-trip preserves only stable physical history fields and is
-- deterministic regardless of Lua table iteration order.
-- Capture the material cells before deliberately adding runtime-only state.
local expectedZeroRut = h:get(0, 0).rutDepthM
local expectedTwoPasses = h:get(2.0, 0).passCount
local expectedExposure = h:get(2.0, 0).deformationExposure

-- Runtime bookkeeping may contain a touched-but-physically-empty cell; it
-- must not bloat the savegame sidecar. maxCells=3 means this insert may evict
-- an older runtime cell, so snapshot expectations must follow actual LRU
-- state rather than assuming persistence changes pruning semantics.
h:commit(9.0, 9.0, {})
assert(h.count == 3)
local snapshot = h:exportSnapshot()
assert(snapshot.version == RealismExtensionsSpatialHistory.VERSION)
assert(snapshot.cellSizeM == 0.2)
assert(#snapshot.cells == 2)

local restored = RealismExtensionsSpatialHistory.new({ cellSizeM = 0.2, maxCells = 10 })
local ok, reason = restored:importSnapshot(snapshot)
assert(ok == true, reason)
assert(restored.count == 2)
assert(restored:get(0, 0).rutDepthM == expectedZeroRut)
assert(restored:get(2.0, 0).passCount == expectedTwoPasses)
assert(math.abs(restored:get(2.0, 0).deformationExposure - expectedExposure) < 0.000001)
assert(restored:get(9.0, 9.0) == nil)

-- A tuning change to the spatial grid must fail closed rather than silently
-- shifting persisted ruts to different terrain cells.
local incompatible = RealismExtensionsSpatialHistory.new({ cellSizeM = 0.25 })
local imported, mismatch = incompatible:importSnapshot(snapshot)
assert(imported == false)
assert(mismatch == "cell size mismatch")

h:clear()
assert(h.count == 0)
assert(h:get(0, 0) == nil)

print("spatial_history_harness: OK")

-- Recovery is spatially bounded, proportional, and rate-limited per cell/pass.
local rh = RealismExtensionsSpatialHistory.new({ cellSizeM=0.20, maxCells=100 })
rh:commit(0.20, 0.20, {
    rutDepthM=0.10,
    deformationExposure=2.0,
    longitudinalShearDistanceM=1.0
})
rh:commit(2.00, 2.00, { rutDepthM=0.10, deformationExposure=2.0 })
local accepted = 0
local cells, raised = rh:recoverParallelogram(
    0,0, 1,0, 0,1,
    { fraction=0.5, maxRaiseM=0.03, minRutM=0.003, nowMs=1000, cooldownMs=1500 },
    function(x,z,raiseM)
        accepted = accepted + 1
        assert(raiseM <= 0.03)
        return true
    end
)
assert(cells == 1)
assert(accepted == 1)
assert(math.abs(raised - 0.03) < 0.000001)
local recovered = rh:get(0.20,0.20)
assert(math.abs(recovered.rutDepthM - 0.07) < 0.000001)
assert(recovered.deformationExposure < 2.0)
local cellsCooldown = rh:recoverParallelogram(
    0,0, 1,0, 0,1,
    { fraction=0.5, maxRaiseM=0.03, nowMs=2000, cooldownMs=1500 },
    function() return true end
)
assert(cellsCooldown == 0)
local outside = rh:get(2.00,2.00)
assert(math.abs(outside.rutDepthM - 0.10) < 0.000001)

-- A rejected writer brush must not erase logical rut history.
local beforeReject = rh:get(0.20,0.20).rutDepthM
local cellsRejected = rh:recoverParallelogram(
    0,0, 1,0, 0,1,
    { fraction=0.5, maxRaiseM=0.03, nowMs=3000, cooldownMs=1500 },
    function() return false end
)
assert(cellsRejected == 0)
assert(math.abs(rh:get(0.20,0.20).rutDepthM - beforeReject) < 0.000001)

-- Numeric callback result couples logical recovery to a calibrated physical
-- writer request instead of assuming the full candidate raise was applied.
local calibrated = RealismExtensionsSpatialHistory.new({ cellSizeM=0.20, maxCells=100 })
calibrated:commit(0.20, 0.20, { rutDepthM=0.10, deformationExposure=1.0 })
local ccells, craised = calibrated:recoverParallelogram(
    0,0, 1,0, 0,1,
    { fraction=0.5, maxRaiseM=0.03, nowMs=1000, cooldownMs=1500 },
    function(x,z,raiseM)
        assert(math.abs(raiseM - 0.03) < 0.000001)
        return raiseM * 0.30
    end
)
assert(ccells == 1)
assert(math.abs(craised - 0.009) < 0.000001)
assert(math.abs(calibrated:get(0.20,0.20).rutDepthM - 0.091) < 0.000001)


-- v14 asynchronous recovery discovery must be read-only until physical terrain
-- work confirms a rise at the rut center.
local ah = RealismExtensionsSpatialHistory.new({ cellSizeM=0.20, maxCells=100 })
ah:commit(0.20,0.20,{rutDepthM=0.10,deformationExposure=2.0,longitudinalShearDistanceM=1.0})
ah:commit(0.40,0.20,{rutDepthM=0.04,deformationExposure=1.0})
local ac = ah:getRecoveryCandidatesParallelogram(
    0,0, 1,0, 0,1,
    {minRutM=0.003,nowMs=1000,cooldownMs=1500,maxCells=10}
)
assert(#ac == 2)
assert(math.abs(ah:get(0.20,0.20).rutDepthM - 0.10) < 0.000001)

local appliedAsync = ah:applyRecoveryAt(
    0.20,0.20,0.012,
    {minRutM=0.003,nowMs=1200}
)
assert(math.abs(appliedAsync - 0.012) < 0.000001)
assert(math.abs(ah:get(0.20,0.20).rutDepthM - 0.088) < 0.000001)
assert(ah:get(0.20,0.20).deformationExposure < 2.0)

local cooled = ah:getRecoveryCandidatesParallelogram(
    0,0, 1,0, 0,1,
    {minRutM=0.003,nowMs=2000,cooldownMs=1500,maxCells=10}
)
assert(#cooled == 1)
print("spatial_history_async_recovery_harness: OK")
