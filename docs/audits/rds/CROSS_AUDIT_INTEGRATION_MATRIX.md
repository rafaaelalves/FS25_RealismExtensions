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

### Native AIR under MR

Exact MR 0.26.08.03 source overwrites `Motorized.updateConsumers` and
reimplements the AIR consumer block.

MR changes brake detection to use its wheel brake-pedal state, but keeps the
native-style:
- AIR fill-unit consumption;
- refill threshold;
- `consumer.doRefill`;
- refill amount.

Therefore a native-AIR-backed RE pneumatic policy must compose at the **effective
MR owner path**, not assume vanilla Motorized remains the final writer.

The user's exact soundExpansionMP then wraps this same consumer path for
reverser behavior and synchronizes `doRefill` for compressor audio.

Target RC behavior:
- suppress only the existing AIR calculation during the effective owner call;
- preserve MR fuel/DEF/other consumers;
- apply RE pneumatic policy exactly once to the same AIR storage;
- leave final `consumer.doRefill` in the RE-authoritative state before
  sound/presentation consumers observe it;
- restore any scoped owner state immediately.

Do not permanently replace/nil the whole consumer table.

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

## Realistic Brakes — exact 1.3 source closure

Exact package:
- `FS25_RealisticBrakes 1.3.0.0`;
- SHA-256 `c6cec8b89fb7bf409ee55f2a2421b989ff7392da0f5c5dedf65bc5d76912aa05`.

The former source gate is closed.

Capability result:
- **engine/Jake brake**: direct MR conflict; do not run two physical owners;
- **parking brake**: useful but overlaps RMS/Enhanced Vehicle and spans several
  wheel/control hooks;
- **service-brake thermal/fade**: distinct, valuable future capability; not
  inherently owned by MR/RMS, but service/condition ownership must be explicit;
- **trailer pneumatic/spring brake**: directly useful to the RDS roadmap and
  closes the exact trailer integration gap;
- **HUD/audio/settings**: presentation/reference only.

Exact trailer lessons now added to the RDS target:
- red supply/emergency and yellow service/control lines are separate state;
- ConnectionHoses is a good connector-state provider;
- transfer must be finite and conservation-aware;
- tractor protection/reserve is required;
- trailer service applications must consume modeled air;
- trailer leakage/persistence/network state are required;
- spring/service wheel groups must remain representable;
- brake actuator capacity must not depend on assumed tire-road friction;
- detached trailer pneumatic state must remain authoritative;
- GIANTS Attachable `airConsumer#usage` is useful native metadata for P0.

Do not expand RDS absorption into RB's engine/Jake or general parking subsystem
merely because exact source is now available.

Full audit:
`../realistic-brakes/README.md`.

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


# Final transversal pass additions — 2026-10-06

This section is the final "did we cross every prior audit?" ledger before the
RDS work is intentionally parked.

## Audit coverage ledger

| Prior audit/domain | Rechecked for RDS absorption | Concrete consequence |
|---|---:|---|
| MoreRealistic | yes | motor/clutch/brake/RPM/AIR final-owner boundaries; AutoDrive hybrid fallback; no duplicate engine brake |
| RMS | yes | preheat/start facade mode, electrical/thermal authority, parking-brake composition, service/security precedents |
| ADS / historical RDSADS | yes | held hard-start outcome, secure action adapter requirement, legacy bridge remains exact-version gated |
| MudSystemPhysics | yes | no pneumatic->friction shortcut; wheel-ground stack decides drag/skid; wetness is not thermal state |
| Reifenverschleiss | yes | brake demand should create real wheel slip/force consequences; no direct RDS->Reifen bridge |
| Dynamic/native PTO | yes | collision-safe inputs, revisioned state, profile resolution, PTO-start interlock option, shared RPM-demand concern |
| realistic 4x4 | yes | sensors -> pure demand/decision -> actuator pattern reused for brakes |
| hydraulic suspension | yes | compose corrections against physical owner; do not seize baseline writer |
| FarmKit | yes | fragmented HUD is not a clone target; engine/spatial-sound ownership remains external |
| soundExpansionMP | yes, exact source | native AIR `doRefill` is already an MP/audio contract; avoid parallel compressor sound/state |
| SoilCompaction / RealisticHarvesting | yes | exactly-once translation/provenance rule generalized to start factors |
| TerraFarm | yes | declarative profile hierarchy + runtime sanity validation |
| Persistent Tracks / VMT / True AI Tracks | yes | only lifecycle/revision/bounded-work precedents apply; no direct RDS integration |
| Reifen workshop/persistence | yes | reinforces server authorization, lifecycle cleanup and no local-only mechanical persistence |
| project StateContract/provider | yes | requires capability-version refactor before START can be added safely |
| Realistic Brakes 1.3 | yes, exact source | trailer/RDS gap closed; MR engine-brake conflict, RMS/EV parking overlap, service thermal/fade candidate, ConnectionHoses/native AIR lessons |

