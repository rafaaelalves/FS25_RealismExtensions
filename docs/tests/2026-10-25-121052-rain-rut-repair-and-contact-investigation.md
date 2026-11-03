# 2026-10-25 12:10:52 — precipitation progression, live native ruts, unverified wheel clipping, causal recovery

Source of truth: user's exact attached `log(20261025-121052).txt` (2,882 lines) and `ModMixer(20261025-121052).log` (143 lines). User observed early superficial ruts (thought Mud), Fiat/other wheels visually entering through ground on field 18 without accompanying visible deformation, then after advancing a month and rainfall with UI map mostly wet/saturated, a larger rut. User expects neighboring NPC farming and later their own cultivation to restore damaged soil. These observations are not replaced with invented exact coordinates/vehicle identity/soil moisture.

## Build and stack integrity

- FS25 1.25.0.0, São Carlos/savegame2; `RE branch=64/merge commit=dd2377fcabbcbb7abe42f930086e2ae47ae088c5 run=40018138687`, same experimental build as prior run. RE `TerrainDeformation=true`, `TerrainGeometryJournal=true`, `TerrainCausalRecovery=true`, `legacyTARGET=false`; journal `unit=1m, restored=0,rejected=0` at 08:20:16.
- RC `main@546806b78cc0c5d0481361b814b6964d3d709f43 run=39180478840`. RC detects `MR=0.26.10.08 Mud=1.3.7.0 RMS=0.12.0.0 TireWear=1.2.2.70 Soil=1.0.0.0 FarmKit=1.0.0.3`; `ADS=- DynamicPTO=- AITracks=-` in *selected game mods* (may still be in mods folder). `FarmKit ACTIVE (wheelCore=external engineMode=external groundCore=external...)` denotes suppression of conflicting FarmKit physics by RC, not a second FarmKit wheel sculptor; final `wheelPhysicsSuppressions=1 groundPhysicsSuppressions=1`.
- RC summary providers observed thousands of active local wetness reads/overrides (`ExtensionsStateProvider.wetnessFreshReads=2413 wetnessSnapshotHits=35719`, `MRMud.localWetnessOverrides=233202`), consistent with runtime sampling. **The uploaded logs do NOT record per-wheel physical wetness before/after monthly time skip**, so no rigorous test of precipitation latency or precise support-bearing transition. No evidence that a game reload is necessary to update the RE/RC probes.

## Measured native height writes and time partition

| Window (cumulative unless noted) | wheelAccepted | wheelConfirmed | noEffect | nativeGuard | cap | recovery callback | physicallyClosed |
|---|---:|---:|---:|---:|---:|---:|---:|
| 08:26 | 7 | 1 | 6 | 0 | 0 | 0 | 0 |
| 08:48 | 3,179 | 772 | 2,407 | 1,501 | 1,470 | 0 | 0 |
| 09:07 | 3,384 | 968 | 2,416 | 2,194 | 2,163 | 0 | 0 |
| 09:08 | 3,397 | 981 | 2,416 | 2,207 | 2,176 | 111 | 4 |
| 09:10 | **3,531** | **1,093** | **2,438** | **2,657** | **2,626** | **232** | **22** |

Between 08:48 and 09:07, 205 fresh wheel write callbacks yielded 196 physically detected lowering and only 9 no-ops (**95.6%**) compared to 772/3179 (**24.3%**) for the earlier accumulated phase. It is **compatible** with the user-reported change in weather/test field/contact context, but NOT proof wetness alone explains it. These are *native callbacks/events*, not unique rut locations and do not prove particular channel/visual shape.

