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
- TerrainDeformation engine merged (disabled by default): vehicle-local specialization, bounded spatial history, path sampling, budgeted/quantized brush batching, server-only writes and explicit GIANTS queue lifecycle ownership.
- Long-session telemetry baseline captured (~8h57m): RC integrations remained stable under millions of wheel-path calls; MRRMS avoided 99.9978% redundant driven-wheel rebuilds and DynamicPTO scopes entered only ~0.31% of hot calls.
- Computation ownership ledger added: separates effect ownership from actual avoided computation and tracks residual overhead (FarmKit plowing/dust wrappers, MudSoil wetness sampling, development telemetry).
- RE packaging/provider discovery fixed: icon is now packaged/validated and RC provider is resolved through the FS25_RealismCompatibility mod environment rather than assuming a shared global.
- ExtensionsStateProvider changed to reuse-first semantics for fresh MRMud wetness/structural-radius snapshots and MR slip cache, with telemetry to measure snapshot hits vs fallbacks.
- MoistureSystem confirmed as KEEP + BRIDGE specialist with explicit agronomic/material moisture domains.
- Loose-material ownership decomposed into rollover, overflow, cover, discharge, presentation and material rules; unified clean-room RE module remains a later candidate.
- soundExpansionMP reclassified as a multi-capability patch pack rather than one sound subsystem.

## Open before first gameplay prototype

- Continue user-supplied and assistant-proposed candidate-mod audits across terrain, drivetrain UX, crop, contamination and visual effects.
- Confirm normalized wheel-state provider design with RealismCompatibility.
- Runtime-validate TerrainDeformation brush scale, queue callbacks and performance in FS25.
- Validate player, attached implement, GIANTS AI and Courseplay behavior before replacing True AI Tracks.
- Design savegame persistence or another safe reconciliation strategy for spatial response history.
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
