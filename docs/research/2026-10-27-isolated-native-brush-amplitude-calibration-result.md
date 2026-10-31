# 2026-10-27 — Isolated additive native actuator: first verified mismatch

## Exact real-game evidence

User log `log(20261028-003639).txt` and ModMixer counterpart on 2026-10-27, FS25 1.25.0.0, RE experimental commit `7eb10710f6cc84b42b8c9a753afccbbf579fa7b6`; RC unchanged.

The sequence at 21:34:14–21:34:53 local:

- `reGeoMark` at x=348.774 z=387.696.
- `reGeoSnap beforeCal`: 25 main height samples and 289 dense *interpolated samples of the SAME main-height API*; no nearby RE history.
- `reTerrainTrial calibrate` at 21:34:25.374 granted ticket 1 for a **single** `LOWER` soft circular native additive brush: amount 0.0015m, radius 0.45m, hardness 0.35. Source path: `TerrainNativeBrushCalibration.run()` to `TerrainWriter:enqueue()` and `_submitBatch()` to `TerrainDeformation:enableAdditiveDeformationMode()`, `setAdditiveHeightChangeAmount(-amount)`, `addSoftCircleBrush(...)`, `g_terrainDeformationQueue:queueJob`. No vehicle wheel signal was needed.
- GIANTS callback `state=0` (success), reported `displacedVolume=0.005859375` (treated as m³ by RE).
- The per-vertex causal journal identified 1 lowered out of 4 sampled native grid vertices: **0.00778m lower** for **0.0015m request = 5.19×**. Session test complete, one job, no second native job.
- After snapshot: 2/25 principal-grid sample points with ≥2mm change, max -0.0036m; 108/289 0.125m-spaced points sampling the same MAIN height API with ≥2mm change, max -0.0074m. No other height operations reported by the queue observer.
- Queue observer: `submissions=1 RE=1 other=0`. Direct observer: `direct=1 directWhileRE=1 overlappingDirectBrushes=1`; this is **NOT evidence of an external second writer**. GIANTS queue executor appears to invoke `:apply` for the same deformation after submission under a different callback target. Queue and apply need de-duplication by identity of the native deformation object, **not** the transient callback target alone. A source code correction to `TerrainNativeSpatialProbe` now tracks queue-object provenance and counts `queueBackedREApply` without an unrelated direct-overlap claim. This requires another live check to fully verify, but the scenario is covered by a regression harness.
- `TerrainNativeWheel` observed native scale 1 in supported samples, no changes; no test inference about other wheel inputs.
- The familiar ManualAttach shutdown `delete(nil)` error is separate.

## Interpretation and cause boundaries

The native deformation event, independent of wheel/yield/soil-response model, produced much larger **persistently observable MAIN-height** change than the amount passed into `setAdditiveHeightChangeAmount`. This directly implicates the current RE additive actuator/control strategy as **not a reliable literal millimeter-depth contract**. It does **not** establish that GIANTS is defective. Terrain height storage quantization, soft-brush distribution, heightmap scale and native setter semantics remain alternative mechanisms.

A plausible candidate is map height increment `q≈255/65535m=0.00389105m`; 2q≈7.7821mm matches the callback's 7.78mm, but **the map's actual vertical heightScale and exact quantum were not read**. One changed vertex and interpolated dense samples do not prove a particular quantization constant. A horizontal 1m heightmap unit is independently verified. Do not confuse 0.125m sampling spacing with native 0.125m vertex geometry. The 58.4mm earlier anomaly remains unproven as the same cause, despite an important reproduction of disproportionate amplitude.

The existing emergency threshold `>25mm OR >8×` did **not** quarantine this 7.78mm event, although it is 5.19× larger than requested. The experimental calibration now marks >2× and >4mm amplitude (for a 1.5mm request) as mismatch and quarantines further RE native writes in that disposable session; this does not redesign production rut policy.

## Implementation after evidence

- Fixed false attribution: queued RE `TerrainDeformation:apply` during GIANTS queue execution is no longer counted as independent competing writer. Also avoids double-counting other queued native jobs as fresh direct writes.
- Changed calibration-only mismatch cutoff; now reports `amplitudeRatio` and `mismatchQuarantine`.
- Added regression tests reproducing 1.5mm→7.78mm mismatch and queue-backed native apply de-duplication. These are stub tests, not engine correctness.

## Architectural conclusion and next engineering focus

Do **not** merge the experimental native ADDITIVE wheel writer as a safe millimeter-precise persistence actuator.

The proposed replacement splits:
1. Wetness, sink, traction and small contact physics remain with Mud/MR/native dynamic wheel displacement; RE's logic can accumulate continuous, bounded rut *debt* but does not command subquantum MAIN geometry per frame.
2. A map-specific, measured **verified vertical quantum** gate controls when physically significant permanent MAIN height changes may be attempted.
3. A research-only `TerrainAbsoluteVertexCandidate` already proposes single-vertex `setTerrainHeightAtWorldPos` with exact world-height target, spatial journal and post-write validation. GIANTS's FS25 engine documentation states that this API accepts absolute height in meters. This must still be verified for live synchronization, persistence, collision/height readback, multiplayer and interaction with fine wheel deformation. Keep it *disabled* until those tests are proven.
4. Any committed main vertex must be tied to verified first-touch geometric ownership and to reversible tillage/recovery accounting. An invalidated or externally changed vertex must never be auto-restored from a guessed baseline.
5. Prove native actuator output against requested physical depth, not merely success callback or volume. Use a **single disposable-save experiment**, not a full agricultural loop, for subsequent absolute-vertex QA when the test harness is ready.

No merge. RE main and RC main unchanged; PR #64 remains draft.
