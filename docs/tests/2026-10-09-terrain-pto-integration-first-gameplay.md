# First in-game validation — RE native PTO + TerrainPlasticYield (2026-10-09)

**Scope:** preliminary integration smoke, **not** harvest→cultivate→seed gameplay acceptance or a controlled before/after comparison.  
**Inputs:** `log(20261009-200823).txt` (~6,230 lines) and `ModMixer(20261009-200822).log` (~142 lines).  
**Session:** FS25 1.24.0.0, game map boot 16:49 local; ~16m20s after first RE diagnostic (16:49:47) to final diagnostics (17:06:06), save succeeded at 17:05:30 in `savegame2`.  
**Known tested build:** RE `feat/terrain-pto-integration-2026-10-09@3e3554a43d1c3c6b3305d609a799d8ffb48a7ca4`, Actions `37979193918`. RC `main@ad7461fb7777691f6f64e2327753417c95b6177b`, Actions `37977810470`, version 0.2.0.4. **These are runtime build identity strings, not just installed ZIP metadata.**

## Actual detected/loaded mod stack

- MR `0.26.10.08`; Mud `1.3.6.0`; Reifen `1.2.2.70`; RMS `0.11.0.0`; SoilCompaction `1.0.0.0`; FarmKit `1.0.0.3`; Realistic Harvesting `1.6.0.0`.
- Recovery Winch `1.0.0.2`, WA Verstopfen Addon `1.4.1.0`, TerraFarm `1.6.3.0` are loaded; no obvious incompatibility shown in this test, but their terrain/work interactions **were not individually exercised/verified**.
- External Dynamic PTO `1.1.3.0` is **available in mod directory but not loaded** in this save. RC `detected DynamicPTO=-` matches exclusive RE PTO owner intent.
- RC integrations all ACTIVE: MRMud, MRMudDraft, MRRMS, MudRMS, MRTireWear, MudSoil, MRSoilHarvest, MRPTO, RMSPTO, FarmKit compatibility. No false global MR `VERIFIED` promotion; MR stays `SOURCE_COMPATIBLE`.
- RE logs `normalized state provider active: FS25_RealismCompatibility`, `TerrainDeformation=ENABLED`; RC `ExtensionsStateProvider wheelContexts=72622`, 74 multi-support contexts and no crawler contexts. RE `context=68083/72536` with 4,453 `noGround`, 0 `noSoil`, 0 `noContact` and `footprint=68083/68083`. This confirms functioning v2 handshake; totals count different update phases and must **not** be assumed to match exactly.

## TerrainPlasticYield — positive evidence, limited conclusions

Final summary: `supported=32613`, `yielded=2858`, `maxYield=1.000`, `maxDemandBearing=2.90`. Thus 91.94% of classified model decisions did not plastic-yield and 8.06% did. These are **not** proportions of total wheel ticks (`789482`), entire processed samples (`256678`), area, driving time, nor measured soil compaction. The gate **actually runs in GIANTS**, contrary to the possibility of a branch/path being missing.

RE writer: `brushesAccepted=2776`, `enqueued=2776`, `coalesced=69`, `submittedBrushes=2707`, `submittedJobs=619`, `failedJobs=0`, `cells=2109`, `retired=3`, `queue=0`, `modelRut=0.149m`, `modelCap=0.149m`, `displacedVolume=17.387` (RE internal value; do **not** label it measured m³). `modelRut` is a peak *computed/requested* depth, not a direct heightmap probe; `geometryProbe=0`, `observedLoweringProbe=0` means no independent physical-depth measurement this session, **not** proof that terrain failed to deform. Last `TerrainPlasticity sample wet=0.93 slip=0.002 instantSink=0.055 ... rut=0.003` is one snapshot, not the wetness/slip at `modelRut=0.149`.

`SurfaceResponse` writers: `FIELD=2431` brushes, `FIELD_SOFT=178`, `FIELD_FIRM=166`, `DIRT_WET=1`. Vehicle attribution: `MR_VariPack_V_190_XC_Plus__Enfardam_12_=2270`, `180-90_DT=167`, `MR_Koralin_9-840__Cultivo_6_=150`, `512_Vario__Enfardam_12_=110`, `6R_155=51`. Largest source is the **baler implement** (2270/2776 = 81.77%), under `512 Vario (Enfardam 12)` root (2380 total). Do **not** assume a severe rut was caused by a seeder or by the tillage tractor. This mix is too different to compare raw accepted-brush totals against prior AI cultivation tests.

Suppressions: `activeCultivatorRutSkips=190360`, `cultivationProtected=330`, `activeQueries=256678`, `activeHits=190360`. Current R6 work guard remains active; the new yield gate is *in addition*, not a replacement. No spatial author-correlation has been proven; guards must eventually be reduced/optimized separately.

## Cultivation/recovery observed (not a recovery certification)

