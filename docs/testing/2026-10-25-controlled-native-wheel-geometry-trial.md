# Controlled native wheel geometry trial — Estância São Carlos

**STATUS:** experimental diagnostic build, do not merge or use on primary save. No in-game validation as of 2026-10-25. Only mock/CI tests were performed. Trial works ONLY with `TerrainControlledWriteTrial=true` (enabled by default on this branch; main remains untouched).

## Purpose

Discriminate three possibilities after the 1.7mm RE native ADDITIVE wheel request coincided with a 58.4mm observed terrain-height loss on 2026-10-25:

1. **RE-exclusive problem:** a single RE native brush produces a large reported volume / height delta, even with no foreign spatially overlapping operations.
2. **Concurrent writer:** native queue or direct `TerrainDeformation:apply` calls from third parties issue potentially overlapping operations during RE's job; source names from stack traces are hints, not proof.
3. **No RE main write:** the same height/visual effect occurs when RE writes NOTHING, suggesting either a different native writer or a physical/fine-height response or a measurement artifact.

This is not a live code change to the physical rut algorithm. It's a reproducible A/B experiment with an explicit no-write baseline.

## Important safety semantics

- `scripts/terrain/TerrainControlledWriteTrial.lua` defaults to `OBSERVE`: `Engine.processSample` still computes RE soil context/response but returns **before history commits and before native wheel brush enqueue**.
- `TerrainWriter:_submitBatch` independently **rejects ALL RE native terrain jobs**, including automatic recovery/maintenance, unless a valid *one-use* reservation is active. This is the last line of defense against an accidental old queue job.
- One-shot mode requires a singleplayer server, no native anomaly quarantine, initialized causal geometry journal, both intact optional queue/direct-area observers, one reserved RE wheel brush, at most 0.003001m requested lowering and at most 0.60m radius. If any condition is not met, refuse; no global queue or native changes are submitted by RE.
- A successful authorization is consumed **before** native API invocation, even if the API later fails. A callback releases the reserved ticket and permanently disarms until another explicit console command. No repeated automatic attempts.
- No dynamic override of `WheelPhysics.displacementScale`, no absolute-vertex writer, no save migration beyond journal v1->v2 distrust logic. Other mods (including TerraFarm/Mud) are **not** blocked by this trial.
- `reTerrainTrial cancel` cannot reverse any operation already submitted to the GIANTS engine. If a malformed/large hole appears, **quit without saving** and restore the copied save. Never use this on the real save.

## Operator procedure — start with OBSERVE only

1. **Duplicate the current save to another save slot**, including its mods, so test progress and sidecars are disposable. Keep production RE/RC ZIP backups. Do not load the original slot with this experimental RE.
2. Use the **verified code build** from [successful GitHub Actions run 40602826388](https://github.com/rafaaelalves/FS25_RealismExtensions/actions/runs/40602826388), Git commit `bc1db9798512bca53a03d06e30ee2f133700b835`. Scroll to **Artifacts** and download `FS25_RealismExtensions-bc1db9798512bca53a03d06e30ee2f133700b835`. **Extract the outer workflow artifact ZIP** to obtain `FS25_RealismExtensions.zip`; install this *inner mod ZIP* (not both). Remove duplicate/older RE ZIPs; verify `BuildIdentity` and the startup `TerrainTrial | OBSERVE_ONLY` notice. The enclosing ZIP has a second file `SHA256SUMS.txt` for checking integrity.
3. In the developer console on the copied singleplayer save: `reTerrainTrial status` should show `mode=OBSERVE`. Then run `reTerrainTrial probe`; finally `reTerrainTrial status`. It should show **`queueProbe=true spatialProbe=true`**. If either false, stop and send the startup log; don't arm.
4. On an **unworked, safe patch of soil away from existing major ruts** stand where a tractor WHEEL (not just the vehicle center) will actually cross within 2m, then run `reGeoMark` and `reGeoSnap before`. Drive a tractor **slowly across that marked patch**, with at least one wheel passing directly over or within 2m. Stop and run `reGeoSnap afterNoRE`. The new `WHEEL_CONTACT` lines must show `stage=context near2m>0` **and ideally** `stage=eligible near2m>0` in the `before->afterNoRE` interval. If both remain zero, the pass was not established by the logger even if the main geometry did not change; report as **inconclusive**, not as a pass. Avoid AI cultivators, landscape edits and TerraFarm machines during the trace.
5. Collect `log.txt` and the corresponding ModMixer log after the brief pass (and, if practical, after one minute for compact `TerrainTrialHealth`/`TerrainSpatialProbe` counters). **Do not use `reTerrainTrial arm` in this first baseline**; the first test should make no RE terrain writes. Baseline should show `TerrainTrialHealth | mode=OBSERVE ...`, **no RE native heightmap jobs**, but vanilla/Mud/fine wheel physics may still produce transient or measured effects. This baseline is worth investigating **before** deciding to arm. No 1-year progression, plowing/seeding/harvesting, or full-hour gameplay needed.

## Optional second phase — ONLY after baseline is understood

On an untouched nearby piece of a **COPIED** save, use `reGeoMark` and `reGeoSnap beforeOneShot`. Run `reTerrainTrial arm`, which now refuses an absent/stale mark and confines the next one-shot wheel brush to a center within 1.35m of the marked point (max 0.60m brush radius). This keeps the brush inside the +/-2m height-sampling window. If it says `ARM REFUSED` inspect observer integrity first and do not override. Drive enough to cause one RE eligible wheel sample. RE will authorize at most ONE native lower job, disarming at the submission boundary. Stop, run `reTerrainTrial status` and `reGeoSnap afterOneShot`. Save nothing. Include `TerrainNativeDelta`, `TerrainNativeQuarantine`, `TerrainSpatialProbe`, `TerrainQueueProbe`, `TerrainTrialHealth` and `REGeoProbe` lines in the next log upload.

**Interpretation**: `0` overlaps from observers != proof of no external writer; direct apply wrappers may be unhookable or the physical wheel displacement may not use Lua `TerrainDeformation`. No line should be interpreted as proprietary output calibration unless the callback volume, before/after vertices, terrain unit and envelope logs agree. If a large anomaly appears, the RE session quarantines future writes but **the first damage still occurred**. Never save the test map.

## Remaining gates after A/B

- Proven target map quantum and native absolute-height setter calibration (currently no universally trusted quantum value)
- Fine physical native wheel displacement versus permanent main-height storage in relaunch and multiplayer
- Validated field-work recovery restores only owned geometry, no collateral vertices
- Vehicle wheel radius / Mud/MR/RTW compatibility under the finalized choice
- Release performance, long-save persistence, reload, MP and compatibility validation

**2026-10-27 validated control:** the next real baseline recorded 192 contacts and 2 eligible samples within 2m of the marked patch with 0/25 and 0/289 terrain-height changes, no RE native jobs and zero observed queue/direct deform submissions. This provides the first genuine marked-wheel control and supports proceeding to exactly ONE scoped write only on a disposable save. The subsequent 1.35m marker gate was added to prevent an unrelated vehicle or out-of-grid brush from consuming the trial.\n\n**2026-10-26 real baseline:** earlier build `9079e848` had zero measured height change but `readOnlyWheelSkips` was flat throughout the marked snapshot interval. It did not prove an actual wheel pass over the marker. This revision adds explicit per-snapshot wheel-zone evidence before any one-shot arm should be considered. No need for whole agricultural cycle.

**CI passing is not a test of GIANTS native terrain semantics.**
