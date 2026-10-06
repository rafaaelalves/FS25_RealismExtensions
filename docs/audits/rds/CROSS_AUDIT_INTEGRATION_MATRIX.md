# RDS absorption — cross-audit integration matrix

Updated: 2026-10-06
Status: research / implementation deferred

Purpose: preserve the final cross-stack reasoning before native RDS replacement
work begins. This document deliberately crosses the RDS 1.4 exact-source audit
with prior MR, RMS, Reifen, Mud, FarmKit, Dynamic PTO, 4x4, active suspension,
TerraFarm, Persistent Tracks/VMT and RC provider audits.

## Executive architecture

The RDS replacement must not become another monolithic realism mod.

Target ownership:

```text
                           normalized READ state
external specialists ──> RC capability contexts ──> RE StateContract
                                                       |
                                                       v
                                                EngineStartControl
                                                       |
                          intent/action adapters <──────+
                                                       |
                                               authoritative owner

RE PneumaticState/Policy
        |
        +--> BrakeDemand
        |
        +--> BrakeActuatorAdapter --> active brake/vehicle-physics owner

Shared RE presentation consumes revisions/reasons from both.
```

Three explicit layers matter:

1. **state owner** — who computes/holds the authoritative physical state;
2. **decision/orchestration owner** — RE may decide operator policy/readiness;
3. **actuator owner** — MR/RMS/GIANTS/another specialist may own the final
   physical write.

Do not collapse them because one external mod currently bundles all three.

---

## MoreRealistic (MR)

### Relevant audited ownership

MR globally participates in VehicleMotor/control even for many non-converted
vehicles:
- clutch/start-in-gear;
- motor-run checks;
- engine RPM/torque;
- wheel/control;
- engine braking;
- PTO workload.

### RDS assimilation consequence

RE must not:
- set motor torque scale for cold running;
- add a second engine-brake model;
- assume vanilla start-in-gear/clutch semantics are the final path;
- write RPM directly from multiple modules.

Preferred composition:
- `EngineStartControl` owns intent/state-machine UX;
- MR remains motor/drivetrain response owner;
- RC translates only the specific requested state into an MR-owned boundary.

### New opportunity — one engine-RPM demand aggregator

Native PTO already creates an MR minimum-RPM demand from hand throttle.
Future cold-idle and possibly air-compressor fast-idle could otherwise create
additional independent RPM wrappers.

Introduce a conceptual `EngineRpmDemand` aggregator:

```text
sources:
  PTO_HAND_THROTTLE
  COLD_IDLE
  AUX_COMPRESSOR_FAST_IDLE (future, optional)
  other future RE features

effectiveMinRpm = owner-aware composition of active demands
```

The initial composition may often be `max()`, but source/reason/priority and
phase rules must remain explicit.

Important:
- CRANKING is not normal RUNNING idle control;
- do not automatically reset a mechanical-style PTO hand throttle on engine
  start unless a vehicle/profile explicitly requires it;
- one RC/MR adapter should apply the final demand instead of each RE module
  wrapping `vehicle.controlVehicle` independently.

---

## Realistic Mechanical Systems (RMS)

### Relevant audited ownership

RMS already owns:
- engine thermal;
- battery/electrical state;
- starter;
- glow/preheat;
- hard-start/failure state;
- optional parking brake;
- mechanical condition/stress.

Its architecture also provides strong precedents:
- semantic dirty groups;
- full initial stream;
- server-owned persistent state;
- multi-rate scheduling.

### Start integration

Prefer normalized read contexts for:
- engine temperature;
- battery SOC/voltage;
- starter state;
- glow state;
- relevant mechanical block reasons.

Action boundary:
- RE sends crank/contact intent through a narrow adapter;
- final start outcome remains RMS-owned;
- RE transitions to RUNNING only after authoritative motor state confirms it.

Important security finding from the RMS audit:
existing RMS start-button/effect events have controller-validation gaps.
Do not encode those weaknesses into the RE contract. A production adapter should
require a corrected/upstream API or perform server-side controller validation at
the RC boundary.

### Pneumatic / parking-brake overlap

RMS's ordinary parking brake may auto-release for throttle/input or AI.

A low-air spring brake is **not** merely an ordinary player parking-brake
request and must not disappear because the driver applies throttle.

Model separately:

