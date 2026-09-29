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
h:commit(2.0, 0, { passCount = 2 })
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
local snapshot = h:exportSnapshot()
assert(snapshot.version == RealismExtensionsSpatialHistory.VERSION)
assert(snapshot.cellSizeM == 0.2)
assert(#snapshot.cells == 3)

local restored = RealismExtensionsSpatialHistory.new({ cellSizeM = 0.2, maxCells = 10 })
local ok, reason = restored:importSnapshot(snapshot)
assert(ok == true, reason)
assert(restored.count == 3)
assert(restored:get(0, 0).rutDepthM == h:get(0, 0).rutDepthM)
assert(restored:get(2.0, 0).passCount == h:get(2.0, 0).passCount)

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
