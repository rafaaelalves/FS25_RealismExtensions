# Project status

Updated: 2026-09-28

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
- Realistic 4x4 audit scaffold created; exact ZIP still pending.

## Open before first gameplay prototype

- Audit the exact Realistic 4x4 Traction System ZIP once attached.
- Continue user-supplied candidate-mod audits across terrain, drivetrain UX, PTO, tire wear, crop and visual effects.
- Confirm normalized wheel-state provider design with RealismCompatibility.
- Define exact slip semantics and units.
- Define terrain/wetness/freeze/source ownership.
- Audit True AI Tracks source/runtime behavior before functional replacement.
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
