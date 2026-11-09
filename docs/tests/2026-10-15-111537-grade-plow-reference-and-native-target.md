# 2026-10-15 07:43–08:15 — grade and plow: reference V2 rejects, native TARGET no-ops and concurrent rut writers

Evidence: user's uploaded `log(20261015-111537).txt` (8,384 lines) and `ModMixer(20261015-111538).log` (143 lines). This is the first full R1 field session on PR #53 `53/merge@fee104b9df41d860830e4115d0a5a0b0c8e05de1`, Actions 38665763521, alongside RC `main@f04d28cdf5dfa171122b9fd3d17f9f1a77061011`. The final log tail starts another game's initial startup after the save and is NOT a second completed gameplay session.

## Save and versions

- FS25 1.24.0.0, São Carlos map; TerrainDeformation enabled; `restored terrain history cells=28919` at 07:49:22; `saved terrain history cells=29994` at 08:14:55; `Game saved successfully (savegame2)` at 08:14:58. Difference is +1075 history cells, NOT +1075 independent physical potholes. Prior session saved 28918; one-cell discrepancy not evidence of loss.
- 8 startup duplicate-specialization errors arise from unrelated `FS25_CBI6800CT.WoodGrinder`. No RE/RC Lua exception seen. ModMixer 59 live targets, 0 unknown, healthy; `Cutter.onEndWorkAreaProcessing` reorder drift due to `FS25_CombineXP` missing live hook, reverted NATURAL order; does not implicate cultivation's recovery without further trace.
- Research PR #53 is **observability only** for predeformation references; logging of `terrainUnit=1.0000m` and optional logical 0.2m-cell anchors is not yet mesh-vertex reconstruction or a change in TARGET actuation. Do not present PR #53 as a correction.

## Work sessions and tool-by-tool outcome

- 24 identified TerrainPass sessions: 15 CULTIVATOR / SHALLOW_DISC completed by ~08:03:57, and subsequent PLOW sessions through 08:14:56. IDs represent engine's work activity windows, NOT guaranteed multiple traversals of the same rut.
- At end of SHALLOW_DISC phase: 7185 physically worked work areas, 6306 history-guided intent points, 4934 structural attempts marked scheduled, **586 native TARGET applied**, **487 center unchanged (83.1%)**, 73 toward +12 reached (85, 14.5%), 14 away (2.4%). `historyRecoveredCells=200`, accumulated logic debt resolved=.919m across cells, NOT recovered geometric depth of one rut.
- Final after PLOW: 10856 worked areas, 10120 intent points, 9049 scheduled, 864 applied, 613 unchanged, 185 toward, 32 reached, 34 away, 505 history cells retired. **PLOW incremental**: 3671 worked areas, 3814 intent points, 3536 scheduled, 278 applied, **126 center unchanged (45.3%)**, 112 toward +20 reached (132, 47.5%), 20 away (7.2%), 305 cells retired. Direct tool comparison is confounded by different areas, profile strength, and concurrent harvester/tractor traffic. `PLOW` target strength .42, base amount .85; `SHALLOW_DISC` strength .30, base amount .65, but BOTH use tiny 0.45m TARGET radius.
- Full-scope 864 jobs: 613 no center movement, 217 improvement/reached, 34 moved away. `targetRaised=219`, `targetLowered=32`, none additive RAISE/SMOOTH. `maxAbs=0.7174->0.5773m` and `patchMaxResidual=.6404m` are relative to a fitted post-damage plane, **not** measured crater depths; `intentMaxRut=.012m` and runtime `modelRut max=.134m` are different tracking metrics. Do not infer a single rut of 72cm or 5.8m lift from the totals.
- Same location sampling proves both behaviors: at x=390.40,z=312.20 two successive SHALLOW_DISC pulses amount .650,.812 kept center at 152.1680908 while target was 152.2761; at x=388.80,z=386.20 two TARGET pulses raised measured center by ~12.5mm each, with ~21mm contemporaneous fitted-reference drift; x=388.80,z=326.40 lowered by 2.3mm on two attempts away from original TARGET. Therefore neither complete no-op nor universally successful actuator.

## Reference V2 repeatedly rejecting known points: confirmed work amplification

