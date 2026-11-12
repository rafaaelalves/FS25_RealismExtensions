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

-- Real SHADOW observations are cumulative: a stable 10mm logical
-- target can request at most two verified ~3.891mm native steps. Feeding
-- it again 50 frames must never create more than the original desired
-- 10mm. Incremental and cumulative accounting cannot be mixed.
local cumulativeJ=J.new(999,{unitM=1,sample=read})
local cumulativeB=assert(B.new({quantumM=q,toleranceM=0.00005}))
local cumulativeCalls=0
local cumulative=assert(C.new({
    journal=cumulativeJ,budget=cumulativeB,explicitWrite=true,
    verifyExclusive=function()return true end,
    writeHeight=function(x,z,y)
        cumulativeCalls=cumulativeCalls+1
        set(x,z,math.floor(y/q+0.5)*q)
    end
}))
for n=1,50 do
    local result,why=cumulative:applyOne(410,410,0.010,"CUMULATIVE")
    if result~=nil then
        assert(result.verified==true)
    else
        assert(why=="SUB_QUANTUM_DEBT")
    end
end
assert(cumulativeCalls==2)
assert(math.abs(read(410,410)-(base-2*q))<0.00005)
assert(math.abs(cumulativeB:getDebt("410:410")-(0.010-2*q))<0.000001)
local mixedResult,mixedWhy=cumulative:applyOne(410,410,q,"INCREMENTAL")
assert(mixedResult==nil and mixedWhy=="MIXED_DEBT_CONTRACT")

-- Real 03-Nov scenario: request=1.5mm, native height step~3.891mm.
-- CUMULATIVE 1.5mm demanded over 100 ticks must produce ZERO writes;
-- increasing the same target to 3mm also must not dig a full step.
-- Only once cumulative demand reaches 4.5mm may one verified quantum
-- be submitted; repeated unchanged target then cannot produce a second.
local exactBudget=assert(B.new({quantumM=q,toleranceM=0.00005}))
local exactJournal=J.new(999,{unitM=1,sample=read})
local exactCalls=0
local exact=assert(C.new({
    budget=exactBudget,journal=exactJournal,explicitWrite=true,
    verifyExclusive=function()return true end,
    writeHeight=function(x,z,y)
        exactCalls=exactCalls+1
        set(x,z,math.floor(y/q+0.5)*q)
    end
}))
for _=1,100 do
    local skip,reason=exact:applyOne(490,490,0.0015,"CUMULATIVE")
    assert(skip==nil and reason=="SUB_QUANTUM_DEBT")
end
assert(exactCalls==0 and read(490,490)==base)
assert(select(1,exact:applyOne(490,490,0.003,"CUMULATIVE"))==nil)
assert(exactCalls==0)
local exactResult=assert(exact:applyOne(490,490,0.0045,"CUMULATIVE"))
assert(exactResult.verified and exactCalls==1)
assert(math.abs(exactResult.beforeY-exactResult.afterY-q)<0.00005)
assert((base-read(490,490))<=0.0045+0.00005)
for _=1,100 do
    local skip,reason=exact:applyOne(490,490,0.0045,"CUMULATIVE")
    assert(skip==nil and reason=="SUB_QUANTUM_DEBT")
end
assert(exactCalls==1)

-- LIVE FS25 evidence (11-Nov write, 12-Nov independent post-reload
-- readback), now kept as a precise regression fixture. Requested a full
-- 255/65535m quantum; GIANTS returned ~59 nanometers LESS lowering,
-- not a second step. The unchanged cumulative target must NEVER
-- duplicate this q-sized excavation after float32 height readback.
-- This synthetic harness validates accounting only, not live persistence.
local liveBefore=152.50973510742188
local liveAfter=152.50584411621094
local liveMeasured=liveBefore-liveAfter
assert(math.abs(liveMeasured-0.0038909912109375)<1e-12)
assert(liveMeasured<=q and math.abs(q-liveMeasured)<0.000001)
set(348,387,liveBefore)
local liveJ=J.new(999,{unitM=1,sample=read})
local liveB=assert(B.new({quantumM=q,toleranceM=0.00005}))
local liveCalls=0
local liveC=assert(C.new({
    budget=liveB,journal=liveJ,explicitWrite=true,
    verifyExclusive=function()return true end,
    writeHeight=function(x,z,target)
        assert(x==348 and z==387)
        assert(target<liveBefore and target>liveBefore-q)
        liveCalls=liveCalls+1
        set(x,z,liveAfter)
    end
}))
local liveResult=assert(liveC:applyOne(348,387,q,"CUMULATIVE"))
assert(liveResult.verified==true and liveCalls==1)
assert(math.abs(liveResult.beforeY-liveBefore)<1e-10)
assert(math.abs(liveResult.afterY-liveAfter)<1e-10)
assert(liveJ.pendingCount==0 and liveB.quarantined==false)
local noRepeat,noRepeatReason=liveC:applyOne(348,387,q,"CUMULATIVE")
assert(noRepeat==nil and noRepeatReason=="SUB_QUANTUM_DEBT")
assert(liveCalls==1)
assert(math.abs(liveB:getDebt("348:387")-(q-liveMeasured))<1e-10)
assert(liveB.entries["348:387"].committedM<=q)
assert(liveB.entries["348:387"].committedM>0)

