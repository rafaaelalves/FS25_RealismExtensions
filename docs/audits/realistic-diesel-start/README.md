# Realistic Diesel Start 1.4.0.0 audit

Updated: 2026-10-06

Exact source:
- archive: `FS25_RealisticDieselStart(2).zip`
- mod: `FS25_RealisticDieselStart`
- title: Realistic Diesel Start
- author: NegroATR - GN Realism
- version: `1.4.0.0`
- SHA-256: `a2a983c7754bc4fb3dffc04839fb16cf844c72d7664ae78cfcd70fcf3c15721c`
- declared multiplayer support: true
- package: 20 entries
- Lua: 7 files / 3,692 lines
- XML: 8; parsed successfully
- executable/path-traversal payload: none found
- reusable source license in supplied ZIP: not found

Previous RC reference:
- RDS `1.2.0.0` + ADS `0.9.2.8`
- legacy RDSADS bridge was runtime-validated in RC 0.1.1.1.

Purpose:
re-audit the new RDS release and decide whether its native ADS/RealisticBrakes/
Diesel Fuel System integrations supersede, change or expand RC responsibilities.

## Executive decision

**KEEP EXTERNAL. UPDATE RECOMMENDED.**

RDS 1.4.0.0 is not currently an RE absorption target.

The important architectural result is:

**RDS 1.4 partially supersedes the old RDSADS bridge.**

The new upstream version natively solves several boundaries that RC previously
had to own:
- engine-key/start gesture routing with ADS;
- ADS held-key state synchronization;
- prolonged ADS hard-start crank;
- ADS-aware HUD thermometer suppression;
- Realistic Brakes trailer-air handoff;
- Diesel Fuel System cold-start/start-block query points.

RC should therefore become **smaller**, not stack the old bridge on top of the
new upstream behavior.

## Solution-quality gate

### RDS 1.4 ↔ Advanced Damage System
Classification:

**PAIRWISE_FIX_ONLY / PARTIALLY_SUPERSEDES_RC**

Strong:
- RDS owns the ignition gesture and explicitly reports held-key state to ADS;
- ADS can keep cranking during hard starts;
- RDS no longer lets ADS's vanilla key path bypass glow-plug sequencing;
- HUD suppression is per vehicle and respects ADS exclusion.

Still unresolved:
- RDS and ADS retain independent engine-temperature models;
- RDS still has its own cold-start failure/damage model;
- RDS still applies cold torque/cold-drive damage while ADS also owns
  cold/mechanical consequences.

Therefore:
- retire the old RC key/HUD ownership;
- retain a narrow temperature/preheat/consequence composition layer.

### RDS 1.4 ↔ Realistic Brakes 1.3
Classification:

**GOOD_AND_ADOPT_PRINCIPLE**

RDS exposes a narrow truck-air contract:
- `rdsGetAirPressure()`;
- server-owned `rdsSetAirPressure(bar)`.

Realistic Brakes consumes it while retaining ownership of trailer tank/hose
state.

No RC bridge is justified.

Principle:
> expose the smallest semantic owner API required by the partner instead of
> sharing private state or wrapping each other's internals.

### RDS 1.4 ↔ Diesel Fuel System
Classification:

**GOOD_DIRECTION / ADOPT_PRINCIPLE**

RDS asks optional provider-like questions:
- `scGetColdStartFactor()`;
- `scGetStartBlockReason(shortText)`.

This preserves Diesel Fuel System as owner of fuel quality/fuel-path readiness.

Weakness:
- capability is discovered by method presence rather than a versioned provider
  descriptor.

RC 1.4 must preserve these calls rather than replace `tryCrank()` wholesale.

## RC 1.4 design

New branch:
`research/rds-1.4.0-current-base`

Based on the current Reifen/Mud RC line.

For exact RDS 1.4:
- keep native RDS key routing;
- keep native ADS start-button synchronization;
- keep native RDS HUD/ADS exclusion logic;
- keep native RealisticBrakes air API;
- keep native Diesel Fuel System queries;
- use ADS temperature as RDS thermal source only when ADS actually manages that
  vehicle;
- translate RDS glow + fuel readiness into ADS
  `ENGINE_HARD_START_MODIFIER`;
- suppress only the duplicate RDS random-start failure for that ADS-managed
  crank;
- suppress RDS cold torque/cold-drive consequences only for ADS-managed
  vehicles;
- preserve full RDS behavior for ADS-excluded vehicles;
- retain RC's diesel-only classification boundary.

The legacy RDS 1.2 path remains untouched for the already-validated exact
version.

## What becomes obsolete in RC for RDS 1.4

Retire in the 1.4 path:
- global deletion of RDS thermometer HUD;
- global `damageEnabled=false` under ADS;
- clutch-only replacement of RDS action registration;
- RC ownership of ADS `onStartButtonAction` routing;
- full RC replacement of RDS `tryCrank()`;
- RC reimplementation of RDS contact/start gesture lifecycle.

These were justified for the old source but would now fight or erase upstream
1.4 fixes.

## What remains justified

- diesel-only eligibility for a diesel-specific realism stack;
- one thermal authority when ADS is active for the vehicle;
- glow/fuel-readiness → ADS hard-start semantic translation;
- removal of duplicate RDS cold mechanical consequences under ADS;
- preservation of native RDS behavior when ADS explicitly excludes the vehicle;
- telemetry and runtime verification.

## Current recommendation

Upgrade RDS and RC **together**.

Running RDS 1.4 with the older RC bridge is not the desired final stack:
the old bridge was designed around the pre-1.4 ownership model and would
override several fixes now owned upstream.

Running RDS 1.4 with no RDSADS bridge is much better than before, but still
leaves duplicate thermal/cold-start/cold-drive models beside ADS.

The reduced native-aware RC adapter is the preferred target.

## Detailed files

- [STATIC_FINDINGS.md](./STATIC_FINDINGS.md)
- [INTEGRATION_OPPORTUNITIES.md](./INTEGRATION_OPPORTUNITIES.md)
- [RUNTIME_TEST_PLAN.md](./RUNTIME_TEST_PLAN.md)

## Status

Static/source audit: **complete**.

RC source/harness/CI: pending final green run on
`research/rds-1.4.0-current-base`.

In-game runtime validation: **pending**.
