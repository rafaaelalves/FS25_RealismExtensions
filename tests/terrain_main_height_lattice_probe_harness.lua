-- No GIANTS engine. Synthetic 16-bit MAIN lattices; no writes.
dofile("scripts/terrain/TerrainMainHeightLatticeProbe.lua")
local P=RealismExtensionsTerrainMainHeightLatticeProbe
local function heightsFor(scale,withNoise)
    local q=scale/65535
    local heights={}
    for i=0,80 do
        local jitter=withNoise and ((i%3)-1)*0.000008 or 0
        heights[#heights+1]=100+40000*q+i*q+jitter
    end
    return heights,q
end
local samples,q=heightsFor(255,true)
local r,why=P.analyzeHeights(samples)
assert(r~=nil and why==nil)
assert(r.status=="ONE_LATTICE_CANDIDATE")
assert(r.best.heightScaleM==255)
assert(r.best.quantumM==q and r.best.maxResidualM<=0.00005)
assert(r.best.adjacentLevelPairs>=2)
assert(r.authorizesNativeWrite==false)
assert(r.best.authorizesNativeWrite==false)
assert(r.count==81)

-- The same data also fits a q/2 sublattice, but has NO observed q/2
-- adjacency; don't promote that aliased smaller interval to real physics.
local half=assert(P.analyzeHeights(samples,127.5))
assert(half.best==nil)
assert(half.status=="INSUFFICIENT_OR_ALIASED_EVIDENCE")
assert(half.candidates[1].adjacentLevelPairs==0)

-- A constant/near-constant patch is NOT evidence for ANY height quantum.
local flat={}
for i=1,81 do flat[i]=152.5 end
local flatResult=assert(P.analyzeHeights(flat))
assert(flatResult.best==nil)
assert(flatResult.status=="INSUFFICIENT_OR_ALIASED_EVIDENCE")

-- Even the true q is unknown if ALL sampled differences are multiples of 2q.
local even={}
for i=0,80 do even[#even+1]=100+40000*q+i*(2*q) end
local evenResult=assert(P.analyzeHeights(even))
assert(evenResult.best==nil)
assert(evenResult.candidates[1].authorizesNativeWrite==false)

-- Nonstandard map heightScale: never auto-default to 255m.
local arbitrary,qArb=heightsFor(300,false)
local explicit=assert(P.analyzeHeights(arbitrary,300))
assert(explicit.best~=nil and explicit.best.heightScaleM==300)
assert(explicit.best.quantumM==qArb)
local missing=assert(P.analyzeHeights(arbitrary))
assert(missing.best==nil)
local wrong=assert(P.analyzeHeights(arbitrary,255))
assert(wrong.best==nil)
assert(wrong.candidates[1].evidence=="RESIDUAL_MISMATCH")

local alternativeSamples=heightsFor(512,false)
local alternative=assert(P.analyzeHeights(alternativeSamples))
assert(alternative.best~=nil and alternative.best.heightScaleM==512)
assert(select(1,P.analyzeHeights({1,2,3}))==nil)
assert(select(1,P.analyzeHeights({},255))==nil)
assert(select(1,P.analyzeHeights(samples,0))==nil)
assert(select(1,P.analyzeHeights(samples,0/0))==nil)
assert(select(1,P.analyzeHeights(samples,99999))==nil)
local hasNan={}
for i=1,81 do hasNan[i]=100+i end
hasNan[50]=0/0
assert(select(1,P.analyzeHeights(hasNan,255))==nil)

-- Live adapter uses exactly an 81-vertex bounded READ ONLY scan around
-- RE's mark and journal. Never calls a GIANTS native setter.
local count=0
local centerX,centerZ=344,387
RealismExtensionsTerrainGeometryProbe={position={x=344.2,z=387.4}}
RealismExtensionsTerrainRuntime={geometryJournal={
    unitM=1,
    getHeight=function(_,x,z)
        count=count+1
        return 100+q*(40000+2*(x-centerX)+3*(z-centerZ))
    end
}}
g_server={}
g_currentMission={}
setTerrainHeightAtWorldPos=function()
    error("LATTICE PROBE MUST NEVER WRITE")
end
local captured=assert(P.scanMarkedArea())
assert(captured.status=="ONE_LATTICE_CANDIDATE")
assert(captured.best.heightScaleM==255)
assert(captured.centerX==centerX and captured.centerZ==centerZ)
assert(captured.horizontalUnitM==1 and count==81)
local ok,report=P.consoleAtMarkedArea()
assert(ok and report.status=="ONE_LATTICE_CANDIDATE")
assert(count==162)
local requested=assert(P.scanMarkedArea(300))
assert(requested.best==nil)
assert(count==243)
RealismExtensionsTerrainGeometryProbe.position=nil
assert(select(1,P.scanMarkedArea())==nil)
RealismExtensionsTerrainGeometryProbe.position={x=344.2,z=387.4}
g_server=nil
assert(select(1,P.scanMarkedArea())==nil)
print("terrain_main_height_lattice_probe_harness: OK")