-- Real 03-Nov readback examples are close to q*n, but world float
-- roundoff can put them microscopically BELOW the native lattice.
-- An absolute target of before-q is then hazardous for floor quantizers:
-- before-q lands below the NEXT boundary and may lower two full quanta.
-- The interior 0.75q target is safe for both floor and nearest rounding.
local floorJournal=J.new(999,{unitM=1,sample=read})
local floorBudget=assert(B.new({quantumM=q,toleranceM=0.00005}))
local yBelow=base-0.000007
set(491,490,yBelow)
local legacyTarget=yBelow-q
assert(math.abs((yBelow-math.floor(legacyTarget/q)*q)-2*q)
    <0.00002) -- old before-q would cause ~2q in a floor quantizer
local floorCalls,floorTarget=0,nil
local floorCandidate=assert(C.new({
    budget=floorBudget,journal=floorJournal,explicitWrite=true,
    verifyExclusive=function()return true end,
    writeHeight=function(x,z,y)
        floorCalls=floorCalls+1
        floorTarget=y
        set(x,z,math.floor(y/q)*q)
    end
}))
local floorResult=assert(floorCandidate:applyOne(491,490,q))
assert(floorResult.verified==true and floorCalls==1)
assert(math.abs(floorTarget-(yBelow-0.75*q))<0.000000001)
assert(math.abs(floorResult.beforeY-floorResult.afterY-q)<0.00005)
assert(floorBudget.quarantined==false)
local floorResult2,floorReason=floorCandidate:applyOne(491,490,q,"CUMULATIVE")
assert(floorResult2==nil and floorReason=="MIXED_DEBT_CONTRACT")

-- Matrix against alternative quantizers and map height scales.
-- No explicit 255m default is allowed in production. Each mock injects
-- its OWN q and a small +/- jitter in MAIN's returned height.
for _,scaleQ in ipairs({255/65535,0.0015,0.01}) do
    for _,quantizer in ipairs({"FLOOR","NEAREST"}) do
        for _,fractionalReadback in ipairs({-0.002,0,0.002}) do
            local grid=scaleQ*40000
            local now=grid+fractionalReadback*scaleQ
            local simHeight=now
            local thisJournal=J.new(999,{unitM=1,
                sample=function(x,z)
                    if x==600 and z==600 then return simHeight end
                    return grid
                end
            })
            local thisBudget=assert(B.new({
                quantumM=scaleQ,toleranceM=0.00005
            }))
            local thisWriter=assert(C.new({
                budget=thisBudget,journal=thisJournal,explicitWrite=true,
                verifyExclusive=function()return true end,
                writeHeight=function(x,z,y)
                    local k=y/scaleQ
                    if quantizer=="FLOOR" then
                        simHeight=math.floor(k)*scaleQ
                    else
                        simHeight=math.floor(k+0.5)*scaleQ
                    end
                end
            }))
            local step,why=thisWriter:applyOne(600,600,scaleQ)
            -- Positive readback bias estimates a little MORE than the
            -- q-sized physical step. That cannot be approved when only
            -- q was authorized, even though it is inside the general
            -- 50um quantizer matching tolerance: fail closed instead.
            if fractionalReadback>0 then
                assert(step~=nil and step.verified==false)
                assert(why=="OBSERVED_LOWERING_EXCEEDS_DEBT")
                assert(thisBudget.quarantined==true)
                assert(thisBudget.stats.verified==0)
            else
                assert(step~=nil and step.verified==true
                    and why==nil, "rounding safety: "..quantizer)
                assert(thisBudget.quarantined==false)
                assert(thisBudget.stats.verified==1)
            end
            assert(now-simHeight>0 and now-simHeight<=scaleQ*1.01)
        end
    end
