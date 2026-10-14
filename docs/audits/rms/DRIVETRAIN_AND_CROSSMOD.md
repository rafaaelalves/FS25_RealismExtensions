# RMS drivetrain and cross-mod topology audit

Baseline: RMS `0.10.0.0`, ZIP SHA-256 `6741f193f22a5f85f5543c73d7f566b6686ab90bf7b705fd66d6d3421cb0d021`.

This pass complements RC `MRRMS`. RC already repairs MoreRealistic state after RMS changes the live driveline. This document studies the RMS driveline itself and what its topology-changing design means for other mods.

## Architecture

RMS does not emulate 2WD by merely changing a coefficient.

It discovers the GIANTS differential tree and caches:
- differential roots;
- center differential where present;
- wheel membership of the primary axle;
- wheel membership of the engageable axle;
- original torque ratio / max speed ratio / child topology;
- lockable wheel-to-wheel axle differentials;
- twin-track layouts.

When a switchable center graph exists, RMS creates two differential plans:
- **full graph** for 4WD / AUTO-engaged;
- **primary-only graph** for 2WD.

Applying a mode can call:
- `removeAllDifferentials()`;
- `addDifferential(...)` for a rebuilt graph;
- `updateMotorProperties()`.

So the effective driven-wheel topology genuinely changes at runtime.

## Primary / engageable axle inference

For a conventional two-axle graph RMS chooses the engageable side primarily from steerable-wheel share. On a tie it prefers the side with larger local Z, based on the usual vehicle-forward geometry.

This is a sensible generic fallback and avoids a vehicle-name database, but it is still heuristic. Articulated machines, unusual four-wheel steering, reversed geometry and exotic multi-root graphs belong in runtime coverage rather than being assumed correct.

If RMS cannot identify a safe switchable center topology, it falls back conservatively rather than arbitrarily deleting driveline branches.

## AUTO

AUTO is a real graph owner, not a display mode.

It engages 4WD when:
- wheel slip exceeds the configured threshold; or
- speed is low while dynamic motor load is high.

It disengages only after speed is above the release threshold and slip stays low for the hysteresis period.

A particularly good detail is that RMS's own wheel-slip sampler adapts to the effective RMS topology: primary wheels always count, while engageable wheels only count when the extra axle is actually engaged. AUTO therefore does not keep estimating slip from an axle it has disconnected.

## Differential lock

Open wheel-to-wheel axle differentials are given an intentionally permissive max-speed ratio.

For a reduced/non-native graph, RMS simulates lock by:
- reducing the max-speed ratio to the configured locked value;
- dynamically biasing torque toward the slower wheel.

For the full center graph it classifies the lock as `nativeLock` and keeps the original axle max-speed ratio rather than forcing the configured locked ratio.

That latter path needs runtime validation. The UI/tutorial describes a lock that forces inside/outside wheels toward equal speed. If an original differential has a materially open max-speed ratio, retaining it may produce a softer lock than the advertised behavior.

## Confirmed auto-release defect

The settings tooltip says:

> differential locks disengage automatically above the release speed and re-engage below it while requested.

The state model contains both:
- `diffLockRequested`;
- `diffLockEngaged`.

That is exactly the right model for temporary speed-based release.

However, when speed exceeds the threshold, `updateDiffLockState()` calls:

```
setDrivetrainState(vehicle, state.driveMode, false, state.parkBrake, false)
```

This clears `diffLockRequested`, not only `diffLockEngaged`.

As a result, after the automatic release there is no retained request to re-engage when the machine slows down. This is a source-confirmed behavior/documentation mismatch.

Recommended upstream patch:
- preserve `diffLockRequested=true`;
- set only the effective engaged state false while over-speed;
- allow the existing lower-speed branch to re-engage it.

## Wind-up model

RMS accumulates driveline wind-up while:
- driving;
- steering;
- tire-ground friction is high enough;
- 4WD or differential lock is active.

4WD uses a smaller configured contribution. Full differential lock can reach a hard threshold and cause immediate transmission condition loss, then resets the wind-up state to a partial residual.

The model also feeds ordinary transmission wear.

### Surface semantics concern

For ordinary 4WD, RMS consumes `avgGroundSurfaceFactor` so softer terrain can release driveline strain.

For differential lock, the code forces:

```
surfaceFactor = 1
```

That means surface compliance is ignored whenever the lock is engaged; only tire-ground friction still gates accumulation.

This may exaggerate wind-up on deformable/soft soil relative to the user-facing explanation ("turning on a high-grip surface"). It is a **DESIGN_RISK**, not yet a proven defect. A runtime matrix should compare asphalt/gravel/dry field/wet field with equivalent steering and speed.

## Enhanced Vehicle coexistence

RMS explicitly steps aside when Enhanced Vehicle owns differential or parking-brake control.

It first checks Enhanced Vehicle runtime globals and otherwise re-reads Enhanced Vehicle's settings XML every ten seconds.

This is good ownership behavior.

### Cross-mission cache risk

The settings cache is module-global:

```
evConfigCache = { diff=nil, park=nil, nextReadTime=-math.huge }
```

and its deadline is based on `g_time`.

No mission lifecycle reset was found in the drivetrain source. If `g_time` moves backwards/reset on loading another save in the same process, a deadline created in the previous mission can remain far in the future and suppress config rereads.

