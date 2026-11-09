# Integrated terrain/PT0: 14 Oct 2026 19:04–21:02, history continuity and PTO inspection

Inputs: `log(20261015-000251).txt` (31,293 lines / 8.7MB) and `ModMixer(20261015-000249).log` (142 lines). All times in the FS25 logfile are local. The large game log **contains TWO distinct game sessions**: 2026-10-13 23:42–23:55 (already audited, see 2026-10-14-integrated-pto-terrain-baling-and-persistence-audit.md) and the **new** session from 2026-10-14 19:03–21:02. Never combine their cumulative telemetry: both restart counters at loading. User explicitly reports continuing the *same* save over these sessions; an older backup was restored at some earlier point, NOT between the recent sessions. This user evidence invalidates casually attributing unexplained history discontinuity to switching saves.

## Verified build and persistence chronology

- RE integration artifact in both sessions: `integration/terrain-r1-main-pto-v16-2026-10-13@14ebb9c961a4437153148ab632fc29edffbd057c`, CI run 38502014385; RC main installed at `f04d28cdf5dfa171122b9fd3d17f9f1a77061011`; FS25 1.24.0.0; TD enabled.
- Older earlier observed game session (not in this file) ended by persisting **23,052** history cells. A subsequent session on **the same save**, logged in this file at 2026-10-13 23:43, **did not emit** `restored terrain history cells=` nor `terrain history not restored:` even though TerrainDeformation is enabled and runtime starts. It saved **8,145** cells at 23:55:43 and `Game saved successfully (savegame2)` at 23:55:46. The cause of absent restoration is NOT established. It is a real continuity question, not user-proven rollback.
- NEW 2026-10-14 19:04:02: **`restored terrain history cells=8145`**, which directly matches the prior session's persisted count. It saved **28,918** at 21:02:01 and `Game saved successfully (savegame2)` at 21:02:06. Therefore **normal persisted continuity is verified for this load**; earlier gap remains unaccounted for.
- Source `TerrainPersistence.load` silently returns `no persisted terrain history` if its computed `savegameDirectory/realismExtensionsTerrain.xml` does not exist; `Core.loadMap` suppresses this exact condition, while logs other failures (XML read, identity/version, geometry mismatch) when experimental diagnostics are verbose. This makes a missing sidecar one plausible explanation for the previous silent startup, not a definitive one: save context, load order and actual file state not captured there. Code also guards against mismatched heightmap sample if an older sidecar is restored.
- A count of historical cells is **not** proof of exact physical rut depth or unique new ruts. Adding 20,773 history cells (28,918-8,145) can include newly represented spatial areas, not 20,773 brand-new individual holes; never infer the previous 23,052 are reconstructible from current terrain without validated baseline.

## New two-hour gameplay profile

- A total of 1,411 ~5s diagnostics windows in the NEW session. No working cultivator/plow events: R1 `calls=0`, `worked=0`, TARGET `scheduled=0 applied=0`, reference V2 `accepted=0 rejected=0`; no R1 tests exercised.
- End deformation `brushesAccepted=29348`, `submittedBrushes=28635`, `coalesced=713`, `submittedJobs=4591`, `callbackJobs=4591`, `failedJobs=0`, `modelRut(max)=0.149m` (simulation target, not observed geometric depth), runtime cells=28,918, retired=0.
- End owner attribution `MR_VariPack_V_190_XC_Plus__Enfardam_10_=24663` (84.04%), `512_Vario__Enfardam_10_=4685` (15.96%); all PLAYER, one Fendt root. Accepted brush percentages are NOT physical volume or depth percentages. Some mechanical pressure differences observed previously, but no controlled comparison.
- Surface response FIELD=445,477 observations and all 29,348 writes; DIRT_COMPACTED=20,561 / 0 writes, HARD=16 / 0. No novel non-field deformation demonstrated. `TerrainPlasticYield supported=414611 yielded=29628`, ratio not meaningful as area percentage. Samples vary by local position/time; no global moisture assumption.
- `geometryProbe=0` for ordinary rut writes. No direct post-native-heightmap probe confirmation for these writes. Writer aggregate `displacedVolume=118.493` is job callback reporting and must not be confused with geometric mass-conserved displacement (SoilMassTransport remains disabled).
- Performance cumulative `vehicleUpdate=753220 avg=0.0408ms max=3.057ms total=30745.9ms`; writer flush inclusive `1891 avg=0.1491ms max=0.444ms total=282ms`. These timings alone cannot prove FPS/performance quality. Visual tire-tracks `points=2248337`, `accepted=184958`, `deferred=2131057`, `retained=36021`, `chunks=44`, `sinkErrors=0`; counts are cumulative, not proof of two million pending queue items. Excessive telemetry log size from 1,411 windows could be throttled in normal play later.

## Two valuable live `rePTOInspect` snapshots (Krone VariPack, native PTO)

- 19:18:23, Fendt 512 Vario, `540E`, `COMPATIBLE`, 1 native connected shaft, engaged, effective motor ratio ~3.1778, engine ~1329.61 RPM; MR reports actual modeled PTO RPM ~418.408 (0.77483 of 540), dynamic baler load ~59.272 kW. `PWR?` not involved.
- 19:22:41, same `540E` and engaged native shaft, engine 800 RPM, MR reports modeled PTO RPM ~251.748 (0.46620 of 540), baler load ~16.388 kW. These RPM reports track the engine within both fixed ratios, but the power change has independent feed/throughput confounders; no causal proof that load is directly controlled by RPM. Inspector snapshot is **not** a physical shaft sensor.
- RC MR PTO telemetry end: stateHits=1,269,541; manualGovernorScopes=752,094; runtimeReinstalls=0; RC provider wheel contexts=123,616. No detected new RE PTO error.

## Compatibility and other warnings

- ModMixer `BOOT CONFIRMED HEALTHY`, 59 live hook targets, 0 unknown; June-generated static 26 conflict candidates are not 26 newly realized runtime bugs.
- RC `MRMud Integrity pointer drift ... widthRadius=false` at startup in both sessions; ambiguous safe wrapper, `supportWidthRadiusCorrections=0` and `supportWidthLoadCorrections=1440` end. Do not claim the radius shim is broken without focused source/runtime trace.
- Known `FS25_CBI6800CT.WoodGrinder` 8 duplicate specializations each startup; existing `FS25_manualAttach/.../DetectionHandler.lua:65 delete(nil)` exception on shutdown. External DynamicPTO is merely listed among **available** installed ZIPs and not active as another PTO owner in RC. One FS25_AnimalPlanner selected husbandry warning; unrelated to terrain.

## Technical decisions / suggested next instrumentation

1. Do not change terrain deformation or MR/Mud pressure because user found long baling pass tolerable. Continue R1 rehabilitation work in separate PR; all new sessions have not exercised it.
2. Treat sidecar discontinuity as an **open investigation** with explicit priority: at future startup capture save path, authoritative state, existence and format/map/geometry validation outcome **without logging personal directory locations unnecessarily**. Missing sidecar on existing saved game should be observable, rather than silently passed off as first-run. Retain save metadata and history backups; no overwriting sidecar from older backup without matching GIANTS heightfield.
3. Keep PTO validated at source/harness level and by these two operational snapshots; no RPM throughput claim, no MP claim.
4. If needed, compare unique contact footprints/per-wheel pressure for Krone; do not extrapolate area damage from 84% brush calls.
5. User can keep playing normally. Save a focused R1 log only after harvest/worked tillage; no benefit repeating 2h full verbose sessions solely for R1 proof.

No runtime physics/code modifications made by this audit.