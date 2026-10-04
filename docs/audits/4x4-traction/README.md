# Realistic 4x4 Traction System assimilation audit

Updated: 2026-10-04

Exact package audited:
- mod: `FS25_4x4TractionSystem`
- title: Realistic 4x4 Traction System
- author: Zasty Chalk
- published package version: `1.6.0.0`
- ZIP SHA-256: `eff66ca5b261cfefc76c776dfd41ac225199d832f65b8d7e54146bac2f73c09c`
- declared multiplayer support: true
- package: 45 entries, no executable payloads / no path traversal found
- Lua source: 12 files, 4,175 lines, ~185 kB
- source-code reuse license: **not found in the ZIP**
- note: several source comments retain internal `2.x` development numbering; the shipped modDesc/readme public package line is `1.6.0.0`

Purpose: extract useful automatic-drivetrain reasoning from the mod without creating a second physical drivetrain owner beside RMS.

## Executive decision

**DO NOT ABSORB THE PHYSICAL DRIVETRAIN SOLVER.**

**ABSORB / REDESIGN THE DECISION-MODEL IDEAS ONLY, preferably as an upstream RMS improvement or a normalized drivetrain-demand advisor.**

The exact mod contains a genuinely useful separation:

```
sensors -> traction demand -> pure decision -> actuator ramp -> differential physics
```

The first three layers contain ideas that can improve the target stack.

The last two largely duplicate a domain already owned more robustly by Realistic Mechanical Systems.

Current project boundary remains:
- RMS owns live 2WD/4WD/differential topology and mechanical consequence;
- MR owns base drivetrain/vehicle physics where applicable;
- RC composes MR/RMS and exposes final state;
- Mud owns target-stack tire pressure/CTIS and local sink/grip-related ground state.

## Why RMS remains the physical owner

The exact 4x4 mod scans GIANTS differentials and picks any differential whose two children are themselves differentials as a center candidate. Because the scan overwrites the field as it walks the array, the last such candidate wins.

It then assumes:
- branch 1 = front;
- branch 2 = rear.

That is workable on conventional graphs but much weaker than the audited RMS layout inference.

RMS:
- discovers the differential tree;
- identifies primary and engageable sides using steerability and geometry fallbacks;
- retains full/reduced graph plans;
- can install an actual primary-only graph for 2WD;
- fails conservatively when topology is unsafe.

The 4x4 package instead leaves the graph connected and simulates 2WD by applying an approximately zero center torque ratio plus a very permissive speed ratio.

For the target stack, replacing RMS with that architecture would be a regression.

## Strongest part: pure decision semantics

`FourWDTractionModel.decide(ctx)` is deliberately close to a pure function.

It separates:
- measured slip;
- predicted tractive demand;
- manual override;
- speed/steering release;
- hysteresis/hold state;
- differential-lock decision;
- reason code.

This is a valuable design precedent.

Particularly good details:
- asymmetric engage/disengage thresholds;
- minimum hold time;
- launch grace because low-speed slip is unreliable;
- brake-slip rejection;
- steering/headland release;
- reason/explainability state;
- gradual Smart target rather than binary physical engagement;
- requested decision separated from actuator ramp.

These ideas should inform RMS AUTO improvement.

## Better than the current mod: target-stack inputs

The exact mod has to infer many states itself.

RE/RC/RMS can do better.

Current source may read:
- global weather wetness;
- wheel `netInfo.slip`;
- direct private Soil Draft data;
- direct MR `mrLastForce`;
- component mass;
- two-point terrain grade lookahead;
- broad implement-lowered state.

A target-stack advisor should consume normalized authoritative state:
- final effective driven wheels/topology from RMS;
- per-wheel local slip/contact state;
- actual axle/wheel loads;
- local physical wetness/surface compliance from RC/Mud composition;
- actual draft/drawbar force from the best available provider;
- MR motor/load state where appropriate;
- actual steering curvature;
- brake demand;
- current wind-up risk / high-grip surface state;
- path-aligned terrain grade when anticipation is enabled.

This removes most private-mod polling.

## Proposed capability: Drivetrain Demand Advisor

Do not build another `FourWDTractionSystem`.

If this logic is retained, its output should be **advice**, not differential writes:

```
DrivetrainDemandAdvisor
    axleAssistDemand01
    rearLockDemand01
    frontLockDemand01
    primaryReason
    reasonMask
    confidence01
    releaseConstraints
```

