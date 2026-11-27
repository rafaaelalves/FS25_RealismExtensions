-- Pure sub-quantum geometry planning, no GIANTS height setters.
dofile("scripts/terrain/TerrainMainFootprintGate.lua")
dofile("scripts/terrain/TerrainAbsoluteHeightPlanner.lua")
local P=RealismExtensionsTerrainAbsoluteHeightPlanner
assert(P.new({})==nil)
assert(P.new({unitM=0})==nil)
local shadow=assert(P.new({unitM=1,maxSources=3}))
-- Thousands of no-yield or unchanged saved cells must not consume
-- the bounded shadow source pool before one real plastic rut occurs.
for i=1,100 do
    assert(shadow:observe("no-debt-"..i,i,0,0,0).state=="UNCHANGED")
    assert(shadow:observe("saved-"..i,i,0,0.024,0.024).state=="UNCHANGED")
end
assert(shadow.sourceCount==0 and next(shadow.vertices)==nil)
local a=assert(shadow:observe("cell-1",10.25,20.20,0.0017))
assert(a.state=="QUANTUM_UNVERIFIED")
assert(a.vertexKey=="10:20" and a.doesNotWrite==true)
assert(shadow:observe("cell-1",10.25,20.20,0.0017).state=="UNCHANGED")
assert(math.abs(shadow:getVertex(10,20).demandM-0.0017)<1e-8)
local next=assert(shadow:observe("cell-1",10.25,20.20,0.0032))
assert(math.abs(next.addedM-0.0015)<1e-8)
assert(math.abs(shadow:getVertex(10,20).demandM-0.0032)<1e-8)
assert(shadow:observe("cell-1",10.65,20.20,0.005)==nil)
assert(math.abs(shadow:getVertex(10,20).demandM-0.0032)<1e-8)
assert(shadow:observe("cell-2",10.28,20.18,0.0025).vertexKey=="10:20")
assert(math.abs(shadow:getVertex(10,20).demandM-0.0032)<1e-8)
assert(shadow:getVertex(10,20).sourceCount==2)
assert(shadow.stats.accumulatedM>shadow:getVertex(10,20).demandM)
assert(shadow:observe("cell-3",11.20,20,0.001))
assert(shadow:observe("cell-4",12.20,20,0.001)==nil)
assert(shadow.stats.capacityRefusals==1)
assert(shadow:summary():find("mode=NO_WRITE",1,true))
assert(shadow:summary():find("quantum=UNVERIFIED",1,true))

local q=255/65535 -- supplied externally; not inferred by this planner
local confirmed=assert(P.new({unitM=1,verifiedQuantumM=q}))
assert(confirmed:observe("A",250.1,300.1,0.0017).state=="SUB_QUANTUM_SHADOW")
assert(confirmed:observe("A",250.1,300.1,0.0017).state=="UNCHANGED")
assert(confirmed:observe("A",250.1,300.1,0.0034).state=="SUB_QUANTUM_SHADOW")
assert(confirmed:observe("A",250.1,300.1,0.0043).state=="QUANTUM_READY_SHADOW")
assert(confirmed.stats.vertexCrossings==1)
assert(confirmed:observe("A",250.1,300.1,0.0054).state=="QUANTUM_READY_SHADOW")
assert(confirmed.stats.vertexCrossings==1)
assert(confirmed:observe("missing",1,2,0/0)==nil)
assert(confirmed:observe("missing",1,2,math.huge)==nil)
assert(confirmed:observe("missing",1,2,-0.01)==nil)
assert(confirmed.stats.rejected==3)

-- 20cm sample cells on a 1m native vertex are not 25 independently
-- stackable vertical excavations. A passing 2mm rut across 25 cells
-- remains 2mm high-level demand, not a catastrophic 50mm command.
local overlapping=assert(P.new({unitM=1,maxSources=100,
    verifiedQuantumM=q}))
for ix=1,5 do
    for iz=1,5 do
        local name=string.format("cell-%d-%d",ix,iz)
        local x=10+(ix-3)*0.12
        local z=20+(iz-3)*0.12
        local out=assert(overlapping:observe(name,x,z,0.002))
        assert(out.vertexKey=="10:20")
        assert(out.state=="SUB_QUANTUM_SHADOW")
    end
end
assert(math.abs(overlapping:getVertex(10,20).demandM-0.002)<1e-8)
assert(overlapping:getVertex(10,20).sourceCount==25)
assert(math.abs(overlapping.stats.accumulatedM-0.05)<1e-8)
assert(overlapping:summary():find("vertexDemandSumM=0.002000",1,true))
assert(overlapping:summary():find("multiSourceVertices=1",1,true))
assert(overlapping:observe("cell-3-3",10,20,0.004).state
    =="QUANTUM_READY_SHADOW")
