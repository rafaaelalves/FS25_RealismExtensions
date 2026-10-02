# FS25 Realism Extensions

A modular Farming Simulator 25 project for realism phenomena that are **missing** from the target specialist stack.

RealismExtensions does not try to replace mature systems merely to reduce the mod count. It consumes authoritative state and adds consequences such as terrain deformation only where ownership is genuinely missing.

## Current state

Version string `0.0.1.0` still identifies the development line, but TerrainDeformation is now an active experimental gameplay capability on feature branches. It is not finished or release-stable yet.

Start here:
1. `docs/project/CONTEXT.md` — stable project orientation.
2. `docs/project/CURRENT_HANDOFF.md` — exact current implementation and next runtime test.
3. `docs/DEVELOPMENT_PROCESS.md` — evidence/telemetry/testing rules.
4. `docs/project/PROJECT_STATUS.md` — capability state and blockers.
5. `docs/project/OWNERSHIP.md` / `ARCHITECTURE.md` — normative ownership and module boundaries.

## Relationship with RealismCompatibility

```text
specialist realism mods
        |
        v
FS25_RealismCompatibility
  normalized state/provider
        |
        v
FS25_RealismExtensions
        |
        +--> TerrainDeformation
        +--> future CropInteraction
        +--> future SurfaceEffects
```

RealismCompatibility coordinates overlapping external mods. RealismExtensions owns only missing phenomena. Feature modules should not independently reach into MoreRealistic, MudSystemPhysics, Reifenverschleiss, RMS, SoilCompaction or Dynamic PTO internals.

## Active module: TerrainDeformation

The active research/development target is a common player/AI/implement deformation engine driven by authoritative:
- longitudinal and lateral slip;
- local wetness;
- sink depth;
- load/footprint;
- tire dimensions;
- surface state;
- freeze/thaw state.

The goal is to make the terrain visibly respond to physics already produced by MR + Mud rather than creating another traction/sink simulation.

This module is also the first candidate for functionally replacing True AI Tracks.

## Clean-room policy

FarmKit was audited to identify useful phenomena and architectural gaps. Its source/assets are not copied into this project. Replacement behavior is independently designed and implemented.

See `docs/decisions/` for decisions that should survive future context loss.

## Development

CI:
- runs Lua harnesses;
- validates `modDesc.xml`;
- validates declared source files;
- builds `FS25_RealismExtensions.zip`;
- verifies the ZIP root.

The `main` branch should remain a coherent, reviewable state. Research/feature work belongs on focused branches.
