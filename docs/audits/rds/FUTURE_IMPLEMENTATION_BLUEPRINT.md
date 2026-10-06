# RDS functional replacement — future implementation blueprint / return handoff

Updated: 2026-10-06
Status: **DEFERRED — research package complete, no implementation requested**

Purpose: when this work is resumed in a future chat/session, this file is the
entry point. It preserves sequencing, unresolved gates, ownership rules,
features worth keeping, rejected shortcuts and external audits still required.

## Read order when returning

1. `docs/audits/rds/README.md`
2. **this file**
3. `CROSS_AUDIT_INTEGRATION_MATRIX.md`
4. `ABSORPTION_ARCHITECTURE.md`
5. `START_MODEL.md`
6. `PNEUMATIC_MODEL.md`
7. `NATIVE_AIR_BACKEND.md`
8. `DESIGN_LESSONS.md`
9. `PERFORMANCE_AND_LIFECYCLE.md`
10. `RUNTIME_TEST_PLAN.md`
11. `REALISTIC_BRAKES_PREAUDIT.md`
12. `SOURCE_DIFF_1_2_TO_1_4.md`
13. `STATIC_FINDINGS.md`
14. ADR `0006-rds-functional-absorption.md`

Do not restart by reading RDS source from zero unless upstream changed.

## Canonical evidence

Exact RDS current baseline:
- `FS25_RealisticDieselStart 1.4.0.0`;
- SHA-256:
  `a2a983c7754bc4fb3dffc04839fb16cf844c72d7664ae78cfcd70fcf3c15721c`.

Previous exact baseline:
- RDS 1.2.0.0;
- SHA-256:
  `e22816e712ef6a48c8f0210209f9983a7c4da3bc55a6267a7fbaad5c5f6bacbd`.

Exact cross-source:
- soundExpansionMP 1.2.0.0;
- SHA-256:
  `51c428cb12d975ee8b7cb555eea4d142b81b0574bc89de63e13c27999b0ca8f4`.

Existing audited owners:
- MR 0.26.08.03;
- RMS 0.10.0.0;
- Reifen 1.2.2.67;
- current Mud 1.3.4.0 line;
- current native PTO feature research/implementation;
- RC historical RDSADS for RDS 1.2.

## Final replacement decision

Functional replacement remains recommended.

Do not port RDS as a monolith.

Target capability modules:

```text
StartProfileResolver
StartCapabilityResolver / normalized StartContext
EngineStartControl
Start Action/Interop adapters
Shared RE HUD slots

PneumaticProfileResolver
PneumaticBrakeSystem
BrakeDemandModel
BrakeActuatorAdapter
Pneumatic backend (native AIR or RE-owned; decision pending)
```

Optional future shared infrastructure:
- `EngineRpmDemand` once there is a second real RPM-demand consumer;
- semantic presentation/audio events.

## Non-negotiable ownership rules

### RE may own
- ignition/contact/crank operator UX;
- diesel/preheat profile semantics;
- orchestration and explainable readiness;
- genuinely missing pneumatic physical policy/state;
- low-air/spring-brake **demand**;
- shared HUD/presentation state.

### RE must not silently own
- MR motor torque/drivetrain;
- RMS/ADS battery/starter/failure state;
- generic mechanical damage;
- Reifen/Mud tire-ground physics;
- RMS parking-brake final physics;
- engine/Jake brake and brake fade as incidental RDS scope;
- a second independent AIR reservoir beside a native authoritative AIR backend.

## Existing architecture to reuse

### State reads

Extend the existing:

`RealismExtensionsState <- RC RealismCompatStateProvider`

Do not create per-mod direct reads in gameplay modules.

Future state contexts can include:
- START;
- MECHANICAL;
- PNEUMATIC only where another owner exists.

Version contexts separately.

### Actions

Read-only state contract is not an action bus.

Create a narrow action/interop contract for:
- crank/contact intent to RMS/ADS/GIANTS;
- final brake-demand application to an external physics owner;
- other owner mutations only when a concrete need exists.

Private external tables stay in RC adapters if unavoidable.

## Start implementation sequence

### Phase S0 — contract skeleton / no behavior replacement

Deliver:
- `StartProfileResolver`;
- `StartContext` contract shape;
- capability owner/provenance diagnostics;
- no RDS suppression yet.

Prove:
- diesel / non-diesel / electric classification;
- existing RC provider contract can evolve without breaking wheel consumers;
- exact profile resolution is stable.

