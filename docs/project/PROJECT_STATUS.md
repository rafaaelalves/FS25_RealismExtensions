# Project status

Updated: 2026-10-06

## Release / development state

- Version string remains `0.0.1.0`.
- TerrainDeformation is an integrated experimental gameplay capability under active development.
- Canonical terrain/recovery branch: `feat/terrain-recovery`.
- TerrainDeformation and development diagnostics are intentionally enabled.
- SoilMassTransport remains disabled while the now-working recovery baseline is stabilized.

## Runtime-validated foundation

- RC normalized state consumption.
- Pressure/load/support-width footprint for ordinary wheel contexts.
- Distance/cadence-based rut progression.
- Persistent SpatialHistory + savegame persistence.
- Server-owned TerrainDeformation writer with bounded jobs and async callbacks.
- Surface gating.
- Mud instantaneous sink separated from persistent RE plastic deformation.
- Physical TerrainDeformation smoothing changes the heightfield.
- Recovery evaluates measured local roughness/relief rather than center-height sign alone.
- Repeated cultivator work (`realArea=0, area>0`) continues physical recovery.
- Tractor + active soil-working combination suppresses RE persistent rut generation during stable work windows.
- Runtime recovery convergence validated with Koralin 9-840.
- MR Mach Till 412 also entered the same pipeline successfully, confirming recovery is not tied to one specific implement model.

## Current state

TerrainRecovery mechanism is runtime validated. Calibration and architecture evolution are now the active work.

Immediate planned features:
- TerrainPassTracker;
- RecoveryPassSummary;
- slope-aware roughness;
- target roughness;
- TerrainWorkFootprint;
- TerrainRecoveryProfile.

## Contact-system work after recovery measurement/calibration

The current ordinary-wheel model must evolve into an explicit ContactFootprint layer supporting:
- single pneumatic tires;
- dual/twin tires;
- wide/flotation tires;
- implement/support wheels;
- native GIANTS crawlers/tracks.

Native crawler support must use `spec_crawlers.crawlers` as a first-class grouped contact rather than pseudo-wheel processing.

## AI / True AI Tracks

Terrain physics must remain driver-agnostic and be validated for:
- PLAYER;
- GIANTS AI;
- COURSEPLAY.

`FS25_aiTracks` / True AI Tracks is not assumed to be required. It requires a dedicated source/runtime ownership audit to decide whether to retire it, coexist for visual-only behavior, or coordinate overlap through RC.

## Major remaining blockers / research

- pass-based rather than cooldown-based recovery dose;
- target/convergence roughness;
- tool-family recovery semantics;
- ordinary/dual/wide/implement contact normalization;
- first-class native crawler footprint;
- implement-wheel ordering relative to soil-working elements;
- player/GIANTS AI/Courseplay parity;
- external-terrain-edit history reconciliation;
- adaptive SoilMassTransport mass balance before any re-enable;
- underbody/high-centering diagnostics.

Detailed sequencing and acceptance criteria:
`docs/project/TERRAIN_EVOLUTION_PLAN.md`.

## External precedent work

TerraFarm architecture audit remains active at `docs/audits/terrafarm/README.md`. It is a design precedent, not a patch/bridge requirement.


## RunningGearWear assimilation research

Real Tire Wear 1.6.0.0 exact-source audit is complete:
`docs/audits/realtirewear/README.md`.

Decision:
- high-value **CANDIDATE_ABSORB / REDESIGN**;
- no implementation started;
- Reifen remains current tire/track wear owner;
- target future module is `RunningGearWear`, combining Real Tire Wear's
  server-authoritative state/network/service/failure ideas with Reifen's
  stronger first-class track and structural-radius semantics;
- target wear physics must be redesigned around per-unit rolling/slip work,
  absolute load/contact stress and explicit surface abrasiveness;
- no dual wear ownership is permitted in normal play.


## Realistic Diesel Start 1.4 research

Exact-source audit:
`docs/audits/realistic-diesel-start/README.md`.

Decision:
- RDS remains the external owner of diesel ignition/preheat UX and truck
  compressed-air state;
- 1.4 natively supersedes much of the historical RDSADS key/HUD integration;
- RC 1.4 path is reduced to per-vehicle ADS thermal authority,
  glow/fuel-readiness → ADS hard-start composition and duplicate cold-consequence
  suppression;
- Realistic Brakes trailer-air API is good upstream composition and needs no RC
  bridge;
- no functional RE implementation was added;
- static/source/CI work is complete; in-game runtime validation remains.


## Deferred focused experiments

The accepted Mud 1.3.6 + Reifen 1.2.2.70 + RMS 0.11 version line still has
non-blocking focused experiments preserved in:
`docs/project/DEFERRED_EXPERIMENTS.md`.

Highest-priority deferred question:
RMS dynamic drivetrain topology vs Reifen FORCE-WEAR cached driven shares.

These experiments do not reopen the already-passed full-stack smoke or migrated
save reload.


## Realistic Harvesting 1.6.2 audit

Exact package SHA:
`34419a1d37436b10cf4e45318bfaf697c13627ed15d2e65fb74f49f227de66dd`.

Static/source audit is complete.

Decision:
- **KEEP + INTEGRATE**;
- current single-player/trusted stack may update from 1.6.0.0 to 1.6.2.0 with
  save backup + normal harvest/save/reload smoke;
- no RC/RE functional patch is required before update;
- RHM remains harvest-process owner, MR/RMS remain drivetrain/mechanical owners;
- public `RHM_Api` is the preferred future integration boundary;
- FarmKit Straw Refeed remains deliberately unbridged;
- dedicated-server validation remains separate because upstream issue #67 is
  currently open;
- new Harvest History has source-confirmed analytics/accounting issues that do
  not change physical tank loss.

Audit:
`docs/audits/realistic-harvesting/`.
