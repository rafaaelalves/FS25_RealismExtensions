-- Research characterization of the ACTUAL 16-point annular reference
-- estimator used by TerrainWriter. No GIANTS runtime and no physics changes.
-- EXPECTED-BIAS scenarios are observations, not accepted quality thresholds.
dofile("scripts/terrain/RecoverySurfaceEstimator.lua")
local E = RealismExtensionsRecoverySurfaceEstimator

local RING_RADIUS_M = 1.25
local RING_COUNT = 16

local function plane(x, z)
    return 10 + 0.02 * x - 0.015 * z
end
local function gaussian(x, center, sigma)
    local d = (x - center) / sigma
    return math.exp(-0.5 * d * d)
end
local function pointGaussian(x, z, sigma)
    return math.exp(-0.5 * (x * x + z * z) / (sigma * sigma))
end
local function ringSamples(surface)
    local out = {
        { dx=0, dz=0, y=surface(0, 0), center=true, boundary=false }
    }
    for i=0,RING_COUNT-1 do
        local a = (math.pi * 2 * i) / RING_COUNT
        local x = RING_RADIUS_M * math.cos(a)
        local z = RING_RADIUS_M * math.sin(a)
        out[#out+1] = {
            dx=x, dz=z, y=surface(x,z), boundary=true
        }
    end
    return out
end
local function measure(label, surface, trueDeficitM)
    local observed, reason = E.measure(ringSamples(surface))
    assert(observed ~= nil, label .. ": " .. tostring(reason))
    local estimated = observed.centerDeficitM
    assert(estimated == estimated and estimated >= 0)
    local err = estimated - (trueDeficitM or 0)
    print(string.format(
        "reference_stress | %-32s trueRut=%.4fm detected=%.4fm bias=%+.4fm inliers=%.2f boundaryMAD=%.4fm",
        label, trueDeficitM or 0, estimated, err,
        observed.boundaryInlierRatio,
        observed.boundaryMadM
    ))
    return observed
end

-- Passing controls: the current estimator correctly removes a linear grade
-- and measures a narrow, isolated rut. These are prior baseline guarantees.
local level = measure("linear-grade-control", plane, 0)
assert(level.centerDeficitM < 0.000001)
local isolated = measure("isolated-12cm-rut", function(x,z)
    return plane(x,z) - 0.12 * pointGaussian(x,z,0.20)
end, 0.12)
assert(math.abs(isolated.centerDeficitM - 0.12) < 0.0001)

-- Characterize real unresolved classes from recent recovery logs:
-- long parallel tire lanes, a wide rut covering the reference ring, and
-- natural curvature. No runtime trace identifies which one caused 0.89m
-- estimated residual; this harness only demonstrates susceptibility.
local longRut = measure("longitudinal-single-lane", function(x,z)
    return plane(x,z) - 0.12 * gaussian(x,0,0.28)
end, 0.12)
local dual = measure("parallel-lanes-12cm", function(x,z)
    return plane(x,z) - 0.12 * math.max(
        gaussian(x,0,0.28), gaussian(x,1.05,0.28)
    )
end, 0.12)
local wide = measure("broad-round-rut-12cm", function(x,z)
    return plane(x,z) - 0.12 * pointGaussian(x,z,0.90)
end, 0.12)
local natural = measure("natural-curvature-12cm", function(x,z)
    return plane(x,z) + 0.12 * (x*x + z*z) / (RING_RADIUS_M^2)
end, 0)
local extreme = measure("synthetic-curvature-85cm", function(x,z)
    return plane(x,z) + 0.85 * (x*x + z*z) / (RING_RADIUS_M^2)
end, 0)

-- Not physics acceptance criteria. These assertions LOCK DOWN CURRENT
-- LIMITATIONS as reproducible failures to fix in a future R1 estimator PR.
-- When a corrected estimator is introduced, REPLACE with accuracy guards.
assert(longRut.centerDeficitM > 0.10)
assert(dual.centerDeficitM > 0.04 and dual.centerDeficitM < 0.09)
assert(wide.centerDeficitM > 0.05 and wide.centerDeficitM < 0.10)
assert(natural.centerDeficitM > 0.10)
assert(extreme.centerDeficitM > 0.80)
assert(natural.boundaryInlierRatio > 0.99)
assert(extreme.boundaryInlierRatio > 0.99)
print("recovery_reference_stress_harness: CHARACTERIZATION ONLY OK")
