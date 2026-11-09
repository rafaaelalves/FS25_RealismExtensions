-- Strict metadata lifetime budget for a TireTrack visual observer.
-- All these operations are Lua memory bookkeeping, NEVER soil writes.
dofile("scripts/tracks/VisualTrackJournal.lua")
local J=RealismExtensionsVisualTrackJournal
local function point(x,z)
    return {x=x,y=0,z=z,ux=1,uy=0,uz=0,
        r=0.2,g=0.3,b=0.2,dirtAmount=0.2,
        groundDepth=0.01,tireDirection=1,onTerrain=true,
        colorBlendWithTerrain=0.5,sessionTimeMs=1}
end
local runtime=J.new({
    retainClosedFragments=false,maxTrackedNativeIds=3,
    maxPointsPerOpenFragment=16
})
local finalized={}
runtime:addFragmentSink({onFragmentClosed=function(_,track,f,reason)
    finalized[#finalized+1]={id=track.nativeTrackId,
        closeReason=reason,points=#f.points}
end})
assert(runtime:onCreate(1,0.6,1,1))
assert(runtime:onCreate(2,0.6,1,1))
assert(runtime:onCreate(3,0.6,1,1))
assert(#runtime.tracks==3)
assert(runtime:onPoint(1,point(0,0)))
assert(runtime:onPoint(2,point(1,0)))
assert(runtime:onPoint(3,point(2,0)))
-- Every track is still physically active. Do NOT truncate an open trace
-- to admit a fourth ID: refuse the fourth without altering prior points.
assert(runtime:onCreate(4,0.6,1,1)==false)
assert(runtime.stats.nativeIdCapRefusals==1)
assert(runtime.tracksByNativeId[4]==nil)
assert(#runtime.tracks==3)
assert(runtime:onCut(2))
assert(finalized[#finalized].id==2)
-- With one inactive track, admit another by evicting only that old ID.
assert(runtime:onCreate(4,0.6,1,1))
assert(runtime.stats.nativeIdEvictions==1)
assert(runtime.tracksByNativeId[2]==nil)
assert(runtime.tracksByNativeId[4]~=nil)
assert(#runtime.tracks==3)
assert(runtime:onPoint(2,point(10,0))==false)
assert(runtime:onPoint(1,point(0.5,0)))
assert(runtime:onCut(4))
assert(runtime:onCreate(5,0.6,1,1))
assert(runtime.stats.nativeIdEvictions==2)
assert(runtime.tracksByNativeId[4]==nil)
assert(runtime:onCut(1))
assert(runtime:onCut(3))
assert(#runtime.tracks==3)

-- Native reused ID should replace its own header (never append).
local old2=runtime.tracksByNativeId[5]
assert(runtime:onCreate(5,0.6,1,1))
assert(#runtime.tracks==3)
assert(runtime.tracksByNativeId[5]~=old2)
assert(runtime.stats.nativeIdReuses==1)

-- Exhaustive turnover: no boundless headers after long sessions.
for id=100,650 do
    assert(runtime:onCreate(id,0.6,1,1))
    assert(runtime:onPoint(id,point(id*0.1,0)))
    assert(runtime:onCut(id))
    assert(#runtime.tracks<=3)
end
assert(runtime.stats.nativeIdEvictions>500)
assert(runtime.retainedPoints==0)
for _,tr in ipairs(runtime.tracks) do
    assert(runtime.tracksByNativeId[tr.nativeTrackId]==tr)
    assert(runtime.tracks[tr.trackListIndex]==tr)
    assert(#tr.fragments==0)
end

-- Snapshot-retaining variant MUST NOT evict historical fragments, but
-- repeated reuse of an existing native ID must ALSO consume the cap.
-- An explicitly refused reuse must invalidate the active ID mapping so
-- future native points are not attached to a retired track generation.
local retained=J.new({
    retainClosedFragments=true,maxTrackedNativeIds=2
})
assert(retained:onCreate(10,0.5,1,1))
assert(retained:onPoint(10,point(1,1)))
assert(retained:onCreate(20,0.5,1,1))
assert(retained:onCreate(10,0.5,1,1)==false)
assert(retained.stats.nativeIdCapRefusals==1)
assert(retained.tracksByNativeId[10]==nil)
assert(retained:onPoint(10,point(2,2))==false)
assert(retained:onCreate(30,0.5,1,1)==false)
assert(retained.stats.nativeIdEvictions==0)
assert(#retained.tracks==2)
assert(retained.tracks[1].fragments[1].closed==true)
print("visual_track_native_id_cap_harness: OK")
