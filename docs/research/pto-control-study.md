# PTO control architecture

Date: 2026-10-05  
Branch: `feat/pto-control`

## Goal

Own PTO operator control inside RealismExtensions without inheriting the
architecture, names, UI assets or runtime polling model of any external PTO
mod.

The implementation is concept-driven:
- model real tractor PTO selection;
- preserve GIANTS/MR/RMS ownership boundaries;
- expose one stable state contract;
- avoid per-frame state discovery;
- use evidence-backed capability profiles rather than horsepower/name guesses;
- keep UI/visual presentation independent from physical state.

## Real-world behavior chosen

The supported operator model is manual:
- select 540 / 540E / 1000 / 1000E only when the tractor actually supports it;
- set hand throttle independently;
- show current PTO mode/requirement;
- reject gearbox-mode changes while PTO is engaged;
- warn on implement-family mismatch;
- never auto-select a PTO gear on behalf of the operator.

This matches the common real-tractor pattern: PTO speed selection is a cab
control (mechanical lever or electro-hydraulic selector), engagement is a
separate control, and panel indication reports PTO state.

No AUTO mode is implemented.

## Runtime ownership

### RealismExtensions

RE owns:
- selected PTO speed mode;
- hand-throttle request;
- tractor capability resolution;
- attached implement requirement resolution;
- persistence and multiplayer replication;
- generic HUD/dashboard-facing state;
- standalone GIANTS physical adaptation when no external drivetrain owner is
  active.

### RealismCompatibility

RC owns only composition with external specialist owners:
- MR sees selected gearing in its canonical 540-rpm PTO domain;
- RMS computes PTO capacity/utilization through the selected gearing;
- state is scoped to owner calculations and motor state is restored
  immediately.

### GIANTS

GIANTS remains the base power-consumer/motor implementation.

The standalone RE adapter does not write a new ratio every frame. It hooks the
two native queries that already need PTO information:
- `VehicleMotor.getPtoMotorRpmRatio`;
- `VehicleMotor.getRequiredMotorRpmRange`.

The selected ratio is scoped into the native RPM-range calculation because
GIANTS reads the raw `ptoMotorRpmRatio` field internally, then the original
field is restored immediately.

## Performance architecture

There is no PTO `onUpdate` or `onUpdateTick` controller.

State changes only on:
- vehicle load;
- save restore;
- implement attach;
- implement detach;
- operator input;
- network replication.

The public state object carries a monotonic `revision`.

RC caches by:
`vehicle + revision + canonicalPtoRpm`.

Therefore stable PTO state can be consumed by thousands of MR/RMS hot-path calls
without recalculating capability, attachment requirements or motor ownership.

The temporary assetless HUD also caches its rendered string by revision.

## Domain model

Modes:
1. 540
2. 540E
3. 1000
4. 1000E

Mode data contains:
- physical shaft RPM family;
- economy flag.

Capability data contains:
- supported modes;
- native GIANTS motor ratio;
- optional evidence-backed per-mode engine RPM/motor ratio;
- capability source/profile ID.

Unknown tractors are deliberately conservative:
- native 540 only;
- no inference of 1000/E modes from horsepower, price or display name.

## Evidence profiles

Initial evidence profiles are intentionally small.

### Fiat 180-90
- 540
- 1000

No economy PTO mode is assumed.

### HM 10-500 / HM10500 family
- requirement override: 1000 rpm

This profile exists because the game's ordinary power-consumer data can be
normalized/ambiguous in the MR stack; an evidence-backed requirement override
must beat that ambiguous value.

Profiles are additive. Unknown equipment continues through native fallback.

## Requirement resolution

Requirements are resolved recursively across attached implements only when the
attachment graph changes.

Each consumer can report:
- known 540/1000 requirement;
- unknown PTO requirement;
- evidence source.

The root state reports:
- `requiredShaftRpm` when exactly one known family is present;
- `requirementConflict` when simultaneous consumers require different
  families;
