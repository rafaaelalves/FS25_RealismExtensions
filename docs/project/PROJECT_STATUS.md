# Project status

Updated: 2026-09-30

## Current release line

- Version: `0.0.1.0`
- Phase: first gameplay module integrated + capability/absorption program
- Production defaults: gameplay modules disabled; verbose diagnostics disabled
- TerrainDeformation: integrated into `main` via PR #24 and runtime-validated in the reference stack

## Completed

- Repository foundation, build/CI, diagnostics, architecture and ownership boundaries.
- StateContract v2 and RC normalized wheel/ground-state provider boundary.
- Pressure-driven FootprintModel with low-confidence fallback and crawler fail-closed behavior.
- TerrainResponseModel with bounded pressure/wetness/slip/sink response, separate slip-induced sinkage and authoritative sink anchoring.
- Event-driven TerrainDeformation engine with per-vehicle specialization, path sampling, stationary wheelspin, bounded spatial history, coalesced/budgeted native jobs and server-only writes.
- Savegame persistence for RE terrain response history plus geometry-consistency guard.
- SurfaceResponse v6 classification for field states, mud, compacted dirt, gravel and hard surfaces.
- Runtime validation:
  - FIELD_SOFT / FIELD / FIELD_FIRM produced deformation;
  - DIRT_COMPACTED and HARD remained blocked in ordinary conditions;
  - DIRT_WET deformed only after wetness/slip gates;
  - 37,986 accepted brushes, 36,798 submitted brushes, 5,056 GIANTS jobs, 0 failed jobs;
  - 244.519 m3 callback-confirmed displaced volume;
  - stationary wheelspin remained progressive;
  - 12,483 history cells restored after reload without geometry-mismatch rejection.
- RC->RE reuse validated: full speed-hint hits in captured contexts, MR slip reused from snapshots with 0 direct slip reads, and Mud wetness/radius state predominantly reused.
- Specialization recursion fixed; ModMixer attribution no longer shows pathological repeated registration.
- Capability audits and ownership decisions recorded for MR, Mud, Reifen, RMS, Dynamic PTO, FarmKit, MoistureSystem, True AI Tracks, Real Dirt Color, loose-load systems and related specialists.

## TerrainDeformation readiness

Implemented and validated for the current reference stack; integrated into main and disabled by default.

Remaining work does not block the module's completion status:
- multi-map terrain-layer/profile naming validation;
- grouped crawler/track footprint support;
- explicit GIANTS AI and Courseplay validation before retiring True AI Tracks;
- release telemetry/performance hardening;
- later visual mud/water features such as adhesion, wheel spray and puddles.

## Not current goals

- replacing MR traction;
- replacing Mud sink/stuck/resistance;
- replacing Reifen wear;
- replacing RMS;
- replacing SoilCompaction;
- replacing Dynamic PTO;
- reproducing all FarmKit features;
- creating a unified HUD before authoritative state exists.