### Phase S1 — standalone operator UX

Deliver:
- complete input state machine with no 400/550 ms dead band;
- collision-safe action registration;
- OFF / IGNITION / PREHEAT / READY / CRANKING / RUNNING;
- GIANTS-native fallback state;
- server-authoritative transitions;
- shared HUD slot.

Use GIANTS before duplicating:
- motorTemperature;
- neutral;
- real clutch state where usable;
- getCanMotorRun;
- MotorState.

Do not add:
- generic cold damage;
- direct torqueScale;
- universal synthetic clutch.

### Phase S2 — RMS facet adapters

Add:
- thermal;
- electrical/starter;
- glow;
- hard-start outcome.

Requirements:
- fix/guard RMS start-event controller-authority gaps;
- do not write RMS private tables from RE core;
- wait for authoritative start completion.

### Phase S3 — ADS/fuel facet adapters

ADS:
- reproduce useful RDS 1.4 held hard-start behavior without private core
  coupling;
- compare against historical RC RDSADS.

Fuel specialist:
- support optional cold-start factor/block reason semantics;
- keep fuel facet independent from starter/electrical facet.

### Phase S4 — retire external start owner

Only after standalone + RMS + ADS paths pass runtime/MP gates:
- native RE start becomes authoritative;
- external RDS start path can be disabled/removed from test stack;
- retire obsolete RC RDSADS paths deliberately, not before evidence.

## Canonical start algorithm direction

Hard blocks separate from stochastic difficulty.

If no specialist owns final start:
- fixed server cadence;
- continuous-time hazard:
  `pCatch(dt)=1-exp(-lambda*dt)`;
- lambda composed from explicitly missing readiness facets;
- no frame-rate-dependent random roll.

If specialist owns final start:
- do not run standalone hazard;
- translate only missing RE-owned factor exactly once;
- send intent and observe outcome.

Every adapter documents factors already included.

## Profile strategy

Use the TerraFarm-derived pattern:

```text
native inference
 -> semantic family default
 -> declarative evidence override
 -> runtime sanity validation
```

### StartProfile candidates
- fuel class;
- glow/preheat technology;
- preheat curve;
- clutch/neutral/brake interlock;
- optional PTO-start interlock;
- optional cold-idle behavior;
- dashboard/presentation semantics.

### PneumaticProfile candidates
- backend preference;
- reservoir volume;
- pressure limits;
- governor cut-in/cut-out;
- low-air threshold;
- spring apply/release thresholds;
- compressor flow/reference RPM;
- service chamber demand;
- circuit family;
- trailer capability.

Unknown equipment fails conservatively rather than acquiring fake realism.

## Engine RPM demand — do not forget

PTO already creates a hand-throttle minimum-RPM demand.

Potential future RDS-derived consumers:
- cold idle;
- compressor fast idle.

When a second real consumer exists:
- introduce one `EngineRpmDemand` aggregator;
- one final RC/MR adapter;
- reason/source telemetry;
- do not stack independent controlVehicle wrappers.

Do not reset mechanical PTO hand throttle on start by default.

## Pneumatic implementation sequence

### Phase P0 — native AIR probe

Before creating a reservoir:
- inspect representative native AIR consumers;
- record fill units/capacity/refill metadata;
- verify save/reload/MP;
- verify dashboard/sounds;
- verify soundExpansionMP behavior.

Decision:
- Native-AIR-backed or fully RE-owned storage.

Never dual-own.

### Phase P1 — single-vehicle equivalent reservoir

Physical policy:
- equivalent stored air `Q=P_abs*V`;
- RPM-aware compressor amount flow;
- governor hysteresis;
- service application based on positive command change;
- leakage separately;
- low-air state;
- spring-brake forced demand;
- save/MP/HUD.

No trailer yet.

### Phase P2 — brake actuator composition

Output normalized BrakeDemand.

Compose with:
- RMS parking/vehicle physics if active;
- MR/GIANTS final brake path as appropriate.

Low-air spring brake cannot be auto-released by an ordinary parking-brake
throttle/AI policy.

Do not modify tire friction.

### Phase P3 — optional compressor engine consequence

Only if calibration justifies:
- auxiliary compressor engine load;
- optional compressor fast-idle demand;
- one MR/engine owner adapter;
- no fake load percentage.

### Phase P4 — trailer air

Blocked until exact-source Realistic Brakes audit.

