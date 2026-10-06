# Realistic Brakes 1.3 — reusable design lessons

Updated: 2026-10-06  
Exact baseline: `FS25_RealisticBrakes 1.3.0.0`

Purpose: preserve engineering ideas that are useful beyond brake simulation,
even where the exact RB implementation should not be copied.

## 1. Physical demand and physical actuator should be separate

RB evolved parking behavior across several hooks because it needed to influence
different FS25 control paths.

The cleaner general pattern remains:

```text
state / sensors
    -> pure demand model
    -> one owner-aware actuator adapter
```

For braking:

```text
parking request
thermal effectiveness
spring-brake state
service demand
    -> BrakeDemand
    -> BrakeActuatorAdapter
    -> MR/GIANTS/current final owner
```

This mirrors lessons already extracted from 4x4 and active suspension and should
be treated as a project-wide pattern.

## 2. Exponential relaxation is preferable for slow physical decay

RB cooling uses:

```text
T(t+dt) = T_ambient + (T(t)-T_ambient) * exp(-k*dt)
```

This is a strong reusable pattern for first-order relaxation:
- timestep/FPS invariant;
- works at coarse scheduler cadence;
- works for elapsed-time reconciliation after inactivity.

Potential future uses:
- temperature;
- pressure/leak approximations where physically appropriate;
- control/filter relaxation;
- presentation smoothing.

Do not blindly reuse the formula when the underlying process is not first-order.

## 3. Fix the physical input before optimizing the proxy

RB's thermal model is inexpensive but uses:
- pedal;
- speed factor;
- mass factor.

A future brake-energy model may be both more physical and architecturally
cleaner by consuming actual brake torque / wheel angular velocity.

General lesson:
before caching or micro-optimizing an expensive/awkward input, ask whether that
input exists only because the model itself is indirect.

This is the same lesson already encountered in RDS air use.

## 4. Bounded wake/retry budgets are essential

RB source documents a real historical FPS regression from repeatedly waking
inactive vehicles to preserve parking behavior.

The 1.3 solution bounds the special wake window.

Reusable rule:

```text
attempt active correction for bounded time/budget
 -> observe whether normal owner takes over
 -> stop exceptional wake work
 -> emit diagnostic if unresolved
```

Good candidates:
- vehicle-physics recovery;
- delayed owner attachment;
- HUD/provider discovery;
- controller handoff;
- terrain job retries.

Never keep a fleet permanently active because one feature needs occasional
correction.

## 5. Controller identity should be shared infrastructure

RB independently detects:
- GIANTS AI;
- Courseplay;
- Follow Me.

Trailer code uses a different/narrower rule.

This creates semantic drift.

A shared `ControllerContext` could normalize:

```text
PLAYER
GIANTS_AI
COURSEPLAY
AUTODRIVE
FOLLOW_ME
OTHER
```

with:
- revision;
- controller owner;
- controlled/unattended state.

Modules then consume one context instead of carrying their own mod-name probes.

This is useful beyond brakes:
- start orchestration;
- PTO;
- terrain deformation;
- recovery;
- automation safety.

## 6. ConnectionHoses is a good example of consuming native final state

RB does not need direct manualAttach or Interactive Control APIs to know whether
the air hoses are connected.

It consumes final GIANTS ConnectionHoses state.

This is an excellent integration rule:

```text
interaction/UI mod
 -> native semantic state
 -> physical consumer
```

Prefer consuming the stable resulting state over integrating every possible UI
owner individually.

## 7. Public APIs should expose semantics, not internal storage

RDS's `rdsGetAirPressure/rdsSetAirPressure` is cleaner than private-table
access and allowed RB integration.

But an absolute setter is still too permissive for a conserved resource.

General hierarchy:

bad:
```text
consumer writes private table
```

better:
```text
getValue / setValue
```

best for physical resources:
```text
query context
request transaction/transfer
owner validates
owner mutates
owner emits revision
```

Use this principle for:
- air;
- fluids;
- electrical transfer;
- inventory/material;
- workshop resources.

## 8. One serializer should own one settings file

RB comments/source reflect an earlier issue where multiple partial save paths
could overwrite each other's settings.

1.3 uses one complete serializer.

Project rule:
- one authoritative schema/serializer per persistent config;
- migrations merge fields;
- feature modules submit values to that owner rather than independently
  rewriting the same XML.

This is useful for future shared RE settings.

## 9. Local settings and simulation rules are different domains

RB, like RDS, mixes UI preference with physical simulation settings.

