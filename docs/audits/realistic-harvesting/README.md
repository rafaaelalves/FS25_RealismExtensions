# Realistic Harvesting audit

Updated: 2026-10-08

## Exact current package

- archive: `FS25_RealisticHarvesting.zip`
- mod: `FS25_RealisticHarvesting`
- title: Realistic Harvesting
- author: exekx
- version: `1.6.2.0`
- descVersion: `111`
- multiplayer declared: true
- SHA-256: `34419a1d37436b10cf4e45318bfaf697c13627ed15d2e65fb74f49f227de66dd`
- entries: 87
- Lua: 35 files
- XML: 36 files

Official source:
- repository: `exekx/FS25_RealisticHarvesting`
- repository license: GPL-3.0
- official tag: `V.1.6.2.0`
- tag commit: `02dad49c4d6f12bbcfb13a469df257fdd28ac372`
- official release date: 2026-10-06
- release is not marked prerelease

Previous stack baseline:
- Realistic Harvesting `1.6.0.0`
- official tag commit `a747c83...`

The official tag delta is 22 commits. This is a material physics/feature update,
not a metadata-only package revision.

## Executive decision

### Current single-player / trusted local stack

**UPDATE RECOMMENDED.**

Use a save backup and run one normal harvest + save/reload smoke.

No RC or RE functional patch is required before installing 1.6.2.

### Dedicated / untrusted multiplayer

**CAUTION / SEPARATE VALIDATION.**

As of 2026-10-08, upstream issue #67 reports missing combine/header load and
forage speed/output telemetry on a dedicated server after the current update.

The source also retains requester-authorization gaps on some client->server
settings events.

Do not call dedicated-server behavior fully validated yet.

## Project placement

Realistic Harvesting remains an external specialist.

Ownership:
- RHM = harvesting process/capacity/calibration/loss/harvest telemetry;
- MR = drivetrain/base vehicle physics;
- RMS = mechanical condition/stress;
- Moisture System = preferred agronomic/material moisture provider;
- SoilCompaction = agronomic soil/yield owner;
- FarmKit = separate capabilities, including currently unbridged Straw Refeed;
- RE = no harvesting-process ownership.

Classification:
**KEEP + INTEGRATE. DO NOT ABSORB.**

The public `RHM_Api` is now the preferred future integration boundary.

## What materially changed from 1.6.0

1. crop processing specific-energy values were substantially recalibrated;
2. default target engine load changed from 88% to 80%;
3. throughput smoothing became a rotor/flywheel-inertia model;
4. straw-chopper demand was added;
5. forage processing was split into feed/drum/blower stages;
6. pickup choking/intake resistance was added;
7. live weed canopy increases header/process demand;
8. slope loss was added;
9. moisture/dew loss became a physical loss channel;
10. built-in diurnal moisture fallback was added;
11. AI loss-aware speed limiter was added;
12. public API expanded substantially;
13. server-authoritative trip/field/fleet/year analytics were added;
14. new network/persistence/UI surfaces were added.

## Important compatibility conclusion

RHM's calculated “engine load” is **harvesting-process utilization**, not a
canonical drivetrain motor-load state.

Do not pipe it blindly into MR/RMS as if it were the one true engine-load value.

Its physical actuator is primarily a harvesting speed ceiling.

The normal `getSpeedLimit()` path composes conservatively using the lower
limit, while a direct `motor:setSpeedLimit()` enforcement path exists for
controllers that bypass the normal query.

This direct path is the principal runtime composition risk to observe.

## Files

- [STATIC_FINDINGS.md](./STATIC_FINDINGS.md)
- [UPDATE_1_6_2.md](./UPDATE_1_6_2.md)
- [RUNTIME_TEST_PLAN.md](./RUNTIME_TEST_PLAN.md)

## Current status

Static/source audit: **complete**.

Full-stack ownership review: **complete**.

RC functional change: **none required**.

RE functional change: **none required**.

Single-player update: **approved, runtime smoke pending**.

Dedicated server: **separate caution gate**.
