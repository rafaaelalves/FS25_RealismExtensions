# Real Tire Wear 1.6.0.0 focused runtime plan

Runtime testing is **not required to decide whether to use the mod**. The current
decision is clean-room assimilation research.

Only run these tests when they answer an engine/behavior question that matters
to the future RE implementation.

## T1 — stationary wheelspin wear gap

Create a scenario where a driven tire spins strongly while vehicle translation
is near zero.

Record:
- root distance;
- wheel surface speed;
- longitudinal slip;
- Real Tire Wear wear delta.

Static expectation:
near-zero root movement produces near-zero wear even with large slip.

Purpose:
prove why RE must use tread/slip travel rather than root distance.

## T2 — inside/outside turn distance

Drive a tight constant-radius circle with minimal slip.

Compare left/right tire wear deltas.

Static expectation:
base distance is common vehicle-root displacement, so geometrically different
wheel path lengths are not represented except indirectly through slip/load.

Purpose:
calibrate the value of per-wheel rolling distance.

## T3 — lifted attached implement

Attach an implement with serviceable wheels, lift it so the wheels are visibly
airborne, and drive.

Record:
- `physics.hasGroundContact`;
- contact force;
- Real Tire Wear groundType/loadFactor/wearFactor;
- wear delta.

Static concern:
the attached-root fallback can classify the wheel as contacting.

## T4 — relative load model

Compare:
1. lightly loaded vehicle with even axle distribution;
2. heavily loaded vehicle with the same proportional distribution.

If every wheel's force rises proportionally, Real Tire Wear's relative factor
should stay similar.

Purpose:
prove the need for absolute normalized load/contact stress.

## T5 — surface factor causality

Drive equal-distance/equal-speed/equal-slip runs on:
- road;
- hard dirt;
- field;
- very soft ground.

Record ground factor and wear.

Purpose:
validate the static 1.00/1.08/1.15/1.25 mapping and compare it with desired
abrasiveness semantics.

## T6 — physical radius

Force high wear visually.

Capture:
- originalPhysicsRadius;
- visualMaxTreadDepth;
- current physics.radius;
- `PHYSICS_TREAD_LOSS_FACTOR` effect.

Static expectation:
physics radius remains/restores original; there is no structural tread shrink.

## T7 — puncture consequence

Force/trigger a puncture.

During the ~8 s leak:
- record visual deformation;
- wheel friction/stiffness;
- rolling resistance if observable;
- speed limit;
- sound lifetime;
- network damaged state.

Static expectation:
continuous air loss is presentation-only; the durable physical policy is mainly
the damaged bool + 15 km/h combination speed cap.

## T8 — server/client wear authority

Dedicated server or host+client:
- drive one vehicle from a client;
- observe server/client wear;
- force a packed wear threshold crossing;
- join a second client later.

Expected:
- server advances durable wear;
- clients receive initial stream/incremental event;
- JIP converges.

This test is useful as a reference for the future RE network contract.

## T9 — unauthorized workshop request

Dedicated two-farm test or isolated event harness.

Attempt a replacement request from farm A targeting farm B's synchronized
vehicle.

Static source indicates the server checks the target vehicle owner's funds but
not requester authorization.

Do not exploit this outside a controlled local test.

Purpose:
define the permission checks RE must add.

## T10 — wheel-configuration persistence identity

Accumulate asymmetric wear, save, then change wheel/tire configuration if the
vehicle allows it and reload.

Check whether index-based wear state maps to the intended physical units.

Purpose:
design stable RE running-gear identity.

## T11 — crawler state model

Use a supported crawler.

Record:
- internal tire entries;
- member-wheel wear;
- crawler visual average;
- service unit grouping.

Purpose:
compare Real Tire Wear member-wheel persistence with Reifen's first-class track
model before implementing RE tracks.

## T12 — normal-wheel visual update cost

Large fleet/client profile.

Measure:
- calls to `updateVisualWear`;
- shader writes;
- material-ensure calls;
- time spent while wear is unchanged.

Purpose:
set RE dirty-refresh cadence.

## T13 — friction ordering with MR/Mud

Only if needed to understand GIANTS callback ordering.

Run Real Tire Wear with MR+Mud in a disposable profile.

Capture every owner touching:
- tireGroundFrictionCoeff;
- frictionScale;
- setWheelShapeTireFriction.

This is **not** a target compatibility test and should not lead to an RC bridge.
It exists only to choose the clean RE composition boundary.

## T14 — workshop UI lifecycle

Load save A, use workshop, return to menu, load save B without restarting FS25.

Check:
- duplicated buttons;
- mouse interception;
- screen re-registration;
- stale vehicle/UI references.

Purpose:
avoid copying the global GUI hook lifecycle.

# Future RE prototype gates

Once `RunningGearWear` exists, its own acceptance tests should replace these
reference tests.

Minimum prototype proof:
1. stationary wheelspin produces slip wear;
2. rolling wear uses per-unit travel;
3. airborne wheel produces zero wear;
4. absolute load changes wear under equal relative axle distribution;
5. surface abrasion and slip are separate inputs;
6. server is sole durable-state authority;
7. grip is relative/monotonic;
8. no duplicate traction owner with MR/Mud;
9. Reifen active -> RE wear owner refuses normal activation;
10. save/load and JIP preserve the same state.