assert(math.abs(overlapping:getVertex(10,20).demandM-0.004)<1e-8)
assert(overlapping.stats.vertexCrossings==1)
-- Returning to a loaded save must not manufacture native demand equal to
-- the persisted RE rut depth. Only *new* target increase counts.
local restored=assert(P.new({unitM=1,verifiedQuantumM=q}))
local h=assert(restored:observe("old-cell",42.1,90.1,0.024,0.024))
assert(h.state=="UNCHANGED")
assert(restored.stats.accumulatedM==0)
h=assert(restored:observe("old-cell",42.1,90.1,0.027,0.024))
assert(h.state=="SUB_QUANTUM_SHADOW")
assert(math.abs(h.addedM-0.003)<1e-8)
assert(restored:observe("bad",40,40,0.01,0/0)==nil)

-- The shadow's depth bucket and coarse-cell geometry are independent.
-- Even one full verified quantum plus a narrow tyre is FINE ONLY, never
-- permission to cut a complete main-heightmap vertex.
local geom=assert(P.new({unitM=1,verifiedQuantumM=q,maxSources=12}))
local narrow=assert(geom:observe("narrow",10,20,q*2,0,nil,{
    available=true,supportWidthM=0.35,footprintLengthM=1.2,
    dirX=1,dirZ=0,pathContinuity=true
}))
assert(narrow.state=="QUANTUM_READY_SHADOW")
assert(narrow.mainGeometryState=="FINE_ONLY_OR_UNREPRESENTABLE")
assert(narrow.authorizesMainWrite==false)
assert(geom:getVertex(10,20).demandM>=q*2)
local wide=assert(geom:observe("wide",11,20,q*2,0,nil,{
    available=true,supportWidthM=1.1,footprintLengthM=1.1,
    dirX=1,dirZ=0,pathContinuity=true
}))
assert(wide.mainGeometryState=="MAIN_RESEARCH_CANDIDATE")
assert(wide.authorizesMainWrite==false)
local noDir=assert(geom:observe("spin",12,20,q*2,0,nil,{
    available=true,supportWidthM=1.1,footprintLengthM=1.1,
    dirX=0,dirZ=0,pathContinuity=false
}))
assert(noDir.mainGeometryState=="GEOMETRY_UNKNOWN")
assert(geom.stats.mainFineOnly==1)
assert(geom.stats.mainResearchCandidates==1)
assert(geom.stats.mainGeometryUnknown==1)
assert(geom:summary():find("mainFootprintSamples=3",1,true))
assert(geom:summary():find("mainFineOnly=1",1,true))
-- Multiple source cells may share a vertex; one narrow source is not
-- promoted by adding its requested depth to a neighboring narrow source.
local narrow2=assert(geom:observe("narrow2",10.2,20,q*3,0,nil,{
    available=true,supportWidthM=0.35,footprintLengthM=1.2,
    dirX=1,dirZ=0,pathContinuity=true
}))
assert(narrow2.mainGeometryState=="FINE_ONLY_OR_UNREPRESENTABLE")
assert(geom:getVertex(10,20).demandM==q*3)
assert(geom:getVertex(10,20).sourceCount==2)
assert(geom.stats.mainFineOnly==2)
local incomplete=assert(geom:observe("notConnected",13,20,q*2,0,nil,{
    available=true,supportWidthM=1.1,footprintLengthM=1.1,
    dirX=1,dirZ=0,pathContinuity=false
}))
assert(incomplete.mainGeometryState=="GEOMETRY_UNKNOWN")
assert(incomplete.mainGeometryReason=="NO_BOUNDED_MEASURED_PATH")
assert(incomplete.authorizesMainWrite==false)


-- 07-Nov-2026 Fiat 180-90 DT live regression (game v1.25.1,
-- Estancia Sao Carlos, RE 93339e2b, 3 sources/1 MAIN vertex/5
-- growth observations). The actual log reports 19.836 mm across
-- logical sources but ONLY 6.708 mm at the single shared vertex,
-- and a maximum MAIN cell support of 6.6%. Never let 3 wheel
-- sources turn into 19.836 mm of geometrical excavation.
local fiat=assert(P.new({unitM=1,verifiedQuantumM=q,maxSources=8}))
local fiatFootprint={
    available=true,supportWidthM=0.30,footprintLengthM=0.22,
    dirX=1,dirZ=0,pathContinuity=true
}
local fiatOne=assert(fiat:observe("fiat-A",344.02,387.02,
    0.003000,0,nil,fiatFootprint))
assert(fiatOne.mainGeometryState=="FINE_ONLY_OR_UNREPRESENTABLE")
assert(fiatOne.authorizesMainWrite==false)
assert(fiat:observe("fiat-A",344.02,387.02,
    0.006708,0,nil,fiatFootprint).addedM>0)
