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

PTO smoke passes classification and bridge installation. The normalized RC state provider 2/2 and terrain callback activation were **confirmed in the 2026-10-09 repeat** documented below. This completes the previously missing provider compatibility smoke; model-specific physical PTO gearing/hand-throttle and the separate terrain severity defects have different validation scopes. PR #33/#16 are not automatically merged by this finding.

## Repeat combined smoke — 2026-10-09 00:56–01:01 local

Uploaded: `log(20261009-040128).txt` and `ModMixer(20261009-040128).log`.

**Exact builds:**
- RE PR #33 merge build `38992a026c02f18f5c8248dac9989cbde99795a8`, Actions run `37807491695`.
- RC PR #16 merge build `001774b38b16ef92310ef2f267de11f642b12212`, Actions run `37802023323`.

**Positive regression evidence:** `normalized state provider active: FS25_RealismCompatibility`; terrain enabled, sampled `3266` wheel contexts via RC provider. RC confirms `MR+RE PTO ACTIVE` and `RMS+RE PTO ACTIVE` and normal Mud 1.3.6 / MR 0.26 / RMS 0.11 / Reifen bridges. Non-PTO cultivation on JD 7R310 stays `consumers=0`, avoiding incorrect PTO load. `ModMixer` 59 named hook targets and 0 unknown hooks, but the pre-existing hook re-registration warning remains. No evidence of direct PTO ratio operator change, so do not claim independent full PTO speed-mode gameplay validation from this log.

**Core causal interpretation:** GitHub comparison of RE PR #33 vs RE `main` reveals **no modified `scripts/terrain/**` source files**; all terrain core and surface response remains present in `main`. The RE PR's `scripts/api/StateContract.lua` 1/1 -> 2/2 fix restores compatibility with the existing RC provider. The earlier `20261008-151659` smoke logged provider mismatch and `context=0/85278`, `brushesAccepted=0`; the current run proves the disabled terrain engine was reactivated. The PTO work **did not directly implement a new excavation model**, but the provider-version repair made the existing source produce geometry again. This is a genuine behavior change caused by the compatibility fix and must be acknowledged.

**Newly observed terrain activity (cumulative around 01:01:01):**
- 16 tracked vehicles, 58 wheels, `3266` context requests / `2482` accepted contact contexts; `11963` accepted wheel brush samples, `11473` submitted brushes, `2516` callback jobs, 0 failed jobs.
- Maximum **modeled**, not geometrically measured rut is **0.080 m**; instantaneous Mud sink reaches **0.168 m**, plastic persistent sink reaches **0.080 m**; latest coherent sample: local wetness `0.76`, slip `0.304`, instantaneous sink `0.133 m`, plastic transfer `0.59`, persistent sink `0.079 m`. Earlier coherent sample wet `0.26` while brushes were already being applied. **No recorded rainfall event proves that rain started**. Field soil and travel may produce different wetness readings.
- `FIELD_SOFT=5885 seen/5864 brushes`, `FIELD=6172/6099`, compacted dirt 136/0, hard 18/0. In `SurfaceResponse.lua`, cultiv/plow/seedbed/stubble tokens select `FIELD_SOFT` with `maxStaticRutDepthM=0.08`, `maxSlipRutDepthM=0.18`, deformability=1.0. The `FIELD_SOFT` profile has no rain-only minimum wetness. This may be excessive for the user-defined "deepest rut only during actual rain" playability target. The same user observes starkly deeper ruts than when cultivating in the previous, provider-disabled morning session.
- JD 7R 310 `(Cultivo 6)` Courseplay driver active 47 seconds, overlapping geometry mutation; the aggregate log **does not attribute individual brushes to a vehicle, position, implement, or field ID**, so do not assign a specific hole to that vehicle without per-wheel/brush diagnostics.

### High-priority latent risks exposed (terrain issue, not PTO scope)

