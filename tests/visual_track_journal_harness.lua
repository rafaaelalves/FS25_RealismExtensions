dofile("scripts/tracks/VisualTrackJournal.lua")
local J=RealismExtensionsVisualTrackJournal
local function p(x,z,o)
    o=o or {}
    return {x=x,y=0,z=z,ux=o.ux or 1,uy=0,uz=o.uz or 0,
        r=o.r or 0.4,g=o.g or 0.3,b=o.b or 0.2,
        dirtAmount=o.dirt or 0.8,groundDepth=o.depth or 0.02,
        tireDirection=o.dir or 1,onTerrain=o.onTerrain~=false,
        colorBlendWithTerrain=o.blend or 0.5,sessionTimeMs=o.t or 1000}
end

local j=J.new({minSpacingM=0.30,maxSpacingM=1,maxGapM=3,maxRetainedPoints=100})
local finalized={}
j:addFragmentSink({onFragmentClosed=function(self,track,fragment,reason)
    finalized[#finalized+1]={track=track.logicalTrackId,reason=reason,n=#fragment.points}
end})
assert(j:onCreate(10,0.65,4,1000))
for _,x in ipairs({0,0.1,0.2,0.3}) do assert(j:onPoint(10,p(x,0))) end
assert(j:onCut(10))
local snap=j:getSnapshot()
local pts=snap.tracks[1].fragments[1].points
assert(#pts>=2 and #pts<4 and pts[1].x==0 and pts[#pts].x==0.3)
assert(finalized[1].reason=="CUT")

-- Curve and material/depth changes survive simplification.
assert(j:onPoint(10,p(1,0)))
assert(j:onPoint(10,p(1.3,0)))
assert(j:onPoint(10,p(1.5,0.2)))
assert(j:onCut(10))
assert(#j:getSnapshot().tracks[1].fragments[2].points>=3)
assert(j:onPoint(10,p(2,0,{depth=0.01})))
assert(j:onPoint(10,p(2.1,0,{depth=0.02})))
assert(j:onCut(10))
assert(#j:getSnapshot().tracks[1].fragments[3].points==2)

-- Non-terrain contact is excluded from world-persistent history.
assert(j:onPoint(10,p(3,0)))
assert(j:onPoint(10,p(3.1,0,{onTerrain=false})))
assert(j.stats.nonTerrainSkipped==1)
assert(finalized[#finalized].reason=="LEFT_TERRAIN")

-- Teleport/large gap creates a discontinuity instead of a long visual line.
assert(j:onPoint(10,p(4,0)))
assert(j:onPoint(10,p(20,0)))
assert(j.stats.gapCuts==1)

-- Reusing a native id retires the previous logical track generation.
local oldId=j.tracksByNativeId[10].logicalTrackId
assert(j:onCreate(10,0.7,5,2000))
assert(j.tracksByNativeId[10].logicalTrackId~=oldId)
assert(j.stats.nativeIdReuses==1)

local args={n=15,10,3,4,5,1,0,0,0.1,0.2,0.3,0.7,0.04,-1,true,0.6}
local parsed=J.parsePoint(args,1234)
assert(parsed.x==3 and parsed.sessionTimeMs==1234)
assert(J.parsePoint({n=14},0)==nil)

local j2=J.new()
local obs=j2:makeAdapterObserver(function() return 5000 end)
obs:createTrack(nil,{n=2,0.8,7},{n=1,99})
obs:addTrackPoint(nil,{n=15,99,1,2,3,0,0,1,0.2,0.3,0.4,0.5,0.01,1,true,0.25},{n=1,true})
obs:cutTrack(nil,{n=1,99},{n=0})
local s2=j2:getSnapshot()
assert(s2.tracks[1].fragments[1].points[1].sessionTimeMs==5000)

local j3=J.new({minSpacingM=0.01,maxSpacingM=0.05,maxRetainedPoints=100})
for track=1,3 do
    assert(j3:onCreate(track,0.5,1,0))
    for i=0,60 do assert(j3:onPoint(track,p(i*0.06,track))) end
    assert(j3:onCut(track))
end
assert(j3.retainedPoints<=100 and j3.stats.prunedPoints>0)
print("visual_track_journal_harness: OK")
