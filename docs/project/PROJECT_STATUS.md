# Project status

Updated: 2026-09-30

## Current release line

- Version: `0.0.1.0`
- Phase: TerrainDeformation baseline integrated; completion work reopened
- Production defaults: gameplay modules disabled; verbose and timing diagnostics disabled.
- Safety gate: disabled TerrainDeformation does not register the vehicle specialization or append a `TypeManager.validateTypes` hook; development branches explicitly opt in. See stabilization fix of 2026-10-08.
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