Then:
- connection state;
- truck/trailer reservoir capacities;
- conservation-aware transfer/equalization;
- emergency/supply semantics;
- manualAttach/Interactive Control only as connector providers.

## Realistic Brakes audit gate

Before trailer-air or generalized brake simulation:
- obtain exact current Realistic Brakes source;
- audit manual parking brake;
- spring brakes;
- engine/Jake brake;
- fade/temperature;
- trailer reservoir;
- hoses;
- Enhanced Vehicle ownership;
- AI bypass;
- RDS API usage.

Do **not** absorb engine/Jake/fade simply because it is adjacent to pneumatics.

## Audio/presentation rule

Prefer one sound owner per semantic event.

Native AIR backend:
- keep native compressor start/run/stop;
- preserve soundExpansionMP MP sync;
- reuse native compressed-air/release samples where suitable.

RE may own:
- low-air buzzer/telltale;
- consolidated start/glow/pneumatic HUD.

Starter audio:
- specialist owner wins when specialist owns crank mechanics.

Do not duplicate Realistic Brakes parking/spring sounds later.

## Shared HUD direction

Do not reproduce RDS `withADS/withoutADS` coordinate branches.

Use semantic slots:
- START_STATUS;
- ENGINE_WARNING;
- PTO_STATUS;
- PNEUMATIC;
- MECHANICAL_STATUS.

Cache geometry by UI-scale/aspect/HUD revision.

Useful RDS 1.4 lessons:
- UI-scale event invalidation;
- width/height aspect-aware normalization;
- pixel snapping;
- per-vehicle owner checks;
- dev calibration commands.

Remove dead resources when presentation is retired.

## Multiplayer/configuration

Separate:

```text
LocalPreferences
SimulationConfig
DevCalibration
```

Server/save authority:
- start simulation rules;
- pneumatic config;
- stochastic outcomes.

Local:
- HUD visibility/layout;
- local key mapping;
- presentation preference.

Client sends intent; server derives outcomes.

All action events validate controlling connection and legal transition.

Full initial state is required.

## AI/controller rules

AI skips gestures, not physical readiness.

Need explicit paths for:
- GIANTS AI;
- Courseplay;
- AutoDrive.

Do not solve AI deadlock by creating free persistent air.

Use bounded preparation/readiness state and diagnostics.

## Performance architecture

Do not run every concern every frame.

Suggested:
- active held-key interaction: frame only while active;
- HUD: draw;
- start provider snapshots: revision/event or 100–250 ms;
- pneumatic physics: 100–250 ms server fixed cadence;
- offline leak: elapsed-time reconciliation;
- warnings: change-driven;
- transient one-shot tasks: existing RE scheduler.

Reuse caches and revisions.

Profile before calling any static hot path a bottleneck.

## Explicitly rejected RDS behaviors

Do not reproduce:
- every motorized non-electric vehicle = diesel;
- 400–550 ms input timing hole;
- universal synthetic clutch;
- duplicate engineHeat when authoritative thermal exists;
- direct cold `motor.torqueScale`;
- speed>8 cold damage;
- local client random start result;
- client-selected damage amount;
- missing initial stream;
- continuous held-pedal pressure drain scaled by vehicle kinetic proxies;
- constant bar/sec compressor independent of volume/RPM;
- truck-category-only pneumatic eligibility;
- vanilla generic damage as sole leak-health input;
- speed-gated spring brake force;
- spring brake controlling service brake lamps;
- absolute external `setPressure` as final transfer API;
- magic AI pressure creation;
- parallel native AIR + RE AIR authority;
- handwritten build/version identity.

## Preserve / improve these RDS ideas

- staged key/contact/preheat/crank UX;
- governor hysteresis;
- persistent air loss concept;
- compact/thresholded network values;
- final start confirmed by actual motor transition;
- optional capability APIs;
- provider-supplied failure reason;
- default-only keybind migration;
- UI-scale invalidation;
- speedometer-relative HUD anchoring;
- per-vehicle owner resolution;
- live development calibration tools.

## External update rule

When returning:
1. check whether RDS is newer than 1.4.0.0;
2. source-diff only the affected capability boundaries;
3. check RMS/MR/ADS/Realistic Brakes versions actually used;
4. do not automatically port upstream algorithm changes;
5. update provider/ownership contracts first.

## Implementation stop conditions