Two physically completed `TerrainPass` snapshots:
- `#1 SHALLOW_DISC` distance 687.52m, duration 416.24s, 10574 work callbacks, 9636 changed, 938 repeat, 3 causal cells.
- `#2 SHALLOW_DISC` distance 663.64m, duration 205.52s, 5350 callbacks, 5090 changed, 260 repeat, 0 causal cells.

Total `TerrainRecovery v32R7 calls=21539 worked=21537 intentEmpty=21499 intentPoints=96 intentMaxRut=0.004m`, `historyRecoveredCells=3 depth=0.010m`, `scheduled=96 applied=0 complete=3 targetComplete=3 stalled=0 noOp=0`, `patch=3/3 retained=0 maxAbs=0.0011->0.0000m`, `inFlight=0`, `machineTargetJobs=0`. Tiny residuals/three cells may have been retired/processed without native terrain brush; this is *consistent with* negligible recoverable debt. It neither proves the recovery solver is broken nor validates reconstruction of large existing ruts. No existing history restore entry appears at boot in this log. Do not equate `scheduled=96` with 96 distinct holes.

**Performance opportunity**: 21,499/21,537 worked callbacks (~99.82%) find no history candidate; `protectedMarks=5,706,063` are repeated marking operations, not distinct cells. `TerrainPerf recovery=21537 avg=0.7677ms max=2.933ms total=16533.5ms`; `vehicleUpdate=192026 avg=0.0402ms max=1.744ms total=7712.0ms`; `flushInclusive=351 avg=0.0807ms max=0.260ms total=28.3ms`; `callbackNested=619 avg=0.0045ms max=0.020ms`. They are profiled **per-call elapsed timings, not FPS/p95**; do not infer a frame-rate regression. The negative broad-phase for undamaged field remains a credible *later* optimization, but not a reason to block next field-cycle gameplay.

## PTO integration evidence

`PTOControl active; vehicleTypes=50`; `PTO standalone physics=inactive reason=external drivetrain owner active` is **expected when MR owns powertrain** and RC `MRPTO` bridge is active. Numerous `PTO operator` events for Fiat 180-90 DT and 6R 155 show mode and hand-throttle changes. `MRPTO effectiveRatioScopes=74631 motorizedUpdateScopes=51457 startGearRatioScopes=12621 stateHits=297158`; `RMSPTO effectiveRatioCapacityScopes=32524`. This is genuine callback execution in game, but does not measure actual shaft RPM/torque or prove all AI-governor cases. Some `required=500` values are shown as `mismatch=true` for selected 540/540E; these are **operator warnings**, not automatically a PTO regression. PTO gameplay specifics belong to PTO workstream.

## Other warnings, attribution and save

- Duplicate vehicle specialization errors (eight) from `FS25_CBI6800CT.WoodGrinder` at boot; known separate mod.
- `FS25_manualAttach/.../DetectionHandler.lua:65` `delete(nil)` after save, at shutdown; known external mod, not RE.
- MRMud integrity pointer `widthRadius=false` warning reappears while widthLoad etc true; `supportWidthRadiusCorrections=0` not an actual wide-support exercise. No evidence here to modify bridge.
- `ModMixerHooks` 59 targets active / 0 unknown hook(s), watchdog boot healthy; historic static scanner data was generated 2026-06-01 and should not be interpreted as Oct 9 live clashes. ModMixer also warns 53,958 intercept calls vs 1,520 stored; cannot attribute any hook-registering culprit from that alone.
- Visual capture `observerErrors=0`, `sinkErrors=0`, `integrity=true`; large `deferred` and `cuts` counters aren't proof of corruption.
- `saved terrain history cells=2109` at 17:05:25; `Game saved successfully (savegame2)` at 17:05:30. Save **completed**, but persistence **reload of the generated 2109 history cells** remains to be tested.

## Recommended focused next game test (do not request repeats of this smoke)

1. On a **backup** save and fixed mod stack/build identities, choose a representative ordinary-weather harvest→cultivate→seed cycle. Observe *same field/soil* before and after seeder for visible persistent ruts. No special machine immunity.
2. Contrast **one** genuinely saturated/high-slip setup; document whether large ruts still form.
3. Reload the just-saved `savegame2` and confirm history restoration (2109 cells should not be required to match exact count if post-save modifications occurred; inspect the actual file).
4. If user reports severe ruts despite reasonable soil moisture, capture screenshot/location and matching log `wet`, pressure, slip, writer actor; do not adjust `bearingPa` by speculation. Investigate baler wheel pressure/footprint separately if severe deformation concentrates there.
5. If gameplay passes, schedule negative-history spatial broad-phase for a later optimization pass; keep PTO external controller out of this terrain PR.

**Status:** initial integration smoke passes; no immediate reason to replace the successful RE/RC ZIPs or edit physics solely due to these logs. Release gate and MR `SOURCE_COMPATIBLE` remain unchanged.
