# Terrain response model

Updated: 2026-09-29

Status: pure response model; no GIANTS terrain writes yet.

## Purpose

Convert normalized wheel/ground state plus the RE footprint model into bounded terrain-deformation intent.

This layer owns consequences, not traction or sink physics.

Inputs include footprint pressure/geometry, structural radius, support width, physical wetness, observed sink, longitudinal/lateral slip, vehicle speed, wheel-surface speed, freeze state, ground-state hints and history.

Outputs include vertical imprint, longitudinal excavation, lateral scrub, rut capacity, target rut depth/delta, rut width and next history.

## Design rules

### Observed sink is an anchor

When Mud reports `sinkDepthM`, TerrainResponse must never produce geometry shallower than that observed physical state. RE may add geometric excavation from slip/repeated passes but does not rewrite Mud sink.

### Pressure changes capacity sub-linearly

The first model uses `pressureDrive = (groundPressure / referencePressure)^0.55`, bounded to a safe range.

This is intentionally not presented as a calibrated Bekker pressure-sinkage law. We do not yet have map/soil-specific `kc`, `kphi` and `n` parameters.

### Wetness controls susceptibility

Physical wetness from Mud controls how readily geometry can deform. Dry soil retains a small non-zero floor so heavy equipment can still leave shallow tracks. Hard freeze nearly suppresses deformation.

`groundMudPotential` is used only as a weak terrain-state hint. Mud `sinkMul`, `radiusMinFactor` and related tuning remain Mud parameters and are not copied into RE as deformation coefficients.

### Longitudinal and lateral slip are different phenomena

- longitudinal slip -> excavation / digging
- lateral slip -> scrub / width growth

They have separate deadbands and displacement-saturation scales.

### Shear displacement, not raw slip alone

The model accumulates approximate relative-contact displacement as `max(vehicleSpeed, wheelSurfaceSpeed) * dt * effectiveSlip`.

This preserves two important cases: a spinning wheel can dig while the vehicle is nearly stopped, and a locked/sliding wheel can deform while wheel-surface speed is near zero.

The RC provider therefore exposes `wheelSurfaceSpeedMps` from MR cached wheel speed or GIANTS axle-speed fallback.

### Janosi-Hanamoto-inspired saturation

Shear response uses the qualitative form `response = 1 - exp(-j / K)`.

This gives strong early response and diminishing gains as displacement accumulates. Current K values are RE calibration constants, not claimed soil measurements.

### Repeated passes approach a capacity

The model does not add fixed depth each pass. It computes `remaining = capacity - currentDepth` and applies only a fraction of that remaining depth. Repeated passes therefore show diminishing increments and remain bounded.

Spatial persistence/merging is not implemented yet; history is passed into the pure model explicitly so the later terrain engine can choose the correct spatial data structure.

## Current provisional defaults

These are tuning parameters, not measured universal soil constants:

- reference pressure: 100 kPa;
- max rut capacity: 36% of structural tire radius;
- hard-freeze multiplier: 0.02;
- longitudinal shear saturation length: 0.18 m;
- lateral shear saturation length: 0.14 m;
- longitudinal slip deadband: 0.025;
- lateral slip deadband: 0.020.

They are centralized in `TerrainResponseModel.DEFAULTS`.

## Harness relationships

The pure Lua harness asserts:

- wetter ground -> higher susceptibility and deeper capacity;
- higher ground pressure -> higher pressure drive;
- longitudinal slip -> more excavation;
- lateral slip -> more scrub and wider rut;
- spinning wheel can excavate at near-zero vehicle speed;
- sliding/locked wheel can deform with near-zero wheel surface speed;
- repeated passes have diminishing depth increments;
- rut remains bounded by capacity;
- observed Mud sink is never contradicted;
- hard freeze strongly suppresses response;
- slip below deadband does not accumulate shear.

## Physical basis

The architecture is informed by established terramechanics concepts: Bekker-style pressure/sinkage separates vertical support from shear behavior, while Janosi-Hanamoto shear response uses a saturating displacement law rather than unlimited linear slip response.

We are not yet claiming calibrated implementations of either law because map-specific soil parameters are unavailable.

## Next step

The next layer is the TerrainDeformation engine that will collect wheel contexts without global per-frame vehicle scans, compute footprint + response, maintain spatial history, throttle/merge brush operations, call GIANTS TerrainDeformation APIs, and use one player/AI/implement pipeline.

True AI Tracks should be disabled/replaced only after runtime parity is proven.