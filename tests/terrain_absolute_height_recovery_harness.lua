-- Real SpatialHistory + no-write 1m-vertex planner integration.
-- Demonstrates *logical* recovery only, never GIANTS native geometry.
dofile("scripts/terrain/SpatialHistory.lua")
dofile("scripts/terrain/TerrainAbsoluteHeightPlanner.lua")
local H=RealismExtensionsSpatialHistory
local P=RealismExtensionsTerrainAbsoluteHeightPlanner
local q=255/65535 -- explicit test input; NOT inferred from map data
local h=H.new({cellSizeM=0.20})
local p=assert(P.new({unitM=1,verifiedQuantumM=q}))
local events={}
h.onRecovery=function(key,remaining,applied)
    events[#events+1]={key=key,remaining=remaining,applied=applied}
    assert(p:onHistoryRecovered(key,remaining,applied)==true)
end
local a=h:getKey(0,0)
local b=h:getKey(0.2,0.2)
assert(a~=b)
assert(p:observe(a,0,0,0.006,0).state=="QUANTUM_READY_SHADOW")
assert(p:observe(b,0.2,0.2,0.004,0).state=="QUANTUM_READY_SHADOW")
h:commit(0,0,{rutDepthM=0.006,longitudinalShearDistanceM=0.001})
h:commit(0.2,0.2,{rutDepthM=0.004,longitudinalShearDistanceM=0.001})
assert(math.abs(p:getVertex(0,0).demandM-0.006)<1e-8)

-- One targeted logical recovery partially lowers the maximum, but the
-- second overlapping source is still present. The vertex's new demand is
-- max(4mm, 2mm) and not 4mm + 2mm.
local raised=h:applyRecoveryAt(0,0,0.004,{minRutM=0,nowMs=1000})
assert(math.abs(raised-0.004)<1e-8)
assert(#events==1 and events[1].key==a)
assert(math.abs(p:getVertex(0,0).demandM-0.004)<1e-8)
assert(p:getVertex(0,0).crossed==true)
assert(math.abs(p.stats.recoveredDemandM-0.004)<1e-8)

-- Circular recovery changes B only; A retains a nonzero 2mm demand.
local cells,reduced=h:applyRecoveryCircle(
    0.2,0.2,0.09,0.004,1,{minRutM=0,nowMs=2000})
assert(cells==1 and math.abs(reduced-0.004)<1e-8)
assert(math.abs(p:getVertex(0,0).demandM-0.002)<1e-8)
assert(p:getVertex(0,0).crossed==false)
assert(#events==2 and events[2].key==b)

-- Validated tillage callback can close A's remaining logical rut.
local count,depth=h:recoverParallelogram(
    -0.1,-0.1,0.1,-0.1,-0.1,0.1,{
        fraction=1,maxRaiseM=0.01,minRutM=0,
        cooldownMs=0,nowMs=3000,maxCells=4
    },function()return true end)
assert(count==1 and math.abs(depth-0.002)<1e-8)
assert(p:getVertex(0,0)==nil)
assert(p.sourceCount==0)
assert(#events==3 and events[3].key==a)
assert(p.stats.recoveries==3)
assert(math.abs(p.stats.recoveredDemandM-0.01)<1e-8)
-- A new post-tillage wheel passage creates a fresh epoch; old max target
-- must not block new damage and no stale 1m vertex remains allocated.
assert(p:observe(a,0,0,0.003,0).state=="SUB_QUANTUM_SHADOW")
assert(p.sourceCount==1)
assert(math.abs(p:getVertex(0,0).demandM-0.003)<1e-8)
assert(p:observe(a,0,0,0.002,0).state=="TARGET_DECREASE_UNVERIFIED")
assert(math.abs(p:getVertex(0,0).demandM-0.003)<1e-8)

-- Rejected/zero logical recovery is not proof of repaired geometry.
local before=#events
assert(h:applyRecoveryAt(0,0,0.001,{minRutM=0})==0)
assert(#events==before)
assert(p:onHistoryRecovered("missing",0,0.001)==false)
assert(p:onHistoryRecovered(a,0,0)==false)

-- A low maxSources planner cannot be permanently exhausted by
-- years of fully recovered cells. Each recovered source is reclaimed.
local churn=assert(P.new({unitM=1,maxSources=1}))
for i=1,30 do
    local key=string.format("%d:%d",i,i)
    local x=i*2
    local z=i*3
    assert(churn:observe(key,x,z,0.005))
    assert(churn.sourceCount==1)
    assert(churn:onHistoryRecovered(key,0,0.005)==true)
    assert(churn.sourceCount==0)
    assert(next(churn.vertices)==nil)
end
assert(churn.stats.recoveries==30 and churn.stats.capacityRefusals==0)

-- Observer failures must not undo a completed SpatialHistory recovery.
h:commit(3,3,{rutDepthM=0.005,longitudinalShearDistanceM=0.001})
h.onRecovery=function()error("diagnostic-observer-should-not-break-soil")end
assert(h:applyRecoveryAt(3,3,0.001,{minRutM=0})>0)
assert(h.recoveryObserverFaults==1)
local remaining=h:get(3,3)
assert(remaining~=nil and math.abs(remaining.rutDepthM-0.004)<1e-8)
print("terrain_absolute_height_recovery_harness: OK")
