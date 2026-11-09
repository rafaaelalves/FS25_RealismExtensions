# 14 Oct 2026: integrated PTO+terrain first baling session — runtime audit

Inputs: user-uploaded `log(20261014-025555).txt` (5,183 lines) and `ModMixer(20261014-025555).log` (141 lines). FS25 1.24.0.0. Session local 2026-10-13 23:42:32–23:55:49, game interval 23:43:44–23:55:44 (~12 min).

## Build confirmation / compatibility

- RE BuildIdentity: `integration/terrain-r1-main-pto-v16-2026-10-13@14ebb9c961a4437153148ab632fc29edffbd057c`, run 38502014385; `TerrainDeformation=ENABLED`, RC state provider found; native visual TireTrack adapter installed, probe integrity true and 0 observer errors.
- RC BuildIdentity: `main@f04d28cdf5dfa171122b9fd3d17f9f1a77061011`, run 38498559891. This is the installed RC artifact SHA. MR+Mud, MR+RMS, Mud+RMS, MR+RE PTO, RMS+RE PTO active. External DynamicPTO archive **available** in mods folder but not active per RC `DynamicPTO=-`; do not mistake `Available mod` for loaded.
- RE PTO Control attached to 50 vehicle types. Fendt 512 Vario with Krone MR VariPack V 190 XC Plus recognized `consumers=1 known=1 unknown=0 required=540 gearFamily=540 mismatch=false`; operator selected `540E`, hand throttle ROAD (0%); RC MRPTO summary `stateHits=123987 manualGovernorScopes=72760 runtimeReinstalls=0`. This verifies integration contracts/selection and no detectable runtime instability in this session, **not** that shaft RPM/torque/throughput behaved correctly across loads; no `rePTOInspect` sample.
- ModMixer boot healthy: 59 named hook targets, zero unknown; old June static scan cannot assert a newly manifested conflict. Existing external duplicate CBI6800CT WoodGrinder specializations on load (8 errors) and ManualAttach `DetectionHandler.lua:65 delete(nil)` only at savegame exit. ModMixer warning `53958 interceptor calls vs 1520 stored` may indicate re-registration, but attribution and impact are unproven.

## Critical persistence discrepancy (P0 investigate **before** repair A/B)

- This session had **NO** `restored terrain history cells=...` nor `terrain history not restored:...` message at startup; `Core:loadMap` normally calls `TerrainPersistence.load` when TD is enabled, authoritative server and runtime available.
- `TerrainPersistence.load` silently reports `no persisted terrain history` when `savegameDirectory/realismExtensionsTerrain.xml` missing/unavailable. Other file-read, map identity, format version and heightmap geometry mismatch errors would produce a verbose `terrain history not restored: <reason>` (since experimental verbose=true). Both logs show TD enabled and server. Thus **strong evidence that the sidecar was absent at this load**, subject to startup context, not a proven file-loss root cause.
- Earlier known savegame2 session `log(20261013-024326).txt` saved **23,052 cells**. Current `savegame2` saved **8,145** cells at 23:55:43, followed by `Game saved successfully` 23:55:46. No restore means 8,145 likely came from new runtime writes, not a full continuation of previous 23k history. Could be different backup/copy or file moved, not safe to call it a regression due to code integration. **Heightmap damage may persist independently** while logical RE provenance history is missing.
- Action: freeze/backup original save folder including `realismExtensionsTerrain.xml` and terrain map; compare existence/mtime with backup copy before repairing; avoid overwriting sidecar from another terrain state without geometry validation. Do not silently regenerate 23k history from 8k; model must not invent it.

## Deformation workload: predominantly Krone baler, not tractor