```text
manualParkingRequest
forcedSpringBrakeDemand
releaseAllowed
reason
```

The final brake owner composes these. A pneumatic safety constraint remains
active until pressure permits release.

Do not have RE and RMS both independently force wheel braking.

---

## Reifenverschleiss

Reifen owns persistent tire/track wear and structural tread-radius loss.
MR/Mud/RC own the healthy composed contact/traction baseline.

Pneumatic consequences should therefore enter the system as brake torque/demand,
not as a friction multiplier or forced vehicle speed.

This allows the existing stack to produce natural consequences:
- wheel lock;
- sliding on low grip;
- tire wear/deformation from the actual wheel state.

No new RDS->Reifen bridge is justified merely because spring brakes can skid a
wheel.

---

## MudSystemPhysics

Mud owns:
- local physical wetness;
- sink/resistance/stuck;
- tire pressure;
- wheel-ground state.

This reinforces the brake-demand architecture:
RE should not decide that a spring brake makes a vehicle immobile at a special
speed threshold. The final wheel-ground stack decides whether available engine
torque can drag the applied brakes on the current surface.

Ambient/start temperature also must not be inferred from Mud's physical-ground
wetness/freeze state. Thermal/environment and soil-state domains remain separate.

---

## Dynamic/native PTO

The PTO assimilation produced several reusable precedents:
- evidence-backed vehicle capability profiles;
- event/revision-driven public state;
- hot-path cache by revision;
- state/presentation separation;
- owner-specific RC translation rather than persistent motor mutation;
- collision-safe inputs and observable action registration.

Apply the same principles to start/pneumatics.

### Potential start interlock

Some real machines may require PTO disengaged for starting.

If supported:
- add an explicit profile/interlock capability such as
  `requiresPtoDisengaged`;
- `InterlockFacet` consumes the native RE PTO public state;
- do not invent a universal PTO-start interlock from category/name heuristics.

---

## 4x4 traction audit

The strongest reusable pattern was:

```text
sensors -> normalized demand / pure decision -> actuator
```

Apply this directly to pneumatics:

```text
pressure/circuit state
        |
        v
BrakeDemandModel
  serviceDemand01
  springDemand01
  parkingDemand01
  reasonMask
        |
        v
BrakeActuatorAdapter
        |
        v
active physical owner
```

Benefits:
- testable pure decision layer;
- explainable reasons;
- no duplicate wheel/drivetrain physics;
- easy future provider replacement.

---

## Active/hydraulic suspension audit

The key lesson was **compose against the baseline; do not seize ownership and
discard later owner writes**.

For start/brakes:
- read the specialist baseline/state;
- output a normalized correction/demand;
- compose once at the physical owner boundary.

Do not implement RDS-style direct shared-state writes merely because they are
easy to observe.

The split-rate controller precedent also supports 100–250 ms pneumatic physics
with fast visual/input actuation only where needed.

---

## FarmKit + soundExpansionMP

### Audited sound ownership

Current stack reasoning:
- MR: engine RPM/load synthesis;
- FarmKit: optional spatial propagation of drivetrain samples;
- soundExpansionMP: extra operational/MP sounds.

Exact `soundExpansionMP 1.2.0.0` additionally matters for RDS assimilation:
it synchronizes the GIANTS native AIR consumer `doRefill` state so native
compressor start/run/stop audio works in multiplayer, and it fixes native AIR
consumer direction handling under reverse/reverser behavior.

### Consequence

Do not build a parallel compressor-sound owner by default.

Prefer:
- reuse native vehicle compressor/air-release samples when the native AIR
  backend is active;
- low-air buzzer remains a separate warning presentation;
- starter/crank audio follows the specialist start owner when one exists;
- avoid duplicate Realistic Brakes parking/air sounds if that mod is active.

A future presentation contract can expose semantic events such as:
`STARTER_ACTIVE`, `AIR_COMPRESSOR_LOADED`, `LOW_AIR_WARNING` without
requiring every gameplay module to manage sound samples directly.

---

## Native GIANTS AIR consumer

This is a major cross-audit result.

FS25 Motorized already has an AIR consumer path with:
- fill-unit storage;
- brake-related air consumption;
- refill threshold/state;
- `consumer.doRefill`;
- native compressor start/run/stop sounds;
- compressed-air/release sound support;
- save/network behavior inherited from native fill-unit/motorized systems.

