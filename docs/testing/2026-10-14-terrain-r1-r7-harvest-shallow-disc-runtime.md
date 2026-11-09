# Terrain R1/R7 — harvest + shallow-disc work-area recovery session

Date of play: **2026-10-14**, 21:37–22:07 local game log; report prepared 2026-10-14/15.  
Exact branch/build (runtime): `integration/terrain-r1-main-pto-v16-2026-10-13`, `14ebb9c961a4437153148ab632fc29edffbd057c`, CI run `38502014385`.  
Log: `log(20261015-010719).txt`, SHA-256 `8a8f128344dbeed806478d31175fe39f36d62b725f62e28ef57338467ae4ab64`.  
ModMixer: `ModMixer(20261015-010718).log`, SHA-256 `238286b0a492444ef5f5532f591891b6ab029b8de62a98be1685b9f17eeef273`.

## User observation / test objective

User partially harvested a field and subsequently operated what they called a plow, experiencing little/no apparent geometric repair and suspecting that driving the towing tractor over the soil worsened it. Previous R1/R7 reference-v2 tests were limited by estimator reliability and GIANTS TARGET no-ops. This is now an actual tillage-recovery session, **not** a log where `TerrainRecovery calls=0`.

## Identity and chronology

- 21:38:57: `restored terrain history cells=28918`; terrain feature enabled on exact integration branch.
- 21:41–21:42: standalone periodic `TerrainMaintenance v1` ran once, scanning 28918 history cells; `started=573 target=486 complete=248 neighbor=248 patch=5630/262 depth=3.654m`. This occurred well **before** the observed tillage passes, so do not attribute this work to the plow.
- 21:50–22:03: new RE-origin geometric rut work was produced while harvesting (S780). At 22:04:00 before tillage `brushesAccepted=435`, `RutWriters vehicles=[S780=435]`, `displacedVolume=23.422`; maximum modeled rut 0.115m.
- 22:04:08: **last logged successful save**, before the first tillage pass.
- 22:04:27–22:06:57: four `TerrainPass` completions; all `op=CULTIVATOR profile=SHALLOW_DISC`, work-area width 3.94–4.00m and depth 3.15–3.18m. The game-side object ran a cultivator specialization/path; a physical moldboard `PLOW` profile was **not** exercised in this session. The source deliberately chooses SHALLOW_DISC when `spec_cultivator.useDeepMode == false`.
- 22:06:59: leave save; no subsequent `Game saved successfully` in the log. Do **not** assume tillage geometry/history persisted after this exit.

### Four pass summaries (these counts are work-area events, not height corrections)

| Pass | Distance | Duration | Calls | Changed areas | Repeats | Causal cells |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 4.86m | 2.04s | 50 | 0 | 50 | 0 |
| 2 | 102.95m | 38.50s | 862 | 467 | 395 | 28 |
| 3 | 136.56m | 44.38s | 1016 | 91 | 925 | 28 |
| 4 | 133.96m | 43.44s | 963 | 28 | 935 | 26 |

## Final runtime diagnostics (22:06:57)

### Recovery was active but insufficient

- `TerrainRecovery v32R7 calls=2892 worked=2891 intentCells=2459 intentPoints=1337 intentEmpty=2235 intentMaxRut=0.010m`.
- `structuralScheduled=1179` but only `TARGET applied=73`, with **58 no-op centers**, **12 toward target**, **2 reached**, **1 away** and no unmeasured result in `TerrainTargetOutcome`.
- `TerrainRecoveryTarget complete=3 patch=129/3 retained=126 historyRecoveredCells=3 historyRecoveredDepth=0.014m`. **Do not count 586 changed work areas as 586 geometric repairs.**
- Physical center sampling `maxAbs=0.1245->0.1245m`, with `targetMaxDelta=0.0125m`, `targetAbsDelta=0.1456m`, `centerRaise=0.1440m` (sum of successful rises, not area average), `centerLower=0.0016m`; `residualWorsen=0.0016m`.
- Severe gate: `TerrainReferenceV2 accepted=74 rejected=25780`, every rejected probe labeled `CURVED_OR_INCONSISTENT`. Approx 99.71% of evaluated V2 references rejected; these are *attempts*, many on repeatedly revisited areas, **not 25,780 independent physical rut sites**.
- In exact source `RecoveryReferenceV2.measure`, this rejection comes from `abs(innerFit.c - outerFit.c) > 0.035m`. A more flexible reference cannot simply disable the gate: earlier indiscriminate raising created mounds. The surface-baseline estimator is the first systemic blocker.
- Native GIANTS TARGET remains second independent blocker: 58/73 applied operations did not move their measured centers. Examples: `TerrainTargetSample` x=388.60 z=387.20, target=152.4421, before=after=152.3190765 (12.30cm shortfall, unchanged), and x=390.20 z=390.20 eventually rose in ~9mm increments.
- Third evidence gap: work-area intent max `0.010m` in history while one sampled physical residual reached `0.1245m` and `modelRut=0.115m`. Those are not directly equivalent quantities; investigate history/debt spatial coverage vs physical geometry and only reconcile history after real geometry changes.

