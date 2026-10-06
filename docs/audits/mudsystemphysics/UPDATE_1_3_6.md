# MudSystemPhysics 1.3.6.0 update audit

Date: 2026-10-06

## Exact package

- version: `1.3.6.0`
- ZIP SHA-256: `fba0536405f082c3bec2e69452591fe2e051a87d652ee0be66f4124f855601f7`
- package entries: 114
- Lua source: 36 files, 29,412 lines, 1,157,856 bytes
- multiplayer: true
- reusable source license: not found in supplied ZIP
- public distribution currently also states that code reuse outside the system is prohibited; treat source strictly as audit evidence / clean-room functional reference

Compared primarily against:
- current audited 1.3.4.0 rebuild SHA `268f64f03c14ae003c16a6a66d5841485c1cd5a1f82393350593ea00daca1f1e`;
- RC 0.2.0.2 checkpoint `b89a0c6b2ebe6d9efaee95d300c9f066046b5a47`.

## Decision

**KEEP + INTEGRATE.**

Mud remains the physical ground/mud specialist.

The 1.3.6 update is desirable: it improves scheduling, dirtying/caching and Reifen composition without taking over domains that should move to RE.

For the target stack, upgrade recommendation is:

**ADOPT 1.3.6 WITH THE FOCUSED RC COMPATIBILITY HARDENING, THEN RUN THE TARGETED RUNTIME SMOKE.**

The unmodified RC 0.2.0.2 already recognizes 1.3.6 as an eligible 1.3.x runtime-contract candidate and all required Mud symbols remain. Static review nevertheless found one meaningful MR+Mud+Reifen wrapper-order edge introduced by the new Reifen API-v1 call path. The RC research branch closes that edge and improves structural-radius provenance.

## RC compatibility result

### Existing bridges that remain required

- `MRMud` local wetness -> MR;
- MRMud structural-radius separation;
- MRMud Mud-base-resistance suppression under MR;
- MRMud artificial motor-load suppression;
- MRMud puncture-grip consequence;
- MRMud dual/twin support-width composition using `mrTotalWidth`;
- `MudRMS`;
- `MudSoil`;
- `MRTireWear`;
- RC -> RE `ExtensionsStateProvider`.

### Bridges removed

**None.**

### New/changed RC work

1. Mud 1.3.6 is registered as `SOURCE_COMPATIBLE` for MRMud, MudSoil and MudRMS.
2. MRMud consumes Mud's explicit Reifen structural-radius channel when available.
3. ExtensionsStateProvider can expose the same channel directly.
4. MRTireWear is hardened against the exact Mud API-v1 late-wrapper ordering case.

Working RC branch:
- `research/mud-1.3.6-current-base`.

Full RC compatibility audit:
- `FS25_RealismCompatibility/docs/audits/2026-10-06-mud-1.3.6-compatibility-audit.md`.

## Reifen integration changed materially

Mud now exposes:

```
__MudRadiusCombiner.supportsReifenverschleissRadiusChannel = true
__rvOrigRadius
__rvDesiredRadius
```

and publishes the same combiner capability into Reifen's environment.

Mud's own radius owners then use the worn Reifen radius as structural baseline before applying:
- field sink;
- generic mud sink;
- pressure deformation;
- puncture deformation.

This is a strong improvement because it expresses the physical layering directly:

```
permanent worn structure
        ↓
pressure / puncture structural consequence
        ↓
temporary terrain sink
        ↓
final physical radius
```

The exact ordering varies by subsystem, but permanent wear no longer needs to be rediscovered indirectly from an unworn "original" marker.

### Why MRTireWear is still required

Mud's native Reifen bridge solves:
- Mud friction scale × Reifen wear;
- Mud radius ownership × Reifen worn radius;
- Reifen wear -> Mud puncture risk.

It does **not** solve:
- MR healthy terrain/wetness grip × Reifen wear.

Therefore RC MRTireWear remains the correct MR↔Reifen owner.

## New API-v1 wrapper-order caveat

The previous 1.3.4 Mud/Reifen bridge called its captured `getWearAppliedTarget`, which made the prior wrapper-order algebra valid in both directions.

Mud 1.3.6 can instead call:

`getWearAppliedTargetForScale(vehicle, wheel, baseScale)`

directly.

That is a better API because the evaluation baseline is explicit. It also means a Mud wrapper installed outside an already-installed RC wrapper can intentionally bypass that older wrapper.

Normal load order is likely safe because Mud installs at map load and RC uses a delayed bootstrap. But Mud also has a delayed compatibility retry, so an adverse order is possible.

RC now detects only that exact known Mud compatibility wrapper and moves MRTireWear outside it if necessary. It does not attempt to become universally "last".

## TractorTerrainDynamics removal

Mud 1.3.6 temporarily removes its TractorTerrainDynamics compatibility source and no TTD references remain in the package.

Impact on current RC:
- no required MRMud/MudRMS/MudSoil contract disappeared;
- no RC module depended on the removed Mud file;
- no existing RC bridge should be removed.

