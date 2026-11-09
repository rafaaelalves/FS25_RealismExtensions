# 2026-10-25 19:17 — post-isolation native rut amplitude and possible 16-bit vertical quantization

**Evidence**: user-uploaded `log(20261025-191723).txt` (2,544 lines), `ModMixer(20261025-191723).log` (143 lines). Source cross-check: RE experimental PR #64 at **code** commit `a8740d4a8f185b806df6c226dcdc65dea4a6b440`, CI run `40219093796`; RC production `main@546806b78cc0c5d0481361b814b6964d3d709f43`. Game FS25 **1.25.0.0** / Estância São Carlos.

**Decision: FAIL for native lowering amplitude attribution/safety.** Do not merge experimental terrain into RE main or remove provisional protection. This is *not* a failure of the causal recovery subsystem: no recovery work was exercised. Documentation-only analysis, no new mod ZIP, physics patch, RC change or game test.

## 1. Exact runtime scope

- RE `TerrainMode journalRequested=true causalRequested=true legacyTARGET=false`; `TerrainDeformation=ENABLED`; 1,501 mechanical history cells restored; native geometry journal `restored=937 rejected=0`. The 937 entries come from previously saved geometry: **this session has no `Game saved successfully` and does not prove a new save/restore cycle**.
- RC v0.2.0.9 detected MR 0.26.10.08 / Mud 1.3.7.0 / RMS 0.12.0.0 / Reifen 1.2.2.70 / SoilCompaction 1.0.0.0 / FarmKit 1.0.0.3 / Realistic Harvesting 1.6.4.1. Intended bridges active, `StackRisk=0 known-rule findings`. MRMud `widthRadius=false` is prior observed top-function pointer drift, **not proof of lost execution**. RC MRMud friction, rolling, local wetness and resistance counters are positive at unload.
- Mud/RC `TerrainFreezeState frozen=false airC=-1.96 wetness=.624` at 16:14:17. This **was not a frozen test** (`TerrainHealth frozenContexts=0`), unlike prior 13:40 sessions.
- FarmKit compatibility reports `wheelCore=external, groundCore=external`, suppressed owned paths; ModMixer reports its `WheelPhysics.serverUpdate` append. TerraFarm and WaterInDeepTireTracks_MrHunter **were actually loaded**, but neither log proves either modified main height during a particular RE callback. ModMixer dated scan warns about DynamicDrivePro/other mods not actually loaded; don't treat historical scanner names as live writers.
- Log also reports 8 duplicated `FS25_CBI6800CT` specialization registration errors at load and `FS25_manualAttach/DetectionHandler.lua:65 delete(nil)` on unload. They are separate defects, with no demonstrated connection to rut amplitude.

## 2. Generation outcomes under the corrected **one RE job in flight** implementation

At 16:15:17 and 16:16:17, respectively:

| Metric | Earlier | Later |
|---|---:|---:|
| Journal jobs, lower-positive, no-effect | 214 / 35 / 179 | **251 / 44 / 207** |
| Wheel accepted / deferred | 214 / 424 | **251 / 531** |
| Amplified *positive events* | 26 | **35** |
| nativeActualMaxSum | 1.3424m | **1.5954m** |
| nativeRequestedSum | 0.0883m | **0.1045m** |
| Native depth-cap refusals (sample encounters) | 218 | **218** |
| nativeJobs started / finished | 214 / 214 | **251 / 251** |
| isolatedNativePending / isolatedPendingSkips | false / 0 | **false / 0** |
| Recovery candidates / callbacks / improved / closed | 0 / 0 / 0 / 0 | **0 / 0 / 0 / 0** |
| Maintenance periods | 0 | **0** |

Computed: 207/251 = **82.5%** native jobs with no measured lowering, 44/251 = **17.5%** with lowering; 35/44 = **79.5%** of lowering-positive events exceed request + 2 mm. `1.5954m/0.1045m ≈ 15.27` compares **sums of the per-operation maximum sampled lowering** and paired requests, not a single 1.6m hole, not vertical rut depth, not moved-soil volume, and not necessarily unique vertices. Neither 218 cap encounters nor 531 deferred encounters means that many distinct ruts.

Six bounded `TerrainNativeDelta` events (same as in uploaded log):