Therefore the first RE pneumatic prototype must compare:
1. **Native-AIR-backed** state;
2. fully RE-owned reservoir.

Reject a permanent hybrid with two independent authoritative air reservoirs.

The native AIR implementation is not necessarily physically sufficient — its
consumption/refill algorithm is still game-oriented — but its persistence,
network and presentation infrastructure may be valuable to retain.

See `NATIVE_AIR_BACKEND.md`.

---

## Realistic Brakes

Public 1.3 behavior indicates overlap in:
- manual/parking brake;
- engine/Jake brake;
- brake thermal/fade;
- trailer air hoses/reservoir/spring brake;
- RDS truck-air integration.

Exact source has not yet been audited.

Therefore:
- do **not** absorb engine brake/Jake/fade as part of the RDS project;
- do not implement trailer-air final ownership before an exact Realistic Brakes
  audit;
- first RDS replacement milestone may own tractor/truck pneumatic supply state
  only;
- the trailer phase requires a separate ownership decision.

---

## SoilCompaction / RealisticHarvesting

No direct start/pneumatic owner collision exists.

The important reusable lesson from MR+Soil harvest composition is
**exactly-once semantic translation**.

Do not independently multiply:
- glow difficulty;
- fuel cold factor;
- ADS/RMS hard-start effect;
- temperature penalty

if one owner already incorporated another factor.

Every adapter must document:
- input domain;
- output domain;
- factors already included;
- factors still missing.

This motivates a canonical start-readiness/outcome model rather than ad-hoc
multipliers.

See `START_MODEL.md`.

---

## TerraFarm audit

The reusable pattern is:

```text
generic inference
 -> semantic-family defaults
 -> declarative profile override
 -> runtime sanity validation
```

Apply it to:
- `StartProfile`;
- `PneumaticProfile`.

Candidate declarative fields:
- fuel/preheat technology;
- start interlock strategy;
- optional PTO-start interlock;
- reservoir volume/capacity;
- normal/cut-in/cut-out/low-air pressure;
- compressor flow curve;
- service-chamber demand;
- spring apply/release thresholds;
- circuit/trailer capability.

Profiles should be data, not long Lua filename chains.

Developer tooling should report:
- resolved profile;
- source;
- rejected/stale override;
- fallback reason.

---

## Persistent Tracks / Visual Mud Tracks

No direct start/pneumatic integration is justified.

Only generic architecture lessons carry over:
- server-owned persistent state;
- revisions/sequence IDs;
- bounded work;
- lifecycle cleanup;
- presentation separated from physical state.

Do **not** create spatial/chunk infrastructure for vehicle start/air state; that
would be unnecessary complexity.

---

## RC / RE provider architecture

RE already has `RealismExtensionsState` and RC already exposes an aggregate,
reuse-first provider.

Do not create parallel direct per-mod provider systems inside EngineStartControl.

Preferred evolution:

```text
RC aggregate provider
  getWheelContext()       existing
  getStartContext()       future
  getMechanicalContext()  future/when justified
  getPneumaticContext()   future/when external owner exists
          |
          v
RE StateContract
```

Each context should have its own version so extending START does not invalidate
WHEEL consumers.

Read-only state and mutation must remain separate.

Conceptual action side:

```text
RE intent
  -> RE Interop/ActionContract
  -> RC owner adapter
  -> external authoritative action
```

Examples:
- request crank through RMS/ADS;
- apply final forced brake demand through RMS/MR owner;
- request fuel-system priming only if a public owner capability exists.

This keeps gameplay modules free of private external-mod tables.

---

## Final cross-audit conclusion

No prior major audit reverses the RDS functional-absorption decision.

They collectively make the implementation boundary stricter:

- **RE owns interaction/policy and genuinely missing pneumatic state**;
- **RC normalizes or adapts active specialist ownership**;
- **MR/RMS/Mud/Reifen continue to own their physical domains**;
- **GIANTS native AIR should be reused where it provides valuable state
  infrastructure**;
- **profiles are declarative and evidence-backed**;
- **state reads, decisions and physical actuation stay separate**;
- **all persistent/stochastic mechanical outcomes are server authoritative**;
- **translation is exactly once and provenance-aware**.
