-- A NON-GIANTS test of a deliberately DISABLED-by-default setter candidate.
-- Do not confuse 1m main-heightmap vertex edits with 0.125m physical ruts.
dofile("scripts/terrain/TerrainGeometryJournal.lua")
dofile("scripts/terrain/TerrainQuantizedHeightBudget.lua")
dofile("scripts/terrain/TerrainAbsoluteVertexCandidate.lua")
local J=RealismExtensionsTerrainGeometryJournal
local B=RealismExtensionsTerrainQuantizedHeightBudget
local C=RealismExtensionsTerrainAbsoluteVertexCandidate
local q=255/65535
local heights={}
local base=q*36000
local function key(x,z) return tostring(x)..":"..tostring(z) end
local function read(x,z) return heights[key(x,z)] or base end
local function set(x,z,y) heights[key(x,z)]=y end
local j=J.new(999,{unitM=1,sample=read})
local b=assert(B.new({quantumM=q,toleranceM=0.00005}))
local writes=0
local function setter(x,z,y)
    writes=writes+1
    -- A mock 16-bit quantizer: GIANTS API behavior is NOT known from this.
    set(x,z,math.floor(y/q+0.5)*q)
end
local disabled=assert(C.new({budget=b,journal=j,writeHeight=setter}))
assert(disabled:applyOne(10,10,2*q)==nil)
assert(writes==0 and b:getDebt("10:10")==0)
local c=assert(C.new({
    budget=b,journal=j,writeHeight=setter,explicitWrite=true,
    verifyExclusive=function()return true end
}))
assert(c:applyOne(10.2,10,q)==nil)
assert(writes==0)
-- First pass below quantum: hold the request, don't write native height.
local defer,reason=c:applyOne(10,10,q*0.55)
assert(defer==nil and reason=="SUB_QUANTUM_DEBT")
assert(writes==0 and b:getDebt("10:10")>q/2)
-- Second physical pass: one-step direct absolute target, with actual readback.
local outcome=assert(c:applyOne(10,10,q*0.65))
assert(outcome.verified==true)
assert(math.abs(outcome.beforeY-outcome.afterY-q)<0.00005)
assert(writes==1 and c.stats.verified==1 and b.quarantined==false)
assert(j.observations["10:10"]~=nil)
assert(j.observations["10:10"].owned==true)
assert(math.abs(j.observations["10:10"].preREHeightM-base)<0.00005)
assert(j.pendingCount==0)
-- A second direct command cannot spend more than one quantum either.
local another=assert(c:applyOne(10,10,q))
assert(another.verified==true)
assert(writes==2 and j.observations["10:10"].preREHeightM==base)
assert(read(11,10)==base and read(10,11)==base)

-- A 'setter' that changes a neighboring vertex must NOT be certified as
-- vertex-local even when the requested center vertex moved by exactly q.
local j2=J.new(999,{unitM=1,sample=read})
local b2=assert(B.new({quantumM=q,toleranceM=0.00005}))
local bad=assert(C.new({
    budget=b2,journal=j2,explicitWrite=true,
    verifyExclusive=function()return true end,
    writeHeight=function(x,z,y)
        set(x,z,y)
        set(x+1,z,read(x+1,z)-q)
    end
}))
local unsafe,whyBad=bad:applyOne(50,50,q)
assert(unsafe~=nil and unsafe.verified==false)
assert(whyBad=="UNTRUSTED_NATIVE_SIDE_EFFECT")
assert(b2.quarantined==true and j2.pendingCount==0)
assert(j2.observations["50:50"].owned==false)
assert(j2.observations["51:50"].owned==false)
assert(bad:applyOne(70,70,q)==nil)

-- A fake engine that lowers the center by 15 steps instead of one:
-- quarantine, but do not automatically raise it back on a live save.
local j3=J.new(999,{unitM=1,sample=read})
local b3=assert(B.new({quantumM=q,toleranceM=0.00005}))
local burst=assert(C.new({
    budget=b3,journal=j3,explicitWrite=true,
    verifyExclusive=function()return true end,
    writeHeight=function(x,z,y) set(x,z,read(x,z)-15*q) end
}))
local blown,reasonBurst=burst:applyOne(90,90,q)
assert(blown.verified==false and reasonBurst=="UNBOUNDED_OBSERVED_DELTA")
assert(b3.quarantined==true)
assert(j3.observations["90:90"].owned==false)
assert(j3.pendingCount==0)

-- Even an explicitly enabled setter may never bypass queue/session isolation.
local isolated=assert(C.new({budget=assert(B.new({quantumM=q})),
    journal=J.new(999,{unitM=1,sample=read}),
    explicitWrite=true,writeHeight=setter}))
local beforeGuardWrites=writes
local refused,guardReason=isolated:applyOne(120,120,q)
assert(refused==nil and guardReason=="EXCLUSIVITY_UNAVAILABLE")
assert(writes==beforeGuardWrites)
local exclusivityCalls=0
local lost=assert(C.new({budget=assert(B.new({quantumM=q})),
    journal=J.new(999,{unitM=1,sample=read}),
    explicitWrite=true,writeHeight=setter,
    verifyExclusive=function()
        exclusivityCalls=exclusivityCalls+1
        return exclusivityCalls==1
    end}))
local lostResult,lostWhy=lost:applyOne(130,130,q)
assert(lostResult==nil and lostWhy=="EXCLUSIVITY_CHANGED")
assert(writes==beforeGuardWrites)
assert(lost.budget.stats.pending==0)
print("terrain_absolute_vertex_candidate_harness: OK")
