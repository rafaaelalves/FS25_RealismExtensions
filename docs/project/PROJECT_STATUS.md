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
