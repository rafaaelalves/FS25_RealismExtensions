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

h:clear()
assert(h.count == 0)
assert(h:get(0, 0) == nil)

print("spatial_history_harness: OK")