| Time | Approx. (x,z) | Requested | Observed max lowering | Amplification | Frozen / wetness |
|---|---|---:|---:|---:|---|
| 16:14:28.667 | (263.07,310.87) | 2.4mm | 58.4mm | 24.3× | false / .624 |
| 16:14:28.956 | (262.99,310.87) | 2.4mm | 97.3mm | 40.5× | false / .624 |
| 16:14:29.773 | (262.01,310.88) | 2.4mm | 81.7mm | 34.0× | false / .624 |
| 16:14:30.845 | (271.86,304.36) | 3.0mm | 11.7mm | 3.9× | false / .659 |
| 16:14:31.384 | (270.95,304.36) | 3.0mm | 15.6mm | 5.2× | false / .659 |
| 16:14:31.919 | (270.02,304.36) | 3.0mm | 19.5mm | 6.5× | false / .659 |

Each event reports `moved=1` main-height sample among 2–5 sampled vertices. Values are **net observed heights within each callback**, not proof that the RE brush alone created the delta; visual/fine 0.125m channel not read. Isolated one RE-native job does not lock GIANTS base-game or third-party writer activity. The previous session already had maxima of 7.8, 58.4, 112.8, and 147.9 mm while causal batching was not yet isolated. **The new source fixes are active here; the amplitude anomaly remains.**

## 3. New falsifiable hypothesis: 16-bit main-heightmap vertical steps

A standard GIANTS 16-bit heightmap with `heightScale=255m` has hypothetical sample increment `q = 255/65535 = 1/257m ≈ 0.00389105m (3.891mm)`. The **six observed deltas match integer multiples of q to the log's 0.1mm display precision**:

| Observed (mm) | Nearest integer steps | q-quantized predicted (mm) |
|---:|---:|---:|
| 58.4 | 15 | 58.366 |
| 97.3 | 25 | 97.276 |
| 81.7 | 21 | 81.712 |
| 11.7 | 3 | 11.673 |
| 15.6 | 4 | 15.564 |
| 19.5 | 5 | 19.455 |

The earlier 147.9 mm ≈ 38q, 112.8 mm ≈ 29q, and 7.8 mm ≈ 2q also fit. This is too coherent to ignore: **test vertical quantization explicitly**.

**Not proven**: exact Estância São Carlos `heightScale` was not inspected; GIANTS may use another conversion/representation; a world-height API could be reporting a rounded/sampled geometry effect. Even if quantization is confirmed, it can plausibly explain why 2.4–3.0mm requests yield many no-ops, **but not why an individual callback interval covers 15–25 quanta**. Treat as *two different* questions: discrete vertical storage and accumulation/foreign native operations versus RE request.

Source precedents: GIANTS 16-bit heightmaps (GDN generating-terrain discussion), standard 255m terrain heightScale descriptions (PMC Farming, maps4fs). These prove plausibility, not the map's actual scale or GIANTS runtime editing semantics. The 1m spatial main-heightmap unit from API is **horizontal**, different from candidate 3.891mm **vertical** step and different again from the 0.125m fine deformation surface.

## 4. Next implementation/research gate (not another field-work season)

1. Verify the map's actual `heightScale` from exact map source `i3d` or reliable engine metadata; derive real expected native vertical quantum instead of assuming 255m.
2. Extract before/after **raw main-vertex samples** and `q` step counts for a **single native job** with exact centered grid coordinates and identify the native brush footprint and callback interval. Report new values as requested units, observed units and neighbor collateral.
3. Measure a quiet control with **no RE native writes** and a separate controlled RE-only operation on a disposable copied save, with other height writers excluded or attributable. Serializing RE with itself (now implemented) does not exclude TerraFarm, GIANTS procedural changes or other mods.
4. If 16-bit quantization proves decisive, avoid high-frequency <1-quantum brushes and potential unbounded accumulation. Investigate accumulating a bounded physical-demand ledger until a representable *single quantum* is justified, but only after proving the actuator creates **one** bounded physical quantum (or use a verified direct-vertex alternative with save/sync/collision contracts). Never blindly raise brush amount.
5. Continue with fine 0.125m mesh/contact and 1m main-height channel reconciliation. A callback is a measurement of main API movement, not automatic proof of rendered/physics rut parity.
6. Keep production `main` terrain disabled, experimental PR #64 draft, 10cm/12cm provisional guards intact; do not regress the existing causal restoration, PTO, RC ownership or file persistence.

## Result/status

**Generation safety: FAIL.** **Causal recovery: NOT EXERCISED.** **NPC/public month maintenance: NOT EXERCISED.** **Save roundtrip: NOT EXERCISED in this session** (prior tests established populated roundtrip). **RC physical bridge activity: observed**. **No confirmed RE Lua exception**. No changes to gameplay balance or rollout based only on these counters. 
