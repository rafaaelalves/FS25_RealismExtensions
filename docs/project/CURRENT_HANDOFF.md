# Current development handoff

Updated: 2026-09-30

This file is the first place to read when continuing RealismExtensions in a new chat/session.

## Current state

- `TerrainDeformation` is integrated into `main` via PR #24.
- PR #22 (v5) and PR #23 (historical v6 line) are closed as superseded.
- Production defaults remain safe: `TerrainDeformation=false`, verbose diagnostics off.
- The validated v6 behavior is now the canonical TerrainDeformation implementation in main.

## Runtime validation completed

Captured v6 runtime evidence:
- FIELD_SOFT, FIELD and FIELD_FIRM produced deformation;
- DIRT_COMPACTED and HARD produced zero brushes under ordinary conditions;
- DIRT_WET produced deformation only after wetness/slip gates;
- 37,986 brushes accepted, 36,798 submitted after coalescing, 5,056 native jobs, 0 failed jobs;
- GIANTS callbacks reported 244.519 m3 displaced volume;
- stationary wheelspin remained active with 263 accepted stationary brushes and ~0.584 m cumulative RE-applied depth;
- save/reload restored 12,483 terrain-history cells with no geometry-mismatch rejection;
- RC reuse hints were fully consumed in the captured session: 13,487/13,487 speedHintHits and wheelSurfaceSpeedHintHits, 13,487 slipSnapshotHits, 0 slipDirectReads;
- the user described the gameplay result as quite good.

## Readiness decision

TerrainDeformation is implemented and validated for the current reference stack.

It is ready as the first RE gameplay module in main, but remains disabled by default while the broader project is assembled.

Remaining hardening is follow-up work, not a blocker:
- multi-map terrain-layer/profile naming validation;
- grouped crawler/track footprint modeling;
- explicit GIANTS AI / Courseplay validation before retiring True AI Tracks;
- release-mode performance/telemetry benchmarking.

Mud adhesion, wheel spray and puddles are separate future immersion capabilities, not TerrainDeformation defects.

## Ownership

- MR owns base vehicle dynamics, traction and slip.
- MudSystemPhysics owns wetness, sink/resistance/stuck behavior, tire pressure/load and freeze/ground signals.
- RC arbitrates overlap and exposes normalized authoritative state.
- RE TerrainDeformation owns visible/persistent rut geometry and surface-dependent geometric consequence.

Surface caps bound geometry invented by RE. Authoritative Mud sink remains a lower bound, so rut capacity may exceed a v6 surface cap when the active physics owner reports deeper real sink.

## Next development step

Treat TerrainDeformation as complete enough to leave alone. Re-open it only for concrete regressions, multi-map compatibility findings, crawler support, AI/Courseplay validation or measured performance issues. Move development focus to the next RE capability.
