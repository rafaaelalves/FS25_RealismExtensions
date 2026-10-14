# FS25 Realism Extensions

A modular Farming Simulator 25 project for realism phenomena that are **missing** from the target specialist stack.

RealismExtensions does not try to replace mature systems merely to reduce the mod count. It consumes authoritative state and adds or absorbs missing consequences only where ownership is genuinely missing.

## Current state (2026-10-13)

**Production `main` includes native PTO V1.6**, merged in PRs [#39](https://github.com/rafaaelalves/FS25_RealismExtensions/pull/39) and [#45](https://github.com/rafaaelalves/FS25_RealismExtensions/pull/45). The companion [RealismCompatibility](https://github.com/rafaaelalves/FS25_RealismCompatibility) `main` contains the MR/RMS bridge and the HM10-500 PROFILE 1000 vs MR raw 540 normalization fix ([RC #25](https://github.com/rafaaelalves/FS25_RealismCompatibility/pull/25)). Source/CI and selected singleplayer scenarios were validated; a real multiplayer session is **not validated**.

**Current normal-play module settings:** `PTOControl=true`, `TerrainDeformation=false`, verbose/performance diagnostics disabled. Terrain's registration/bootstrap is inert while disabled, so the stable PTO build cannot create new research ruts. Experimental terrain branches require separate explicit opt-in and should not be used as the everyday `main` ZIP.

The repository mod version remains `0.0.1.0` (active development); PTO `V1.6` is a functional milestone. The validated wheel-based terrain baseline exists in the repository, **not a completed production deformation/recovery module**. Its next acceptance gate is repeated-pass rut recovery followed by a traversable seedbed and ordinary soil-yield restraint.

**What's next:** [current roadmap and ownership](docs/project/ROADMAP.md), [post-PTO-V1.6 priority review](docs/project/2026-10-13-POST-PTO-V16-ROADMAP-REVIEW.md) and [current handoff](docs/project/CURRENT_HANDOFF.md). The old `feat/terrain-distance-response-v7` instructions farther below are historical research checkout examples, **not the present active development branch**.

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
        +--> native PTOControl (main, enabled)
        +--> TerrainDeformation (main code, disabled)
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
- pull requests that include non-documentation changes;
- manual `workflow_dispatch`.

Documentation-only changes under `docs/**` or Markdown-only commits are ignored by the automatic push/PR workflow, so they do not build or upload a mod ZIP. Mixed code + documentation commits still run the full CI.

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

For an **older archived v7 terrain experiment (not current release)**:

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
