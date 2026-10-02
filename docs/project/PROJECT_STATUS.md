# Project status

Updated: 2026-10-02

## Release / development state

- Version string remains `0.0.1.0`.
- TerrainDeformation is an integrated baseline but remains under active completion/research.
- Active recovery work continues on canonical branch `feat/terrain-recovery`.
- TerrainDeformation and verbose diagnostics are intentionally enabled on the active development branch.
- SoilMassTransport is currently disabled while TerrainRecovery is isolated.

## Validated foundation

- RC normalized state consumption.
- Pressure/load/support-width wheel footprint for ordinary wheel contexts.
- Distance/cadence-based rut progression.
- Persistent SpatialHistory + savegame persistence.
- Server-owned TerrainDeformation writer with bounded jobs and async callbacks.
- Surface gating.
- Mud instantaneous sink separated from persistent RE plastic deformation.
- Physical TerrainDeformation smoothing path executes and changes terrain.
- Recovery evaluates local roughness change rather than center-height sign alone.

## Current TerrainRecovery state

v21 runtime showed smoothing could reduce measured local roughness but RE LOWER writes from the implement/root combination could still occur.

Root cause found in GIANTS Cultivator semantics:
- `realArea` = changed agricultural state;
- `area` = processed area;
- repeated passes may have `realArea=0` while still physically working.

v21 incorrectly used `realArea>0` for both recovery and rut suppression. A repeated pass could therefore become SMOOTH OFF + LOWER ON.

v22:
- marks active combinations before vanilla processing when the cultivator is enabled/moving;
- uses GIANTS `spec.isWorking` after processing;
- uses processed `area` for recovery;
- keeps repeated physical passes eligible for smoothing and rut suppression;
- has a regression harness for `realArea=0, area>0`.

Runtime validation is pending.

## Observability upgrade

New runtime diagnostics include cumulative changed/processed/repeated cultivation area and five-second causal windows for:
- work/change/repeat;
- smoothing/callbacks;
- roughness improved/worsened;
- rut writes blocked/accepted;
- per-writer/root window deltas.

See `docs/DEVELOPMENT_PROCESS.md`.

## Major remaining blockers

- validate v22 recovery without destructive writes;
- refactor work detection / footprint / terrain operation boundaries after runtime proof;
- first-class native crawler/track footprint;
- implement-wheel ordering relative to soil-working operation;
- adaptive SoilMassTransport realization/mass balance before re-enabling it;
- player/GIANTS AI/Courseplay parity;
- underbody/high-centering diagnostics;
- True AI Tracks ownership/retirement decision;
- performance/persistence regression validation.

## External precedent work

TerraFarm architecture audit is active at `docs/audits/terrafarm/README.md`. It is being used as a design precedent, not as a patch/bridge requirement.
