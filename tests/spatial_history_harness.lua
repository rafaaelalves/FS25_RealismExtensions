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
