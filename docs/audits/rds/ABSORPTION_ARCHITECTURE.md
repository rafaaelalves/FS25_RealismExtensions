# RDS functional-absorption architecture

Status: research proposal, not implementation.
Updated: 2026-10-05

## Objective

Absorb the useful RDS behavior into RE without creating a second RMS/ADS/MR mechanical simulator.

The target is **not** a renamed `RealDieselStart.lua`. It is a small set of capability owners and provider contracts.

## 0. Reuse the existing RE/RC contract architecture

RE already has a public `RealismExtensionsState` contract and RC already owns
an aggregate reuse-first provider for specialist state.

Do not create a second parallel "RDS provider framework".

Preferred evolution:

```text
external owner internals
        |
        v
RC aggregate provider/adapters
        |
        +--> getWheelContext()      existing
        +--> getStartContext()      future
        +--> getMechanicalContext() future only when justified
        +--> getPneumaticContext()  future when external air owner exists
        |
        v
RE StateContract
        |
        v
RE gameplay modules
```

Each context should be independently versioned so extending START does not
invalidate WHEEL consumers.

### Reads and actions are different contracts

`RealismExtensionsState` should remain read-oriented.

Mutation/intent must use a separate narrow action boundary:

```text
RE EngineStartControl intent
        |
        v
RE Interop/ActionContract
        |
        v
RC owner adapter
        |
        v
RMS / ADS / GIANTS action
```

This prevents gameplay code from directly writing specialist private tables.

The same distinction applies to final pneumatic brake demand.

## 1. RE `EngineStartControl`

RE-owned operator state.

Responsibilities:
- explicit diesel/start eligibility;
- contact/ignition intent;
- manual key gesture;
- preheat/readiness orchestration;
- crank request lifecycle;
- warnings;
- AI-safe automatic orchestration;
- server-authoritative transition state;
- public read-only state for HUD/RC.

Suggested interaction state:

```text
OFF -> IGNITION -> PREHEAT -> READY -> CRANKING -> RUNNING
```

`PREHEAT` may be skipped when the provider/profile says it is unnecessary.

Do **not** give `WARMUP` mechanical ownership. Cold/warm state is supplied by the mechanical provider. RE may expose a derived warm-up advisory for presentation.

## 2. `StartCapabilityResolver` — compose facets, not one winner

The exact RDS 1.4 source invalidates the earlier idea of choosing one monolithic
`StartMechanicalProvider`.

A vehicle may legitimately have multiple simultaneous authoritative owners:
- RMS/ADS for electrical starter/battery state;
- a fuel-system specialist for cetane, blocked filter, air in fuel lines;
- RE profile data for ignition/glow technology;
- a drivetrain owner for neutral/clutch/interlock state.

Resolve ownership **per capability facet**.

Conceptual reads:

```text
ThermalFacet.getEngineTemperatureC(vehicle)
ElectricalStartFacet.getBatteryState(vehicle)
ElectricalStartFacet.getStarterState(vehicle)
GlowFacet.getGlowState(vehicle)
FuelStartFacet.getColdStartFactor(vehicle)
FuelStartFacet.getStartBlockReason(vehicle)
InterlockFacet.getStartInterlockState(vehicle)
MotorStartFacet.getStartDifficulty(vehicle)
```

Conceptual intents:

```text
IgnitionFacet.requestIgnition(vehicle, enabled)
MotorStartFacet.requestCrank(vehicle, context)
MotorStartFacet.releaseCrank(vehicle)
```

The coordinator composes the facets into one operator-visible result instead
of allowing one provider to erase another domain.

Example:
```text
ADS starter = healthy
Fuel provider = blocked filter
RE glow = ready
=> crank intent is allowed electrically, but combustion/start remains blocked
   with the fuel provider's authoritative reason.
```

Provider APIs expose normalized values/reasons, not mutable specialist tables.

### RMS

RMS already has engine thermal, battery/electrical, starter, preheat/glow and hard-start mechanics.

When RMS owns one of those facets, RE is the **interaction/orchestration layer**:
- staged key intent from RE;
- readiness/mechanics from RMS;
- final crank/start success from RMS;
- presentation from RE.

RE must not maintain a second temperature/battery/failure model.

### ADS

Historical RC RDSADS work proved the same ownership split: RDS gesture/preheat needed to compose with ADS starter/battery/hard-start authority.

