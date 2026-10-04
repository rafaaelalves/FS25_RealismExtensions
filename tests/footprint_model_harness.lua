dofile("scripts/terrain/FootprintModel.lua")

local Model = RealismExtensionsFootprintModel

local radial = {
    grounded = true,
    isCrawler = false,
    structuralRadiusM = 0.8,
    baseTireWidthM = 0.6,
    supportWidthM = 0.6,
    wheelLoadN = 24000,
    wheelLoadMeasured = true,
    tirePressureBar = 1.0,
    sinkDepthM = 0.04,
    physicalGroundWetness = 0.7
}

local a = Model.compute(radial)
assert(a.available == true)
assert(a.model == "PRESSURE_DRIVEN")
assert(a.confidence == "HIGH")
assert(math.abs(a.targetGroundPressurePa - 110000) < 0.001)
assert(math.abs(a.contactAreaM2 - (24000 / 110000)) < 0.000001)
assert(math.abs(a.footprintLengthM - ((24000 / 110000) / 0.6)) < 0.000001)
assert(a.geometryLimited == false)

local lowPressure = {}
for k, v in pairs(radial) do lowPressure[k] = v end
lowPressure.tirePressureBar = 0.8
local b = Model.compute(lowPressure)
assert(b.available == true)
assert(b.contactAreaM2 > a.contactAreaM2)
assert(b.groundPressurePa < a.groundPressurePa)

local dual = {}
for k, v in pairs(radial) do dual[k] = v end
dual.supportWidthM = 1.2
dual.supportContactWidthM = 1.2
dual.supportSpanM = 1.34
dual.supportGapWidthM = 0.14
dual.supportSegments = {
    {offsetM=-0.37,widthM=0.60,radiusM=0.8},
    {offsetM=0.37,widthM=0.60,radiusM=0.8}
}
local c = Model.compute(dual)
assert(c.available == true)
-- With pressure-driven support, the same load/pressure needs the same total
-- area; extra width shortens the footprint instead of inventing extra area.
assert(math.abs(c.contactAreaM2 - a.contactAreaM2) < 0.000001)
assert(c.footprintLengthM < a.footprintLengthM)
assert(c.supportSegmentCount == 2)
assert(#c.contactPatches == 2)
assert(math.abs(c.supportGapWidthM-0.14)<0.000001)
assert(math.abs(c.contactPatches[1].offsetM+0.37)<0.000001)
assert(math.abs(c.contactPatches[2].offsetM-0.37)<0.000001)
assert(math.abs(
    c.contactPatches[1].contactAreaM2
    + c.contactPatches[2].contactAreaM2
    - c.contactAreaM2
)<0.000001)
assert(math.abs(
    c.contactPatches[1].wheelLoadN
    + c.contactPatches[2].wheelLoadN
    - dual.wheelLoadN
)<0.000001)

local fallback = {}
for k, v in pairs(radial) do fallback[k] = v end
fallback.tirePressureBar = nil
local d = Model.compute(fallback)
assert(d.available == true)
assert(d.model == "GEOMETRY_FALLBACK")
assert(d.confidence == "LOW")
assert(math.abs(d.contactAreaM2 - (0.6 * 0.8 * 0.53)) < 0.000001)

local estimatedLoad = {}
for k, v in pairs(radial) do estimatedLoad[k] = v end
estimatedLoad.wheelLoadMeasured = false
local e = Model.compute(estimatedLoad)
assert(e.available == true)
assert(e.confidence == "MEDIUM")

local crawler = {}
for k, v in pairs(radial) do crawler[k] = v end
crawler.isCrawler = true
crawler.supportKind = "CRAWLER"
crawler.tirePressureBar = nil
crawler.trackFootprintFactor = 3
local f = Model.compute(crawler)
assert(f.available == true)
assert(f.kind == "CRAWLER")
assert(f.model == "MR_TRACK_GEOMETRY")
assert(f.inflationPressureBar == nil)
assert(math.abs(f.footprintLengthM-(0.8*3*0.53))<0.000001)
assert(math.abs(f.contactAreaM2-(0.6*0.8*3*0.53))<0.000001)
assert(math.abs(
    f.groundPressurePa-(24000/f.contactAreaM2)
)<0.000001)
assert(#f.contactPatches >= 2)
local trackArea,trackLoad,trackShare=0,0,0
for _,patch in ipairs(f.contactPatches) do
    trackArea=trackArea+patch.contactAreaM2
    trackLoad=trackLoad+patch.wheelLoadN
    trackShare=trackShare+patch.exposureShare
    assert(patch.continuousTrack==true)
    assert(math.abs(patch.groundPressurePa-f.groundPressurePa)<0.000001)
end
assert(math.abs(trackArea-f.contactAreaM2)<0.000001)
assert(math.abs(trackLoad-crawler.wheelLoadN)<0.000001)
assert(math.abs(trackShare-1)<0.000001)

local airborne = {}
for k, v in pairs(radial) do airborne[k] = v end
airborne.grounded = false
local g = Model.compute(airborne)
assert(g.available == false)

local hugeLoad = {}
for k, v in pairs(radial) do hugeLoad[k] = v end
hugeLoad.wheelLoadN = 500000
local h = Model.compute(hugeLoad)
assert(h.available == true)
assert(h.geometryLimited == true)
assert(h.footprintLengthM == 2 * hugeLoad.structuralRadiusM)
assert(h.groundPressurePa > h.targetGroundPressurePa)

print("footprint_model_harness: OK")
