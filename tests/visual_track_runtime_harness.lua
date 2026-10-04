dofile("scripts/tracks/NativeTireTrackAdapter.lua")
dofile("scripts/tracks/VisualTrackJournal.lua")
dofile("scripts/tracks/VisualTrackChunkStore.lua")
dofile("scripts/tracks/VisualTrackRuntime.lua")
local A=RealismExtensionsNativeTireTrackAdapter
local R=RealismExtensionsVisualTrackRuntime
A.uninstall(); A.resetProbe(); A.observers={}; A.setProbeEnabled(false); R.shutdown()
local mt={}; mt.__index=mt
function mt:createTrack(width,atlas) return 12 end
function mt:addTrackPoint(...) return true end
function mt:cutTrack(id) return true end
local sys=setmetatable({},mt)
assert(A.install(sys))
assert(R.initialize(A,{journal={minSpacingM=0.1,maxSpacingM=1},chunkStore={chunkSizeM=10}}))
sys:createTrack(0.5,2)
sys:addTrackPoint(12,0,0,0,1,0,0,0.2,0.2,0.2,0.5,0.01,1,true,0.3)
sys:addTrackPoint(12,0.2,0,0,1,0,0,0.2,0.2,0.2,0.5,0.01,1,true,0.3)
sys:cutTrack(12)
local d=R.getDiagnostics()
assert(d.active and d.creates==1 and d.pointsSeen==2 and d.cuts==1)
assert(d.fragmentsFinalized==1 and d.chunkCount>=1 and d.chunkPointReferences>=2)
-- Closed history moved to chunks; journal does not retain a second point copy.
assert(d.retainedPoints==0)
assert(#R.queryChunks(0,0,5)>=1)
local observerCount=#A.observers
R.shutdown()
assert(not R.active and #A.observers==observerCount-1)
A.uninstall()
print("visual_track_runtime_harness: OK")
