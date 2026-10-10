# Third runtime dataset: accumulated harvest damage → SHALLOW_DISC recovery

**Log capture:** `log(20261010-022723).txt` and `ModMixer(20261010-022723).log`; FS25 1.24.0.0. In-game runtime 2026-10-09 22:49–23:25 local (real operating diagnostic ~22:52–23:25).  
**RE ZIP actually loaded:** `feat/terrain-pto-integration-2026-10-09@3e3554a43d1c3c6b3305d609a799d8ffb48a7ca4` (Actions 37979193918).  
**RC ZIP actually loaded:** `main@ad7461fb7777691f6f64e2327753417c95b6177b`. Experimental occupancy broadphase PR #40 is **NOT installed** in this session. All measures are from this game log; no direct user screenshots, physical tape measurements or external updated engine geometry.

## Confirmed persistent save reload

The previous session `log(20261009-204016).txt` saved `1830` history cells to `savegame2`. This new boot explicitly reports `restored terrain history cells=1830` at 22:51:44, closing the earlier question about persistence in the *same save sequence*. New save at 23:09:55 stored `8158` cells, then at 23:25:45 stored `12258` cells; `Game saved successfully (savegame2)` follows both. Geometry-vs-sidecar validation did not abort this restore. Reload of newest 12258-cell state still unobserved; do not infer final geometry faithfully reconstructed from these counts alone.

## Operational coverage

A large S780 harvesting episode created real rut ownership. Subsequently the Fiat 180-90 DT with Koralin/MR 980 cultivated a disturbed area. At 23:20:20 the **first actual R7 recovery** appears; prior to that calls were zero. All recorded passes are **CULTIVATOR / SHALLOW_DISC**, not a seeder:

| completed pass | worked callbacks | changed | repeated | distance | duration | causal cells (per pass, nonunique) |
| 1 | 702 | 336 | 366 | 66.22m | 26.94s | 298 |
| 2 | 23 | 0 | 23 | 2.93m | 0.83s | 0 |
| 3 | 2046 | 335 | 1711 | 241.11m | 80.15s | 391 |
| 4 | 931 | 115 | 816 | 103.22m | 34.40s | 191 |
| 5 | 182 | 26 | 156 | 24.18m | 7.06s | 28 |
| **Total** | **3884** | **812** | **3072** | **437.66m** | **149.38s** | **908** (not unique) |

`TerrainRecovery v32R7` final: `calls=3885 worked=3884 intentCells=58623 intentPoints=22902 intentEmpty=1000 intentMaxRut=0.159m stampSkips=4886 enqueued=2883 rejected=0 callbacks=2883 centerUp=1014 centerDown=109 historyRecoveredCells=579 historyRecoveredDepth=3.643m protectedMarks=371879`, `activeCultivatorRutSkips=24403` and `cultivationProtected=0`. The 3.643m is a **sum across multiple historical debt reductions**, not depth of one rut or a guaranteed native physical height gain.

## R1 TARGET geometry — mixed success and serious convergence gap

Unlike older SMOOTH-only R7, the new path is active: `TerrainRecoveryTarget scheduled=19982 applied=2883 complete=354 stalled=831 targetComplete=169 noOp=1756 improved=945 worsened=90 initialPositiveSkip=185`. Native geometry callback counts show `targetRaised=1014 targetLowered=109`; the writer successfully submitted work. `centerRaise=24.6842m centerLower=0.4835m` are sums of measured center height deltas across callbacks; do **not** interpret as movement of a single rut or net ground mass conserved. `residualReduce=23.8572m residualWorsen=0.4026m` likewise sums and need spatial correlation to compare per location.

Important: `maxAbs=0.6650->0.6344m`, `patchMaxResidual=0.6846m`, `patch=12727/398 retained=12329`. The after-residual maxima and much larger-than-modeled (`modelRut max=0.180m`) structural residuals warrant careful root-cause audit of terrain-plane estimation, brush target positioning and the patch reconciliation mechanism. **It does not prove a real 63–68cm rut**: estimator reference may be affected by natural slope, uneven terrain, spatial mismatch, or differently defined reference plane. Nor can `retained=12329` automatically be treated as unique unrepaired physical cells (cumulative work metrics).

