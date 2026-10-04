dofile("scripts/terrain/FootprintModel.lua")
dofile("scripts/terrain/TerrainResponseModel.lua")

local F=RealismExtensionsFootprintModel
local R=RealismExtensionsTerrainResponseModel

local function baseContext()
    return {
        grounded=true,
        structuralRadiusM=0.80,
        baseTireWidthM=0.60,
        supportWidthM=0.60,
        supportContactWidthM=0.60,
        supportSpanM=0.60,
        supportGapWidthM=0,
        supportKind="ROUND_WHEEL",
        supportSegments={{offsetM=0,widthM=0.60,radiusM=0.80}},
        wheelLoadN=24000,
        wheelLoadMeasured=true,
        tirePressureBar=1.0,
        physicalGroundWetness=0.75,
        groundMudPotential=0.75,
        hardFrozen=false,
        speedKph=8,
        wheelSurfaceSpeedMps=2.3,
        longitudinalSlip=0.08,
        lateralSlip=0.02,
        sinkDepthM=0.03
    }
end

local single=baseContext()
local sf=F.compute(single)
assert(sf.available and #sf.contactPatches==1)
local sr=R.compute(single,sf.contactPatches[1],nil,250)
assert(sr.available)

local dual=baseContext()
dual.supportWidthM=1.20
dual.supportContactWidthM=1.20
dual.supportSpanM=1.34
dual.supportGapWidthM=0.14
dual.supportSegments={
    {offsetM=-0.37,widthM=0.60,radiusM=0.80},
    {offsetM= 0.37,widthM=0.60,radiusM=0.80}
}
local df=F.compute(dual)
assert(df.available and #df.contactPatches==2)
assert(math.abs(df.groundPressurePa-sf.groundPressurePa)<0.000001)
for _,patch in ipairs(df.contactPatches) do
    local dr=R.compute(dual,patch,nil,250)
    assert(dr.available)
    -- Same inflation pressure means the average normal stress stays the same;
    -- topology changes where it is applied rather than inventing a "dual
    -- bonus" in TerrainResponse.
    assert(math.abs(dr.pressureDrive-sr.pressureDrive)<0.000001)
    -- Each tyre is the same 0.60 m width as the single reference tyre, so its
    -- own rut width stays the same. The dual advantage here is load sharing /
    -- shorter contact length and two separated lanes, not a fake width bonus.
    assert(math.abs(dr.rutWidthM-sr.rutWidthM)<0.000001)
end

local crawler=baseContext()
crawler.supportKind="CRAWLER"
crawler.isCrawler=true
crawler.tirePressureBar=nil
crawler.supportWidthM=0.70
crawler.supportContactWidthM=0.70
crawler.supportSpanM=0.70
crawler.supportSegments={{offsetM=0,widthM=0.70,radiusM=0.80}}
crawler.trackFootprintFactor=3
local cf=F.compute(crawler)
assert(cf.available and cf.kind=="CRAWLER")
assert(cf.groundPressurePa<sf.groundPressurePa)
assert(#cf.contactPatches>=2)
local exposureShare=0
for _,patch in ipairs(cf.contactPatches) do
    exposureShare=exposureShare+(patch.exposureShare or 0)
    local cr=R.compute(
        crawler,
        patch,
        nil,
        250*(patch.exposureShare or 1)
    )
    assert(cr.available)
    assert(cr.pressureDrive<sr.pressureDrive)
end
assert(math.abs(exposureShare-1)<0.000001)

print("wheel_support_response_harness: OK")
