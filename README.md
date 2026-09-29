# FS25 Realism Extensions

A modular Farming Simulator 25 project for realism phenomena that are **missing** from the target specialist stack.

RealismExtensions does not try to replace mature systems merely to reduce the mod count. It consumes authoritative state and adds consequences such as terrain deformation only where ownership is genuinely missing.

## Current state

Version `0.0.1.0` is an infrastructure-only foundation. It has no active gameplay effects.

Start here:
1. `docs/project/CONTEXT.md` — short handoff for a new contributor/chat.
2. `docs/project/PROJECT_STATUS.md` — current state and next work.
3. `docs/project/OWNERSHIP.md` — normative phenomenon ownership.
4. `docs/project/ARCHITECTURE.md` — boundaries and module rules.
5. `docs/project/ROADMAP.md` — capability roadmap.

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

## First planned module: TerrainDeformation

The first research target is a common player/AI/implement deformation engine driven by authoritative:
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