No previous audit uncovered a reason to cancel RDS functional absorption.
Several did narrow the allowed implementation boundary.

---

## New architecture correction — StateContract must be capability-optional

Current `RealismExtensionsState` validates one provider by requiring:
- provider API v2;
- wheel context v2;
- `getWheelContext()`.

That is appropriate for current TerrainDeformation consumers, but it must **not**
become an accidental dependency of native engine-start behavior.

Standalone RE start must work with:
- GIANTS Motorized state;
- RE profiles;
- no RealismCompatibility installed.

External specialist state should be optional enrichment through RC.

### Target provider-info shape

Do not bump one global context version every time a new capability is added.

Conceptual:

```text
providerInfo {
    apiVersion = 2,
    capabilities = {
        WHEEL = { version=2 },
        START = { version=1 },
        MECHANICAL = { version=1 },
        PNEUMATIC = { version=1 }
    }
}
```

Rules:
- provider protocol/API major changes remain explicit;
- each context has its own version;
- TerrainDeformation validates only WHEEL;
- EngineStartControl requests START if available and fills missing fallback
  state from native GIANTS/profile logic;
- absence of RC does not disable standalone RE start;
- a START provider must not be forced to implement WHEEL merely to register.

This should be solved in S0 before start gameplay code.

---

## Single-owner facts vs multi-contributor constraints

The "facets" model needs one more distinction.

Some values normally need **one authoritative source**:
- engine temperature;
- battery voltage/SOC;
- final starter state;
- final motor-running state.

Other start conditions can have **multiple independent contributors**:
- interlocks: neutral + clutch + brake + PTO + provider-specific;
- fuel: low cetane + air in line + blocked filter + starvation;
- hard blocks from several owners;
- advisory/reason state.

Therefore do not implement every facet as:
`owner -> one scalar`.

Use two semantic classes:

```text
AuthoritativeChannel<T>
    value
    owner
    revision

ConstraintSet
    contributors[]
    hardBlocks[]
    modifiers[]
    provenance
```

Example:

```text
RMS fuel subsystem: clogged filter
Diesel Fuel provider: low cetane
RE profile: glow ready
ADS electrical: starter healthy
```

Both fuel causes may legitimately exist. One must not erase the other merely
because they share the word "fuel".

Composition still follows exactly-once provenance; two adapters must not expose
the same physical cause under different labels.

---

## Controller-policy layer — PLAYER / GIANTS AI / Courseplay / AutoDrive

RDS and Realistic Brakes both solved AI deadlocks by bypassing/mutating parts of
their simulation. The cross-audits show a cleaner rule:

**controller policy may skip human interaction, but must not silently disable
physical safety state.**

Conceptual:

```text
PhysicalState
    start readiness
    air pressure
    spring-brake demand

ControllerPolicy
    PLAYER       -> manual gesture
    GIANTS_AI    -> automatic preparation
    COURSEPLAY   -> automatic preparation + controller adapter
    AUTODRIVE    -> automatic preparation + controller adapter
```

Important MR consequence:
- MR deliberately bypasses its central wheel-control implementation for active
  AutoDrive;
- therefore spring-brake actuation must sit at a physical boundary that remains
  effective under that fallback;
- do not attach forced spring-brake behavior only to the player/controller
  command layer.

Runtime acceptance must prove forced low-air brake demand survives:
PLAYER / GIANTS_AI / COURSEPLAY / AUTODRIVE.

For start:
- controller code that calls motor start directly must not bypass authoritative
  readiness;
- automatic controllers use the same server transition graph with a different
  interaction policy.

---

## Safe load/join ordering

Crossing Reifen/RMS lifecycle findings with pneumatic persistence exposes a
specific safety gate.

If a vehicle/trailer loads with insufficient air:
1. restore authoritative storage state;
2. derive low-air/spring-brake demand;
3. install/apply final brake constraint;
4. only then allow ordinary vehicle wake/motion.

