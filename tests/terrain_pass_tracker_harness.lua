-- Pure deterministic pass tracker tests: geometry, timing and lifecycle.
dofile("scripts/terrain/TerrainPassTracker.lua")
local T = RealismExtensionsTerrainPassTracker
local tractor = {rootNode=100}
local implement = {}
local otherImplement = {}
local x = 0
getWorldTranslation = function(node)
    assert(node == 100)
    return x, 0, 0
end
local function op(vehicle, ms, changed, processed, working, speed, kind)
    return {
        vehicle=vehicle,
        rootVehicle=tractor,
        operationKind=kind or "CULTIVATOR",
        toolProfile={id="CULTIVATOR"},
        nowMs=ms,
        speedKph=speed or 7.2,
        physicallyWorking=working ~= false,
        changedArea=changed,
        processedArea=processed
    }
end
T.reset()
local a = T.observe(op(implement,1000,12,12,true))
assert(a==1)
-- Same frame, another work area: no new pass and no fake travel distance.
assert(T.observe(op(implement,1000,0,8,true)) == a)
assert(T.observeCausalCell(implement,"CULTIVATOR","0:0")==true)
assert(T.observeCausalCell(implement,"CULTIVATOR","0:0")==false)
x = 2
assert(T.observe(op(implement,2000,0,8,true))==a)
local pa = T.getDiagnostics()
assert(pa.passStarted==1 and pa.passActive==1 and pa.passCompleted==0)
-- An inactive callback closes immediately and snapshots the completed pass.
T.observe(op(implement,2100,0,0,false))
local d=T.getDiagnostics()
assert(d.passActive==0 and d.passCompleted==1)
local s=d.passLast
assert(s.passId==1 and s.operationKind=="CULTIVATOR" and s.reason=="INACTIVE")
assert(s.callbacks==3 and s.changedCallbacks==1 and s.repeatCallbacks==2)
assert(s.changedArea==12 and s.processedArea==28)
assert(s.uniqueCausalCells==1 and s.cellsCapped==false)
assert(s.durationMs==1000 and math.abs(s.distanceM-2)<0.00001)
assert(math.abs(s.meanSpeedKph-7.2)<0.00001)

-- Repeat-only passes count as physically real, even if changedArea=0.
assert(T.observe(op(implement,2200,0,11,true))==2)
assert(T.observeCausalCell(implement,"CULTIVATOR","0:0")==true)
-- Transient zero processedArea while spec works does not force a split.
assert(T.observe(op(implement,2300,0,0,true))==2)
T.expire(2600)
assert(T.getDiagnostics().passActive==1)
T.expire(3901)
d=T.getDiagnostics()
assert(d.passCompleted==2 and d.passLast.reason=="IDLE")
assert(d.passLast.repeatCallbacks==1 and d.passLast.changedArea==0)

-- Different tools sharing one root do not become the same logical pass.
T.reset()
assert(T.observe(op(implement,1000,1,2,true))==1)
assert(T.observe(op(otherImplement,1000,1,2,true))==2)
assert(T.observe(op(implement,1000,1,2,true,7.2,"PLOW"))==3)
assert(T.getDiagnostics().passActive==3)
T.observe(op(implement,1010,0,0,false))
assert(T.getDiagnostics().passActive==2)
-- The max memory budget is bounded, with no behavioral effect on recovery.
T.DEFAULTS.maxObservedCellsPerPass=2
assert(T.observeCausalCell(otherImplement,"CULTIVATOR","1")==true)
assert(T.observeCausalCell(otherImplement,"CULTIVATOR","2")==true)
assert(T.observeCausalCell(otherImplement,"CULTIVATOR","3")==nil)
T.observe(op(otherImplement,1020,0,0,false))
assert(T.getDiagnostics().passLast.cellsCapped==true)
T.DEFAULTS.maxObservedCellsPerPass=4096

-- Discontinuous world positions are ignored, not counted as a huge field pass.
T.reset()
x=0
T.observe(op(implement,1000,1,2,true))
x=1000
T.observe(op(implement,1100,1,2,true))
T.observe(op(implement,1200,0,0,false))
assert(T.getDiagnostics().passLast.distanceM==0)

-- False-positive one-tick workArea is rejected when not physically working.
T.reset()
assert(T.observe(op(implement,2000,10,10,false))==nil)
assert(T.getDiagnostics().passStarted==0)
print("terrain_pass_tracker_harness: OK")
