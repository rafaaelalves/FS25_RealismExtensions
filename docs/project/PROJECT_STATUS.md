# Project status

Updated: 2026-10-09

## Native PTO consolidation checkpoint (2026-10-09)

- Draft PR #33 selectively ports the native PTO feature onto main without importing experimental terrain or recovery code.
- Main-based companion bridge is RC draft PR #16; both consolidated branches passed Lua/XML/harness/ZIP CI gates.
- PTOController/HUD/manual governor are included; PTOControl is enabled on this candidate branch only.
- Runtime evidence: non-PTO cultivator classification, 540-RPM VariPack, 1000-RPM Heizohack, operator selector/interlock, MR+RE/RMS+RE bridges and 273 detailed MRPTO causality samples have been observed with the paired October 9 builds. Outstanding release gates: AI-powered implement in game, save/reload of nondefault mode and throttle, and final smoke of the terrain-disabled build. CI alone cannot satisfy these gates.
- RE #34 merged into `main` at `cbb9a941`: terrain is disabled by default and specialization registration is inert. This PTO candidate preserves `PTOControl=true`, `TerrainDeformation=false` and RC StateContract 2/2; dedicated harness guards the defaults.
- Canonical experimental terrain branch remains `feat/terrain-recovery` and is not merged as part of PTO.
- Sections below retain earlier terrain-baseline history.

## Current release line

- Version: `0.0.1.0`
- Phase: TerrainDeformation baseline integrated; completion work reopened
- Production terrain default: TerrainDeformation disabled, verbose and performance diagnostics disabled; this candidate explicitly enables PTOControl only.
- Safety gate: disabled TerrainDeformation does not register its vehicle specialization or wrap `TypeManager.validateTypes`; development terrain branches intentionally opt in.
- TerrainDeformation: integrated into `main` via PR #24, runtime-validated as a baseline, **not yet complete**

## Baseline validated

- StateContract v2 / RC normalized state path.
- Pressure-driven pneumatic FootprintModel for ordinary wheel contexts.
- TerrainResponseModel with bounded pressure/wetness/slip/sink response and authoritative sink anchoring.
- Event-driven TerrainDeformation engine with stationary wheelspin, spatial history, coalesced native jobs and server-only writes.
- Savegame response-history persistence with geometry-consistency guard.
- SurfaceResponse v6 field/dirt/gravel/hard classification.
- Captured runtime session:
  - FIELD_SOFT / FIELD / FIELD_FIRM deformation;
  - DIRT_COMPACTED and HARD blocked under ordinary conditions;
  - DIRT_WET gated by wetness/slip;
  - 37,986 accepted brushes, 36,798 submitted, 5,056 GIANTS jobs, 0 failed jobs;
  - 244.519 m3 callback-confirmed displaced volume;
  - stationary wheelspin active;
  - 12,483 history cells restored after reload;
  - RC speed/slip state reuse validated.

## TerrainDeformation completion blockers

- Remove the current low-speed/update-cadence rutting bias.
- Validate single vs dual/twin footprint/load/pressure behavior.
- Implement grouped crawler/track support; current FootprintModel intentionally rejects crawlers.
- Validate player, GIANTS AI, Courseplay and wheeled implements with True AI Tracks disabled.
- Resolve True AI Tracks native visual-track permission vs physical-deformation ownership before retirement.
- Re-run the terrain capability against audited FarmKit / True AI Tracks / MudSystemPhysics / SoilCompaction / Reifen / RC precedents before closure.
- Keep performance/persistence stability after these changes.

## Project rule reinforced

RE is capability-driven and audit-driven. External-source audits must be actively cross-checked against implementation before a module is declared complete. The project goal is not merely to add missing effects, but to recover selected FarmKit functionality and selectively absorb/improve external-mod capabilities with clearer ownership, richer behavior and less redundant computation.

## Not current ownership goals

- replacing MR drivetrain/traction;
- replacing Mud sink/stuck/resistance;
- replacing RMS mechanical ownership;
- replacing SoilCompaction agronomic compaction;
- reproducing MoistureSystem.
