# 2026-10-27 — Marked-wheel passive baseline validated

## Supplied evidence

User runtime files `log(20261027-232707).txt` (2,802 lines) and `ModMixer(20261027-232707).log` (142 lines). Game version FS25 1.25.0.0 / Engine 10.0.0, test logged 20:19–20:27 local on 2026-10-27. GIANTS map Estância São Carlos. Experimental RE `0cc21aa10812afe4f9d9c56a296d8b391f5db386` (run 40256866230) loaded at 20:21:46. RC main `546806b78cc0c5d0481361b814b6964d3d709f43`.

Protected mode `TerrainTrial | OBSERVE_ONLY` loaded; user typed `reTerrainTrial probe` at 20:23:08, `status` at 20:23:17 with `queueProbe=true` and `spatialProbe=true`. At each health snapshot from 20:23:24 through 20:26:24:
- `TerrainTrialHealth mode=OBSERVE pending=false approved=0 rejected=0 completed=0`.
- `TerrainHealth journalJobs=0 wheelAccepted=0 wheelConfirmed=0 nativeActualMaxSum=0 nativeRequestedSum=0`.
- `TerrainQueueProbe submissions=0 RE=0 other=0`, `TerrainSpatialProbe direct=0 queuedObserved=0 hooks=1 drifts=0 unavailable=0`.
- Up to 20:26:24 `TerrainNativeWheel` observed `samples=3829 distinct=10 ready=2782 baseline=2782 nonDefault=0 changes=0 scaleMin=1.000 scaleMax=1.000` for supported wheel shapes. Doesn't prove all wheel physics parameters constant.

### Valid wheel contact in exact probe interval (difference from 2026-10-26 prior test)

User `reGeoMark` at 20:23:36 marked **x=277.036 z=296.909**; `reGeoSnap antes` at 20:23:43 captured 25 1m-grid heights and 289 0.125m-dense *samples of the SAME height API*; `reGeoSnap depois` at 20:26:41.

- `WHEEL_CONTACT interval=antes->depois stage=context total=2976 near2m=192 near4m=656 nearest=0.258m`.
- `stage=eligible total=66 near2m=2 near4m=6 nearest=1.108m`. The two near2 eligible wheel samples establish local eligible demand, but their physical centers are not individually logged. Under current engine, one sample may be eligible after plastic yield and before the observe-only early return. Thus these are useful opportunities, **not** proof that an actual brush at exactly the center would have been constructed and applied or that any baseline controlled the same brush in a later independent run.
- Both snapshots exactly match, including `centerResidual=-0.0021m valleyResidual=-0.0044m`, `rutDebt=none`, `firstTouch=none`; `DELTA changed(>=2mm)=0/25` and `0/289`, `maxRaise=0 maxLower=0 avgAbsChange=0`.
- This is the **first supported actual marked wheel passage in no-RE-write mode**. It strongly separates wheel passing on this map from measured main API geometry changes when RE's native persistent writing is blocked. It doesn't exclude engine-internal fine native track displacement, non-wheel actions at other places/times, or all possible TerraFarm/Mud input pathways.
- `TerrainFreezeState frozen=false airC=-1.96 wetness=0.624` at x=263.2,z=310.9 is one sampled context, **not** proof the whole pass at 277,297 had exactly this wetness.
- RC `[MRMud] Integrity pointer drift widthRadius=false` at 20:22:28 is not a native height-write diagnosis. RC MRMud summary after quit contains `rollingResistanceCalls=32673 structuralRadiusOverrides=32673 supportWidthLoadCorrections=296 supportWidthRadiusCorrections=0`.
- At map shutdown, a separate `FS25_manualAttach/src/core/DetectionHandler.lua:65` `delete(nil)` error occurs (unrelated to the RE geometry test). `FS25_CBI6800CT` repeatedly attempts duplicate vehicle specialization registration at startup. Neither is evidence of the rut-amplitude root cause.

## Interpretation

This baseline rejects the explanation that the same *persistent-height measurements* necessarily change whenever an eligible wheel passes with the full mod stack loaded. It raises the priority of testing RE native ADDITIVE command semantics with controlled one-shot and callback volume; it does NOT prove that RE alone generated the previous 58.4mm outlier. Original outlier's source cannot be retroactively attributed.

No terrain-code main merge; PR #64 still experimental draft.

## Code hardening before any one-shot

Earlier trial `reTerrainTrial arm` would reserve the **first** eligible wheel anywhere. Changed in experimental branch on 2026-10-27:
- Requires an explicit `reGeoMark` and valid `reGeoSnap beforeOneShot` at same coordinates in current map.
- Snapshots exact marked x/z in `Trial.armCenter`; `tryReserve(x,z)` refuses eligible wheel centers farther than **1.75 m** without consuming one-shot permission.
- `beforeNative` independently verifies brush x/z is inside the same 1.75m radius, and retains the single LOWER, <=3.001mm, <=0.60m brush limit with native queue/direct observer integrity and session quarantine.
- No automatic retry after a valid ticket is consumed; callback disarms. No increase in map deformation, no new native writer.

Unit and real-writer harness coverage includes non-writing default, missing source probes, required mark/snapshot, off-site refusal, one-attempt lifecycle, and native callback. Mock CI is **not** GIANTS terrain correctness.

## Next test protocol, no full agriculture loop

A new standalone test **only on disposable save** can now isolate ONE RE ADDITIVE wheel write. On area intentionally close to former marked conditions, new build only:

1. `reTerrainTrial probe`; `reTerrainTrial status` confirms `mode=OBSERVE queueProbe=true spatialProbe=true`.
2. `reGeoMark` while standing on the selected future wheel track; `reGeoSnap beforeOneShot`.
3. `reTerrainTrial arm`; verify marker-scoped confirmation. Tractor wheel pass within 1.75m of mark; do not use TerraFarm machinery or implement geometry editing during the pass.
4. `reTerrainTrial status` afterwards; `reGeoSnap afterOneShot`; quit WITHOUT saving, especially if overshoot visible.
5. Collect RE log / ModMixer logs. Important lines `TerrainTrialNativeSubmit`, `TerrainTrialNativeCallback`, `TerrainNativeDelta`, `TerrainNativeQuarantine`, `TerrainSpatialProbe`, `WHEEL_CONTACT`, `REGeoProbe DELTA`.

If `mode=ONE_SHOT_ARMED` still visible, no eligible wheel generated the intended command; do not claim a true positive/negative. Do not repeat endless cycles to force it; inspect context model instead. If actual write occurs, any gross overshoot triggers fail-closed ownership/quarantine but the first physical terrain change cannot be undone, so never test on primary save.
