# Project status

Updated: 2026-09-29

## Current release line

- Version: `0.0.1.0`
- Phase: project foundation + capability/absorption audit
- Gameplay effects: none
- Active implementation branch: `chore/project-foundation`

## Completed

- Repository initialized.
- Core principles and ownership boundaries documented.
- Build/CI scaffold created.
- Minimal FS25 mod bootstrap created.
- Diagnostics prefix established: `[RealismExtensions]`.
- StateContract API v1 scaffold created and harnessed.
- Initial TerrainDeformation research direction documented.
- Capability catalog and asset strategy added.
- Dynamic PTO 1.1.2.0 audited as a strong absorption candidate.
- Reifen 1.2.2.67 audited as a layered absorption candidate.
- FarmKit capability/asset replacement scope documented.
- Realistic 4x4 Traction System 1.4.0.0 exact ZIP audited: keep RMS as physical drivetrain owner; retain richer AUTO/decision ideas for RMS-facing improvement.
- Real Dirt Color 1.1.5.0 exact ZIP audited: strong clean-room replacement candidate via SurfaceContamination.
- Exact six-mod source follow-up completed: MoistureSystem 2.0.0.8, True AI Tracks 2.2.0.1, RealPhysics LoadSpill 1.0.0.0, Loose Load 1.0.0.0, Mud Sprayer 1.0.0.0 and soundExpansionMP 1.2.0.0.
- True AI Tracks promoted to a strong TerrainDeformation absorption target; exact source exposed an apparent still-broken 150 ms scan gate.
- StateContract v2 merged with a versioned RC provider boundary for wheel/ground state.
- Pressure-driven FootprintModel merged: tire-pressure-aware contact area/ground pressure with low-confidence geometry fallback; crawlers fail closed pending grouped track modeling.
- TerrainResponseModel merged: bounded wetness/pressure/slip/sink response with separate longitudinal excavation, lateral scrub, observed-sink anchoring and diminishing repeated-pass accumulation.
- MoistureSystem confirmed as KEEP + BRIDGE specialist with explicit agronomic/material moisture domains.
- Loose-material ownership decomposed into rollover, overflow, cover, discharge, presentation and material rules; unified clean-room RE module remains a later candidate.
- soundExpansionMP reclassified as a multi-capability patch pack rather than one sound subsystem.

## Open before first gameplay prototype

- Continue user-supplied and assistant-proposed candidate-mod audits across terrain, drivetrain UX, crop, contamination and visual effects.
- Confirm normalized wheel-state provider design with RealismCompatibility.
- Design the spatial history / brush scheduler for TerrainDeformation.
- Audit exact GIANTS TerrainDeformation calls and brush semantics before runtime writes.
- Measure TerrainDeformation cost and persistence behavior.
- Implement a small player-wheel deformation prototype behind a disabled-by-default feature flag.

## Not goals for the first prototype

- replacing MR traction;
- replacing Mud sink/stuck/resistance;
- replacing Reifen wear;
- replacing RMS;
- replacing SoilCompaction;
- replacing Dynamic PTO;
- reproducing all FarmKit features;
- creating a unified HUD before authoritative state exists.