Classification: **STRONG_CANDIDATE** until reproduced.

Low-risk fix:
- clear the cache during map delete/load; or
- detect `now < lastReadTime` / backward clock movement.

## Restore ownership risk

RMS caches the original differential graph at layout construction and uses that snapshot when it restores ownership.

If another mod legitimately changes the differential graph after RMS captured it but before RMS releases control, restoring the old snapshot can overwrite that later owner's changes.

No current target-stack failure is proven. Treat this as an ownership contract issue, not a reason for a blind patch.

A public/provider boundary is preferable to multiple mods independently rebuilding the differential tree.

## Reifenverschleiss interaction — source-confirmed mismatch

The Reifen 1.2.2.67 audit previously marked its force-wear/dynamic-drivetrain interaction as a strong candidate.

Cross-reading the exact RMS and Reifen packages now confirms the mismatch.

Reifen:
1. traverses `vehicle.spec_motorized.differentials`;
2. computes wheel torque shares;
3. caches those shares per vehicle in `rvDifferentialWheelShareCache`;
4. later uses the cached shares for FORCE-WEAR.

RMS subsequently changes the live GIANTS differential graph when switching between 2WD and 4WD/AUTO.

Therefore the Reifen cache no longer necessarily describes the active graph.

Nuance:
- Reifen's ordinary live "is this wheel driven?" diagnostic can notice that a disconnected axle is no longer in the current graph;
- but the cached torque shares for the remaining driven axle still reflect the former full graph, so FORCE-WEAR can under-allocate the active axle's share in 2WD;
- track/reference-wheel paths can use the stale share more directly.

This is now a **CONFIRMED_STATIC cross-mod mismatch**, not merely a hypothesis.

### Correct integration directions

Preferred upstream Reifen fix:
- invalidate/recompute differential wheel-share cache when topology changes; or
- expose a topology signature and rebuild when it differs.

Cleaner long-term RMS/RC direction:
- RMS exposes a read-only effective driven-wheel/topology provider;
- RC normalizes it once for consumers that need the final active driveline.

Avoid:
- a permanent RC patch that reaches into Reifen private cache tables unless an upstream/public boundary is unavailable.

Existing RC `MRRMS` solves the analogous problem for MoreRealistic by synchronizing `mrIsDriven` and driven-wheel aggregate state after `RMS_Drivetrain.applyState`. It does not currently solve Reifen's cached torque-share model.

## Parking brake

RMS also owns an optional parking-brake state:
- automatically holds unattended stopped vehicles;
- releases for player throttle/input;
- releases for AI;
- actual physics enforcement is applied in the breakdown/vehicle-physics path.

Enhanced Vehicle ownership is respected independently for the parking-brake capability.

## API opportunity

The drivetrain module already contains the information needed for a much cleaner cross-mod contract.

A small stable read-only API could expose:
- current drive mode;
- effective 4WD state;
- effective primary/engageable wheel indices;
- effective driven wheel indices;
- effective differential-lock requested/engaged state;
- parking-brake state;
- wind-up stress;
- a topology revision/signature.

That would reduce the need for RC/Reifen/MR integrations to infer private RMS layout internals.

## Runtime matrix

Before closing runtime validation:
1. conventional rear-drive tractor: 2WD -> 4WD -> AUTO;
2. front-drive or unusual topology if available;
3. four-wheel steering / articulated machine;
4. twin track;
5. AUTO engage/release hysteresis;
6. lock request retained across over-speed release;
7. lock wheel-speed behavior with original axle maxSpeedRatio > 1;
8. wind-up on asphalt / gravel / dry field / wet field;
9. Enhanced Vehicle coexistence and second-save reload;
10. Reifen FORCE-WEAR before/after RMS topology switch;
11. MR driven wheel metadata after each topology switch.


# RMS 0.11 drivetrain / cross-mod delta

## Drivetrain topology contract

The RC-relevant topology functions are text-identical to 0.10:
- `buildLayout`;
- `initSpec`;
- `applyState`;
- `setDrivetrainState`.

Therefore MRRMS can remain on the same ownership model.

The configurable differential-lock release speed became a fixed local constant
(`10 km/h`), but the retained-request bug remains: speed release still passes
`diffLockRequested=false` into `setDrivetrainState`.

## MoreRealistic

RMS still has limited direct MR awareness in dynamic motor-load estimation.

It still does not solve:
- MR driven-wheel metadata after RMS graph rebuilds;
- RMS transmission failure semantics bypassed by MR replacement shift paths.

MRRMS remains required.

## Reifen 1.2.2.70

No drivetrain revision/effective-wheel/share provider was added.

The exact current mismatch therefore remains:

```
RMS rebuilds differential graph
        ↓
Reifen FORCE-WEAR cached GIANTS shares can become stale
```

Keep the existing runtime magnitude gate before implementing a narrow provider
or invalidation bridge.

## Dynamic PTO

The native-capacity helper used by RMSDynamicPTO remains unchanged.

0.11 also reuses that helper to size PTO engagement shock. The existing effective
ratio composition should therefore apply naturally to both:
- continuous utilization;
- high-RPM engagement damage.

This must be validated at runtime with at least two PTO modes/ratios.

## Mud

The clogging consequences still read global GIANTS ground wetness.

MudRMS remains the appropriate boundary for field-local physical wetness.