### New rut authorship during the plowing phase

- At 22:04:00 `RutWriters vehicles=[S780=435]`; at 22:06:57 `vehicles=[S780=456]`. **21 additional rut brushes were attributed to S780** during the phase, not to the tractor used for tillage.
- Across the whole session, `456` accepted new rut brushes, `PLAYER=82` and `AI_FIELD=374`; final `displacedVolume=24.030` is a writer cumulative metric, not a direct before/after survey of the field.
- `activeCultivatorRutSkips=18666`, `cultivationProtected=1` at end. Exact `TerrainDeformationEngine.processSample` source skips RE rut writes on the **entire active tractor/implement combination** when `TerrainRecovery.isRutGenerationSuppressed` is true. Rut suppression therefore *did run*. It does **not** prove that another mod, native tracks, existing heights, or a later nonworking tractor pass could not change appearance.
- **Conclusion on alleged tractor worsening:** RE does not attribute a new rut brush to the tillage tractor in this log. Some new persistent ruts were created concurrently, but their logged source was S780. A claim that the plowing tractor itself generated new RE ruts is **not supported**.

### Other events

- There were no native terrain callback failures (`failedJobs=0`). Absence of exceptions **does not** mean recovery succeeded.
- `TerrainPerf recovery=2891 avg=0.3353ms max=0.682ms total=969.4ms` across observed session. Latency is measurable but does not alone prove a meaningful FPS penalty.
- At save exit, `FS25_manualAttach` reported `delete(nil)`, a known **unrelated teardown bug**; WoodGrinder `FS25_CBI6800CT` produced eight duplicate-specialization startup errors. Do not conflate these with terrain.
- RealisticHarvesting `1.6.3.0` and WA Clogging `1.4.1.0` were both loaded; no RH-related Lua exception in this log. This is **not** a full RH+WA behavioral acceptance test.

## Conclusions and next implementation direction (not implemented)

1. **Recovery failure confirmed.** Short/local improvement exists; no demonstrated meaningful repair across repeated passes.
2. **Reference estimator is overly restrictive for much of the tested geometry**, or is seeing contaminated inner/outer sample surfaces. Keep safeguards against mounds but study local curvature, spatially clean samples, and R1-vs-R2 reference fit; investigate before changing thresholds.
3. **GIANTS TARGET no-ops are substantial.** Diagnose spatial overlap, effective deformation footprint, native heightmap quantization and actuator behavior. Target values should not be treated as applied earth movement.
4. **History/physical residual mismatch** needs cell-local causal inspection: 1cm intentMax vs 12.45cm measured residual is not automatically a bug but prevents simplistic recovery confidence.
5. **Instrument and test an actual `PLOW` implementation separately.** The current sample tests only `SHALLOW_DISC`; consider actual work-area and tool's XML/specializations, including possible useDeepMode=false.
6. **Separate S780 work during plowing** for causal attribution; controlled follow-up needs no ongoing AI harvester while checking one geometric segment.
7. Preserve current branch as experiment; do **not** merge to `main` or loosen reference gates / enable indiscriminate RAISE based on this log alone.
8. Because the last save preceded the four tillage passes, do not claim their final field changes were persisted.

**Status:** LOG-CONFIRMED FAILING RECOVERY / PRECISE CAUSE PARTIALLY IDENTIFIED / NO SOURCE PATCH / NEXT TARGETED ENGINE EXPERIMENT PENDING.
