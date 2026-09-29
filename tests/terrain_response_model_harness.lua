dofile("scripts/terrain/TerrainResponseModel.lua")

local Model = RealismExtensionsTerrainResponseModel

local function clone(t)
    local r = {}
    for k, v in pairs(t) do r[k] = v end
    return r
end

local footprint = {
    available = true,
    supportWidthM = 0.6,
    structuralRadiusM = 0.8,
    groundPressurePa = 110000
}

local base = {
    grounded = true,
    structuralRadiusM = 0.8,
    supportWidthM = 0.6,
    speedKph = 10,
    wheelSurfaceSpeedMps = 3.2,
    longitudinalSlip = 0.08,
    lateralSlip = 0.02,
    physicalGroundWetness = 0.35,
    groundMudPotential = 0.55,
    hardFrozen = false,
    sinkDepthM = 0.02,
    sinkSeverity = 0.025
}

local a = Model.compute(base, footprint, nil, 100)
assert(a.available == true)
assert(a.rutDepthM >= base.sinkDepthM)
assert(a.rutCapacityM >= a.rutDepthM)
assert(a.rutWidthM >= footprint.supportWidthM)
assert(a.longitudinalShearIncrementM > 0)

-- Wet soil must be more susceptible and permit a deeper rut capacity.
local wet = clone(base)
wet.physicalGroundWetness = 0.9
local b = Model.compute(wet, footprint, nil, 100)
assert(b.soilSusceptibility01 > a.soilSusceptibility01)
assert(b.rutCapacityM > a.rutCapacityM)
assert(b.rutDepthM > a.rutDepthM)

-- Higher pressure should increase vertical drive/capacity.
local highPressure = clone(footprint)
highPressure.groundPressurePa = 220000
local c = Model.compute(base, highPressure, nil, 100)
assert(c.pressureDrive > a.pressureDrive)
assert(c.rutCapacityM >= a.rutCapacityM)

-- Longitudinal slip should primarily increase excavation.
local highSlip = clone(base)
highSlip.longitudinalSlip = 0.65
local d = Model.compute(highSlip, footprint, nil, 200)
assert(d.longitudinalExcavation01 > a.longitudinalExcavation01)
assert(d.longitudinalShearDistanceM > a.longitudinalShearDistanceM)

-- Lateral slip should increase scrub and widen the rut.
local lateral = clone(base)
lateral.lateralSlip = 0.55
local e = Model.compute(lateral, footprint, nil, 200)
assert(e.lateralScrub01 > a.lateralScrub01)
assert(e.rutWidthM > a.rutWidthM)

-- A spinning wheel must accumulate shear even with almost no vehicle speed.
local stuck = clone(base)
stuck.speedKph = 0
stuck.wheelSurfaceSpeedMps = 5
stuck.longitudinalSlip = 0.8
local f = Model.compute(stuck, footprint, nil, 200)
assert(f.longitudinalShearIncrementM > 0)
assert(f.longitudinalExcavation01 > 0)

-- A sliding/locked wheel still gets shear from vehicle motion.
local sliding = clone(base)
sliding.speedKph = 18
sliding.wheelSurfaceSpeedMps = 0
sliding.longitudinalSlip = 0.7
local g = Model.compute(sliding, footprint, nil, 200)
assert(g.longitudinalShearIncrementM > 0)

-- Repeated identical passes must show diminishing depth increments and remain bounded.
local history = nil
local increments = {}
local last = nil
for i = 1, 8 do
    local r = Model.compute(wet, footprint, history, 100)
    increments[#increments + 1] = r.rutDepthDeltaM
    history = r.nextHistory
    last = r
end
assert(increments[2] <= increments[1] + 0.0000001)
assert(increments[8] < increments[1])
assert(last.rutDepthM <= last.rutCapacityM + 0.0000001)

-- Observed Mud sink is an immediate lower bound.
local sunk = clone(base)
sunk.sinkDepthM = 0.12
sunk.sinkSeverity = 0.15
local h = Model.compute(sunk, footprint, nil, 16)
assert(h.rutDepthM >= 0.12)

-- Authoritative sink can exceed RE's provisional modeled capacity cap.
local deepSink = clone(base)
deepSink.sinkDepthM = 0.40
deepSink.sinkSeverity = 0.50
local h2 = Model.compute(deepSink, footprint, nil, 16)
assert(h2.rutCapacityM >= 0.40)
assert(h2.rutDepthM >= 0.40)

-- Hard freeze should almost eliminate deformation response.
local frozen = clone(wet)
frozen.hardFrozen = true
frozen.sinkDepthM = 0
frozen.sinkSeverity = 0
local i = Model.compute(frozen, footprint, nil, 100)
assert(i.soilSusceptibility01 < 0.05)
assert(i.rutCapacityM < b.rutCapacityM)
assert(i.rutDepthM < b.rutDepthM)

-- Slip below deadband should not accumulate shear.
local tinySlip = clone(base)
tinySlip.longitudinalSlip = 0.01
tinySlip.lateralSlip = 0.01
tinySlip.sinkDepthM = 0
tinySlip.sinkSeverity = 0
local j = Model.compute(tinySlip, footprint, nil, 100)
assert(j.longitudinalShearIncrementM == 0)
assert(j.lateralShearIncrementM == 0)

print("terrain_response_model_harness: OK")