Do not permit:
```text
vehicle physics active
 -> one frame of free roll
 -> spring brake restored later
```

The same applies to a disconnected trailer loaded with an empty reservoir.

Join-in-progress requires the initial state before presentation/control is
considered ready.

---

## Connected-resource lifecycle — learn from RMS external power

Truck/trailer air transfer is a paired-resource problem.

Future connector rules:
- each vehicle persists its own reservoir, never a direct Lua object reference
  to the partner;
- hose/attachment connection is transient topology;
- pair solve exactly once per server step;
- transfer is symmetric/conservative;
- detach/delete invalidates both sides immediately;
- stale partner references fail closed;
- connection action is server-validated.

This directly avoids the class of stale reciprocal-reference defect already
identified in RMS external-power deletion.

ManualAttach / Interactive Control may provide **connection state**, not
permission to mutate air amount client-side.

---

## Pneumatic condition/service ownership gate

The first RDS audit correctly rejected vanilla `damageAmount` as the leak-health
signal. The deeper question is: who owns pneumatic degradation?

Do not answer this implicitly during P1.

### MVP
- profile baseline leakage;
- explicit externally supplied fault/condition if available;
- no random RE brake-system wear/failure model.

### Future
If compressor/line/chamber degradation is desired, prefer:
1. an RMS-side extensible subsystem/service API; or
2. a small normalized condition contract that RMS/workshop can consume.

Only create a separate RE pneumatic condition/service lifecycle if no mechanical
owner can represent the capability cleanly and the feature is valuable enough
to justify independent persistence/service UX.

Avoid ending with:
- RMS mechanical workshop;
- Reifen tire workshop;
- RE pneumatic workshop;
- Realistic Brakes service UI

all independently pricing adjacent vehicle maintenance.

RMS's Condition / Stress / Service separation remains the preferred conceptual
model for future pneumatic degradation.

---

## Brake demand must be extensible beyond one scalar

A single `springDemand01` is adequate for an MVP, but do not freeze the public
contract around "all wheels receive the same brake".

Air-brake systems can have:
- primary/secondary service circuits feeding different wheel groups;
- service chambers with different effective areas;
- spring chambers only on selected axles;
- trailer circuits.

Official air-brake reference confirms dual service circuits and wheel-specific
chambers, while spring brakes are a separate subsystem.

Future-compatible demand shape:

```text
BrakeDemand {
    service {
        global01
        wheelGroups[] optional
    }
    spring {
        global01
        wheelGroups[] optional
    }
    manualParking {
        global01
        wheelGroups[] optional
    }
    reasonMask
}
```

MVP may fill only global values; the adapter API remains evolvable.

Do not model low pressure as tire-friction reduction.

---

## Compressor engine consequence — reserve, do not fake

RDS models compressor pressure but no mechanical compressor power demand.

A future higher-fidelity model may add:
- compressor torque/power demand while loaded;
- optional governor/fast-idle RPM request.

Rules:
- do not add synthetic "engine load percentage";
- translate real auxiliary power/torque demand into the active MR/GIANTS engine
  owner;
- keep RPM request separate from power demand;
- do not create a generic `AuxiliaryPowerDemand` bus until a second real
  consumer justifies it.

The existing `EngineRpmDemand` candidate remains valid for:
- PTO hand throttle;
- cold idle;
- optional compressor fast idle.

If compressor power becomes real, exactly-once provenance is required so RMS
electrical/other owners do not count the same accessory demand twice.

---

## Presentation hierarchy — dashboard before extra HUD where possible

RDS grew a large overlay partly because every state was presented externally.

For native RE, presentation preference should be:

1. native/in-cab dashboard value/telltale when a safe vehicle interface exists;
2. shared RE HUD semantic slot;
3. warning toast only for transition/attention state.

Probe native AIR dashboard/sound behavior during P0.

The shared HUD remains important, but "unified HUD" should not mean "duplicate
every gauge already present in the cab".

---

## Legacy RDS save migration opportunity

Exact RDS 1.4 persists:

```text
<vehicle>.realDieselStart#airPressure
<vehicle>.realDieselStart#engineHeat
<vehicle>.realDieselStart#lastStamp
```

When external RDS is eventually retired, a one-time migration can preserve the
only state that is truly valuable across ownership change.

