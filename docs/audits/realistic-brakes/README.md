# Realistic Brakes 1.3.0.0 — exact-source capability audit

Updated: 2026-10-06  
Status: **STATIC SOURCE AUDIT COMPLETE / runtime pending / ownership decision deferred**

## Exact package

User-supplied:
- mod: `FS25_RealisticBrakes`
- author: NegroATR (GN Realism)
- version: `1.3.0.0`
- multiplayer declared: true
- ZIP SHA-256: `c6cec8b89fb7bf409ee55f2a2421b989ff7392da0f5c5dedf65bc5d76912aa05`
- Lua source: about 5.1k lines
- public GitHub/source repository: not found
- LICENSE file in supplied ZIP: not found

This audit is exact-source for the supplied 1.3 archive.

## Executive recommendation

**KEEP / EVALUATE BY CAPABILITY. Do not assimilate the whole mod as one unit.**

Realistic Brakes contains at least four materially different capabilities:

1. manual/parking brake;
2. service-brake temperature, fade and permanent lining/drum damage;
3. engine/exhaust/Jake-style braking plus automatic downshift;
4. trailer pneumatic reservoir / hoses / spring-brake behavior.

They do not share the same best owner in the project's target stack.

### Preliminary ownership outcome

| Capability | Current RB implementation | Target-stack direction |
|---|---|---|
| manual parking brake | useful but multi-hook physical owner | **EVALUATE / conflict with RMS + Enhanced Vehicle** |
| brake thermal/fade | unique and interesting | **EVALUATE; strongest independent RB feature outside trailer air** |
| engine/exhaust/Jake brake | directly writes motor brake + gears | **DO NOT DUPLICATE under MR; strong ownership conflict** |
| trailer hoses/reservoir/spring brake | closes major RDS gap; mixed physics quality | **valuable integration/reference; exact audit feeds future RE pneumatics** |
| HUD/audio | functional but fragmented | future shared presentation, not clone target |

The user is not currently planning a full RB assimilation. That is appropriate. The exact source is valuable now mainly for:
- evaluating whether RB can safely join the stack later;
- closing the RDS/trailer-air architecture;
- extracting reusable physics/network/lifecycle ideas;
- identifying conflicts that would need an RC/upstream solution before enabling all RB subfeatures beside MR/RMS.

## Source architecture

Loaded through `scripts/RBRegister.lua`.

Vehicle specialization:
- `realisticBrakes` added to vehicle types with `motorized + wheels`.

Trailer specialization:
- `rbTrailerAir` added to non-motorized `attachable + wheels + connectionHoses`.

Global physical/control hooks include:
- `WheelsUtil.updateWheelsPhysics`;
- `WheelsUtil.getSmoothedAcceleratorAndBrakePedals`;
- vehicle `getBrakeForce`;
- per-vehicle motor `lowBrakeForceScale` / `lowBrakeForceSpeedLimit`;
- gearbox `setGear()` for automatic exhaust-brake downshift.

Global presentation/config hooks include:
- `FSBaseMission.draw`;
- settings-frame update/open appends;
- many development/calibration console commands.

## Strong positive patterns

- full main-vehicle initial MP stream;
- quantized brake temperature/damage state;
- server-side thermal progression;
- exact exponential cooling rather than Euler step;
- 250 ms cache for parking mass/slope calculation;
- 250 ms AI-controller detection cache;
- bounded 8-second wake workaround after a previously unbounded performance bug;
- final trailer spring-brake actuation uses wheel brake force rather than setting friction/velocity directly;
- ConnectionHoses is used as the hose-state provider, so manualAttach/Interactive Control can compose indirectly;
- RDS integration uses public `rdsGetAirPressure/rdsSetAirPressure` methods instead of private RDS spec tables;
- trailer equalization at least attempts amount conservation through relative reservoir volumes;
- main save/network state has explicit initial synchronization.

## Highest-priority concerns

1. **MR engine-brake ownership conflict** — RB rewrites `lowBrakeForceScale` and invokes `setGear()`.
2. **parking-brake multi-owner conflict** — RB owns several wheel/control layers, forcibly disables Enhanced Vehicle parking state, and can overlap RMS parking brake.
3. **AI/controller physics divergence** — main brake/fade effects are deliberately bypassed for AI; AutoDrive is not covered consistently.
4. **local simulation settings in MP** — physical settings are stored per-user with no authoritative sync.
5. **client event authorization gaps** — park/exhaust events do not prove sender controls target vehicle.
6. **thermal model uses pedal/speed/mass proxies rather than actual dissipated brake work**.
7. **trailer air confuses service-line loss with supply-line loss**.
8. **trailer air omits service-brake air demand, leaks, protection valve and finite transfer flow**.
9. **trailer reservoir has persistence but no dedicated network state**.
10. **generic vehicle repair clears RB brake damage**, conflicting with RMS-style subsystem service ownership.

## Documents

- `STATIC_FINDINGS.md` — evidence-ranked exact-source findings.
- `PHYSICS_AND_OWNERSHIP.md` — parking, engine brake, fade and target-stack owners.
- `TRAILER_AIR_AND_RDS.md` — exact RDS/trailer relationship and future RE pneumatic consequences.
- `NETWORK_PERSISTENCE_AUTHORITY.md` — MP, settings, save and security.
- `PERFORMANCE_AND_LIFECYCLE.md` — cadence/hot-path/lifecycle audit.
- `INTEGRATION_OPPORTUNITIES.md` — MR/RMS/RDS/Mud/Reifen/AI/HUD integration decisions.
- `RUNTIME_TEST_PLAN.md` — evidence gates before stack adoption or assimilation.
- RDS-side closure: `../rds/REALISTIC_BRAKES_PREAUDIT.md` and related pneumatic docs.

## Current decision

Do **not** begin RB replacement work from this audit.

If RB is considered for the active stack:
1. validate trailer air + parking/fade in runtime;
2. solve/disable the MR engine-brake overlap;
3. solve parking ownership with RMS/Enhanced Vehicle;
4. verify PLAYER / GIANTS AI / Courseplay / AutoDrive;
5. only then classify each capability as KEEP, INTEGRATE, PATCH or ABSORB.

Static phase: **CLOSED**. Runtime phase: **OPEN**.