`noOp=1756` (60.9% of target applications), `stalled=831`, and `worsened=90` are substantial, despite 945 improved and 354 completions. **Do not mark R1 recovery complete or calibrated yet**. Note `TerrainRecoveryGeometry | relief=0 centerDeficit=0 convergence=0` is the *legacy SMOOTH-probe family*, while active `TerrainRecoveryTarget` has its own counters. Neither zero legacy counter nor all brush calls being TARGET implies R1 was idle.

## Plastic yield and native writer

`TerrainPlasticYield supported=98667 yielded=19716 maxYield=1.000 maxDemandBearing=5.17`, i.e. 83.35% supported / 16.65% yielded among classified decisions, **not** ratio of total wheel ticks/area/duration. A sample at end: `wet=0.72 slip=0.624 persistentSink=0.144 rut=0.144` is *one recorded contact*, not proof of a 14.4cm local measured rut. `Footprint pressurePa=110000..250000`, `maxLoadN=75763`, `wideSupport=12326`: provider handoff and nonconstant pressure now appear.

`TerrainDeformation runtime brushesAccepted=18765 enqueued=21648 coalesced=6788 submittedBrushes=14860 submittedJobs=6308 failedJobs=0 cells=12258 retired=579 modelRut=0.180m geometryProbe=2883 observedLoweringProbe=0.483`. `brushesAccepted` includes **only new rut** whereas `enqueued/submitted/jobs` include **recovery** (2883); hence do not subtract accepted and submitted directly to infer writer losses. Vehicle writers `S780=13879, 180-90_DT=3923, MR_980=963`; implementation may attribute the implement separately from root tractors. `TerrainActors PLAYER=1287, AI_FIELD=13494, AI_GENERIC=3984` accepted. AI is not fully suppressed; cultivator root is protected while working.

## RC integration and other mod stack

RC provider active and healthy (wheelContexts=54580, multiSupport=12566, 0 crawlers). `MRMudDraft draftCalls=33795 overrides=783 samples=783 wrapperLost=0`: now shows *actual soil-work overlay*, unlike preceding harvester-only `overrides=0`. `MudSoil localWetnessOverrides=11844`. `MRPTO stateHits=274550, RMSPTO effectiveRatioCapacityScopes=10141`; PTO controls also logged, although this session does not specifically calibrate PTO output shaft RPM. ModMixer active 59 targets, 0 unknown, healthy watchdog, unchanged June 2026 scan dataset. The eight `FS25_CBI6800CT.WoodGrinder` registration errors remain external known noise, not evidence of an RE regression. ModMixer version 1.4.2.1.

## Performance

`TerrainPerf` final: `vehicleUpdate=233371 avg=0.0468ms max=3.727ms total=10924ms`; `recovery=3884 avg=0.4096ms max=0.967ms total=1590.7ms`; `flushInclusive=4938 avg=0.4637ms max=1.647ms total=2289.7ms`; `callbackNested=6308 avg=0.0527ms max=0.203ms total=332.2ms`. Recovery callbacks in *actively damaged soil* differ qualitatively from earlier runs that were ~99% empty; do not infer FPS gains/regressions by naive mean comparison. Current ZIP does not include PR #40 spatial occupancy index. CI tests of PR #40 passed in isolation, but real-game performance not yet evaluated.

## Decision and next work

1. Continue same working RE ZIP `3e3554a`; **do not switch to PR #40 mid-cycle**, or change bearing thresholds just to make more/deeper ruts.
2. R1 real geometry completion is now the primary correctness issue. Review `TerrainRecoveryTarget`'s reference-plane estimator, mismatch against history cell center, and no-op/stall reasons before adjusting intensity or introducing a new actuator. Compare actual visual hole depth with logged reference residual at the same location, ideally from current screenshot and subsequent build test, not from raw aggregate maxima.
3. The **seeding after cultivation** acceptance gate remains unobserved; this log proves only harvest→shallow disc stages.
4. Persistence restore of 1830 confirmed, 12258 newer cells saved; latest reload still a future check, not a blocker.
5. No code changes justified yet by isolated maxima alone; prioritize audit and an explanation of R1 stalled/noOp semantics before any mechanical hotfix. Keep PR #40 a separate optional performance candidate, and PR #38 experimental.

**Status:** persistence and mixed-work integration PASS; R1 recovery PARTIAL and under audit; TerrainPlasticYield gate active but ordinary harvest→cultivate→seed acceptance PENDING.