Exact RDS 1.4 now confirms the problem directly: its ADS support writes private
start-button fields and waits for ADS to complete an externally-owned hard
start. The behavior is good; the coupling is not.

Native RE should replace that private boundary with capability-facet adapters
rather than reproducing ADS private state inside RE core.

### GIANTS fallback

Current FS25 Motorized already exposes useful fallback state:
- native motor temperature;
- neutral state;
- clutch-pedal state;
- getCanMotorRun;
- MotorState.

When no deeper specialist owns a facet, prefer those native facts before
creating RE duplicate thermal/interlock state.

### Fuel-system providers

Exact RDS 1.4 demonstrates a useful independent fuel facet:
`scGetColdStartFactor()` and `scGetStartBlockReason()`.

RE should generalize that idea rather than hard-code one mod name. Fuel quality,
air in lines, filters and priming can contribute to start readiness without
owning the starter or thermal model.

### MoreRealistic

MR keeps engine/drivetrain physics. Do not port RDS's direct `motor.torqueScale` write.

If MR needs an RE start/cold-state input, compose it narrowly through RC at an MR-owned boundary.

## 3. `StartProfileResolver`

Separate technology data from start logic.

Possible evidence-backed profile fields:

```text
fuelClass            diesel / gasoline / electric / unknown
glowTechnology       none / legacy / quick / modern
preheatCurveId
startInterlock       clutch / neutral / brake / provider / none
airBrakeCapability   none / truck / tractorUnit / explicitProfile
compressorProfile
```

Fallback:
- explicit diesel consumer enables conservative diesel behavior;
- ambiguous vehicles do not receive glow-plug behavior simply because they are motorized;
- sparse curated overrides handle unusual mod vehicles.

Glow timing should be technology-aware. Manufacturer references show old standard glow plugs may need around 20 s while modern high-speed/ceramic systems can reach starting temperature in roughly 2 s.

## 4. RE `PneumaticBrakeSystem`

This is the strongest unique physical absorption candidate because RMS has no equivalent compressed-air supply simulation.

Storage/backend ownership is **not yet fixed**. Current FS25 already exposes a
native AIR consumer/fill path used by vehicle compressor sounds and by the exact
soundExpansionMP stack.

### Native AIR backend

The first prototype must compare:
- native-AIR-backed storage + RE physical policy;
- fully RE-owned reservoir + deliberate native bridge.

Never keep both as independent authoritative air states.

See `NATIVE_AIR_BACKEND.md`.

Responsibilities:
- compressor/governor;
- reservoir/circuit state;
- service application demand;
- leaks;
- low-air warning;
- spring/parking brake availability/effect state;
- save/network state;
- later trailer supply contract.

It does **not** blindly own final wheel braking when MR/RMS owns vehicle physics.

RE produces normalized `BrakeDemand`; RC/owner adapters apply it once at the
active physical owner boundary.

Low-air spring brake is a forced constraint distinct from an ordinary manual
parking-brake request. This matters with RMS, whose parking-brake policy may
release for throttle or AI.

See `PNEUMATIC_MODEL.md`.

## 4b. Shared engine-RPM demand

PTO hand throttle already needs an engine minimum-RPM request.

If cold idle or compressor fast-idle becomes a real second consumer, introduce
one shared `EngineRpmDemand` domain and one final MR/GIANTS adapter rather than
multiple independent `controlVehicle` wrappers.

Potential sources:
- PTO hand throttle;
- cold-idle profile;
- future auxiliary-compressor fast idle.

Do not generalize this before a second validated consumer exists.

## 5. Shared RE HUD/settings

Do not create another RDS-specific HUD/settings stack.

Use the controlled-entity HUD lifecycle already proven by native PTO.

Default presentation:
- glow/readiness;
- contact/crank state only when useful;
- pneumatic pressure / warning / spring state;
- provider-backed temperature only when RE standalone owns it or an explicit consolidated-HUD option is chosen.

Avoid duplicate temperature gauges beside RMS/ADS.

## Ownership matrix

