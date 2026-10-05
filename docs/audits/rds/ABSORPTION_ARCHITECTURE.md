# RDS functional-absorption architecture

Status: research proposal, not implementation.
Updated: 2026-10-05

## Objective

Absorb the useful RDS behavior into RE without creating a second RMS/ADS/MR mechanical simulator.

The target is **not** a renamed `RealDieselStart.lua`. It is a small set of capability owners and provider contracts.

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

## 2. `StartMechanicalProvider`

Select one authoritative mechanical provider per vehicle.

Conceptual reads:

```text
getEngineTemperatureC(vehicle)
getAmbientTemperatureC(vehicle)
getBatteryState(vehicle)
getStarterState(vehicle)
getGlowState(vehicle)
getStartInterlockState(vehicle)
getStartDifficulty(vehicle)
canCrank(vehicle)
```

Conceptual intents:

```text
requestIgnition(vehicle, enabled)
requestCrank(vehicle, context)
releaseCrank(vehicle)
```

Priority:
1. RMS when RMS manages the vehicle;
2. ADS when ADS manages it and RMS does not;
3. minimal GIANTS/RE fallback.

Provider APIs expose normalized values, not mutable specialist tables.

### RMS

RMS already has engine thermal, battery/electrical, starter, preheat/glow and hard-start mechanics.

With RMS active, RE is the **interaction/orchestration layer**:
- staged key intent from RE;
- readiness/mechanics from RMS;
- final crank/start success from RMS;
- presentation from RE.

RE must not maintain a second temperature/battery/failure model.

### ADS

Historical RC RDSADS work proved the same ownership split: RDS gesture/preheat needed to compose with ADS starter/battery/hard-start authority.

Native RE should replace that private bridge with a provider contract rather than reproducing synthetic RDS state.

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

Responsibilities:
- compressor/governor;
- reservoir/circuit state;
- service application demand;
- leaks;
- low-air warning;
- spring/parking brake availability/effect state;
- save/network state;
- later trailer supply contract.

It does **not** blindly own final wheel braking when MR/RMS owns vehicle physics. RC composes only the final effect where required.

See `PNEUMATIC_MODEL.md`.

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
| engine temperature | RMS > ADS > fallback | consume |
| battery/starter | RMS > ADS > fallback | consume |
| glow mechanical health | specialist/provider | consume/fallback |
| hard-start/failure mechanics | specialist/provider | request/consume |
| drivetrain torque response | MR/RMS | no direct write |
| generic mechanical damage | RMS/ADS | no direct write |
| electrical/light consequences | RMS/ADS/vanilla | ignition intent only |
| compressed-air supply | RE | owner |
| pneumatic condition | provider/fallback | consume |
| final brake force | active physics owner | compose if needed |
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
- standalone no-damage provider;
- shared HUD;
- server authority + MP sync.

### B — RMS provider
- temperature/battery/starter/glow integration;
- no duplicate thermal/damage state.

### C — ADS provider
- validate ADS 0.9.2.8;
- replace historical RDSADS semantics for native RE.

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