1. **LRU terrain history eviction can re-excavate persisted ground**: `TerrainDeformationEngine.DEFAULTS.maxHistoryCells=50000` and `historyCellSizeM=0.20`; `SpatialHistory:commit()` drops **1000 oldest cells** when max exceeded; the session loads **49913 history cells**, runtime `cells=49984` at 01:00:16, then `49753` at 01:00:21 while processing many new brushes — pattern consistent with live pruning. `TerrainDeformationEngine.processSample` uses `previousDepth=0` when a cell has no history and reconstructs rut progression from zero; the actual GIANTS terrain heightfield may still contain the excavated geometry. Returning to an evicted cell could therefore lower it **again** beyond the intended per-cell physical cap. Needs reproducible failure test with simulated LRU eviction and real geom probe before choosing remedy. Increasing maxCells is only a memory-costly palliative, not an invariant-preserving correction.
2. **Transport/berm volume overshoot:** at 01:01:01, `SoilMassTransport targetTransport=1.596 m3` and `raised=4.200 m3`, `realization=2.63`, `balanceError=+2.604 m3`; `berms=917`. Callback volumes are GIANTS-reported displaced volumes, **not validated ground height samples**; yet overproduction relative to requested berm volume implies calibration or reporting-model problem, with potential for exaggerated ridges. Do not interpret the reported `displacedVolume=282.883` as independently measured net material displacement.
3. **Geometry evidence missing:** `geometryProbe=0`, `requestedDepth=0.000`, `observedLoweringProbe=0.000`. Thus modeled 8cm rut, Mud transient 16.8cm sink and callback volume cannot be equated to visually measured rut depth or actual material balance. Enable *bounded* sampling at a small number of brushes before making stronger claims.
4. **Historical geometry vs current field treatment:** restored sidecar holds rut/shear history, and GIANTS terrain geometry can persist across cultivation (which changes field status/textures). Neither `TerrainPersistence.load` nor `SpatialHistory.importSnapshot` itself digs on load. Distinguish already persisted field topography from new deforming wheel traffic using pre-drive snapshot.
5. **Performance interpretation:** active terrain now costs `vehicleUpdate=9657 avg=0.0702ms max=3.117ms total=678.2ms`, `flush=723 avg=0.1260ms total=91.1ms`, `callback=2516 avg=0.0272ms total=68.5ms`. Old `avg=0.0092ms` was with zero terrain jobs; never advertise their simple ratio as overall FPS delta. Terrain async queue/heightfield cost and GPU frame timing not captured. ModMixer warns `53926` interceptor calls vs `1520` stored; no direct attribution to PTO or terrain.

**Priority next step:** isolate terrain-recovery feature's correctness gates (geometry delta with tiny sampled budget, LRU eviction invariant, berm feedback control and surface/wetness severity), rather than silently changing excavation constants inside PTO consolidation. Back up the player's savegame before running tests that write terrain heightmaps; this session logs an exit but does not independently prove whether deformed ground was persisted afterwards.

The provider-version acceptance gate from prior smoke **passes** with the paired RE/RC builds. PTO PRs should be judged independently of pre-existing terrain calibration defects, with any specific control/physical gearing checks being separately scoped; no automatic merge here.

## PTO-only review after 2026-10-09 repeat (following user terrain clarification)

The user's cultivation/field restoration uses a separate terrain workstream. Any surface interpretation belongs there; a `wet=0.26` and later `wet=0.76` from aggregate wheel samples is **NOT** evidence of a time evolution at one physical field position, and rain was explicitly absent. No changes to `scripts/terrain/**` in the PTO branch.

**Validated:** RC provider 2/2 active, MR+RE PTO and RMS+RE PTO install, integration telemetry `manualGovernorScopes=1466`, `effectiveRatioScopes=729`, `stateHits=13717`, and `RMSPTO.effectiveRatioCapacityScopes=296` demonstrate live bridge execution. **Not validated by this run:** operator switching gear with real 540/1000 PTO implement engaged/disengaged, exact shaft/motor RPM, hand-throttle command vs actual RPM, AI operation, savegame persistence and MP round-trip. `handThrottleControlCalls=0`, `handThrottleGovernorScopes=0` and `causalitySamples=0` make it incorrect to call those behaviors fully accepted. The John Deere 7R 310 cultivation was a **non-PTO** work task.

**Defect fixed in PTOResolver:** the original detection mapped all `spec_powerConsumer.ptoRpm >= 750` to `1000` and all other positive values to `540`, creating false 1000 compatibility for 750, 900, 1300, 1400 PTO consumers. Now preserve the exact manufacturer/native `ptoRpm` in requirement collection; 750/900/1300/1400 remain unselectable under the present four-mode rear PTO gearbox UI but explicitly mismatch instead of silently misclassifying. Regression harness covers every value and contradictory attachments. This does **not** implement additional shaft modes.

**Merge readiness:** automated build and behavioral harness should pass again. After that a **single focused in-game PTO acceptance scenario** is still required to verify a verified tractor with a real 540 implement and preferably a 1000 tool, switching off/on with interlock, operating hand-throttle vs actual RPM, changing from ROAD, AI/idle restoration, save-and-reload, and no additional logging/physics errors. Once these specific behaviors are evidenced, PR #33 and #16 can be individually marked ready and merged without using the separate terrain calibration task as a PTO merge blocker. Factory package unknowns are documented scope limits, not a reason to wait for every DLC model to be operated.
