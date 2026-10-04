# Branch consolidation and cleanup — 2026-10-04

Status: **CONSOLIDATION IN PROGRESS**

Goal: return the repository to a simple operating model.

## Branches to keep

### `main`
Purpose:
- validated, reviewable baseline only.

2026-10-04 consolidation:
- pre-recovery terrain foundation through `perf/terrain-profiler-v10-2` was merged normally into main;
- recovery v11+ was intentionally excluded because current recovery still has open runtime/design issues.

Main merge commit:
- `8f73ad416d1de1c19fbd1e67df999d3e922d2f41`

### `feat/terrain-recovery`
Purpose:
- **single canonical active development branch**.

After this cleanup it should contain:
- current recovery implementation/research;
- tracks/VMT assimilation checkpoint;
- Hydraulic + 4x4 audit documentation;
- next TireTrack `createTrack` bootstrap experiment.

Do not create a new branch for every recovery or tracks experiment. Use commits + CI identity + runtime docs for milestones.

## Branches that become redundant after canonical fast-forward

- `feat/assimilation-tracks-vmt`
- `audit/assimilation-hydraulic-4x4`

Their content is consolidated into canonical active work.

## Historical linear checkpoints safe to remove

These are preserved by the consolidated history of main or the canonical active branch:

- `feat/terrain-distance-response-v7` — `8f955a31cfb2fe9d64c28b017350ce185f64ad1c`
- `feat/terrain-mass-transport-v9` — `8015c8441ccf33f706810841b4db254796d02d19`
- `feat/terrain-plasticity-response-v10` — `b6193fd072d23812dc6b5799918c8e6ef2aa086e`
- `perf/terrain-runtime-v10-1` — `3a7391153a5919ad13f64fb72b01083141e086d1`
- `perf/terrain-profiler-v10-2` — original baseline tip `d866800e67138383252ab9f5d18c1e292a9a6e1d`
- `perf/terrain-writer-coalescing` — `97a096ef0094eb24312d99397d88369f41244bb3`
- `feat/terrain-recovery-v11` — `f44ad2c259f2ad3a2170c2be0616af9e1d1599d9`
- `feat/terrain-recovery-v12` — `16d11a5604a8bdf8c245b0a6260c6fdaf6b93821`
- `feat/terrain-recovery-v13` — `e10c806105d0870c59a499d39bcc67351fca70ea`
- `feat/terrain-recovery-v14` — `cdb61e0a5bf0d534fc66b6ba3245b73b35d85318`
- `feat/terrain-recovery-v15` — `a7fa63cb0eac52d977d2b8154efd93a2466c7586`
- `feat/terrain-recovery-v17-native-soften` — `031b2c25b0086e32176a970147e55e0eba119a86`
- `feat/terrain-recovery-v18-native-chain` — `18f3451ffb5841a21f1c28befa698e4420634e04`
- `feat/terrain-recovery-v19-runtime-native-smooth` — `4f49b974341e306d3108b5f5d06b3e521445c8e6`
- `feat/terrain-recovery-v20-cultivation-isolation` — `57ea3829db5f898501934ffcc595865dc1c2ccf2`
- `feat/terrain-recovery-v21-machine-smoothing` — `de0ade4abcacca410573dd57c6665ca344b6e03f`
- `feat/terrain-recovery-v22-physical-work-state` — `0c11126cd246bb96a4dab82e791da30e255a7219`

## Superseded divergent experiments to remove

These are intentionally **not** merged as active behavior. Their exact tips are retained here for archaeology:

- `feat/terrain-geometry-v5` — `f8c6bfc22c37929419f7094e1abb131c35229a2e`
- `feat/terrain-surface-response-v6` — `551d64b27a2b9d1dbcef7f28943910732c996e18`
- `feat/terrain-underbody-relief-v8` — `2919b10a370c5fc2a038ee232af18702f8c550d7`
- `feat/terrain-recovery-v16` — `8d048c311458d24af1160be74d80bbfa62f0b342`
- `test/slip-sinkage-metrics-v5` — `2a1fa1382f13ef0c68020d0870ac106a84a17839`
- `test/terrain-deformation-runtime` — `7b98461d4a2d3a0d47e37c8a962cc8c295d6540e`
- `test/terrain-deformation-runtime-v2` — `c21500dcade451011b5e139fed93222a767239ba`
- `test/terrain-deformation-runtime-v3` — `d36b2cf763d003a094255d9064ced7b143b53b5e`
- `test/terrain-integration-v4` — `e3fae4a816acaba71f03cc71a456d745f7dbc93c`

These old test/experiment branches are not current recovery candidates. Current project docs preserve accepted findings and rejected/superseded directions.

## Pull requests

Obsolete draft PRs #25, #27, #28, #29 and #30 were closed after consolidation.

PR #31 merged the validated terrain foundation to main.

PR #32 merged Hydraulic/4x4 audit research into the active development line.

## CI policy after cleanup

Build workflow:
- runs for runtime/code/test/workflow changes on supported branches;
- **does not run for documentation-only changes** under `docs/**` or Markdown-only commits;
- mixed code + docs commits still run normally;
- manual `workflow_dispatch` remains available.

## Remote deletion limitation

The available GitHub connector can merge/close PRs and move refs but does not expose ref deletion.

Therefore actual remote branch deletion must be performed outside this connector after verifying the canonical branch fast-forward.

Target visible branch set after deletion:
- `main`
- `feat/terrain-recovery`

No other branch is required for current work.