| Capability | Target owner | RE role |
|---|---|---|
| ignition/contact gesture | RE | owner |
| diesel/profile classification | RE | owner |
| preheat UX/orchestration | RE | owner |
| engine temperature | thermal facet owner | consume |
| battery/starter | electrical-start facet owner | consume |
| glow mechanical health | glow facet owner | consume/fallback |
| fuel quality/start blockage | fuel-start facet owner | consume/compose |
| hard-start/failure mechanics | motor-start facet owner | request/consume |
| drivetrain torque response | MR/RMS | no direct write |
| generic mechanical damage | RMS/ADS | no direct write |
| electrical/light consequences | RMS/ADS/vanilla | ignition intent only |
| compressed-air physical policy | RE | owner |
| compressed-air storage backend | GIANTS AIR or RE after prototype | arbitrate one owner |
| pneumatic condition | provider/fallback | consume |
| brake demand | RE pneumatic policy + manual owner state | compose |
| final brake force | active physics owner | apply once through adapter |
| start/air HUD | RE shared HUD | owner |

## AI policy

AI does not perform human gestures but still obeys readiness:

1. automatic ignition/preheat;
2. build safe pneumatic pressure when applicable;
3. crank via provider;
4. depart only when start/brake readiness is valid;
5. bounded timeout and explicit diagnostic so helpers cannot deadlock.

## Multiplayer authority

Server owns:
- mechanically meaningful start transitions/outcomes;
- pneumatic pressure/circuit state;
- spring/parking state;
- persistence.

Client sends operator intent only.

Use:
- full initial stream;
- semantic dirty groups (`START`, `PNEUMATIC`);
- revision/transition ordering;
- controller authorization;
- quantized/thresholded pressure sync.

## Coexistence / migration

While developing:
- external `FS25_RealisticDieselStart` active -> native RE start/pneumatic modules default INACTIVE with explicit reason;
- no dual ownership;
- retire RC `RDSADS` only after native RE provider paths are runtime validated.

Current RDS 1.4 publicly reports ADS compatibility, so the historical external-RDS bridge may already be redundant for that upstream line; verify exact 1.4 source before changing RC support.

## Implementation phases

### A — start-control skeleton
- profile resolver;
- diesel eligibility;
- complete input state machine;
- capability-facet resolver;
- minimal standalone facets without arbitrary damage;
- shared HUD;
- server authority + MP sync.

### B — RMS facet adapters
- temperature/battery/starter/glow integration;
- no duplicate thermal/damage state.

### C — ADS + fuel facet adapters
- validate ADS 0.9.2.8 start ownership;
- replace historical RDSADS semantics for native RE;
- preserve independent fuel-start contributions instead of choosing one monolithic provider.

### D — pneumatic MVP
- equivalent service reservoir;
- RPM-aware compressor;
- application-based air demand;
- leak/warning/spring state;
- save/MP/HUD;
- physics-owner composition.

### E — richer pneumatics
Only after MVP:
- primary/secondary/supply circuits;
- trailer supply/emergency;
- hoses/manualAttach/Interactive Control.

Audit Realistic Brakes before Phase E because current RDS 1.4 explicitly integrates trailer air with Realistic Brakes 1.3.


## Exact 1.4 design refinements

The current source adds four architecture constraints:

1. **Outcome, not command, owns RUNNING.** A crank request may be accepted by
   another system and finish later. RE must wait for the authoritative motor
   transition/event.
2. **Reasons are provider data.** A fuel owner may block start and should return
   the reason rather than forcing RE to reverse-engineer it.
3. **Per-vehicle ownership matters.** ADS can be installed but exclude a
   particular vehicle; provider/HUD selection must resolve per entity.
4. **Physical-resource mutation needs stronger semantics than setters.**
   RDS's new `rdsSetAirPressure` is useful interoperability, but RE should
   expose transactional transfer semantics for air.

These refinements generalize beyond RDS and should influence future RE provider
contracts.


### F — presentation / audio integration
- native AIR compressor/release samples preferred when using native backend;
- preserve soundExpansionMP synchronization;
- low-air warning remains RE presentation;
- do not duplicate specialist starter/parking-brake sounds;
- move active start/PTO/pneumatic indicators into shared semantic HUD slots.

## Cross-audit implementation rule

Every new integration must answer before code is written:

1. Who owns the physical state?
2. Who owns the decision/policy?
3. Who owns the final actuator write?
4. What existing normalized state can be reused?
5. What translation is performed exactly once?
6. What is server authoritative?
7. What happens when the specialist is absent?
8. Which profile evidence makes the capability eligible?
9. How is the result invalidated/revised/cached?
10. Which external dependency can be retired after validation?

The consolidated cross-stack reasoning is in
`CROSS_AUDIT_INTEGRATION_MATRIX.md`.
