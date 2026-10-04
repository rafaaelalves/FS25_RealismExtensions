dofile("scripts/tracks/NativeTireTrackAdapter.lua")
dofile("scripts/tracks/VisualTrackJournal.lua")
dofile("scripts/tracks/VisualTrackRuntime.lua")

local A=RealismExtensionsNativeTireTrackAdapter
local R=RealismExtensionsVisualTrackRuntime
A.uninstall()
A.resetProbe()
A.observers={}
R.shutdown()

local mt={}
mt.__index=mt
function mt:createTrack(width,atlas) return 12 end
function mt:addTrackPoint(...) return true end
function mt:cutTrack(id) return true end
local sys=setmetatable({},mt)

assert(A.install(sys))
local ok,reason=R.initialize(A,{minSpacingM=0.1,maxSpacingM=1})
assert(ok==true and reason==nil and R.active==true)

sys:createTrack(0.5,2)
sys:addTrackPoint(12,0,0,0,1,0,0,0.2,0.2,0.2,0.5,0.01,1,true,0.3)
sys:addTrackPoint(12,0.2,0,0,1,0,0,0.2,0.2,0.2,0.5,0.01,1,true,0.3)
sys:cutTrack(12)

local d=R.getDiagnostics()
assert(d.active==true)
assert(d.creates==1)
assert(d.pointsSeen==2)
assert(d.cuts==1)
assert(d.retainedPoints>=2)
assert(d.rejectedCalls==0)

local snap=R.getSnapshot()
assert(snap~=nil and #snap.tracks==1)

local observerCount=#A.observers
assert(observerCount>=1)
R.shutdown()
assert(R.active==false and R.getSnapshot()==nil)
assert(#A.observers==observerCount-1)

A.uninstall()
print("visual_track_runtime_harness: OK")