This repeated external pattern reinforces a project-wide split:

```text
LocalPreferences
SimulationConfig
DevCalibration
```

The distinction should exist in architecture, persistence and networking.

## 10. Runtime calibration tools are valuable

RB exposes many console controls for:
- temperature/fade calibration;
- HUD placement;
- safe mode;
- diagnostics.

This is valuable during development.

RE should retain strong calibration/diagnostic tooling, but:
- register idempotently;
- make mission-scoped targets lifecycle-safe;
- label dev-only commands;
- promote validated parameters into profiles/data.

## 11. Generic input/action diagnostics are worth centralizing

The packaged `RBDiagBrazo.lua` is not part of brake physics, but it contains a
valuable diagnostic idea.

It checks:
- whether the intended action event registered;
- likely key collision;
- selected control group;
- last input;
- powered/motor state;
- actuator command and limits;
- relevant specializations.

This directly mirrors the failure mode recently encountered with native RE PTO.

Future dev-only service candidate:

`RealismExtensionsControlDiagnostics`

Possible query:
```text
feature/action:
    registered
    active
    eventId
    collisionBypass
    lastInputAt
    callbackCount

controlled entity:
    vehicle
    controlGroup
    powered
    motorState

feature:
    currentState
    lastRejectedReason
    lastTransition
```

Modules can register diagnostic providers instead of each writing one-off
console probes.

Do not copy RB source; preserve the diagnostic concept.

## 12. One semantic sound owner

RB history/comments reveal how quickly 3D + fallback 2D audio can duplicate or
disappear.

General rule:
- physical owner emits semantic event/state;
- presentation chooses one sample path;
- fallback is mutually exclusive with primary;
- MP synchronization follows semantic state, not multiple independent loops.

Useful semantic events:
- RETARDER_ACTIVE;
- AIR_COMPRESSOR_LOADED;
- AIR_RELEASE;
- LOW_AIR_WARNING;
- PARKING_BRAKE_APPLIED.

## 13. Vehicle capability should be profiled separately from tuning

RB classifies car/truck/tractor heuristically and then uses that classification
for both:
- capability;
- heat tuning;
- engine-brake behavior.

Future RE pattern:
```text
CapabilityProfile
    hasExhaustBrake
    parkingFamily
    brakeFamily
    pneumaticTopology

TuningProfile
    thermalCapacity
    cooling
    brakeTorque
    thresholds
```

This prevents a category heuristic from silently becoming physical truth.

## 14. Wrapper order is not a compatibility contract

Exact MR/RB cross-read proves this.

When two mods overwrite the same global function and one owner sometimes does
not call `superFunc`, "load this mod later" is not robust composition.

Project rule:
- detect wrapper identity/order for diagnostics;
- never make preferred load order the long-term architecture;
- expose explicit demand/state/API boundaries.

## 15. Native XML metadata can be valuable even when native physics is not

RB trailer air ignores native `airConsumer#usage`.

Cross-reading GIANTS shows the metadata exists.

This is an important general lesson:
- native algorithm may be game-oriented;
- native metadata can still provide capability/tuning evidence.

Before inventing a heuristic, audit:
- XML declarations;
- fill units;
- native specializations;
- dashboard values;
- attachment metadata.

## 16. Physical safety state should not vanish under automation

RB's main response to difficult controller interactions is often to bypass its
physics for AI.

The robust project rule is:

```text
same physical safety state
+ controller-specific interaction policy
```

Exceptions must be:
- explicit;
- reasoned;
- diagnostic;
- preferably temporary.

This becomes especially important for:
- spring brakes;
- low air;
- start blocks;
- mechanical failures.

## 17. Persistent condition needs an explicit service owner

RB's brake damage is meaningful persistent state, but resets from generic
vehicle repair.

Whenever a module introduces persistent component condition, decide immediately:
- who diagnoses it;
- who services it;
- who prices it;
- who persists it;
- who owns repair transactions.

Otherwise the project accumulates unrelated "repair everything" side effects.

## Final lesson set

The strongest reusable RB ideas are not its coefficient values.

They are:
- exact exponential decay;
- bounded exceptional work;
- native-state/provider reuse;
- amount-aware resource transfer concept;
- physical brake-force actuation;
- runtime calibration tooling;
- one settings serializer;
- diagnostics for action registration/control state.

The strongest warnings are:
- multi-hook physical ownership;
- local simulation settings;
- controller-dependent physics;
- private-mod arbitration;
- wrapper-order composition;
- proxy physics where authoritative mechanical work is available.
