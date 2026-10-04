# FS25 Realism Extensions

A modular Farming Simulator 25 project for realism phenomena that are **missing** from the target specialist stack.

RealismExtensions does not try to replace mature systems merely to reduce the mod count. It consumes authoritative state and adds or absorbs missing consequences only where ownership is genuinely missing.

## Current state

Version `0.0.1.0` is an active development line.

`TerrainDeformation` has a validated wheel-based baseline in `main`, but the module is intentionally still open while low-speed invariance, dual/twin behavior, crawler support and AI/implement parity are completed.

Start here:
1. `docs/project/CURRENT_HANDOFF.md` — exact active development handoff.
2. `docs/project/PROJECT_STATUS.md` — current state and completion blockers.
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

RealismCompatibility coordinates overlapping external mods. RealismExtensions owns missing or deliberately absorbed phenomena. Feature modules should reuse normalized authoritative state instead of independently reaching into MoreRealistic, MudSystemPhysics, Reifenverschleiss, RMS, SoilCompaction or Dynamic PTO internals.

## TerrainDeformation

The active terrain module targets one player/AI/implement deformation engine driven by authoritative:
- longitudinal and lateral slip;
- local wetness;
- sink depth;
- load/footprint;
- tire dimensions and pressure;
- surface state;
- freeze/thaw state.

The goal is to make terrain geometry respond to physics already produced by MR + Mud without creating a second traction/sink solver.

The module is also the candidate for functionally absorbing the relevant parts of True AI Tracks after parity is proven.

## Clean-room policy

FarmKit and the other retained external sources are audited to identify useful phenomena, ownership boundaries and implementation precedents. Their code/assets are not copied into this project. Replacement behavior is independently designed and implemented.

See `docs/decisions/` and `docs/audits/` for decisions and source analyses that should survive future context loss.

## Development

CI runs automatically on:
- `main`;
- `feat/**`;
- `fix/**`;
- `perf/**`;
- `test/**`;
- `diag/**`;
- `chore/**`;
- `research/**`;
- every pull request;
- manual `workflow_dispatch`.

Every successful run:
- runs all Lua harnesses;
- validates `modDesc.xml`;
- validates declared source files;
- builds `FS25_RealismExtensions.zip`;
- verifies the ZIP root;
- records a SHA-256 checksum;
- uploads a 30-day artifact named `FS25_RealismExtensions-<commit SHA>`.

### Updating an existing clone

To update `main`:

```bash
git fetch origin --prune
git switch main
git pull --ff-only origin main
```

To check out a test branch for the first time:

```bash
git fetch origin --prune
git switch --track origin/<branch-name>
```

If the test branch already exists locally:

```bash
git fetch origin --prune
git switch <branch-name>
git pull --ff-only origin <branch-name>
```

For the current v7 test:

```bash
git fetch origin --prune
git switch --track origin/feat/terrain-distance-response-v7
```

If that branch already exists locally, use:

```bash
git switch feat/terrain-distance-response-v7
git pull --ff-only origin feat/terrain-distance-response-v7
```

The `main` branch should remain a coherent, reviewable state. Runtime-test settings belong on focused branches and must be restored to safe production defaults before merge.
