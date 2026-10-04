dofile("scripts/tracks/VisualTrackJournal.lua")
local J=RealismExtensionsVisualTrackJournal

local j=J.new({
    minSpacingM=0.30,
    maxSpacingM=1.00,
    maxChordErrorM=0.04,
    maxDirectionDeltaRad=math.rad(6),
    attributeEpsilon=0.04,
    maxRetainedPoints=100
})

assert(j:onCreate(10,0.65,4,1000))
local function p(x,z,opts)
    opts=opts or {}
    return {
        x=x,y=0,z=z,
        ux=opts.ux or 1,uy=0,uz=opts.uz or 0,
        r=opts.r or 0.4,g=opts.g or 0.3,b=opts.b or 0.2,
        dirtAmount=opts.dirt or 0.8,
        groundDepth=opts.depth or 0.02,
        tireDirection=opts.dir or 1,
        onTerrain=opts.onTerrain~=false,
        colorBlendWithTerrain=opts.blend or 0.5,
        timestampMs=opts.t or 1000
    }
end

-- Straight dense points are aggressively reduced but the endpoint survives cut.
assert(j:onPoint(10,p(0,0)))
assert(j:onPoint(10,p(0.10,0)))
assert(j:onPoint(10,p(0.20,0)))
assert(j:onPoint(10,p(0.30,0)))
assert(j:onCut(10))
local snap=j:getSnapshot()
assert(#snap.tracks==1)
assert(#snap.tracks[1].fragments==1)
local pts=snap.tracks[1].fragments[1].points
assert(#pts>=2 and #pts<4)
assert(math.abs(pts[1].x-0)<0.000001)
assert(math.abs(pts[#pts].x-0.30)<0.000001)
assert(snap.tracks[1].fragments[1].closed==true)

-- A sharp geometric deviation must preserve the pending corner.
assert(j:onPoint(10,p(1.0,0)))
assert(j:onPoint(10,p(1.3,0)))
assert(j:onPoint(10,p(1.5,0.20)))
assert(j:onCut(10))
snap=j:getSnapshot()
local curve=snap.tracks[1].fragments[2].points
assert(#curve>=3)

-- Visual/material state changes are semantic boundaries even at short spacing.
assert(j:onPoint(10,p(2.0,0,{dirt=0.2})))
assert(j:onPoint(10,p(2.1,0,{dirt=0.9})))
assert(j:onCut(10))
snap=j:getSnapshot()
local attr=snap.tracks[1].fragments[3].points
assert(#attr==2)
assert(attr[1].dirtAmount~=attr[2].dirtAmount)

-- Official adapter payload: 15 arguments including native track id.
local args={n=15,10,3,4,5,1,0,0,0.1,0.2,0.3,0.7,0.04,-1,true,0.6}
local parsed,reason=J.parsePoint(args,1234)
assert(parsed~=nil and reason==nil)
assert(parsed.x==3 and parsed.y==4 and parsed.z==5)
assert(parsed.ux==1 and parsed.onTerrain==true)
assert(parsed.timestampMs==1234)

local bad={n=14}
assert(J.parsePoint(bad,0)==nil)

-- Adapter observer normalizes official calls; it never persists raw args.
local j2=J.new()
local obs=j2:makeAdapterObserver(function() return 5000 end)
obs:createTrack(nil,{n=2,0.8,7},{n=1,99})
obs:addTrackPoint(nil,{n=15,99,1,2,3,0,0,1,0.2,0.3,0.4,0.5,0.01,1,true,0.25},{n=1,true})
obs:cutTrack(nil,{n=1,99},{n=0})
local s2=j2:getSnapshot()
assert(#s2.tracks==1 and s2.tracks[1].widthM==0.8 and s2.tracks[1].atlasIndex==7)
assert(#s2.tracks[1].fragments[1].points==1)
assert(s2.tracks[1].fragments[1].points[1].x==1)
assert(s2.tracks[1].fragments[1].points[1].timestampMs==5000)

-- Unknown runtime signature fails closed rather than inventing semantics.
local beforeReject=j2.stats.rejectedCalls
obs:addTrackPoint(nil,{n=16,99},{n=0})
assert(j2.stats.rejectedCalls==beforeReject+1)

-- Bounded retention only prunes closed fragments, never an active path.
local j3=J.new({minSpacingM=0.01,maxSpacingM=0.05,maxRetainedPoints=100})
for track=1,3 do
    assert(j3:onCreate(track,0.5,1,0))
    for i=0,60 do assert(j3:onPoint(track,p(i*0.06,track))) end
    assert(j3:onCut(track))
end
assert(j3.retainedPoints<=100)
assert(j3.stats.prunedPoints>0)

print("visual_track_journal_harness: OK")