Decision:
**do not recreate TTD compatibility in RC speculatively.**

If TTD is present in the active modlist, audit the exact TTD version and test what functionality was actually lost. RC should only acquire a TTD bridge if a genuine cross-mod ownership problem is demonstrated.

## Performance architecture worth learning from

### Chunk work, publish state atomically

The local-wetness/hydrology update is now a staged job.

Work is distributed across frames into working buffers. The externally visible committed moisture state is swapped only after a complete pass finishes.

A save during unfinished work uses the last committed complete state.

This is a strong precedent for RE terrain systems:
- spread expensive spatial work over frames;
- never expose a partially updated world to consumers;
- use generation/buffer identity to invalidate caches naturally.

### Explicit evaluation inputs

The coordinated Reifen API can ask for a wear target for an explicit `baseScale`.

This is preferable to temporarily mutating shared wheel state so another mod evaluates against the desired baseline.

General rule:
**pass the baseline/context into cross-mod APIs whenever practical; avoid temporary mutation as an API.**

### Semantic dirtying

1.3.6 avoids unnecessary physical friction/shader updates when the effective value has not changed.

This reinforces a project-wide principle:
- separate "the owner update ran" from "the actuator state changed";
- dirty expensive engine state only for meaningful changes.

### Negative cache with retry

Empty tire visual caches no longer force discovery every call. A timed retry allows late-created resources to appear.

Useful pattern:
**cache failed discovery too, but make the negative cache bounded or generation-aware.**

## Runtime smoke matrix

Before calling the update runtime-verified:

### MR + Mud
- field-local wetness reaches MR friction and rolling resistance;
- MR owns baseline RR;
- Mud keeps sink/slip resistance;
- no stacked artificial motor-load penalty;
- puncture friction remains composed once.

### MR + Mud + Reifen
- low/medium/high wear;
- verify final grip follows MR × Mud × wear exactly once;
- check MRTireWear rewrap counter remains zero in normal order or increments only for the known late-Mud case;
- no integrity warning followed by loss of functional counters.

### Radius composition
Use a worn tire with pressure change and field sink:
- worn structural radius must remain the baseline;
- pressure/sink must remain temporary;
- current physical radius must never be mistaken for structural radius by MR/RE.

### Dual/twin
- RC support-width correction remains active;
- no native Mud `mrTotalWidth` handling appears;
- radius floors are based on the worn structural radius;
- no double support-width bonus.

### MudRMS / MudSoil
- local wetness injection remains live;
- no signature/dispatch regression.

### Local wetness scheduler
- no visible half-updated wetness band;
- save during a running chunk job preserves last committed complete state;
- large field/map frame-time improvement should be measured rather than inferred.

### Lifecycle / MP
- vehicle reset/reload;
- join-in-progress puncture state;
- dedicated server Reifen-driven puncture risk;
- multi-farm wear/puncture parity.

## RE impact

No RE gameplay rewrite is required.

The RC→RE state-provider boundary remains the correct abstraction.

One provider improvement was made in RC: if Mud 1.3.6 exposes the Reifen structural-radius channel, RE can receive it with explicit provenance instead of inferring through unrelated private markers.

## Upgrade verdict

**Yes, this update is worth taking.**

It is mostly an optimization/compatibility release, and its architectural changes are generally improvements.

Use it with the focused RC branch first and run the smoke matrix before promoting the exact hash to the normal verified stack.


## Was the native integration implemented the best possible way?

**No — but several parts are very good.**

The 1.3.6 Mud↔Reifen bridge solves the immediate physics problem competently:
- stable friction baseline is captured;
- Reifen's own wear curve remains authoritative;
- API-v1 accepts an explicit baseline instead of requiring temporary mutation;
- Mud's multiplier is reapplied once;
- worn structural radius is separated from temporary radius effects.

Those are strong decisions.

The implementation is still constrained by an ad-hoc cross-mod environment:
- partner semantics are inferred mainly from function shape;
- Mud publishes its `__MudRadiusCombiner` directly into Reifen's private environment;
- compatibility can install late, making wrapper order observable;
- private `__rv*` fields carry the state contract;
- development/test override wrappers are installed in the normal compatibility path;
- hook teardown is not fully explicit.

A clean-room design for our ecosystem would instead use versioned provider registration and semantic channels:

```
TireWearProvider
  apiVersion
  capabilities
  getWear01(wheel)
  getStructuralRadius(wheel)
  evaluateRelativeGrip(wheel, baseline)
        |
        +--> Mud puncture/radius consumer
        +--> RC/MR grip composition

GroundPhysicsProvider
  physicalWetness
  sink
  resistance
        |
        +--> RC normalized state
        +--> RE consequences
```

One owner would write each final actuator.

Therefore our response is deliberately **not** to reproduce Mud's compatibility architecture. RC only adapts the exact external boundary we cannot change, and the adapter is:
- minimal;
- version/semantic gated;
- identity checked;
- bounded to setup;
- fail-closed for unknown wrappers/future Mud versions.

That is currently the best compromise between architectural purity and compatibility with the mods we actually use.
