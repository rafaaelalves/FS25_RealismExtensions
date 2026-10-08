# Mainline PTO joint smoke and performance observation — 2026-10-08

## Exact evidence

Uploaded: `log(20261008-151659).txt` and `ModMixer(20261008-151659).log`; session about 11:59–12:16 local.

Loaded RC PR #16 merge build `167ea97ba200a58d3cf56678804ed92dd2743cdc` (run 37794670735) and RE PR #33 merge build `0d2eb36aeadfabe4c62c5e1e865874005ab9ed01` (run 37794959789).

- `MR+RE PTO ACTIVE` and `RMS+RE PTO ACTIVE` (RMS 0.11 SOURCE_COMPATIBLE).
- MR+Mud, MR+RMS, Mud+RMS, MR+Tire and Mud+Soil ACTIVE for Mud 1.3.6, Reifen 1.2.2.70 and RMS 0.11.
- Non-PTO 7R 310 cultivation attachments: `consumers=0`.
- VariPack attachment: `consumers=1 required=540 source=POWER_CONSUMER_PTO_RPM`.
- Heizohack attachment: `consumers=1 required=1000 source=PROFILE`.
- MRPTO and RMSPTO runtime scopes active (at teardown: manualGovernorScopes=65547, effectiveRatioCapacityScopes=3034, runtimeReinstalls=0). These counters demonstrate active integration but do not on their own validate hand throttle RPM behavior.
- ModMixer: 58 active targets, zero unknown hooks. Hook-registration diagnostic `53448 calls/1519 stored` warrants separate instrumentation before assigning overhead.

## Blocking regression uncovered

RE `StateContract` in stable `main` was still requiring RC provider API 1 and wheel-context schema 1, but current RC supplies versions 2/2. Thus `normalized state provider unavailable: provider API version mismatch: expected 1, got 2` was logged 964 times (~once per second), and terrain `context=0` throughout this test. It makes the run unsuitable as a terrain-work or whole-stack performance acceptance test; the PTO API is separate.

Fix in this consolidation: use the already-vetted 2/2 `StateContract` and harness from the PTO development branch (no terrain experimental code). Repeat smoke after CI.

## Other log findings

- GIANTS reported the RE PTO dashboard icon DDS as raw-format texture (three warnings). The build now generates DXT5-compressed DDS, retaining alpha. Verify warning disappears after reinstall.
- Non-RC/RE issues: eight duplicate vehicle specializations from `FS25_CBI6800CT.WoodGrinder` at startup, and pre-existing `manualAttach` `delete(nil)` on map teardown. Do not conflate these with PTO regressions.
- DynamicPTO package appears in the available-mod directory listing, but RC runtime says `DynamicPTO=-`, and the native PTO bootstrap was active. Folder presence is not the same as active mod use.

## Performance observation (qualitative, not causal)

The player reports less stuttering and improved subjective stability, still below desired 90 FPS, with multiple simultaneous stack/environment changes. Neither uploaded log has a measured FPS/frametime series or a controlled before/after comparison.

RE TerrainPerf at end: `vehicleUpdate=165572 avg=0.0092ms max=0.406ms total=1519.7ms`; `flush=0`, `callback=0`. Because the RC wheel-context provider was rejected, these timings cover a largely idle/bypassed terrain path and **cannot** be treated as representative of working terrain deformation.

### Optimization backlog / validation method

1. Fix version regression and use the two paired CI artifacts; verify provider active and real terrain contexts before interpreting cost.
2. Capture A/B runs on identical save, camera path, weather, time, hardware graphics and player activity, recording frame-time median/p95/p99 and >33.3ms or >50ms hitch counts (not just average FPS).
3. Measure terrain deformation, callback/queue flush, MR-Mud, PTO, RMS, Reifen and HUD hooks separately using bounded/optional telemetry; watch cumulative total, call count, max and call frequency.
4. Separate CPU simulation, render (1080p Ultra with V-Sync, extended view/LOD and RTX 3070 Ti), texture loading and log/diagnostic overhead before optimization. No forced feature reductions without evidence.
5. Prefer cached normalized context, event-driven invalidation and no redundant per-wheel queries; add regression tests for correctness and cost on hot paths.
6. Track performance observations and experiments in RC/RE release handoff as ongoing work alongside features, not as proof of any one change's improvement.

## Gate

PTO smoke passes classification and bridge installation. Full integration smoke remains **blocked** until RC state provider 2/2 activates in RE and a short repeat verifies intended physical behavior. PR #33 and #16 remain draft; do not merge prematurely.
