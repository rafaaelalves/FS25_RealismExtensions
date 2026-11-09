# Real Tire Wear assimilation opportunities

## Decision

Do not assimilate Real Tire Wear as a codebase.

Use it as one input to a clean-room RE capability:

`RunningGearWear`

The target should be **better than both Real Tire Wear and Reifenverschleiss**,
not a renamed clone of either.

## Why `RunningGearWear`, not `TireWear`

The capability boundary should represent physical service units:

```
RunningGearUnit
  kind:
    PNEUMATIC_TIRE
    SOLID_TIRE
    RUBBER_TRACK
    STEEL_TRACK
    ROLLER
    IDLER
    UNKNOWN

  identity:
    stableUnitId
    vehicle
    axle/group
    side
    member contacts

  state:
    wear01
    structuralRadiusM?
    failureState
    serviceState
```

This avoids the Real Tire Wear mistake of representing crawler wear as several
ordinary tire entries and the generic-wheel ambiguity already identified in both
external wear systems.

## Best ideas to assimilate from Real Tire Wear

### 1. Server-authoritative durable state

Adopt.

Only the server should own:
- wear accumulation;
- puncture/failure transitions;
- service replacement;
- economic effects.

Clients receive state.

### 2. Compact state replication

Adopt the principle.

Candidate:
- initial stream: full unit list/state;
- update stream or event: dirty running-gear units only;
- quantized wear state where precision is sufficient;
- explicit failure-state enum.

Do not replicate formula inputs/results every frame.

### 3. Monotonic relative grip factor

Adopt the semantic model:

```
healthyGrip
× wearGripFactor
```

Never make wear choose an unrelated absolute terrain coefficient.

The exact Real Tire Wear 1.00→0.80→0.55→0.40 curve is calibration input only,
not an adopted formula.

### 4. Axle/service grouping

Adopt as UI/service topology input.

Discover/normalize axles once, not separately inside the workshop.

### 5. Failure UX chain

Adopt the causal experience:
- failure occurs;
- driver hears/sees it;
- vehicle behavior changes;
- warning is clear;
- workshop can service the affected unit.

Redesign the physics underneath it.

## Best ideas to assimilate from Reifen instead

### 1. First-class track/roller identity

Use this instead of Real Tire Wear's crawler-member-wheel persistence.

### 2. Separated wear channels

Reifen's separation of:
- distance;
- slip;
- active time;
- force/load;

is diagnostically stronger than one opaque product.

RE should keep named channels even if the final wear integration is more
physical than Reifen's formulas.

### 3. Explicit structural-radius owner truth

Use the API-v1 principle:

```
getStructuralWearRadius()
```

separate from:
- pressure deformation;
- puncture deformation;
- sink;
- current actuator radius.

## Proposed clean-room wear model

### Fundamental mistake to avoid

Do not use:

`vehicleRootDistance × slipMultiplier`

as the main tire-wear quantity.

Instead estimate what the tread actually experienced.

### Candidate channels

#### Rolling abrasion

```
rollingDistance =
    abs(wheelSurfaceSpeed) × dt
```

or the best authoritative equivalent available.

```
rollingWear =
    rollingDistance
    × surfaceAbrasiveness
    × loadStress
    × pressureStress
```

This allows inside/outside wheel distance to differ naturally.

#### Slip abrasion / energy

Candidate quantity:

```
slipSpeedLong =
    wheelSurfaceSpeed - groundLongitudinalSpeed

slipWork ~
    abs(longitudinalForce × slipSpeedLong)
    + lateralWeight × abs(lateralForce × lateralSlipSpeed)
```

If force is not available reliably, use a calibrated proxy based on:
- measured load;
- longitudinal/lateral slip;
- effective friction;
- wheel surface speed.

The important property is:

> a spinning tire can wear even when the vehicle itself barely moves.

#### Load/contact stress

Prefer normalized physical load over relative vehicle average.

Inputs already available or becoming available through RC/state providers:
- wheelLoadN;
- supportContactWidthM;
- tire pressure;
- structural radius;
- crawler/track identity.

Candidate normalized stress:

```
contactStressIndex =
    wheelLoadN / effectiveSupportAreaReference
```

Do not assume a dual is simply one tire with doubled width if the gap matters.

#### Surface abrasiveness

Separate abrasiveness from mud/wetness/slip.

Example semantic profile:

```
surface:
  ASPHALT_DRY
  ASPHALT_WET
  HARD_DIRT
  FIELD_DRY
  FIELD_WET
  SOFT_MUD
  STONE
  SNOW
```

The profile should describe material abrasion, not indirectly encode every
other stress effect.

#### Thermal channel — optional later

If high speed/load/slip should accelerate wear, model a named tire-temperature
or heat proxy instead of a hidden `speedFactor`.

Do not add thermal state to the first MVP unless runtime evidence shows it adds
meaningful behavior.

## Proposed state architecture

Persistent state should be small:

```
RunningGearState {
  unitId
  kind

  treadWear01
  structuralWear01

  failureState
  failureSeverity

  diagnostics? {
    rollingWearAccum
    slipWearAccum
    overloadWearAccum
  }
}
```

Diagnostic channel totals may be optional/persisted at lower precision.

Derived values should not all be saved:
- grip factor can be derived from wear;
- structural radius can be derived from original geometry + wear profile;
- warning level can be derived from state.

## Committed-state rule

Wear is slow state.

Prefer:

```
sample physical inputs
      ↓
integrate working wear
      ↓
commit state
      ↓
RC/physics consumers read committed state
```

Do not let one subsystem observe half-updated wheel states in the same logical
generation.

