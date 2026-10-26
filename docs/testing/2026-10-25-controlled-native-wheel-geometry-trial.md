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
2. Install the experimental artifact `FS25_RealismExtensions.zip` from the *successful* Actions run for the exact test commit. Remove older duplicate RE ZIPs; verify log `BuildIdentity`, `TerrainTrial | OBSERVE_ONLY` and `TerrainControlledWriteTrial=true`.
3. In the developer console on the copied singleplayer save: `reTerrainTrial status` should show `mode=OBSERVE`. Then run `reTerrainTrial probe`; finally `reTerrainTrial status`. It should show **`queueProbe=true spatialProbe=true`**. If either false, stop and send the startup log; don't arm.
4. On an **unworked, safe patch of soil away from existing major ruts** record `reGeoMark` (stand on foot near the target, or enter `reGeoMark X Z`) and `reGeoSnap before`. Put a tractor on that spot, drive a **short straight path once** in the same moist condition, stop, and call `reGeoSnap afterNoRE`. Avoid AI cultivators, landscape edits and TerraFarm machines during the trace.
5. Collect `log.txt` and the corresponding ModMixer log. Baseline should show `TerrainTrialHealth | mode=OBSERVE ...`, **no RE native heightmap jobs**, but vanilla/Mud/fine wheel physics may still produce transient or measured effects. This baseline is worth investigating **before** deciding to arm. No 1-year progression, plowing/seeding/harvesting, or full-hour gameplay needed.

## Optional second phase — ONLY after baseline is understood

On an untouched nearby piece of a **COPIED** save, use `reGeoMark` and `reGeoSnap beforeOneShot`. Run `reTerrainTrial arm`. If it says `ARM REFUSED` inspect observer integrity first and do not override. Drive enough to cause one RE eligible wheel sample. RE will authorize at most ONE native lower job, disarming at the submission boundary. Stop, run `reTerrainTrial status` and `reGeoSnap afterOneShot`. Save nothing. Include `TerrainNativeDelta`, `TerrainNativeQuarantine`, `TerrainSpatialProbe`, `TerrainQueueProbe`, `TerrainTrialHealth` and `REGeoProbe` lines in the next log upload.

**Interpretation**: `0` overlaps from observers != proof of no external writer; direct apply wrappers may be unhookable or the physical wheel displacement may not use Lua `TerrainDeformation`. No line should be interpreted as proprietary output calibration unless the callback volume, before/after vertices, terrain unit and envelope logs agree. If a large anomaly appears, the RE session quarantines future writes but **the first damage still occurred**. Never save the test map.

## Remaining gates after A/B

- Proven target map quantum and native absolute-height setter calibration (currently no universally trusted quantum value)
- Fine physical native wheel displacement versus permanent main-height storage in relaunch and multiplayer
- Validated field-work recovery restores only owned geometry, no collateral vertices
- Vehicle wheel radius / Mud/MR/RTW compatibility under the finalized choice
- Release performance, long-save persistence, reload, MP and compatibility validation

**CI passing is not a test of GIANTS native terrain semantics.**
