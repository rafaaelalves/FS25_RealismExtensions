# 2026-10-27 — Single wheel arm did not fire; enable isolated actuator calibration

## Evidence from the user's latest runtime

Files: `log(20261028-001039).txt` and `ModMixer(20261028-001039).log`. Loaded GIANTS FS25 1.25.0.0 at local 21:07–21:10, RE branch build `bc1db9798512bca53a03d06e30ee2f133700b835` and RC main `546806b78cc0c5d0481361b814b6964d3d709f43`.

- 21:07:45: `reTerrainTrial probe`, then 21:07:52 `status` confirmed both queue and direct observers installed.
- 21:08:01: `reGeoMark` at **x=348.843,z=388.054**; 21:08:07 `reGeoSnap beforeOneShot`: principal terrain grid 1.0m; no local rut debt; nominal height minY 152.5104 maxY 152.5495m.
- 21:08:14: `reTerrainTrial arm` accepted, strictly radius 1.35m around marker, at most one additive LOWER ≤3mm.
- At 21:10:18, `ONE_SHOT_ARMED=true`, **native approved=0, reserved=none, completed=0, queueSubmissions=0, directApplies=0**, and at 21:10:27 unchanged terrain.
- `WHEEL_CONTACT beforeOneShot->afterOneShot stage=context total=1820 near2m=32 near4m=115 nearest=0.191m`. Real wheel passed.
- `stage=eligible total=30 near2m=0 near4m=0 nearest=29.477m`. **No wheel in the selected patch passed the deformable-surface/plastic-yield gate.** Therefore no native RE job could be authorized. Do not interpret this as a native GIANTS actuator test.
- Both main sampled arrays were unchanged (`0/25` and `0/289`, `maxRaise=maxLower=0`) and the queue/direct observer saw no operations. This is a second no-RE-native-write control.
- World-wide guard `nativeGuard=12 untrusted=12` shows that some candidate native brushes hit distrust on old journal observations, but **no coordinate attribution** connects them to this marked patch. The 30 eligible events were at least 29.477m away. Cannot attribute local ineligibility to untrusted journaling, which runs **after** the stage=eligible count.

### Source-level diagnosis

`TerrainDeformationEngine.processSample` records `eligible` only after:
1. Actor and active-tool exclusions
2. Surface availability and deformability
3. Terrain response model
4. Plastic-yield required (unless previously active history)

The selected wheel passed the basic grounded and context gates, but not all these later gates. No log has the exact local exclusion reason. When the trial was armed before this revision, processSample could still **commit logical history** for tiny unrelated samples outside the marked patch. This is fixed in the experiment:
- Off-site sample refuses before journal or history activity while trial armed
- Too-shallow sample refuses without logical history mutation while trial is enabled
- Read-only per-stage event counters `WHEEL_CONTACT stage=surfaceBlocked|plasticNoYield|workBlocked|...` reported near marker on snapshots (only stages with local observations are printed)
- Test suite exercises off-site no-write/no-history behavior and staging

### Cleaner next physical experiment: one actuator independent of wheel plastic yield

New `reTerrainTrial calibrate` command delegates to `TerrainNativeBrushCalibration.run()`, added in this branch, **and does not require `arm`**. It automatically applies all the standard arm safety checks (singleplayer, intact queue/direct probes, journal ready, no native anomaly quarantine, no pending writer). It then:
- Requires fresh `reGeoMark` and same-position `reGeoSnap`
- Refuses any untrusted or pre-existing deep native vertex condition via `TerrainGeometryJournal:getLoweringBudget`
- Requires idle native writer/journal; locks all affected native vertices with a causal journal token
- Enqueues **exactly one** `TerrainWriter` ADDITIVE LOWER job, nominal depth **0.0015m** and radius **0.45m**, with pre-submission vertex drift validation
- Reports job ticket, GIANTS displaced volume (if provided), per-native-vertex before/after maximum lowering/raising, number of changed vertices, and extreme-amplitude quarantine
- **Never** records calibration as owned geometry or recovery authority; deliberately completes journal transaction as aborted/untrusted for restitution purposes; does not save the game
- After use the experiment is disarmed. No automatic retry; all other native terrain writes remain suppressed in the trial profile.
- Native effects are *not* reversible within the in-game session; abort the disposable save without saving.

This bypasses the wheel model **only for a user-commanded native actuator calibration**, not general gameplay logic. It addresses the actual unknown: why an earlier RE ADDITIVE command of 1.7mm coincided with a ~58.4mm measured native-height change.

### User test protocol (on COPIED save only)

1. Install the verified successful build for `7eb10710f6cc84b42b8c9a753afccbbf579fa7b6` from GitHub Actions run [40607975697](https://github.com/rafaaelalves/FS25_RealismExtensions/actions/runs/40607975697). Download outer GitHub artifact zip and install only inner `FS25_RealismExtensions.zip`. Never use primary save.
2. `reTerrainTrial probe` then `reTerrainTrial status`; confirm `OBSERVE` and both probes true.
3. Choose a reasonably flat location with no deep existing rut/earthworks, stand on it and run `reGeoMark`, then `reGeoSnap beforeCal`.
4. Run **`reTerrainTrial calibrate`** (do NOT call `arm` first). If it refuses with UNTRUSTED_EDIT, UNIT_UNAVAILABLE, JOURNAL_BUSY or other reason, do **not** force anything. Send the log; refuse means no calibration native job was submitted.
5. If it logs `ONE_NATIVE_ACTUATOR_QUEUED`, let the in-game callback occur, then run `reTerrainTrial status` and `reGeoSnap afterCal`. Quit WITHOUT SAVING.
6. Submit `log.txt` and corresponding `ModMixer` log. Key lines: `RE Terrain Calibration`, `TerrainTrialNativeSubmit`, `TerrainTrialNativeCallback`, `TerrainQueueProbe`, `TerrainSpatialProbe`, `REGeoProbe DELTA`.

**Limitations:** A passing Lua harness/CI cannot establish real GIANTS brush depth semantics. A measured multi-quantum delta could still reflect engine geometry quantization or a concurrent native/internal writer. Other mods are only observed via supported Lua operations. No release certification, no main branch merge.
