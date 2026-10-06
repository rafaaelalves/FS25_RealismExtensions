# Native start coexistence with RMS / ADS

Updated: 2026-10-06
Status: research; exact source cross-check complete for current supplied RMS/ADS

## Why this document exists

The initial RDS absorption sketch treated RMS/ADS mainly as mechanical providers.

Exact-source cross-check shows the distinction must be stronger:
- RMS 0.10 already owns a complete diesel preheat/start sequence;
- ADS 0.9.2.8 owns starter/battery/hard-start behavior but not the same complete
  RMS glow/preheat orchestration;
- RDS 1.4 fills different gaps depending on which owner is present.

Native RE must not run one identical start algorithm across all three stacks.

---

## RMS 0.10 exact behavior

RMS `RMS_Preheat` already implements:
- explicit diesel detection using the DIESEL consumer;
- `IDLE / IGNITION / PREHEATING / READY / FAILED`;
- engine-temperature-based preheat duration;
- glow-plug failure severity;
- lamp test;
- server-side preheat progression;
- automatic crank after readiness;
- bounded automatic-crank timeout;
- hard-start effect after failed glow support;
- AI start blocking for severe cold glow failure.

RMS also:
- replaces the base start action with a composite held-state event;
- uses collision-safe action registration;
- synchronizes preheat/battery state;
- owns battery/starter/electrical mechanics.

Therefore a second RE preheat timer under RMS would be duplicate ownership.

### RMS authority mode

Default target:

```text
RE EngineStartControl
  role = FACADE / OPERATOR POLICY
RMS
  role = PREHEAT + START MECHANICAL OWNER
```

RE may:
- expose normalized RMS state in shared HUD;
- provide reason/presentation;
- request the RMS sequence through an action adapter;
- observe the final motor transition.

RE must not:
- run an independent preheat timer;
- apply a second glow difficulty;
- apply a second cold-start hazard;
- write RMS private start fields.

## RMS UX question — manual key vs automatic crank

RDS-style UX and RMS-native UX are not identical.

RDS goal:
- contact/preheat;
- player intentionally holds/releases the key/starter.

RMS current sequence:
- once preheat completes it can automatically call `startMotor()`.

If the project wants RDS-style manual crank **while retaining RMS mechanics**,
the preferred solution is an RMS-side cooperative contract, not private RE
patching.

Candidate upstream/API additions:
```text
getStartContext(vehicle)
requestIgnition(vehicle)
setCrankIntent(vehicle, held)
cancelCrank(vehicle)
setExternalStartController(vehicle, active)
```

or a configuration/contract that disables RMS automatic crank while preserving
its:
- preheat state;
- glow failures;
- battery/starter;
- hard-start mechanics.

Until such a contract exists, fail conservative:
- use RMS-native start sequence;
- do not fight its state machine merely to reproduce RDS gesture parity.

This is an explicit design gate before S2 implementation.

## RMS security caveat

Exact/current audit confirms `RMS_StartButtonEvent` accepts client target state
without validating that the sender controls the vehicle.

The native RE action adapter must not normalize this weakness into a public
contract.

Preferred order:
1. upstream RMS fixes sender/controller validation;
2. or RC installs a version-gated secure adapter;
3. only then expose the action to RE.

The same rule applies to client-originated start-effect transitions.

---

## ADS 0.9.2.8 exact behavior

ADS owns:
- battery/electrical state;
- starter failure;
- engine failure;
- `ENGINE_HARD_START_MODIFIER`;
- held start-button state;
- startMotor interception;
- starter sound/lifecycle.

RDS 1.4 integrates by writing ADS private start-button fields/events and waiting
for the actual motor start.

Historical RC RDSADS instead translated RDS glow readiness into ADS hard-start
semantics.

### ADS authority mode

Target:

```text
RE:
  operator gesture
  diesel/glow profile and preheat (when no ADS glow owner exists)
  fuel facet composition
  presentation

ADS:
  battery/starter
  mechanical hard-start/failure
  final motor-start outcome
```

RE contributes its glow/preheat effect **exactly once** through an adapter.

Do not reproduce RDS 1.4's private writes in RE core.

## ADS security caveat

Exact ADS source confirms:
- StartButtonEvent sets the requested vehicle's held/down/up state from a
  client without binding the sender to the target controller;
- selected engine start-effect state may also be accepted/rebroadcast from a
  client.

The same secure-adapter/upstream-fix rule applies.

---

## RMS vs ADS

RMS is an independent ADS-derived specialist and already deliberately steps
aside when ADS is active.

Therefore the mechanical start owner should normally resolve to one of:
- RMS;
- ADS;
- GIANTS/RE fallback.

This does **not** mean the entire StartContext has one provider. Fuel/interlock
facets can still come from independent owners.

---

## Standalone / no mechanical specialist

Target ownership:

```text
RE EngineStartControl:
  staged UX
  StartProfile/glow technology
  server-authoritative standalone catch model

GIANTS:
  MotorState
  motorTemperature fallback
  neutral/clutch/getCanMotorRun
  final base start/stop mechanics
```

Do not create a new thermal model unless native temperature proves unusable for
the target vehicles.

---

## Authority-mode matrix

| Active stack | Preheat owner | Battery/starter owner | Final start owner | RE role |
|---|---|---|---|---|
| vanilla / MR only | RE profile + GIANTS temp | GIANTS fallback | GIANTS via RE server intent | full start orchestration |
| RMS | RMS | RMS | RMS | facade/policy/HUD; manual UX only with cooperative API |
| ADS | RE glow unless another glow owner | ADS | ADS | gesture/preheat contribution + facade |
| RMS + fuel specialist | RMS | RMS | RMS | consume fuel facet in addition; avoid double factors |
| ADS + fuel specialist | RE glow + fuel facet | ADS | ADS | compose missing factors exactly once |

MR may still own underlying motor/drivetrain response in every row.

## Cold-idle interaction

RMS also has glow-failure-related idle RPM effects that can touch motor minimum
RPM.

Therefore a future shared `EngineRpmDemand` adapter must inspect RMS ownership
before introducing RE cold-idle demand.

Do not assume all minimum-RPM writes are compatible simply because both raise
idle.

## HUD rule

When RMS owns preheat:
- prefer normalized RMS preheat/readiness in the RE shared slot;
- avoid a duplicate independent RE glow timer/thermometer;
- allow RMS's own HUD to remain until the unified-HUD migration is deliberate.

Presentation consolidation is a separate milestone from mechanical ownership.

## Retirement rule for historical RC RDSADS

- keep it exact-version gated for legacy RDS 1.2 + ADS;
- do not activate it for RDS 1.4;
- retire it only after native RE+ADS runtime parity is proven.

## Implementation blocker recorded

Before implementing RE manual-key UX on top of RMS, answer:

> Are we accepting RMS-native automatic crank, or do we first add/request an
> RMS cooperative manual-crank API?

Do not hide this decision inside a compatibility patch.
