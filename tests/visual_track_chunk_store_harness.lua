dofile("scripts/tracks/VisualTrackChunkStore.lua")
local S=RealismExtensionsVisualTrackChunkStore

local store=S.new({chunkSizeM=10,maxQueryChunks=16})
local snapshot={
    tracks={
        {
            widthM=0.6,
            atlasIndex=2,
            createdAtMs=100,
            fragments={
                {
                    closed=true,
                    points={
                        {x=1,y=0,z=1},
                        {x=9,y=0,z=1},
                        {x=11,y=0,z=1},
                        {x=19,y=0,z=1},
                        {x=21,y=0,z=1}
                    }
                },
                {
                    closed=false,
                    points={{x=2,y=0,z=12},{x=3,y=0,z=12}}
                }
            }
        }
    }
}

local ok,reason=store:rebuildFromJournalSnapshot(snapshot)
assert(ok==true and reason==nil)
local stats=store:getStats()
assert(stats.chunks==3)
assert(stats.fragments==3)
-- Boundary continuity duplicates the prior point into each next chunk.
assert(store:getChunk(0,0)~=nil)
assert(store:getChunk(1,0)~=nil)
assert(store:getChunk(2,0)~=nil)
assert(#store:getChunk(1,0).fragments[1].points>=2)
assert(store:getChunk(1,0).fragments[1].points[1].x==9)
assert(store:getChunk(2,0).fragments[1].points[1].x==19)

-- Open/current-session fragment is intentionally excluded by default.
assert(store:getChunk(0,1)==nil)

-- Direct lookup query returns nearby populated chunks without global sorting.
local nearby=store:queryCircle(10,1,4)
assert(#nearby>=1 and #nearby<=3)
local found=false
for _,chunk in ipairs(nearby) do
    if chunk.ix==1 and chunk.iz==0 then found=true end
end
assert(found)

-- Explicit debug/replay builds may include open fragments.
assert(store:rebuildFromJournalSnapshot(snapshot,{includeOpen=true}))
assert(store:getChunk(0,1)~=nil)

-- Invalid snapshots fail closed and clear old state before import.
local bad=S.new()
local success,msg=bad:rebuildFromJournalSnapshot(nil)
assert(success==false and msg~=nil)
assert(bad:getStats().chunks==0)

store:clear()
assert(store:getStats().chunks==0)
print("visual_track_chunk_store_harness: OK")
