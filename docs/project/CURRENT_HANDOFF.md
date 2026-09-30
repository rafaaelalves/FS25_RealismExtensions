# Current development handoff

Updated: 2026-09-30

This file is the first place to read when continuing RealismExtensions in a new chat/session.

## Current state

- Active implementation: `TerrainDeformation` v6 surface response.
- PR #23 contains the complete v5 geometry/persistence work plus v6 surface calibration and diagnostics.
- PR #22 was closed as superseded by #23.
- Latest v6 CI is green.
- v6 has been runtime-tested successfully in the user's full mod stack.
- Production defaults are restored before merge: `TerrainDeformation=false`, verbose diagnostics off.

## Runtime validation completed

Captured v6 runtime evidence:
- field categories deform correctly: FIELD_SOFT, FIELD and FIELD_FIRM all produced geometry;
- DIRT_COMPACTED and HARD produced zero brushes under ordinary conditions;
- DIRT_WET produced deformation only after the wetness/slip gate;
- 37,986 brushes were accepted, 36,798 submitted after coalescing, 5,056 native jobs completed, and failedJobs remained 0;
- GIANTS callbacks reported 244.519 m3 displaced volume;
- stationary wheelspin remained active with 263 accepted stationary brushes and ~0.584 m cumulative RE-applied depth;
- save/reload restored 12,483 terrain-history cells with no geometry-mismatch rejection;
- RC reuse hints were fully consumed in the captured session: 13,487/13,487 speedHintHits and wheelSurfaceSpeedHintHits, 13,487 slipSnapshotHits, 0 slipDirectReads;
- user described the v6 gameplay result as quite good. Missing mud adhesion/spray/puddles are future immersion features, not TerrainDeformation failures.

## Readiness decision

TerrainDeformation is ready to merge into main as the first validated RE gameplay module, disabled by default for production.

It is not yet a claim of universal release completeness or a basis to retire every terrain-related specialist. Remaining validation/hardening work is deliberately separate:
- multi-map terrain-layer naming/classification;
- grouped crawler/track footprint modeling;
- explicit GIANTS AI / Courseplay coverage before replacing True AI Tracks;
- release-mode performance/telemetry benchmarking;
- broader visual mud/water systems belong to later modules.

## Ownership

- MR owns base vehicle dynamics, wheel/traction simulation and slip.
- MudSystemPhysics owns local wetness, sink/resistance/stuck behavior, tire pressure/load and freeze/ground signals.
- RC arbitrates overlap and exposes normalized authoritative state.
- RE TerrainDeformation owns visible/persistent rut geometry and surface-dependent geometric consequence.

RE must continue to reuse authoritative specialist outputs rather than copy MR/Mud formulas.

## Important model rule

Surface caps bound geometry invented by RE. Authoritative Mud sink remains a lower bound, so `rutCapacityM` may exceed a v6 surface cap when the active physics owner reports deeper real sink. This is intentional and prevents geometry from contradicting vehicle physics.

## Next development step

After merging #23, treat TerrainDeformation as implemented/validated and move to the next RE capability rather than continuing blind calibration. Re-open TerrainDeformation only for concrete regressions, multi-map compatibility findings, crawler support, AI/Courseplay validation, or measured performance issues.
