# Roadmap

Updated: 2026-09-29

## Phase 0 — foundation

- [x] Separate RE purpose from RC compatibility purpose.
- [x] Preserve FarmKit ownership conclusions.
- [x] Decompose moisture into physical/agronomic/material domains.
- [x] Audit initial six external mods by capability.
- [x] Remove unverified FS25 Vehicle Control Addon from the roadmap.
- [ ] Define the first normalized read-only state contract.
- [ ] Define source/license ledger for every dependency considered for absorption.

## Phase 1 — TerrainDeformation prototype

Target: restore missing slip/scrub terrain consequence without duplicating wheel physics.

Prototype must prove:

- player wheel deformation can be driven by authoritative slip state;
- longitudinal and lateral contributions can be separated;
- physical ground wetness changes deformation consequence without becoming a second wetness simulation;
- tire footprint/radius can be consumed without changing structural tire state;
- no friction, traction, sink, resistance, stuck or drivetrain writes occur;
- AI/implement traversal can be added without duplicate wheel processing;
- update cadence is bounded and observable.

True AI Tracks remains AI owner during the first prototype.

## Phase 2 — TerrainDeformation parity and AI migration

- add AI wheel deformation;
- add attached-implement wheel deformation;
- compare runtime/performance with True AI Tracks;
- verify no double deformation;
- verify multiplayer behavior;
- verify save/load persistence semantics;
- only then allow an RE profile that replaces True AI Tracks.

## Phase 3 — environmental presentation

Evaluate `SurfaceContamination` as a visual consequence layer.

Possible scope:
- wet/dry wheel spray where Mud does not already provide it;
- road/hard-surface spray;
- vehicle/implement contamination hooks;
- effect intensity from authoritative physical state.

Constraints:
- do not take traction/sink ownership;
- do not duplicate Mud wheel particles;
- do not reuse Mud Sprayer assets without permission/license.

## Phase 4 — crop and furrow consequences

Evaluate replacement/evolution of retained FarmKit capabilities:

- `CropInteraction`
- `FurrowInteraction`

FarmKit remains owner until RE reaches parity.

## Phase 5 — loose material consequences

Design a unified capability model before coding:

- rollover spill;
- loading overflow;
- cover containment;
- discharge dynamics;
- spill presentation;
- material rules.

Use RealPhysics LoadSpill and Loose Load as behavior references while respecting code/assets licensing.

## Phase 6 — deeper specialist replacement candidates

Independent projects, each requiring its own audit and migration gate:

- `PTOSystem` — possible future replacement/absorption of Dynamic PTO behavior;
- `TireWearState` — possible future replacement/absorption of selected Reifen behavior.

Neither should block TerrainDeformation.

## Definition of success

RE is successful when the realism stack can gain new consequences without forcing the user to choose between:
- duplicate physics;
- disabling useful specialist mods;
- or keeping a monolithic feature bundle solely for one unique behavior.

Every production module should have a clear owner graph, a clean disable path, runtime diagnostics and a compatibility story.