- Final reference evaluations: **accepted=1106 rejected=376172**. All rejection reason codes `CURVED_OR_INCONSISTENT`. Mean rejected difference between inner/outer plane intercepts .1398m, max .3882m; 233835 evaluations had >.1m discrepancy. These are repeated measurements, **not distinct 376k locations**; we must not relax threshold 35mm globally simply to increase acceptance.
- The problem persists **after the disc work stops**: at 08:03:57 referenceV2 accepted=686, rejected=111997, TARGET applied=586; by ~08:08 rejected exceeded 252305, while accepted stayed 686 and TARGET remained 586. Thus a retry/deferred code path is repeatedly evaluating unsupported references without new physical work, not just tool pass processing.
- Source confirms `enqueueStructuralRecoveryPoint` calls `measureRecoveryAt()` and when nil increments rejected/stalled, clears stamp, returns false. A deferred structural retry can requeue the same failed location; `structuralStalled=376425`, `deferredChecks=423943`. Need unique rejected spatial-key counter, failure-age stats, geometry/history-epoch keyed negative cache with TTL/invalidation, and stop/retry policy. Do not cache forever or hide genuine geometry improvement.

## Heightmap and actuator: strong testable hypothesis

- PR53 logs `getTerrainHeightmapUnitSize` **1.0000m**. SpatialHistory logical cell pitch is 0.2m. Both SHALLOW_DISC and PLOW native brushes use TARGET radius .45m, so many centers could miss/underweight native terrain vertices depending GIANTS brush footprint and alignment. The measured center is interpolated; no center movement does not prove no vertex elsewhere moved. 1m lattice **suggests** grid misalignment as a contributor, NOT demonstrated root cause.
- Next experiment should be **on a disposable isolated patch** with same fixed valid target and existing history: sample native vertex grid + center before/after; controlled radius relative to terrain unit (0.45 vs >1.0m), and amount/strength one variable at a time, on-grid/off-grid. Enforce per-cell and aggregate displacement caps, no additive unbounded RAISE or global strength escalation.

## New rut writers during recovery (cannot call plow a net degrader without spatial A/B)

- Final 2510 accepted rut writes attributed S780=1340, MR_980=911, Fiat 180-90 DT=232, Juwel 6 M V 4.1=27; root counts S780=1340 and Fiat=1170. All attribution is accepted brush requests, not physical heightmap deltas.
- At end of all SHALLOW_DISC work, writers were S780=1184, MR_980=780, Fiat=184, Juwel=0. After that, additional S780=156, MR_980=131, Fiat=48, Juwel=27 wrote rut brushes. Thus **harvester and traffic continued to create ruts during later PLOW period**. Cannot attribute worsening to plow alone; sample coordinates and timing must be compared to actual worked lane.
- Juwel sample around 08:10:59 at x390.7,z375.0: `wet=.755 slip=0 sink=.149m transfer=.567 plasticYield=.998 load=13800N pressure=250kPa newModel=.085m acceptedDelta=.0030m` — not proof native terrain lowered 8.5cm; it is a modeled target with 3mm accepted increment. This highlights implement contact writes while physically working and the need to classify tool transport/support wheels vs soil-engaging tips; current active cultivation suppression blocks many samples (`activeCultivatorRutSkips=88600`) but still 27 Juwel writes.
- Fine-grained `TerrainDeformation runtime` reports zero `failedJobs`, although it cannot prove correct geometry; source geometry probes are Recovery TARGET-only, ordinary rut writes have no native height verification.

## First-touch references PR53: read-only evidence

- At final `TerrainPreDeformReference captured=1579 preserved=892 legacyOrUnavailable=39 sampleUnavailable=0`, native mesh size 1m. These are pre-write samples at *logical 0.2m grid cells*, not verified anchors of the 1m native vertices. Existing deformed legacy cells must NOT be assigned synthetic pre-rut baseline.
- Save/reload gate: subsequent load should show persistence/optional anchor survival with matching geometry. If first-touch sample is already influenced by an adjacent overlapping native brush, it is not a trustworthy original height; need footprint-wide native vertex snapshot and owner/epoch provenance before use for actual reconstruction.

## Recommended engineering ordering

1. **P0 controller work starvation:** negative-cache/age backoff of rejected reference attempts, track unique keys and drift distribution, TTL invalidated by causal geometry change; avoid expensive repeated evaluation while no work is occurring. Bounded, CI-harness validated patch on an isolated branch, not physics change.
2. **P0 safe actuator A/B:** match TARGET radius to 1m mesh, measure vertices as well as center, isolate source deformation; no unlimited additive raise.
3. **P1 reliable reconstruction:** adopt V3 first-touch native-vertex anchors for new ruts, curvature-safe multi-scale method for old legacy cells, do not treat after-the-fact sidecar save #surfaceHeightM as predeform reference.
4. **P1 working-tool contact ownership:** isolate Juwel and tractor in precisely same spot without S780, inspect interaction between suppression and wheel rut creation; do not forbid realistic wheel ruts across all wet tillage.
5. Only then practical full harvest -> cultivation/plowing -> seeding acceptance on cloned save; user doesn't need to produce another 30-minute failing plow run yet.

**Status:** audit and correction direction, not a completed R1 repair; no production main merge or physics change.