This mirrors the atomic-generation lesson already taken from Mud hydrology.

## RC interaction if RE becomes the wear owner

Current:
`Reifen + MRTireWear + MRMud`

Potential target:

```
RE RunningGearWear
        │
        ├── publishes wearGripFactor
        ├── publishes structuralRadius
        ├── publishes failure state
        │
        v
RC traction/radius composition
        │
        ├── MR healthy grip
        ├── Mud temporary consequences
        └── RE relative wear
```

Important:
RE should **not** become a second base-traction solver.

### Possible future RC modules

Conceptual only:
- `MRREWear` — compose RE relative wear with MR healthy grip;
- `MudREWear` — give Mud RE structural radius/failure pressure constraints;
- state-provider extension — expose RE running-gear state to other consumers.

Names are not commitments.

## Avoiding a circular RC↔RE dependency

RE may prefer RC's normalized physical input surface for:
- slip;
- load;
- wetness;
- support geometry;
- sink.

RC may later consume RE's committed wear state.

That can create a conceptual cycle if done naively.

Preferred boundary:

```
RC PhysicalInputSnapshot(t)
        ↓
RE wear integration
        ↓
RE committed WearState(t+1)
        ↓
RC traction/radius composition consumes committed wear
```

Wear changes slowly enough that a committed snapshot boundary is physically
acceptable and architecturally deterministic.

RE must also have a vanilla fallback so RC is optional, not a hard package
dependency.

## Tire pressure and puncture ownership

Current target stack pressure owner:
**MudSystemPhysics**.

Therefore a future RE puncture should not independently own a second continuous
pressure model when Mud is present.

Preferred abstraction:

```
RE failure:
  PUNCTURE / LEAK / SIDEWALL_DAMAGE

        ↓ constraint/request

pressure owner:
  Mud TirePressureSystem if active
  RE vanilla fallback otherwise
```

Examples:
- cap achievable pressure;
- impose leak rate/request;
- expose flat/sidewall failure state;
- let the pressure/contact owner compute final deformation.

This is cleaner than Real Tire Wear's local visual-only `airLoss`.

## Structural radius

RE can become permanent wear-radius owner only after Reifen is retired.

Candidate:

```
structuralRadius =
    originalRadius - maxTreadLossM × treadWearCurve
```

The curve/max tread depth should be class/profile based.

Do not directly let:
- pressure;
- sink;
- puncture

change the stored structural baseline.

## Visual architecture

Real Tire Wear proves that generic clean tire material replacement is feasible,
including:
- shader-variation preservation;
- texture/map preservation;
- tire-shape discovery;
- crawler custom shaders.

Do not reuse its shaders/materials/assets under the current provenance
ambiguity.

Preferred RE visual layer:
- own shader/material holder;
- install once per shape/material identity;
- per-object lifecycle ownership;
- dirty updates only when quantized wear/failure state changes;
- explicit teardown where engine resources require it.

MVP can ship without visual tread deformation if necessary; physics/persistence
correctness outranks shader coverage.

## Service/workshop architecture

Do not reproduce the global `Gui.draw/mouseEvent` hook.

Preferred:
- shared RE service panel or supported WorkshopScreen extension;
- normalized service units/axles;
- server-side quote;
- explicit requester authorization;
- affordability validation;
- atomic debit + state reset;
- authoritative state broadcast.

Price policy should be separate from physical wear.

Possible fallback:
- percentage of vehicle price.

Better future source:
- tire/track configuration cost or size/class pricing.

## Migration from Reifen

If RunningGearWear eventually replaces Reifen, preserve user save continuity.

Possible migration workflow:
1. Reifen remains installed for one migration session.
2. RE runs in **READ/IMPORT ONLY** mode.
3. For supported Reifen 1.2.2.70, read public API-v1 wear/radius state.
4. Persist equivalent RE running-gear state.
5. User removes/disables Reifen.
6. RE becomes the owner on next load.

Do not run both physical wear actuators simultaneously during migration.

This should be a deliberate one-time tool, not a permanent compatibility bridge.

## Proposed implementation phases

### Phase A — architecture/prototype
- RunningGearUnit identity/classification;
- server-owned per-tire wear state;
- persistence;
- initial/update network sync;
- RC/vanilla input adapter;
- diagnostics only, no grip/visual effects.

### Phase B — tire wear physics
- rolling distance;
- slip-work proxy;
- load/contact stress;
- surface abrasiveness;
- monotonic wear→grip factor;
- RC composition.

### Phase C — structural/puncture
- structural tread radius;
- puncture/failure state machine;
- Mud pressure-owner integration;
- fallback physics without Mud.

### Phase D — service/UX
- axle/service topology;
- authoritative replacement transaction;
- warnings/HUD;
- workshop UI.

### Phase E — tracks
- first-class rubber/steel track units;
- rollers/idlers if worthwhile;
- class-specific wear/service/visuals.

### Phase F — visual wear
May move earlier if an independent clean-room shader prototype is cheap, but it
must not block correctness.

## Promotion/retirement gate for Reifen

Do not remove Reifen from the user's target stack until RE proves:
1. persistent wear survives save/reload;
2. MP authority is correct;
3. wheel/track identity survives configurations;
4. wear accumulation responds causally to rolling/slip/load/surface;
5. MR/Mud composition has one final owner;
6. structural radius is correct;
7. service is authoritative;
8. performance is acceptable on large fleets;
9. crawler/track parity reaches the user's actual equipment needs;
10. migration or an explicit state-reset decision is available.

Until then:
- Reifen remains current owner;
- RE RunningGearWear stays disabled/research-only;
- no dual ownership in normal play.