assert(fiat:observe("fiat-B",344.12,387.02,
    0.006708,0,nil,fiatFootprint).addedM>0)
assert(fiat:observe("fiat-C",344.02,387.12,
    0.003000,0,nil,fiatFootprint).addedM>0)
assert(fiat:observe("fiat-C",344.02,387.12,
    0.006420,0,nil,fiatFootprint).addedM>0)
local v=assert(fiat:getVertex(344,387))
assert(v.sourceCount==3)
assert(math.abs(v.demandM-0.006708)<1e-9)
assert(math.abs(fiat.stats.accumulatedM-0.019836)<1e-9)
assert(fiat.stats.mainFootprintSamples==5)
assert(fiat.stats.mainFineOnly==5 and fiat.stats.mainResearchCandidates==0)
assert(math.abs(fiat.stats.maxMainCellCoverage01-0.066)<1e-9)
assert(fiat:summary():find("vertexDemandSumM=0.006708",1,true))
assert(fiat:summary():find("mainFineOnly=5",1,true))
for _=1,100 do
    local unchanged=assert(fiat:observe("fiat-A",344.02,387.02,
        0.006708,0,nil,fiatFootprint))
    assert(unchanged.state=="UNCHANGED" and unchanged.addedM==0)
end
assert(math.abs(v.demandM-0.006708)<1e-9)
assert(math.abs(fiat.stats.accumulatedM-0.019836)<1e-9)
assert(v.lastMainGeometryScreen.authorizesMainWrite==false)

-- Area projection: 25 unique 20cm cells at 20mm must remain 20mm
-- across a full 1m support, not 500mm. No gate from narrow tracks.
local spatial=assert(P.new({unitM=1,logicalCellSizeM=0.2}))
local broad={available=true,supportWidthM=2,footprintLengthM=2,
    dirX=1,dirZ=0,pathContinuity=true}
local thin={available=true,supportWidthM=0.35,footprintLengthM=1.2,
    dirX=1,dirZ=0,pathContinuity=true}
for i=-2,2 do
    for k=-2,2 do
        assert(spatial:observe(i..":"..k,i*0.2,k*0.2,0.02,0,nil,broad))
    end
end
local p=assert(spatial:projectMain(0,0))
assert(p.cellCount==25 and math.abs(p.modeledCoverage01-1)<1e-8)
assert(math.abs(p.projectedNewDepthM-0.02)<1e-8)
assert(math.abs(p.researchTargetM-0.02)<1e-8 and not p.authorizesMainWrite)
-- Aliases of a logical cell must not add area or amplify depth.
assert(spatial:observe("alias",0.02,0.02,0.01,0,nil,broad))
p=assert(spatial:projectMain(0,0))
assert(p.cellCount==25 and math.abs(p.projectedNewDepthM-0.02)<1e-8)
-- A single thin track is not a broad MAIN candidate regardless of depth.
local strip=assert(P.new({unitM=1,logicalCellSizeM=0.2}))
for i=-2,2 do assert(strip:observe("strip"..i,i*0.2,0,0.08,0,nil,thin)) end
p=assert(strip:projectMain(0,0))
assert(math.abs(p.modeledCoverage01-0.2)<1e-8)
assert(math.abs(p.projectedNewDepthM-0.016)<1e-8)
assert(p.researchTargetM==nil and p.broadModeledCoverage01==0)
-- Wide new observation qualifies only incremental growth.
assert(strip:observe("strip0",0,0,0.09,0,nil,broad))
p=assert(strip:projectMain(0,0))
assert(math.abs(p.broadProjectedDepthM-0.0004)<1e-8)
assert(strip:onHistoryRecovered("strip0",0.08,0.01))
assert(strip:projectMain(0,0).broadProjectedDepthM<1e-8)
-- Nonaligned 0.2m cells can straddle MAIN boundaries. A centered cell
-- at x=.5 uses half its area on either side, without depth creation.
local seam=assert(P.new({unitM=1,logicalCellSizeM=0.2}))
-- Logical center .6 spans [.5,.7]; choose 0.25m grid for exact seam.
seam=assert(P.new({unitM=1,logicalCellSizeM=0.25}))
assert(seam:observe("seam",0.5,0,0.04,0,nil,broad))
local left,right=seam:projectMain(0,0),seam:projectMain(1,0)
assert(math.abs(left.projectedNewDepthM-0.00125)<1e-8)
assert(math.abs(right.projectedNewDepthM-0.00125)<1e-8)
-- Actual worked polygon clears virtual cell and projected support too.
assert(seam:onWorkedArea({xs=-1,zs=-1,ux=3,uz=0,vx=0,vz=2})==1)
assert(seam:projectMain(0,0).cellCount==0 and seam:projectMain(1,0).cellCount==0)
assert(seam:projectMain(0/0,0)==nil)
print("terrain_absolute_height_planner_harness: OK")