Final cumulative window:
- `TerrainDeformation vehicles=7 wheels=30 vehicleUpdates=73359 wheelTicks=293576 samples=77422 brushesAccepted=13319 cells=8145 retired=0 enqueued=13319 coalesced=697 submittedBrushes=12622 submittedJobs=2113 failedJobs=0 callbackJobs=2113 displacedVolume=54.571`.
- Writer attribution `MR_VariPack_V_190_XC_Plus=10829` (**81.3%** of accepted writes), Fendt 512 Vario `=2490` (**18.7%**). All attributed to PLAYER and one Fendt root. Counts are **write requests**; do not equate to number of physical rut holes or actual recovered/depressed soil volume.
- Surfaces `FIELD=67257 observations/13319 writes`; `DIRT_COMPACTED=10152/0`, `DIRT_WET=1/0`, `HARD=12/0`. Nonfield gravel/dirt deformation **not** demonstrated in this test. Active player-owned full field process.
- `TerrainPlasticYield supported=53366 yielded=13409 maxDemandBearing=2.63`; sampled pressure between 110,000 and 250,000Pa; `maxModelRut=0.149m` is model target, not an observed 14.9cm heightmap depression.
- Causal Krone sample at 23:46:18: x=-63.68,z=-543.53; wetness .803, slip .000, instantaneous Mud sink=.198m, transfer=.661, plasticYield=.831, pressure 250kPa, load 12695N, oldHistory=.000, model target rut=.109m, **accepted incremental depth .0024m**. Lack of longitudinal slip does not exclude normal-load plastic yield in wet soil. Fendt sample at 23:50:19: x=382.06,z=-519.65; wetness=.942 slip=.028 sink=.142m, pressure 110kPa, load 16261N, model rut target=.044m, accepted delta=.0024m. Note root/actor and different coordinates/time.
- `TerrainSinkHandoffProbe maxResidual=.198m maxRepresented=.043m` only shows model handoff, **not** proof of double-counting native height changes. This reinforces future pressure/contact and transient-sink work without authorizing blanket lowering of bearing parameters.
- `VisualTrackCapture` 214617 points, 34935 accepted, 28 chunks, 0 sink errors; `TireTrackProbe integrity=true observerErrors=0`.
- `TerrainPerf vehicleUpdate=73359 avg=.0610ms max=2.023ms total=4472.3ms; flushInclusive=933 avg=.1291ms total=120.4ms; callbackNested=2113 avg=.0049ms total=10.4ms`. CPU telemetry not frame-by-frame FPS; no demonstrated slowdown.

## Recovery status: NOT tested

- All **142** cumulative `TerrainRecovery v32R7` snapshots end with `calls=0 worked=0`; `TerrainRecoveryTarget scheduled=0 applied=0`, `TerrainReferenceV2 accepted=0 rejected=0`. No cultivator/plow GIANTS work-area callbacks fired during this baling session; this is expected, does not show R1 broken or fixed.
- No `TerrainTargetOutcome` or `TerrainTargetSample`, because no TARGET job; PR #44 reference V2 still requires the planned same-rut, same-tool, pass 1/2/3 A/B on cloned saved field.
- No terrain/PTO runtime errors attributed to RE/RC; source CI on integrated branch previously passed. In-game smoke successful within observed subset.

## Next steps / no patch from this log

1. Highest priority: confirm **the missing pre-existing sidecar file** and backup; do not automatically overwrite a 23,052-cell backup with the new 8,145-cell XML without understanding why the former was not loaded. Saving a game is not a valid A/B fixture without matching original terrain metadata.
2. Baler pressure support (Krone > Fendt writes) is an evidence-based separate concern; audit amount of time/contact/wheel count, use of wheel pressure and sink context before making a physics correction. The 81% count alone is not proof of a malfunction.
3. Leave RE PTO and RC pairing unchanged unless a specific reported mechanical malfunction occurs. External DynamicPTO was AVAILABLE only and not detected active by RC.
4. Once persistence state is stable, proceed with targeted R1 repair test. PR #40 broadphase remains excluded and should not be mixed into this diagnosis.

No runtime code changed by this document. Production main remains untouched.
