# Realistic 4x4 Traction System — preliminary audit

Status: **PUBLIC-SOURCE PRELIMINARY ONLY — exact ZIP still required**

The user has downloaded a ZIP, but it is not currently attached/available to the project audit. No source-level conclusion is allowed until that exact package is supplied.

## Publicly advertised current behavior

Recent public descriptions (v1.4.0.0) claim:
- real differential manipulation;
- manual, semi-auto, automatic and Fendt-style intelligent modes;
- rear-wheel slip detection;
- progressive front-axle engagement;
- 3-position differential lock;
- terrain/traction prediction using slope, rolling resistance, lowered-implement effort, soil and moisture;
- auto engagement/disengagement rules for field/headland/road/load states;
- per-vehicle telemetry/persistence;
- HUD showing slip/state/reason;
- multiplayer work in progress / mixed version-history claims;
- compatibility testing with MudSystemPhysics.

Public changelog also says the differential technique was studied from EnhancedVehicle and reimplemented without copying code.

## Why audit it despite RMS overlap

RMS already owns drivetrain/mechanical behavior in the target stack, so a second live 4x4 system is not acceptable.

However, the mod may contain ideas worth:
- proposing upstream to RMS;
- implementing in an RC adapter if RMS exposes the right state;
- using as requirements for a future Extensions/RMS-compatible traction-control UX.

Particularly interesting concepts:
- mode semantics by real drivetrain/transmission family;
- sustained-slip hysteresis;
- progressive engagement instead of binary switching;
- braking/reverse false-positive suppression;
- headland/road-speed disengagement;
- explicit reason/telemetry for automatic decisions;
- load/slope anticipation.

## Exact-source audit questions

When the ZIP is supplied:
1. How does it identify driven axles/differentials?
2. Which GIANTS/MR/RMS fields/functions are written?
3. Does progressive 4WD manipulate differential torque ratios, wheel drive flags, friction or motor torque?
4. Is slip detection raw GIANTS slip or derived?
5. How are load/slope/terrain prediction values calculated?
6. Does it overwrite/append the same functions as RMS/MR/Mud?
7. What state is networked/persisted?
8. Are there public APIs we can use instead of reimplementing?
9. What is its CPU cadence?
10. Are any ideas materially better than RMS's current 2WD/4WD/AUTO behavior?

## Provisional direction

Do **not** plan to absorb this as a second traction owner.

Primary likely outcome:
- extract useful behavior/UX ideas;
- improve RMS integration or propose improvements to RMS;
- only consider functional replacement if source evidence shows RMS cannot represent the desired real differential behavior.