RMS then remains the actuator/owner.

Ideal integration order:
1. upstream RMS adopts richer AUTO/lock demand semantics;
2. otherwise expose an RMS read/request boundary and have RC translate a normalized advisor;
3. only if multiple consumers justify it should RE own the reusable pure advisor.

Do not add a new RE subsystem merely because the source algorithm is interesting.

## Physical traction-demand idea

The source estimates:
- rolling resistance;
- uphill grade force;
- draft force;
- rear-axle traction capacity.

That is a much better basis than "implement is lowered" alone.

But its fallback inputs are coarse.

A better normalized model should estimate:

```
tractiveDemand =
    requiredLongitudinalForce
    / availablePrimaryAxleTraction
```

where required force includes:
- drawbar/draft;
- grade;
- rolling resistance;
- acceleration demand if useful.

Available traction should use:
- actual normal load;
- local effective grip/traction state;
- primary-driven wheel set from RMS.

For descent, use a comparable **braking traction reserve** rather than a fixed grade + trailer-mass rule.

## Differential-lock policy

The source's lock policy contains useful behavior:
- speed release;
- steering release;
- stronger slip threshold for lock;
- front lock only under more severe demand.

A stronger target-stack model can additionally use:
- left/right wheel-speed asymmetry;
- torque-flow loss across an open axle;
- wheel unload state;
- surface compliance/wind-up risk.

Average slip alone is not the best reason to lock a wheel-to-wheel differential.

## Confirmed contradiction: brakeEngage false vs Smart target

The shipped config says `brakeEngage=false` and the readme says braking no longer engages 4WD by default.

The binary reason path correctly checks that config.

However the Smart continuous target includes:

```
(s.brake or 0) > 0.3 and speed > 3 and 1 or 0
```

without checking `cfg.brakeEngage`.

Therefore Smart mode can still demand full engagement during braking even when the setting explicitly disables brake engagement.

This is a confirmed static behavior/config mismatch.

## Fixed-weight slip smoothing is FPS-dependent

The source updates slip every vehicle update using fixed weights such as:
- rise 0.45;
- fall 0.15;
- lock 0.15.

The weights are not derived from `dt`.

Thus the effective time constant changes with frame/update rate.

A clean advisor should use asymmetric **time constants**, not asymmetric per-frame weights:

```
alpha = 1 - exp(-dt / tau)
```

with separate `tauRise` and `tauFall`.

## CTIS/tire pressure: explicitly reject

The exact package has grown into a tire-pressure owner:
- manual pressure for vehicles without onboard CTIS;
- field/road pressure targets;
- onboard presets;
- wheel-radius modification;
- tire visual flattening.

This is outside the target ownership.

MudSystemPhysics already owns target-stack pressure/CTIS.

The 4x4 package directly writes `wheel.physics.radius` and globally overwrites `WheelVisualPartTire.update`.

Its own development notes describe previous conflict with Mud as a radius "tug of war".

This entire physical/visual pressure subsystem is **DO NOT ABSORB**.

Useful lesson only:
- tire-pressure state should be separate from 4WD state;
- transition time and hardware capability matter;
- load/field/road targets are preferable to one binary pressure.

Those lessons belong with the pressure owner, not drivetrain.

## Network authority findings

The automatic decision/physics path is server-owned, which is good.

But manual events are inconsistent:
- 4WD toggle validates farm ownership but not the controlling player/vehicle owner connection;
- tire-pressure event has no sender authorization;
- CTIS preset event has no sender authorization.

Any future control path must validate at the server boundary.

## Licensing

No explicit reusable source-code license was found in the exact ZIP.

Treat the mod only as a clean-room functional/design reference.

## Recommendation

Retain:
- pure decision boundary;
- reason codes;
- hysteresis/hold;
- startup/brake-slip guards;
- gradual requested engagement;
- physics-based traction reserve concept;
- steering/speed release;
- differential-lock safety semantics.

Reject:
- second differential/topology owner;
- center-diff heuristic;
- 2WD via nearly-zero center torque;
- repeated differential graph rebuild as RE ownership;
- CTIS/radius ownership;
- global TireVisual hook;
- private SoilDraft/MR reads as permanent integration;
- global weather wetness as local traction state.

Companion docs:
- [Static findings](./STATIC_FINDINGS.md)
- [Assimilation design](./ASSIMILATION_OPPORTUNITIES.md)
- [Runtime plan](./RUNTIME_TEST_PLAN.md)
