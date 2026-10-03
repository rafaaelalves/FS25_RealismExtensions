# MoreRealistic deep architecture/compatibility audit

Updated: 2026-10-02

Exact stack source audited:
- mod: MoreRealistic
- version: `0.26.08.03`
- supplied ZIP SHA-256: `4646b8c01dd9157d452e66022fdc5323e812e2f287b23bbee657f05f5386b4bb`
- package size: ~9.6k Lua lines
- declared multiplayer support: true

Upstream comparison:
- public repository: `quadural/MoreRealistic_FS25`
- upstream is active and newer than the exact stack source.
- source findings in this audit therefore distinguish exact-stack behavior from current-upstream status.

Purpose: complement, not replace, the existing RealismCompatibility audits. RC already documents concrete MR composition with Mud, ADS, Reifenverschleiss, SoilCompaction, RMS and Dynamic PTO. This audit studies MR itself as an engine modification: ownership, algorithms, converted-asset architecture, failure modes, performance, automation behavior and reusable design lessons for RE/RC.

## Executive result

Recommendation: **KEEP + INTEGRATE**.

MoreRealistic is not a small vehicle addon and should not be functionally absorbed into RealismExtensions. It owns large parts of the baseline vehicle simulation:
- wheel friction and rolling resistance;
- wheel load/support-width semantics;
- wheel-shape inertia and force-point behavior;
- drivetrain and transmission behavior for MR vehicles;
- engine braking and PTO load;
- implement draft force;
- material-throughput power demand;
- mass and center-of-mass recomposition;
- aerodynamic drag/downforce;
- selected default fill densities, prices and crop yields;
- AI/control adjustments;
- a converted-asset catalog layered on top of the global engine changes.

RE should consume normalized physical state and own phenomena MR does not provide, especially persistent terrain geometry and terrain-history/recovery semantics.

RC remains the correct place to coordinate ownership when another mod overlaps MR.

## The key architectural correction

`vehicle.mrIsMrVehicle == false` does **not** mean MR is absent.

MR has at least three scopes:

1. **GLOBAL ENGINE**
   - global `WheelPhysics` hooks;
   - tire friction/rolling-resistance tables;
   - wheel-shape mass/inertia behavior;
   - global vehicle mass/CoM pipeline changes;
   - global aerodynamic drag/downforce;
   - weather wetness floor;
   - default fill/fruit data overrides;
   - several UI/light/AI/base-game fixes.

2. **MR-CONVERTED VEHICLE/IMPLEMENT**
   - custom VehicleMotor instance;
   - MR transmission/hydrostatic/CVT metadata;
   - implement-specific draft/PTO calibration;
   - combine/baler/mower/etc throughput model;
   - work-area stationary semantics;
   - curated suspension/geometry/mass values.

3. **CAPABILITY-GATED**
   - behavior that activates when a specialization/state exists regardless of conversion identity, such as mass contributors, dashboards, dynamic mounts, or wheel capabilities.

Any compatibility detector that only checks `mrIsMrVehicle` is therefore incomplete.

## Major positive design patterns

### Baseline physics ownership is explicit
MR deliberately replaces vanilla algorithms where it believes the base model cannot produce the desired behavior. This is invasive but conceptually coherent: other mods must compose around an owner rather than assume vanilla remains authoritative.

### Wheel support width is first-class
`mrTotalWidth` accumulates additional-wheel width, allowing dual/triple support to influence pressure, friction and rolling resistance. This is a useful input precedent for RE `ContactFootprint`, although crawler geometry still needs a true grouped footprint rather than pseudo-wheel scaling.

### Mass contributors carry center of mass
Fill units, tension-belt objects, mounted objects and wheel mass are not represented only as scalar added mass. MR tracks mass plus its effective CoM and gradually moves the physical CoM to avoid instability. This is a strong architecture precedent.

### Work demand feeds the vehicle
Draft force, PTO demand and material throughput produce real engine load. Combine, baler, mower, tedder, windrower, forage wagon, fruit preparer and woodcrusher models attempt to make the implement mechanically visible to the tractor/engine.

### Work-area outcome and physical work are not treated as the same concept
MR explicitly prevents some stationary work-area processing and can suppress GIANTS wheel displacement on lowered implement wheels when the work area would otherwise repeatedly erase the rut. This closely parallels RE v22's separation between physical work and agricultural-state changes.

## High-value risks/findings

The detailed list is in `STATIC_FINDINGS.md`. Highest-value items:

- confirmed arithmetic-precedence error in the seasonal/night wetness ramp;
- confirmed impossible condition preventing the PTO turn-on peak path from applying;
- confirmed wrong-object lookup of `mrTransmissionIsHydrostatic` in `VehicleMotor.mrUpdate`;
- strong initialization-order candidate for hydrostatic default engine-braking factor;
- confirmed driven-wheel rolling-resistance discontinuity at exact wetness 0 and 1;
- global per-wheel randomization of rotation damping at load time;
- many timestep-dependent smoothing filters that do not use `dt`;
- direct global replacement of `Vehicle.getName` instead of a composable wrapper;
- exact-version console-command teardown name mismatch;
- direct Precision Farming method replacement with no explicit version/shape contract;
- external-map surface classification partly depends on a small exact material-name set.

## Relationship to existing RC work

Existing RC work remains authoritative for already-tested integration behavior:
- **MRMud**: MR owns baseline wheel/drivetrain response; Mud owns local wetness/mud sink/resistance/puncture semantics.
- **MRTireWear**: MR owns healthy terrain/tire friction; Reifen contributes degradation only.
- **MRSoilHarvest**: Soil owns agronomic yield penalty; MR owns machine throughput/power.
- **MRRMS**: RMS drivetrain state is synchronized into MR driven-wheel metadata and bypassed transmission-failure semantics are restored.
- **MRDynamicPTO**: Dynamic PTO selected ratio is translated into MR's canonical PTO domain without permanently replacing native motor state.
- **MRADS**: ADS transmission-failure semantics bypassed by MR's custom transmission path are restored at narrow composition points.

This audit adds the broader explanation of *why* those bridges are necessary and identifies future integration classes.

## Companion documents

- `OWNERSHIP_AND_HOOKS.md` — scope matrix, overwrite strategy, asset overriding and persistence.
- `WHEEL_TRACTION_MASS.md` — friction, pressure proxy, duals/tracks, RR, inertia, mass/CoM and terrain-displacement interactions.
- `DRIVETRAIN_PTO_WORKLOAD.md` — motor/transmission, PTO, draft force and throughput-based workloads.
- `INTEGRATION_OPPORTUNITIES.md` — RC/RE boundaries, AI/controllers, moisture, terrain and patch policy.
- `STATIC_FINDINGS.md` — evidence-ranked defects, risks and cleanup opportunities.
- `RUNTIME_TEST_PLAN.md` — focused tests to execute later in FS25.

## Audit status

Static/source phase: **substantially complete** for 0.26.08.03.

Runtime phase: **pending**. Runtime tests are intentionally deferred until the user is back at the game machine. Static findings must not be promoted beyond their evidence tier.