end

-- The same interior target must NOT allow a native setter that changes
-- continuous world height by 0.75q to be certified as a full q step.
local continuousBudget=assert(B.new({quantumM=q,toleranceM=0.00005}))
local continuousCandidate=assert(C.new({
    budget=continuousBudget,
    journal=J.new(999,{unitM=1,sample=read}),
    explicitWrite=true,verifyExclusive=function()return true end,
    writeHeight=function(x,z,y)set(x,z,y) end
}))
local continuous,continuousWhy=continuousCandidate:applyOne(492,490,q)
assert(continuous~=nil and continuous.verified==false)
assert(continuousWhy=="UNBOUNDED_OBSERVED_DELTA")
assert(continuousBudget.quarantined==true)

-- A native setter returning just q + 0.02mm is within the old
-- readback tolerance but exceeds a vertex's EXACT q demand. Reject
-- before certifying the geometry, untrust the touched vertex, and do
-- not perform any automatic reversal of a real engine write.
local strictJournal=J.new(999,{unitM=1,sample=read})
local strictBudget=assert(B.new({quantumM=q,toleranceM=0.00005}))
local strictNativeCalls=0
local strictCandidate=assert(C.new({
    budget=strictBudget,journal=strictJournal,explicitWrite=true,
    verifyExclusive=function()return true end,
    writeHeight=function(x,z,y)
        strictNativeCalls=strictNativeCalls+1
        set(x,z,read(x,z)-(q+0.00002))
    end
}))
local over,overWhy=strictCandidate:applyOne(650,650,q,"CUMULATIVE")
assert(over~=nil and over.verified==false)
assert(overWhy=="OBSERVED_LOWERING_EXCEEDS_DEBT")
assert(strictNativeCalls==1 and strictBudget.quarantined==true)
assert(strictJournal.observations["650:650"].owned==false)
assert(strictCandidate:applyOne(650,650,2*q,"CUMULATIVE")==nil)
assert(strictNativeCalls==1)

-- Center lowers by EXACTLY one authorized quantum, but the right
-- neighbor also changes by just 20um. Prior generic journal resolution
-- (50um) silently ignored the collateral and could certify the vertex.
-- The isolated absolute research path must detect this and FAIL CLOSED.
local microJournal=J.new(999,{unitM=1,sample=read})
local microBudget=assert(B.new({quantumM=q,toleranceM=0.00005}))
local micro=assert(C.new({
    budget=microBudget,journal=microJournal,explicitWrite=true,
    verifyExclusive=function()return true end,
    writeHeight=function(x,z,y)
        set(x,z,math.floor(y/q+0.5)*q)
        set(x+1,z,read(x+1,z)-0.00002)
    end
}))
local microside,microWhy=micro:applyOne(71,70,q,"CUMULATIVE")
assert(microside~=nil and microside.verified==false)
assert(microWhy=="UNTRUSTED_NATIVE_SIDE_EFFECT")
assert(microside.footprint.movedVertices==2)
assert(microside.footprint.maxLowerM>=q-0.000001)
assert(microBudget.quarantined==true)
assert(microJournal.observations["71:70"].owned==false)
assert(microJournal.observations["72:70"].owned==false)
assert(microJournal.pendingCount==0)