- unknown-requirement count;
- selected-vs-required mismatch.

The system warns; it does not silently change the selected gearbox.

## Public contract

`RealismExtensionsPTO.API_VERSION = 1`

Key public fields:
- `revision`;
- `mode`;
- `modeToken`;
- `shaftRpm`;
- `economy`;
- `effectiveMotorRatio`;
- `nativeMotorRatio`;
- `handThrottlePercent`;
- `handThrottleRpm`;
- `requiredShaftRpm`;
- `requirementKnown`;
- `requirementConflict`;
- `hasPtoConsumer`;
- `mismatch`;
- `capabilitySource`;
- `capabilityProfileId`;
- immutable `availableModeMask`.

Internal profile/mode tables are not exported.

## Persistence / multiplayer

Persisted per vehicle:
- selected mode;
- hand-throttle percentage.

Server authority:
- client requests state change;
- server validates supported mode and PTO-engaged safety;
- accepted state is replicated;
- dirty-stream sync remains available for ordinary state replication.

## Controls

Temporary default keyboard bindings:
- Ctrl + PageUp: next PTO speed;
- Ctrl + PageDown: previous PTO speed;
- Ctrl + Up: hand throttle +5%;
- Ctrl + Down: hand throttle -5%;
- Ctrl + 0: release hand throttle.

These bindings are transitional and may be changed after gameplay feedback.

## Temporary HUD

The current HUD is intentionally assetless.

It shows a compact cached line such as:
`PTO 1000 | 45% | 1000 ok`

Mismatch example:
`PTO 540 | ! requer 1000`

This is an operational/runtime-validation UI, not the final art direction.

Future presentation can add:
- original PTO pictogram;
- proper HUD widget;
- GIANTS DashboardValueType values for compatible in-cab indicators;
- vehicle-specific dashboard profiles.

None of those should change the PTO state/physics contract.

## Migration guard

While the old external PTO owner is installed, RE's native PTO specialization
does not attach to vehicle types.

This prevents duplicate ownership during migration.

RC keeps both bridge families temporarily:
- legacy external-PTO composition;
- native RE-PTO composition.

Only one can become active because RE disables its owner state while the
external owner exists.

After native runtime validation, the external PTO mod can be removed and the
legacy bridge family can be deprecated separately.

## Validation completed in CI

RE harnesses cover:
- mode/family math;
- capability fallback;
- evidence profile matching;
- recursive implement requirement/conflict handling;
- operator selection;
- mode-change rejection while PTO engaged;
- hand-throttle state;
- event-driven requirement refresh;
- standalone GIANTS physical ratio/rpm-range scoping;
- assetless HUD revision cache.

RC harnesses cover:
- native API availability;
- revision-based snapshot reuse;
- canonical 540-domain translation;
- MR scoped ratio + hand-throttle composition;
- RMS scoped PTO capacity composition;
- restoration of native motor state after every scope.

## Runtime gate

First native runtime test should remove/disable the external PTO owner.

Expected:
1. RE log:
   `PTOControl active; vehicleTypes=...`
2. With MR installed:
   standalone GIANTS adapter reports inactive because drivetrain ownership is
   external.
3. RC:
   `MRPTO=ACTIVE`;
   `RMSPTO=ACTIVE` when RMS is applicable;
   legacy external-PTO bridges INACTIVE.
4. Fiat 180-90 exposes 540 and 1000 only.
5. HM 10-500 requirement resolves to 1000.
6. Selecting 540 with that implement shows mismatch.
7. Selecting 1000 clears mismatch.
8. Selector refuses a mode change while PTO is engaged.
9. Hand throttle raises MR minimum engine RPM without requiring accelerator
   input.
10. No persistent overwrite of native `motor.ptoMotorRpmRatio`.

The first runtime log decides whether this branch moves from architectural/CI
validation to gameplay validation.
