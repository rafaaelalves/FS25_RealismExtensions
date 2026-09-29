# Terrain deformation research

Status: research, no active gameplay implementation.

## Problem

The RC0200 target stack can produce convincing physical loss of traction, sink and stuck behavior through MR + Mud, but FarmKit's custom geometric rut deformation is suppressed because its public Ground Physics toggle couples ruts to a competing sink/ground core.

Observed runtime symptom:
- wheels visibly spin and sink;
- vehicle/trailer can become stuck;
- no corresponding custom rut/deformation is produced by FarmKit.

## Goal

Create terrain deformation as a **consequence** of authoritative physics.

## Inputs to validate

- grounded/contact position;
- longitudinal slip;
- lateral slip/scrub;
- effective wheel load or a defensible proxy;
- tire width / contact footprint;
- local Mud wetness;
- Mud sink depth;
- ground/surface type;
- freeze/thaw state;
- vehicle/implement/AI control state.

## Outputs

Only terrain/visual state owned by this module:
- rut depth;
- rut width;
- longitudinal excavation/shear;
- lateral scrub;
- optional track visual metadata.

It must not write MR/Mud friction, motor load, brake force, sink radius or speed caps.

## Desired behavior

- low slip on firm/dry soil: shallow/mostly cosmetic tracks;
- high slip + wet/soft soil: deeper excavation;
- repeated passes: diminishing accumulation with a hard physical/visual bound;
- wider footprint: wider and generally less-deep rut for equal load;
- narrow/heavily loaded tire: greater pressure effect;
- lateral slip: sideways scrub rather than identical longitudinal rut;
- frozen soil: strongly reduced deformation;
- thawed/wet soil: increased susceptibility;
- AI/Courseplay/player: same model, no duplicate AI-only physics.

## True AI Tracks

Treat True AI Tracks as a functional-overlap candidate. Before replacement:
- audit exact 2.2.0.1 implementation;
- determine which GIANTS deformation calls it restores;
- identify AI/implement coverage;
- measure update cadence and persistence;
- reproduce equivalent or better behavior through this common engine.

## Performance budget

Research must establish:
- maximum brush/deformation operations per frame;
- temporal throttling per wheel;
- minimum movement/slip thresholds;
- spatial deduplication/merge behavior;
- maximum active tracked wheels;
- cleanup/persistence semantics.

No prototype graduates to default-on until a long-session profile shows bounded cost.


## WheelContext v1 — resolved input semantics

The first normalized provider contract is now defined around source/runtime evidence rather than inferred convenience fields.

### Resolved

- `grounded` / `soilContact`
  - wheel contact state from the active WheelPhysics object.

- `worldX/worldY/worldZ`
  - Mud contact resolver when available;
  - WheelPhysics contact coordinates as a fallback.

- `longitudinalSlip` / `lateralSlip`
  - direct GIANTS `getWheelShapeSlip` result when callable;
  - MR cached `mrLastLongSlip/mrLastLatSlip` fallback.
  - These are raw physics slip components. TerrainDeformation must decide later whether/how to normalize direction/sign and threshold them for excavation vs scrub.

- `physicalGroundWetness`
  - Mud `FieldLocalWetness:getEffectiveWetnessAt` when active;
  - hard winter freeze forces physical wetness to zero;
  - GIANTS global weather wetness only as a degraded fallback.
  - This field is deliberately distinct from MoistureSystem agronomic/material moisture.

- `structuralRadiusM`
  - RC MRMud/MRTireWear structural-radius hierarchy;
  - permanent Reifen tread wear is structural;
  - Mud sink and tire-pressure deflection are temporary and excluded.

- `tireWidthM`
  - MR total width when available, otherwise wheel physics/base width.

- `trackFootprintFactor`
  - MR track factor where available.
  - This is not yet a physical contact-area model.

- `wheelLoadN`
  - Mud WheelLoadSystem first: measured contact load with smoothing/cache and deterministic mass/axle fallback;
  - MR `mrLastTireLoad` (documented kN) fallback.
  - Units are normalized to newtons.

- `wheelLoadMeasured`
  - distinguishes measured contact load from fallback-estimated load.

- `sinkDepthM`
  - active Mud per-wheel temporary radius-loss state:
    `max(__fgMudCurExtra, __mpMudCurExtra)`.
  - unavailable rather than zero when Mud is not the active sink owner.

- `sinkSeverity`
  - `sinkDepthM / structuralRadiusM`, clamped 0..1.
  - This is a normalized presentation/consequence input, not Mud's own vehicle-level `st.sink`.

- `groundDensityType`, `groundProfileName`, `groundMudPotential`
  - Mud FieldGroundMudPhysics profile identity/state.

- `hardFrozen`
  - Mud hard-winter-freeze state.

### Intentionally unresolved

#### Ground pressure / contact area

Do not freeze a `groundPressure` field yet.

MR currently estimates pressure from roughly:
```text
contactPatch = width * radius * 0.53
pressure ~= load / contactPatch
```

That is useful evidence but not automatically the model RE should inherit.

TerrainDeformation needs a defensible footprint/contact-area model that can distinguish:
- radial tires;
- narrow/high-pressure tires;
- dual/triple configurations;
- crawlers/tracks;
- tire-pressure changes;
- sink-dependent contact patch.

This is the first real physics-model choice that belongs to RE rather than simply exposing an existing owner state.

#### Deformation susceptibility

Do not expose one generic `soilSoftness` scalar yet.

Mud profiles contain useful coefficients (`mud`, `sinkMul`, `radiusMinFactor`, etc.), but they were calibrated for Mud's sink/resistance model.

TerrainDeformation should derive its own deformation susceptibility from authoritative ground identity + wetness + freeze + repeated-state behavior instead of reusing a sink coefficient blindly.

#### Control context

Player/GIANTS AI/Courseplay/AutoDrive identity should be used primarily for scheduling/ownership and diagnostics, not as a physical multiplier by default.

The same wheel state should produce the same deformation regardless of who controls the vehicle unless evidence justifies a difference.

## First prototype boundary

The first gameplay prototype should therefore consume:

```text
contact position
raw longitudinal/lateral slip
physicalGroundWetness
structuralRadiusM
tireWidthM / trackFootprintFactor
wheelLoadN + measured/fallback provenance
sinkDepthM
ground profile identity
hardFrozen
speedKph
```

and write only TerrainDeformation-owned geometry/state.

The next research task is the RE-owned **contact footprint / ground-pressure model**, followed by a deformation-response function and brush/runtime budget.