-- A 'setter' that changes a neighboring vertex must NOT be certified as
-- vertex-local even when the requested center vertex moved by exactly q.
local j2=J.new(999,{unitM=1,sample=read})
local b2=assert(B.new({quantumM=q,toleranceM=0.00005}))
local bad=assert(C.new({
    budget=b2,journal=j2,explicitWrite=true,
    verifyExclusive=function()return true end,
    writeHeight=function(x,z,y)
        set(x,z,math.floor(y/q+0.5)*q)
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

-- Diagonal collateral must be scanned too. Before this protection, the
-- journal's 1.05m sampling envelope detected cardinal neighbors but not
-- the vertices at sqrt(2)m distance, falsely certifying a safe write.
local jd=J.new(999,{unitM=1,sample=read})
local bd=assert(B.new({quantumM=q,toleranceM=0.00005}))
local diagonal=assert(C.new({
    budget=bd,journal=jd,explicitWrite=true,
    verifyExclusive=function()return true end,
    writeHeight=function(x,z,y)
        set(x,z,math.floor(y/q+0.5)*q)
        set(x+1,z+1,read(x+1,z+1)-q)
    end
}))
local footprint=assert(jd:enumerateVertices(60,60,0.70))
assert(#footprint==9)
local diagOutcome,diagReason=diagonal:applyOne(60,60,q)
assert(diagOutcome~=nil and diagOutcome.verified==false)
assert(diagReason=="UNTRUSTED_NATIVE_SIDE_EFFECT")
assert(bd.quarantined==true and jd.pendingCount==0)
assert(jd.observations["60:60"].owned==false)
assert(jd.observations["61:61"].owned==false)

-- Pre-existing foreign/invalidated geometry must not create latent
-- quantized damage that could unexpectedly apply when ownership changes.
local untrustedJournal=J.new(999,{unitM=1,sample=read})
untrustedJournal.observations["80:80"]={
    x=80,z=80,preREHeightM=base,observedHeightM=base,owned=false
}
local untrustedBudget=assert(B.new({quantumM=q}))
local untrustedWriter=assert(C.new({
    budget=untrustedBudget,journal=untrustedJournal,
    explicitWrite=true,writeHeight=setter,
    verifyExclusive=function()return true end
}))
local refusedUntrusted,whyUntrusted=untrustedWriter:applyOne(80,80,q)
assert(refusedUntrusted==nil and whyUntrusted=="UNTRUSTED_EDIT")
assert(untrustedBudget:getDebt("80:80")==0)
assert(untrustedJournal.pendingCount==0)

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
-- A third-party writer moves the MAIN center by only 0.1mm after
-- Journal.begin and before the absolute setter. The old generic 2mm
-- queue threshold allowed that and would attribute it as part of RE's
-- q-sized readback. Strict ABSOLUTE preflight must REFUSE WITH ZERO
-- setters called and preserve the caller's cumulative target debt.
set(665,665,base)
local competingJournal=J.new(999,{unitM=1,sample=read})
local competingBudget=assert(B.new({quantumM=q}))
local originalPreflight=competingJournal.validateBeforeSubmit
local injected=false
function competingJournal:validateBeforeSubmit(token,allowedDriftM)
    assert(allowedDriftM<=0.00001)
    if not injected then
        injected=true
        set(665,665,read(665,665)-0.0001)
    end
    return originalPreflight(self,token,allowedDriftM)
end
local competingCalls=0
local competing=assert(C.new({
    budget=competingBudget,journal=competingJournal,
    explicitWrite=true,
    verifyExclusive=function() return true end,
    writeHeight=function(x,z,y)
        competingCalls=competingCalls+1
        set(x,z,y)
    end
}))
local competingResult,competingWhy=
    competing:applyOne(665,665,q,"CUMULATIVE")
assert(competingResult==nil and competingWhy=="QUEUED_GEOMETRY_DRIFT")
assert(competingCalls==0)
assert(competingJournal.pendingCount==0)
assert(competingBudget.stats.pending==0)
assert(math.abs(competingBudget:getDebt("665:665")-q)<1e-10)
assert(competingBudget.quarantined==true)
assert(competing:applyOne(665,665,q,"CUMULATIVE")==nil)
assert(competingCalls==0)
-- Never recover/rebase the foreign edit as an RE-owned rut.
assert(competingJournal.observations["665:665"]==nil)

-- A setter adapter returning false is failure, even without an exception.
local j4=J.new(999,{unitM=1,sample=read})
local b4=assert(B.new({quantumM=q}))
local adapterFailure=assert(C.new({
    budget=b4,journal=j4,explicitWrite=true,
    writeHeight=function()return false end,
    verifyExclusive=function()return true end
}))
local resultFailure,reasonFailure=adapterFailure:applyOne(140,140,q)
assert(resultFailure~=nil and resultFailure.verified==false)
assert(reasonFailure=="false")
assert(b4.quarantined==true and j4.pendingCount==0)
assert(adapterFailure.stats.writeErrors==1 and adapterFailure.stats.verified==0)
print("terrain_absolute_vertex_candidate_harness: OK")
