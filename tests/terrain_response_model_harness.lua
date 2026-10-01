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
assert(a.observedSinkDepthM == base.sinkDepthM)
assert(a.persistentSinkDepthM <= a.observedSinkDepthM)
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

-- Sustained stationary wheelspin must keep increasing slip-induced capacity
-- after the fast shear term is already near saturation. It must still converge
-- to a finite radius-relative cap.
local stuckHistory = nil
local stuckFirst = nil
local stuckMid = nil
local stuckLast = nil
for n = 1, 80 do
    local r = Model.compute(stuck, footprint, stuckHistory, 100)
    if n == 1 then stuckFirst = r end
    if n == 20 then stuckMid = r end
    stuckLast = r
    stuckHistory = r.nextHistory
end
assert(stuckMid.slipRutCapacityM > stuckFirst.slipRutCapacityM)
assert(stuckLast.slipRutCapacityM >= stuckMid.slipRutCapacityM)
assert(stuckLast.rutCapacityM > stuckFirst.rutCapacityM)
assert(stuckLast.rutCapacityM <= stuck.structuralRadiusM * Model.DEFAULTS.maxSlipRutDepthFraction + 0.0000001)
assert(stuckLast.slipSinkage01 <= 1)

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


-- Equivalent physical travel must be approximately invariant to speed/update
-- subdivision. This specifically guards against the old low-speed bias where
-- repeated samples in the same terrain cell acted like extra passes.
local function simulateTravel(speedKph, stepMs, totalDistanceM, source)
    local ctx = clone(source)
    ctx.speedKph = speedKph
    local speedMps = speedKph / 3.6
    ctx.wheelSurfaceSpeedMps = speedMps * (1 + math.abs(ctx.longitudinalSlip or 0))
    ctx.sinkDepthM = 0
    ctx.sinkSeverity = 0

    local history = nil
    local travelled = 0
    local lastResult = nil
    while travelled < totalDistanceM - 0.0000001 do
        local nominalStepDistance = speedMps * (stepMs / 1000)
        local remaining = totalDistanceM - travelled
        local actualDistance = math.min(nominalStepDistance, remaining)
        local actualDt = actualDistance / speedMps * 1000
        lastResult = Model.compute(ctx, footprint, history, actualDt)
        history = lastResult.nextHistory
        travelled = travelled + actualDistance
    end
    return lastResult
end

local invariantSource = clone(wet)
invariantSource.longitudinalSlip = 0.10
invariantSource.lateralSlip = 0.01

local slowTravel = simulateTravel(2, 250, 2.0, invariantSource)
local fastTravel = simulateTravel(12, 250, 2.0, invariantSource)
local finelySubdivided = simulateTravel(12, 50, 2.0, invariantSource)

assert(math.abs(slowTravel.rutDepthM - fastTravel.rutDepthM) < 0.0005)
assert(math.abs(fastTravel.rutDepthM - finelySubdivided.rutDepthM) < 0.0005)
assert(math.abs(slowTravel.longitudinalShearDistanceM - fastTravel.longitudinalShearDistanceM) < 0.0005)

-- Instantaneous Mud sink is not automatically a permanent rut.
local sunk = clone(base)
sunk.physicalGroundWetness = 0.50
sunk.longitudinalSlip = 0.05
sunk.sinkDepthM = 0.12
sunk.sinkSeverity = 0.15
local h = Model.compute(sunk, footprint, nil, 16)
assert(h.observedSinkDepthM == 0.12)
assert(h.sinkPlasticTransfer01 < 0.10)
assert(h.persistentSinkDepthM < 0.012)
assert(h.rutDepthM < 0.12)

-- The same transient sink in very wet/plastic soil transfers much more strongly.
local deepWetSink = clone(base)
deepWetSink.physicalGroundWetness = 0.95
deepWetSink.longitudinalSlip = 0.75
deepWetSink.sinkDepthM = 0.12
local h2 = Model.compute(deepWetSink, footprint, nil, 16)
assert(h2.sinkPlasticTransfer01 > h.sinkPlasticTransfer01)
assert(h2.persistentSinkDepthM > h.persistentSinkDepthM)
assert(h2.persistentSinkDepthM <= h2.observedSinkDepthM)

-- Even an extreme instantaneous sink must not bypass the plastic transfer rule.
local extremeSink = clone(base)
extremeSink.physicalGroundWetness = 0.50
extremeSink.longitudinalSlip = 0
extremeSink.sinkDepthM = 0.40
local h3 = Model.compute(extremeSink, footprint, nil, 16)
assert(h3.persistentSinkDepthM < 0.04)
assert(h3.rutCapacityM < 0.40)
assert(h3.rutDepthM < 0.40)

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


-- Surface-specific absolute caps must bound RE-invented geometry.
local capped = Model.compute(stuck, footprint, nil, 100, {
    absoluteMaxStaticRutDepthM = 0.06,
    absoluteMaxSlipRutDepthM = 0.15
})
assert(capped.staticRutCapacityM <= 0.0600001)
assert(capped.slipRutCapacityM <= 0.1500001)
assert(capped.rutCapacityM <= 0.1500001)
