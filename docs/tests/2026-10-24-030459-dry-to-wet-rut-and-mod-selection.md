# 2026-10-24 03:04:59 — restored save, wetness gating vs physical rut and selected mod stack

**Sources:** user-provided GIANTS runtime `log(20261024-030459).txt` (2,609 lines, Oct 23 23:50–Oct 24 00:03), `ModMixer(20261024-030459).log` (142 lines). Test observed by user: initially 0–20% dry ground, later wet on map, still little visible wheel excavation. The log confirms RE **does** lower some native main-heightmap vertices, but it does NOT reveal the exact local soil wetness, tire load, pressure, slip, or net depth per vertex at test coordinates. Avoid replacing observations with an invented wetness number.

## Exact build / boot

- FS25 1.25.0.0, savegame2 São Carlos, runtime RE `branch=64/merge commit=dd2377fcabbcbb7abe42f930086e2ae47ae088c5 run=40018138687` (the previous patch with native 10cm/12cm guard and improved summary). `TerrainDeformation=ENABLED`, `journalRequested=true causalRequested=true legacyTARGET=false`; node ready 23:56:38 `unit=1`.
- RE has its own PTOControl active. RC `main@546806b78cc0c5d0481361b814b6964d3d709f43 run=39180478840`; normal compatibility bridges all show enabled where relevant.
- On startup `no persisted geometry journal`. At 23:57:46 a save wrote **0 journal cells** followed by `Game saved successfully` at 23:57:49. This save was *before* native rut lowering (first accepted later at ~00:00). At 00:03:18 `quit savegame` occurs without another explicit successful `saved native geometry journal...` line; **do not claim the 16 later observed native lowerings were persisted to journal**.

## Strict final TerrainHealth readings (cumulative, not independent point count)

| Metric | Value |
|---|---:|
| accepted native wheel brush requests | 46 |
| geometry-journal jobs | 46 |
| observed native lowering **events** | 16 |
| jobs with no observed movement in sampled main-grid footprint | 30 |
| deferred due to journal overlap | 96 |
| native geometry safety gate blocked | 45 |
| of those safety blocks: 10cm accumulated cap | 45 |
| preexisting 12cm hollow detector | 0 |
| untrusted/external editing veto | 0 |
| causal recovery candidates/jobs/physical gain | 0 / 0 / 0 |
| native callback submission failures | 0 |

At 00:00:40 there were 5 jobs / 2 lowering vertex events; at 00:02:40: 46 jobs / 16 lowering events. 16 does **not** mean 16 distinct ruts or unique native vertices, and 10cm cap events do **not** prove 10cm physical depth at a specific exact user-observed spot. The guard checks whether **any** native grid vertex in the brush footprint has accumulated ≥10cm verified local RE lowering, and then declines that brush (temporary safety behavior). There is no per-brush before/after depth summary in this telemetry version.

Zero causal-recovery candidates is **not evidence the recoverer is broken**: this session involved deliberately digging/riding, not an observed eligible active tillage pass. No tool's actual work footprint can be inferred from the counter. A John Deere 6R 250 appears in the log, along with Fiat 180-90 DT; the log does not attribute the 46 lower writes to a specific vehicle.

## Selected active modules vs merely available ZIPs

**Loaded this save:** RE, RC, MoreRealistic (MR), MudSystemPhysics 1.3.7.0, RealisticMechanicalSystems (RMS) 0.12.0.0, Reifenverschleiss 1.2.2.70, SoilCompaction, PrecisionFarming, FarmKit 1.0.0.3, TerraFarm 1.6.5.0 + machines, RealPhysics_LoadSpill, RealisticHarvesting, manualAttach, among many others.

**Available on disk but NOT loaded/selected:** `FS25_DynamicPTO_FFM`, `FS25_AdvancedDamageSystem`, `FS25_ManualConnectorSystem`, `FS25_attachImplementsManually`. RC active detection accordingly says `ADS=-, DynamicPTO=-, AITracks=-, RDS=-`; this means absent from *active runtime*, not necessarily deleted from mods directory.

**FarmKit nuance:** `FarmKit ACTIVE wheelCore=external engineMode=external groundCore=external` signals ***specialist external ownership***, not FarmKit wheel + RE both excavating. Code `RC/scripts/integrations/FarmKitCompatibility.lua` explicitly disables `NXRealisticWheelPhysics.enabled` and `NXFieldPhysicsDensity` when MR/Mud/TireWear own those capabilities. RC shutdown telemetry confirms `wheelPhysicsSuppressions=1`, `groundPhysicsSuppressions=1`, `engineModeSuppressions=1`, `wheelDustOwner=Mud`, `loadSpillOwner=RealPhysics`. Keep the mod for independent features, but no claim of full upstream compatibility certification.

**ModMixer:** dated *scan* reference database Jun 1 2026 lists hundreds of installed mods and potential critical pairs, not current proven active conflicts. Live snapshot identifies FarmKit appended `WheelPhysics.serverUpdate`, MR and Mud physics wrappers, and no unknown hook on 59 measured targets. ModMixer claims 54270 interceptor calls /1571 stored hooks (possible dynamic re-register, not direct proof of lost RE writes). RE wheel deformation callbacks are nonzero, so don't blame an unproven mod conflict as root cause.

**Unrelated runtime issues:** `FS25_CBI6800CT` duplicate registrations on boot; during exit `FS25_manualAttach/src/core/DetectionHandler.lua:65` `delete(nil)` script error. Log does not tie either to RE rut production.

## Model interpretation vs what can be proven

RE `TerrainPlasticYield.lua`: in the active experimental config `TerrainPlasticYield=true`; local bearing is a **model**: moisture wetness transition starts `0.42`, fully wet transition `0.96`, pressure/shear demand vs local bearing `plasticYield01`. `TerrainResponseModel.lua` also transfers Mud sink into permanent geometry only gradually at wetness `0.45–0.90`. Dry conditions ~0–20% making minimal permanent ruts is qualitatively expected. However **the UI 'molhado' category is not a timestamped numerical `physicalGroundWetness` at the wheel**. We cannot claim the model was under its threshold while user drove. RC shutdown telemetry proves local wetness providers were called, not the wetness value at the rut spot.

**Immediate engineering diagnostic gap:** the compact TerrainHealth records safety cap events but **not** per-action physical ground wetness min/max near attempted brushes, load/ground pressure, demandToBearingRatio/plasticYield01, profile category, actual native lowering centimeters, owner vehicle nor counts of pre-model yield veto. No rational reason to increase brush strength or remove the physical cap just from subjective impression. Next engineering step: a strictly bounded *event-triggered attribution* for first few rejected/accepted events after wet condition, including wetness, load, pressure, slip, predicted requested delta, nearest trusted native depth budget, callback realized delta, actual terrain vertices; **not** reinstating noisy 5s telemetry or requesting another long test.

## Decision

- Mod ownership stack is predominantly correct in this run; no demand to remove every available-but-inactive ZIP from the folder.
- RE original/new physical rut generation is active but low effectiveness in principal heightmap: 46 accepted, 16 lowering events, 30 no effect. We do **not** infer exact centimeter depth or wetness from those counts.
- The 10cm verified native cap vetoed 45 brushes; this is a **known gameplay constraint** and should remain clearly temporary, not a realistic constitutive soil model.
- We cannot certify new physical/rut **save persistence**, because the sole successful save happened while journal still empty.
- Focus next on verifying the causal chain without inventing a culprit, and on eventual balanced deep-rut/repair subsystem. Do not merge experimental branch or treat this log as successful release.
