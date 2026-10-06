# Native GIANTS AIR backend study for RE pneumatics

Updated: 2026-10-06
Status: research; backend decision intentionally open

## Why this was reopened

The first RDS audit assumed RE would likely own a new compressed-air reservoir.

Crossing RDS with the current FS25 Motorized source and the exact
`soundExpansionMP 1.2.0.0` source shows that this decision is premature.

GIANTS already has a native AIR consumer/fill path and the user's sound stack
already composes with it.

Therefore the first pneumatic prototype must compare a **native-AIR-backed**
backend against a fully RE-owned backend before choosing storage ownership.

## GIANTS native AIR surface

Current FS25 Motorized source exposes an AIR consumer through:

```text
spec_motorized.consumersByFillTypeName["AIR"]
```

The native path already provides concepts for:
- stored AIR fill level/capacity through fill units;
- braking-related consumption;
- refill threshold;
- compressor/refill state (`consumer.doRefill`);
- `spec.lastAirUsage`;
- compressor start/run/stop samples;
- compressed-air / air-release presentation;
- normal vehicle persistence/network infrastructure.

The native algorithm itself is game-oriented and not accepted as the final
physical model merely because the infrastructure exists.

Reference:
https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=698&version=script

## Exact soundExpansionMP evidence

Exact supplied package:
- `FS25_soundExpansionMP 1.2.0.0`;
- SHA-256:
  `51c428cb12d975ee8b7cb555eea4d142b81b0574bc89de63e13c27999b0ca8f4`.

Relevant behavior:
- synchronizes the native AIR consumer `doRefill` state so compressor
  start/run/stop sounds behave correctly in multiplayer;
- its reverse-direction fix wraps `Motorized.updateConsumers` and preserves
  native AIR consumption semantics around reverser behavior.

This means a parallel RE-only reservoir can create a semantic split:
- RE pressure says one thing;
- native AIR fill/compressor/sounds say another.

That is exactly the kind of duplicate authoritative state RE is intended to
remove.

## RDS 1.4 relationship

RDS 1.4 keeps its own:
- `spec.airPressure`;
- governor state;
- leak;
- brake-use model;
- spring-brake state.

It does not make that private pressure the native GIANTS AIR consumer's
authoritative storage.

RDS custom audio includes warning/start/release behavior, while native
compressor-state audio remains a separate ecosystem concern.

This reinforces the need for one canonical air state in RE.

## Backend candidates

### A — Native-AIR-backed state
**Preferred research candidate, not yet accepted.**

Use GIANTS AIR fill-unit state as the stored-air quantity when the vehicle has a
valid AIR consumer.

RE replaces/composes the physical policy:
- compressor flow;
- governor;
- service application demand;
- leakage;
- low-air/spring state.

Preserve where possible:
- fill-unit save/network support;
- native compressor state;
- native vehicle dashboard/sound hooks;
- soundExpansionMP compatibility.

Potential benefits:
- less duplicate persistence/network code;
- vehicle XML capacity/settings can become evidence;
- native sounds remain aligned;
- fewer parallel states.

Risks/questions:
- GIANTS AIR capacity units may be gameplay abstractions rather than literal
  reservoir volume;
- native updateConsumers may need scoped suppression/composition to avoid
  double consumption/refill;
- some vehicles may have AIR consumer configuration only for sounds/legacy
  gameplay and not realistic capacity;
- not every pneumatic vehicle/mod may expose native AIR.

### B — Fully RE-owned reservoir

RE owns stored air, pressure, persistence and network state.

Advantages:
- complete semantics/control;
- consistent physical units;
- independent of questionable native capacity metadata.

Costs:
- bridge/suppress native AIR consumer;
- synchronize compressor/sound/dashboard presentation separately;
- duplicate infrastructure GIANTS already supplies;
- greater MP/lifecycle surface.

### C — two independent authoritative reservoirs
**REJECT.**

Do not keep both native AIR fill and RE pressure as independent truths.

## Capability resolution

Pneumatic capability evidence hierarchy:

1. explicit RE `PneumaticProfile`;
2. trustworthy native GIANTS AIR consumer;
3. stable specialist/provider declaration;
4. curated vehicle override;
5. category heuristic only as a development/fail-soft hint.

