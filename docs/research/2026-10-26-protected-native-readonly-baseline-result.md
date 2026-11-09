# Protected RE native-terrain baseline — exact game-log outcome (2026-10-25 22:43–22:54 BRT)

## Evidence

User submitted `log(20261026-015444).txt` and `ModMixer(20261026-015444).log`.

**Exact runtime**: GIANTS FS25 1.25.0.0, Estância São Carlos 1.4.0.0, RC 0.2.0.9 main build `546806b78`, RE experimental build `9079e8486403288e47c68035e66c18c19bedea48` / Actions `40255228947`, load `2026-10-25 22:44:56` game-local. Source state provider was RC. Mud 1.3.7.0, MR 0.26.10.08, RMS 0.12.0.0, Reifen 1.2.2.70 detected.

### Protection and observer activation confirmed

- At 22:44:56: `TerrainTrial | OBSERVE_ONLY active; RE native writes blocked`.
- Console `reTerrainTrial status` at 22:46:00 showed `queueProbe=false spatialProbe=false` (correct initial state).
- Console `reTerrainTrial probe` at 22:46:15 and repeat `status` at 22:46:27 showed `queueProbe=true spatialProbe=true`; spatial hook `hooks=1 drifts=0 unavailable=0`.
- The hourly health summaries show `TerrainHealth: journalJobs=0 lowered=0 wheelAccepted=0 wheelConfirmed=0 nativeActualMaxSum=0 nativeRequestedSum=0`; `TerrainTrialHealth: approved=0 rejected=0 completed=0`. No RE main-height terrain write was submitted during this session.
- `readOnlyWheelSkips` increased from 347 (22:46:18) to 1048 (22:48:18), then was **UNCHANGED at 1048** across the 22:52:08–22:54:02 measurement interval, reaching 1049 at 22:54:18. This is crucial: global skip samples mostly happened BEFORE the terrain marker snapshots. A valid tire pass through the sampled patch is **not established** by the log.
- `TerrainQueueProbe` after activation: `submissions=0 RE=0 other=0` over whole trace. `TerrainSpatialProbe`: `circleBrushes=0 direct=0 queuedObserved=0 overlapping*=0`. This is an *idle queue/direct activity result*, not proof another mod never edits terrain; most on-map deformation actions were not requested in this window.
- `TerrainNativeWheel`: up to `samples=9843 distinct=10 ready=5057 baseline=5057 nonDefault=0 changes=0 scaleMin=1 scaleMax=1 unsupported=4786`. Some wheels did not support sink; physics wrapper side-effects on radius/friction/load were not directly measured by the `displacementScale` field.

### Real terrain measured

At 22:52:01 `reGeoMark` x=269.982 z=300.357 on foot. At 22:52:08 `reGeoSnap antes`: `mainUnit=1.000m`, 25 main and 289 dense samples using **SAME** height API, minY=147.3378 maxY=147.5322, centerResidual=-0.0027m, valleyResidual=-0.0038m, no SpatialHistory rut debt and no preDeform reference. At 22:54:02 `reGeoSnap depois` the same shape, `changed(>=2mm)=0/25`, dense `changed(>=2mm)=0/289`, `maxRaise=0 maxLower=0`, same extrema/residuals and no nearby RE native callback. The ground was unchanged **at this one marked location during this interval**, with unverified wheel passage and no exposed native terrain job submission.

This confirms:
1. Protected observe-only build loaded and did not write RE native wheel geometry.
2. Queue/direct Lua hook installation works on this game environment.
3. Observed native wheel scale stayed 1 on sampled supported wheels.
4. No measured main-height change in the marked region during the logged interval.

This does NOT confirm:
- Soil test actually included a grounded, RE soil-eligible wheel at the marked area.
- Mud/MR/TerraFarm did not alter geometry at other times or places.
- A direct **engine-internal** physical wheel displacement did not happen; the dense 0.125m grid is just repeated sampling of the main height API, not a fine-displacement vertex reader.
- RE is sole cause of the prior 58.4mm event.
- The presence or absence of certain modifications on other map versions, speeds, moisture, or machines.

### Other warnings, scoped separately

- `[RealismCompat] [MRMud] Integrity pointer drift ... widthRadius=false` at 22:45:23: other outer wrapper plausible, insufficient basis to blame terrain deformation.
- On **game exit** at 22:54:31: `delete: Argument 1 wrong type Expected Int Actual Nil` traced to `FS25_manualAttach/src/core/DetectionHandler.lua:65` via VehicleAttachmentHandler and ManualAttach deleteMap. This is a real independent lifecycle defect, not the RE native deformation probe. Record for separate audit; do not patch RC/RE blindly.
- ModMixer warns of broad hook chains, including physics replacements. It records no direct proof of duplicate terrain-height writes.

## Specific next code change

To avoid asking the user to repeat vague driving tests, add read-only wheel-zone evidence to `TerrainGeometryProbe`:

- `WHEEL_CONTACT interval=<before->after> stage=context total near2m near4m nearest`: context accepted, ground position valid, moving activity gate passed;
- `stage=eligible`: RE response passed surface/pressure model and reached pre-native trial gate; no history or geometry writes.
- Reset counters after each snapshot so contact is tied **to the exact measurement interval**.

These are no-write debug counters and must not touch normal game behavior unless the experimental trial profile is on. New integration and mock tests required. Only when `near2m>0` and `eligible>0` and a paired height measurement exists is a controlled baseline worthy of interpretation. If both remain zero, do not request or authorize `arm`.

## Later isolated single RE stroke

On a **separate copied game save**, inspect a true no-RE-write baseline with verified contact first. A one-shot `reTerrainTrial arm` could then allow one <3mm native write accompanied by GIANTS displacedVolume and overlap telemetry; cannot infer it is safe merely from a passing CI. Do NOT arm as response to the current incomplete control run.
