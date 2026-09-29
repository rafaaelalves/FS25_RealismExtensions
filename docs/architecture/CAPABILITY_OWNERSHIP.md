# Capability ownership model

Updated: 2026-09-29

This file records the intended owner of each realism phenomenon relevant to Realism Extensions.

The decision unit is a **capability**, not a mod.

## Physical vehicle and ground state

| Capability | Owner | RE role |
|---|---|---|
| drivetrain / engine / base vehicle dynamics | MoreRealistic | consume only if needed |
| base traction / friction | MR + Mud + Reifen composition through RC | no write |
| physical ground wetness | MudSystemPhysics | read-only input |
| sink / terrain resistance / stuck | MudSystemPhysics | read-only input |
| permanent tire wear / worn structural radius | Reifenverschleiss + RC composition | read-only input |
| persistent soil compaction | SoilCompaction | no duplicate model |
| PTO operating mode / effective ratio | Dynamic PTO + RC composition | consume only |
| mechanical subsystem / PTO stress | RMS where active | no duplicate model |

## Moisture domains

| Capability | Owner | RE role |
|---|---|---|
| physicalGroundWetness | MudSystemPhysics | deformation/effects input |
| agronomicFieldMoisture | MoistureSystem | crop/environment input |
| materialMoisture | MoistureSystem | material/storage input |

Never substitute one domain for another simply because all are expressed as moisture percentages.

## Terrain and crop consequences

| Capability | Current owner | Target |
|---|---|---|
| player longitudinal slip rut | FarmKit feature suppressed by RC | **RE TerrainDeformation** |
| player lateral scrub rut | FarmKit feature suppressed by RC | **RE TerrainDeformation** |
| AI native-style ground deformation | True AI Tracks | external initially; **RE candidate replacement** |
| implement-wheel deformation | True AI Tracks | external initially; **RE candidate replacement** |
| furrow/plowing collider consequence | FarmKit | keep initially; future FurrowInteraction candidate |
| speed-based crop damage | FarmKit | keep initially; future CropInteraction candidate |
| persistent compaction/yield memory | SoilCompaction | keep specialist |

## Dirt, spray and presentation

| Capability | Current owner | Target |
|---|---|---|
| wheel-soil dirt/particles | MudSystemPhysics | keep specialist |
| simple wet/dry mud spray | Mud Sprayer | replaceable presentation behavior; no asset reuse |
| implement dust | FarmKit | keep initially |
| road spray | FarmKit | keep initially |
| drivetrain sound synthesis | MoreRealistic | keep specialist |
| drivetrain spatial propagation | FarmKit | keep initially |
| extra MP/operational sounds | soundExpansionMP | keep external |

A future `SurfaceContamination` module must not become a second wheel-ground physics owner. It may consume physical state and render consequences.

## Loose material handling

Do not model "load spill" as one indivisible capability.

```text
rolloverSpill
  -> material leaves vehicle because orientation/accident exceeds containment

loadingOverflow
  -> incoming material exceeds capacity or cannot enter because cover is closed

dischargeDynamics
  -> normal unloading rate/geometry changes with tip animation/angle

spillPresentation
  -> dust, pouring sound, visual feedback

materialRules
  -> which fill types can spill and how containment behaves
```

Current external behavior:

- RealPhysics LoadSpill: strong owner for `rolloverSpill` + `dischargeDynamics`.
- Loose Load: covers `rolloverSpill` plus `loadingOverflow`, cover semantics and presentation.

Therefore there is **no single winner by mod name**.

Initial RE policy:
- do not implement loose-material physics in the first TerrainDeformation milestone;
- do not run two independent rollover owners blindly;
- keep the specialist that owns the desired capability until RE deliberately builds a unified `LooseMaterialConsequences` module;
- verify per-feature disable/settings granularity before recommending a mixed RealPhysics + Loose Load profile.

## FarmKit residual ownership

Under the current RC conservative profile, FarmKit remains useful for several unique systems.

RE should replace them only module-by-module, after parity/runtime evidence:

```text
Planner/PF aggregation      -> FarmKit
furrow/plowing collider     -> FarmKit
crop damage                 -> FarmKit
implement dust              -> FarmKit
road spray                  -> FarmKit
engine sound propagation    -> FarmKit
straw refeed routing        -> FarmKit (RHM processing bridge still desired)
```

## Normalized input direction

Preferred future read-only contract:

```text
REState.getPhysicalGroundWetness(x, z)
REState.getWheelSlip(vehicle, wheel)
REState.getStructuralTireRadius(vehicle, wheel)
REState.getWheelFootprint(vehicle, wheel)
REState.getSinkState(vehicle, wheel)
REState.getGroundProfile(x, z)
REState.getAgronomicFieldMoisture(x, z)
REState.getMaterialMoisture(source)
```

These names are conceptual, not an API commitment.

Implementation should first reuse an RC-normalized state surface if one is introduced. If no such surface exists, adapters remain narrow and owner-specific rather than creating a new global physics layer.