Candidate policy:
- import legacy air pressure only after the target pneumatic backend/profile is
  known;
- convert pressure into the target stored-air domain conservatively;
- apply bounded elapsed leakage using an explicit time basis;
- do **not** inject RDS `engineHeat` into RMS/ADS thermal state;
- mark migration schema/version so it runs once;
- log source and conversion.

If native AIR becomes the backend, migration needs an explicit bar -> stored-air
mapping and must wait until P0 proves native capacity semantics.

Migration is optional compatibility polish, not permission to preserve flawed
RDS algorithms.

---

## Realistic Brakes 1.3 preliminary boundary

Current public 1.3 material (2026-10-04) reports:
- manual/parking brake;
- dynamic engine braking;
- reinforced/Jake-style engine braking;
- brake temperature/fade/failure;
- trailer air reservoir and spring brakes;
- hose connection through manualAttach / Interactive Control;
- RDS truck-air integration;
- AI bypass behavior;
- Enhanced Vehicle coexistence.

This is enough to establish an ownership **gate**, not enough for source
findings.

Before P4/trailer work, exact source must answer:
- who owns final wheel brake force and at which hook;
- whether parking force is modeled as an actuator limit or recomputed from
  vehicle weight/slope;
- how engine/Jake braking collides with MR's existing engine-brake owner;
- brake thermal/fade cadence/authority;
- trailer reservoir units and equalization/conservation;
- spring-brake wheel/axle scope;
- hose connection authority/network lifecycle;
- AI bypass semantics;
- Enhanced Vehicle arbitration;
- save/MP state;
- cleanup on detach/delete.

Until that audit, do not broaden RDS assimilation into "all realistic brakes".

---

## Final negative-space check

The following prior domains were deliberately checked and produce **no direct
RDS integration** today:
- SoilCompaction;
- RealisticHarvesting processing;
- terrain deformation/recovery;
- persistent visual tracks;
- crop interaction;
- loose-load/spill;
- tire pressure/CTIS.

Only generic architecture precedents carry over.

This is intentional. Do not manufacture integrations merely because the systems
exist in the same realism stack.


## Realistic Brakes 1.3 — exact-source cross-audit result

The former public-description-only gate is now closed.

Exact supplied baseline:
- 1.3.0.0;
- SHA-256 c6cec8b89fb7bf409ee55f2a2421b989ff7392da0f5c5dedf65bc5d76912aa05.

### What RB actually owns

Independent capability owners inside the same mod:
- parking brake;
- engine/exhaust/Jake-style braking;
- service-brake thermal/fade/damage;
- trailer reservoir/hoses/spring brake.

Do not make one KEEP/ABSORB decision for all four.

### MR result

RB engine braking directly writes:
- lowBrakeForceScale;
- lowBrakeForceSpeedLimit;
- automatic setGear requests.

This is a confirmed direct collision with MR's engine-brake/drivetrain owner.

If RB enters the target stack, this submodule requires disable/demand-translation
before being considered clean.

### RMS / Enhanced Vehicle result

RB deliberately neutralizes Enhanced Vehicle parking state through EV private
tables.

RMS also has parking-brake ownership and already arbitrates against EV.

Therefore RB + RMS + EV cannot be assumed compatible merely because each pair
contains coexistence logic.

One final parking owner must be selected.

### Trailer result

Useful:
- native ConnectionHoses state;
- persisted trailer pressure;
- conservation-inspired equalization;
- custom wheel brake force;
- native air-release sample reuse.

Missing/incorrect:
- service vs supply hose distinction in spring-brake decision;
- finite flow;
- tractor protection;
- trailer service-air demand;
- leakage;
- spring/service priority;
- wheel-group topology;
- trailer pressure MP stream;
- full controller coverage.

### Native AIR result

FS25 attachables already expose airConsumer#usage.

The native AIR P0 probe is expanded to include trailer/implement demand metadata,
not only towing-vehicle storage/refill state.

### Thermal result

RB brake thermal/fade is a genuinely separate phenomenon not currently owned by
RMS engine/transmission thermal.

It remains an interesting future capability, but its current heat algorithm is
pedal/speed/mass based rather than actual dissipated brake work and its damage
repair is coupled to generic vehicle damage.

### Controller result

RB source confirms why the final RDS controller principle matters:
external mods often fix AI freezes by disabling physics.

RE should instead preserve physical state and vary only interaction policy.

Full audit:
../realistic-brakes/README.md