Do not repeat RDS's "truck category implies air system" as silent final truth.

Diagnostics should report:
- backend;
- capability source;
- native AIR fill unit/consumer identity;
- resolved profile;
- rejected/fallback reason.

## Conserved quantity — simple isothermal equivalent

Pressure alone is not sufficient for physical transfer.

For a fixed-volume reservoir, use a simple equivalent air amount:

```text
Q = P_abs * V
```

where:
- `P_abs` = absolute pressure in bar;
- `V` = reservoir volume in liters;
- `Q` = equivalent compressed-air amount in bar·L.

Gauge pressure:

```text
P_gauge = P_abs - P_atmosphere
```

This is not full thermodynamics. It is a conservation-friendly game model.

### Equalization example

For two reservoirs:

```text
Q_total = P1_abs * V1 + P2_abs * V2
P_final_abs = Q_total / (V1 + V2)
```

assuming idealized complete equalization and no line losses.

This immediately improves over an absolute `setPressure()` API and makes
truck/trailer transfer capacity-dependent.

## Compressor model

Prefer amount flow instead of direct bar/sec:

```text
airAmountRate = ratedFlow * rpmFactor * efficiency
```

Then:

```text
Q += airAmountRate * dt
P_abs = Q / V
```

Benefits:
- same compressor changes pressure faster in a smaller reservoir;
- different reservoir sizes become meaningful;
- trailer transfer is conservative;
- compressor RPM dependence has a clear domain.

Profiles can define:
- rated flow;
- reference RPM;
- idle flow floor;
- cut-in/cut-out pressure;
- reservoir volume.

Do not calibrate final values from RDS constants.

## Service-brake air demand

Model chamber/circuit fill demand primarily from **positive service-command
change**, not kinetic energy.

Concept:

```text
deltaCommand = max(serviceCommand - previousCommand, 0)
airDemand = effectiveChamberVolume * pressureTarget * deltaCommand
```

Release vents chamber air rather than returning it to the reservoir.

Held steady application:
- initial fill demand already occurred;
- remaining reservoir loss is leakage / additional circuit behavior.

This matches the repeated-application vs held-application distinction identified
in the real-world brake-system reference.

## Spring brake / final actuation

Pneumatic state outputs a normalized forced-brake demand.

It does not:
- set tire friction;
- zero vehicle velocity;
- use a special speed threshold as the physical brake switch.

Final actuation belongs to the active brake/vehicle-physics owner.

## Native backend arbitration

If Native-AIR-backed mode is selected, the implementation must explicitly
arbitrate GIANTS `Motorized.updateConsumers`.

Goal:

```text
native AIR storage/presentation infrastructure
+ RE physical air policy
- native duplicate consumption/refill calculation
```

Do not globally replace `Motorized.updateConsumers`.

A narrow owner-aware scope or upstream/public hook is preferred.

## Sounds

When native AIR backend is active:
- drive native `consumer.doRefill` consistently from the RE governor;
- preserve native compressor samples;
- preserve soundExpansionMP sync;
- reuse native release/compressed-air samples where appropriate.

RE-specific warning:
- low-air buzzer/telltale can remain an RE presentation event.

Do not create duplicate compressor loops.

## MVP backend decision gate

Before implementing full `PneumaticBrakeSystem`, build a source/runtime probe
on representative vehicles:

1. identify native AIR consumer/fill unit;
2. record configured capacity/refill fields;
3. observe save/reload and MP behavior;
4. observe compressor sounds/dashboard values;
5. correlate fill level with native braking;
6. test one mod truck known to use air brakes.

Accept Native-AIR-backed storage only if its units/metadata can be mapped to a
stable RE abstraction without per-vehicle hacks.

Otherwise choose fully RE-owned storage and deliberately bridge native
presentation.

## Future trailer boundary

Trailer air is not MVP.

Before implementation:
- exact-source audit Realistic Brakes 1.3;
- determine its reservoir units/authority;
- define connector state separately from air-transfer state;
- use conservation-aware transfer;
- support hose connection providers (native/manualAttach/Interactive Control)
  without making them pneumatic solvers.
