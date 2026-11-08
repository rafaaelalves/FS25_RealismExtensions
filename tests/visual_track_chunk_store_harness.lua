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

-- A working farm can produce thousands of vehicle/implement tracks in
-- one session. Evict oldest FINALIZED visual fragments so the read-only
-- journal cannot accumulate unlimited point references or spatial chunks.
-- Evicted visuals never create a physical soil recovery instruction.
local bounded=S.new({
    chunkSizeM=10,maxQueryChunks=16,
    maxStoredChunks=2,maxStoredFragments=3,
    maxStoredPointReferences=6
})
local function addTrackAt(x,logicalId,n)
    local pts={}
    for i=1,(n or 2) do
        pts[#pts+1]={x=x+(i-1)*0.1,y=0,z=1}
    end
    local track={logicalTrackId=logicalId,widthM=0.4,atlasIndex=2}
    local f={sequence=logicalId,closed=true,points=pts}
    return bounded:addFragment(track,f,"CURRENT_SESSION")
end
assert(addTrackAt(1,1))
assert(addTrackAt(11,2))
assert(bounded:getStats().chunks==2)
assert(addTrackAt(21,3))
assert(bounded:getStats().chunks==2)
assert(bounded:getChunk(0,0)==nil)
assert(bounded:getChunk(1,0)~=nil)
assert(bounded:getChunk(2,0)~=nil)
assert(bounded:getStats().evictedFragments==1)
assert(bounded:getStats().evictedPointReferences==2)
assert(addTrackAt(31,4))
assert(bounded:getChunk(1,0)==nil)
assert(bounded:getStats().pointReferences<=6)
assert(bounded:getStats().fragments<=3)
-- A huge fragment cannot be silently truncated and mistaken for
-- a continuous wheel-track segment. Nor may it leave an empty chunk.
assert(addTrackAt(81,5,7)==false)
assert(bounded:getChunk(8,0)==nil)
assert(bounded:getStats().overflowRefusals==1)
-- Repeated additions must stay within all caps and compact FIFO metadata.
for i=1,1000 do
    assert(addTrackAt(i*10+100,1000+i))
end
local stats=bounded:getStats()
assert(stats.chunks<=2 and stats.fragments<=3
    and stats.pointReferences<=6)
assert(stats.evictedFragments>=1000)
assert(bounded.chronologyTail<256)
bounded:clear()
local zero=bounded:getStats()
assert(zero.chunks==0 and zero.fragments==0
    and zero.pointReferences==0 and zero.evictedFragments==0
    and bounded.chronologyTail==0)

print("visual_track_chunk_store_harness: OK")