At 09:10:29 the recovery path reports:
- `recoveryCandidates=232 callback=232 improved=231 closed=22 gained=9.5878m maxGain=0.1790m maxDeficit=0.2763m`.
- `gained` is **the sum of per-callback vertical gain amounts**, not a 9.6m trench, neither net excavated soil volume nor unique-vertex gain (one vertex may undergo multiple operations).
- Actual causal work is being scheduled and a small portion is fully closed according to known source baseline, **but visual/gross geometric acceptance is still untested**. One `unsafe=1 collateral=1` proves at least one adjacent native sample moved.
- `byTool=0/0/0/232` means **OTHER bucket**, NOT proof an NPC did this. `CausalRecovery.observeWorkedArea` logs only toolPLOW/SUBSOILER/CULTIVATOR; valid `TillageRecoveryProfiles` IDs `SHALLOW_DISC`, `POWER_HARROW`, `PLOW_PACKER` are all mapped to OTHER. Log at 09:05–09:06 shows `MR 980` 4m cultivator mounted with Fiat 180-90 DT, temporally preceding first measured restitution at 09:08. Does not prove exact author of each write; add actor/vehicle/field and complete profile-name instrumentation before NPC certification.
- Work-area recovery currently hooks **real GIANTS Cultivator/Plow processArea + physicallyWorking, processedArea>0**. Simulated NPC field-state changes without actual implement work-area events **have no native restitution hook**; this remains a separate gap. A neighboring farm having undergone tillage visually does not certify that RE physically repaired its ruts.

## Persistence milestone

- At boot native journal `restored=0` in the restored backup.
- Confirmed separate sidecar saves: **73** trusted cells @08:35:51, **670** @08:52:56 (unknown=3), **941** @09:09:51 (unknown=3), **948** @09:10:35 (unknown=3), each followed by `Game saved successfully`.
- The prior run had only a 0-cell sidecar save **before** actual rutting. This new run PROVES RE can export a populated sidecar to disk, **but does not yet show loading it on a fresh game session**; a subsequent open should report `restored=N` and reject any external changed samples if needed. Preserve caveat: journal sidecar and main terrain heightmap save are not atomic when pending native jobs.
- `maxDeficit=0.2763m` is more than the temporary `0.10m` `getLoweringBudget` target envelope: real native displacement, request-depth units, and ledger attribution STILL warrant examination; do not assume a global 10cm final max and do not remove the guard without a controlled before/after delta probe.

## Wheel clipping (field 18) — diagnosis incomplete

There ARE physics contact queries failing in the log:
- @08:23:39 Fiat `series90_axle_component2` + `series90_main_component1`: `Wheel shape not found for 'getContactPoint'`, shape indices **65–68**.
- @08:47:23 New Holland `TX32` components `tx32_main_component1` + `tx32_backAxis_component2`: same error, shape indices **99–102**.
- Both bursts immediately precede Mud `vehicle delete begin/complete`. Could be stale contacts during delete/update, or a vehicle config/physics issue. **Neither error is tied to field 18 coordinates nor proven to explain the visual wheel penetration**. The visual symptom could also be transient Mud sink/visual deformation height vs collision plane mismatch, while RE's 1m main heightmap is not altered at that moment. Exact affected vehicle, xyz, wheel native contact height vs visual displacement, Mud sink/radius, and main heightmap are absent in this log.
- Root cause must not be asserted on the strength of those wheel errors. Determine whether clipping persists with RE geometric writer suppressed and Mud active, then with a valid wheel contact after reload (controlled single-variable A/B when practical).

## Reconciliation / actions

1. **Do not ask user to stop gameplay, reload at precipitation transition or repeat dozens of plow passes.** This is progress towards a playable mod: native ruts and causal recovery callbacks physically occur.
2. Resume normal farm work. To judge *their own* tillage, evaluate specific physically affected area and post-work transitability; `closed=22` is not 'whole field fixed'. Do not infer that neighboring NPC abstract field operations automatically invoke GIANTS real area callbacks.
3. Fix telemetry `toolOTHER` collapse of valid profiles, plus actor provenance and wetness/load/pressure + exact native before/after delta samples. Keep bounded and opt-in; the previous health reports are enough for trends, but not physical calibration.
4. Audit 10cm fixed native cap vs 27.63cm trusted starting deficits and collateral side-effects before relaxing hard guard or declaring the root cause. Reconcile main collision height vs visual fine Mud sink and GIANTS tire tracks.
5. **Do not treat ModMixer's 2026-06-01 scan-based conflict list as a live confirmed stack conflict**. Live chain reports intact wrappers but only reflects measured named hooks. Classic unrelated `CBI6800CT` duplicate specializations and `FS25_manualAttach` `delete(nil)` on exit still visible.
6. No physics/build change from this source audit; production main and RC untouched.

Status: **real system moves geometry and sometimes repairs it, gameplay release gate still OPEN**.