Stop and redesign if implementation requires:
- RE gameplay code reaching into RMS/ADS private tables;
- a second authoritative motor temperature while specialist/native exists;
- two independent compressed-air reservoirs;
- permanent overwrite of MR motor control from multiple RE modules;
- spring-brake code altering tire friction;
- local-client mechanical randomness;
- copy/paste of unlicensed RDS code/assets.

## Definition of ready-to-start implementation

Research is sufficient when:
- this blueprint is reviewed;
- ADR 0006 is accepted rather than proposed;
- native AIR backend probe scope is agreed;
- first implementation milestone is chosen (recommended S0/S1);
- current upstream dependency versions are rechecked.

Until then, keep this branch documentation-only.


## Final pre-implementation gates added by transversal pass

### G0 — capability-versioned state contract

Before adding START to the existing state/provider API:
- do not make START require WHEEL context;
- preserve standalone RE behavior without RC;
- version START/MECHANICAL/PNEUMATIC contexts independently;
- external specialist contexts are optional enrichment;
- native GIANTS/profile fallback remains available.

Recommended provider metadata:
```text
capabilities.WHEEL.version
capabilities.START.version
capabilities.MECHANICAL.version
capabilities.PNEUMATIC.version
```

### G1 — ownership primitive selection

For every StartContext field mark it as either:
- `AUTHORITATIVE_CHANNEL`; or
- `CONTRIBUTOR_SET`.

Do not implement a generic "one owner per facet" abstraction.

Examples:
- temperature -> authoritative channel;
- battery -> authoritative channel;
- fuel constraints -> contributor set;
- interlocks -> contributor set.

### G2 — controller-policy matrix

Before finalizing start/brake actuation, define behavior under:
- PLAYER;
- GIANTS AI;
- Courseplay;
- AutoDrive.

Automated controllers may skip gestures, not low-air/spring physical safety.

Forced spring brake must survive MR's AutoDrive wheel-control fallback.

### G3 — safe load/join ordering

For low-air state:
- restore storage;
- derive forced brake;
- install actuator constraint;
- only then allow ordinary vehicle wake.

No one-frame free-roll window.

### G4 — pneumatic service ownership

P1 must not invent an independent maintenance/workshop system.

Decide only:
- baseline leak;
- external condition input.

Future wear/failure waits for explicit RMS/service ownership decision.

### G5 — storage abstraction before backend decision

Implement/tests should target `PneumaticStorageBackend`, not direct native AIR
or direct RE fields.

P0 chooses the backend after runtime evidence.

### G6 — Realistic Brakes source audit before trailer phase

Current 1.3 public behavior is documented in
`REALISTIC_BRAKES_PREAUDIT.md`.

P4 remains blocked until exact-source ownership is understood.

### G7 — legacy RDS migration policy

Before external RDS removal, decide whether to import:
- legacy air pressure;
- elapsed leak timestamp.

Do not import RDS engineHeat into specialist thermal state.

## Further feature reservations

These are **reserved design opportunities**, not MVP scope.

### F1 — compressor engine load
Possible real auxiliary power/torque demand while compressor is loaded.

Must compose with MR/GIANTS engine owner; never fake a load percentage.

### F2 — compressor fast idle
Possible EngineRpmDemand source if evidence/calibration supports it.

### F3 — axle/circuit brake demand
Future service/spring demand can target wheel groups rather than one global
scalar.

### F4 — pneumatic component condition
Compressor/line/chamber/dryer condition only after maintenance ownership is
resolved.

### F5 — in-cab/native presentation
Prefer native dashboard/telltales when available before adding more HUD gauges.

### F6 — trailer paired-resource solver
Conservation-aware truck/trailer transfer, solved once per connected pair/server
step, with symmetric detach/delete cleanup.

## Explicit controller principle

Do not follow either shortcut seen in adjacent external mods:
- "AI gets free pressure";
- "AI is excluded from brake physics".

The target is:
```text
same physical state
+ different interaction policy
```

If a controller requires a bypass for stability, make it an explicit,
diagnosed policy exception rather than silently mutating persistent state.

## Final research completion rule

When this project resumes, **do not start with another broad audit**.

First:
1. check dependency versions;
2. read this blueprint and the final cross-audit matrix;
3. close only the currently blocking gate;
4. implement the smallest agreed milestone.

Re-open broad research only if:
- an upstream mod materially changed ownership;
- Realistic Brakes exact source adds/removes a major capability;
- runtime evidence contradicts the current contracts.
