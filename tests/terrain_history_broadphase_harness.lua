-- The coarse tile index is strictly a negative broad-phase: never discard
-- candidates, including on negative coordinates, save/load, LRU or retirement.
dofile("scripts/terrain/SpatialHistory.lua")
local History = RealismExtensionsSpatialHistory
local h=History.new({cellSizeM=0.2,tileCellSpan=10,maxCells=200})
local function candidates(x,z,w,d,opts)
    return h:getRecoveryCandidatesParallelogram(
        x,z, x+w,z, x,z+d, opts or {minRutM=0.003,nowMs=10000}
    )
end
local function occupancyAt(x,z)
    local _,ix,iz=h:getKey(x,z)
    return h:hasOccupiedTileInCellBounds(ix,iz,ix,iz)
end

-- Empty fields: no 20-cm cell probes are required, not even when there
-- is unrelated old history on another farm.
assert(#candidates(0,0,8,4)==0)
assert(not occupancyAt(0,0))
h:commit(100,100,{rutDepthM=0.030})
assert(not occupancyAt(0,0))
assert(occupancyAt(100,100))
for _=1,1500 do assert(#candidates(0,0,8,4)==0) end
-- Real damage must be observed immediately after write, even on borders
-- between buckets and negative world coordinates.
h:commit(-2.0,-2.0,{rutDepthM=0.035,deformationExposure=0.4})
assert(occupancyAt(-2,-2))
assert(#candidates(-2.5,-2.5,1,1)==1)
h:commit(-2.0,-2.0,{rutDepthM=0.060,deformationExposure=0.5})
assert(h.occupiedTiles["-1:-1"]==1)
assert(#candidates(-2.5,-2.5,1,1)==1)

-- A shear-only live cell may produce a false positive broad-phase, but
-- never a spurious rut candidate. Do not index only rut >= default 3mm.
h:commit(4,4,{deformationExposure=0.01})
assert(occupancyAt(4,4))
assert(#candidates(3.5,3.5,1,1)==0)

-- Any route removing cells MUST remove their tile occupancy too.
assert(h:removeAt(-2,-2))
assert(not occupancyAt(-2,-2))
assert(#candidates(-2.5,-2.5,1,1)==0)
h:commit(-0.2,0.2,{rutDepthM=0.01,deformationExposure=0.01})
assert(#candidates(-0.4,0,0.8,0.5)==1)
local applied=h:applyRecoveryAt(-0.2,0.2,0.01,{minRutM=0.003,nowMs=10000})
assert(applied==0.01)
assert(not occupancyAt(-0.2,0.2))

-- A second cell in the same tile keeps occupancy alive when one retires.
h:commit(-0.2,-0.2,{rutDepthM=0.025})
h:commit(-0.4,-0.2,{rutDepthM=0.020})
assert(h.occupiedTiles["-1:-1"]==2)
h:removeAt(-0.2,-0.2)
assert(h.occupiedTiles["-1:-1"]==1)
assert(#candidates(-0.6,-0.4,0.4,0.5)==1)

-- Round-trip import must rebuild occupancy from actual persisted live cells.
local snapshot=h:exportSnapshot()
local restored=History.new({cellSizeM=0.2,tileCellSpan=10,maxCells=200})
local ok,err=restored:importSnapshot(snapshot)
assert(ok,err)
assert(restored.occupiedTiles["-1:-1"]==1)
local re=restored:getRecoveryCandidatesParallelogram(
    -0.6,-0.4,-0.2,-0.4,-0.6,0.1,{minRutM=0.003,nowMs=10000})
assert(#re==1)
restored:clear()
assert(restored.count==0)
assert(next(restored.occupiedTiles)==nil)

-- LRU pruning is distinct from ordinary 'retired' debt and must update
-- tiles even when the removed cell was not read through removeAt.
local p=History.new({cellSizeM=0.2,tileCellSpan=8,maxCells=2})
p:commit(-40,0,{rutDepthM=0.01})
p:commit(20,0,{rutDepthM=0.01})
assert(p.count==2)
p:commit(40,0,{rutDepthM=0.01})
assert(p.count==2)
assert(p:get(-40,0)==nil)
local _,ix,iz=p:getKey(-40,0)
assert(not p:hasOccupiedTileInCellBounds(ix,iz,ix,iz))
local _,ax,az=p:getKey(20,0)
assert(p:hasOccupiedTileInCellBounds(ax,az,ax,az))

-- A candidate's cooldown still applies inside an occupied tile.
local blocked=h:getRecoveryCandidatesParallelogram(
    -0.6,-0.4,-0.2,-0.4,-0.6,0.1,
    {minRutM=0.003,maxCells=10,cooldownMs=1500,nowMs=10000})
assert(#blocked==1)
h:applyRecoveryAt(-0.4,-0.2,0.005,{minRutM=0.003,nowMs=10500})
local cooling=h:getRecoveryCandidatesParallelogram(
    -0.6,-0.4,-0.2,-0.4,-0.6,0.1,
    {minRutM=0.003,maxCells=10,cooldownMs=1500,nowMs=11000})
assert(#cooling==0)
local later=h:getRecoveryCandidatesParallelogram(
    -0.6,-0.4,-0.2,-0.4,-0.6,0.1,
    {minRutM=0.003,maxCells=10,cooldownMs=1500,nowMs=13000})
assert(#later==1)
print("terrain_history_broadphase_harness: OK")
