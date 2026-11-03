# RE Terrain — 03/11 live absolute height evidence and wheel-contact registry correction

Date of game log **2026-11-03, 00:00–00:04 -03**. Based on user-supplied `log(20261103-030422).txt` (not committed to repository) and `ModMixer(20261103-030422).log`. This source is **specific to one short real FS25 session**; avoid generalizing to all maps or APIs.

## 1. Live measurement: success of *immediate MAIN readback*, not recovery

- FS25 build 1.25.0.0, map Estância São Carlos; RE `BuildIdentity branch=64/merge ... run=41564084900`, RC production `v0.2.0.9` main commit `546806b78cc0c5d0481361b814b6964d3d709f43`.
- RE startup `TerrainTrial | OBSERVE_ONLY active`; restored 1,501 logical history cells and 937 native-journal observation records with no import rejections. These do **not** give new native-height recovery permission.
- `reTerrainTrial probe`: native/direct observers requested and later healthy: QueueProbe submissions=0, RE=0, other=0, pointerDrift=0; SpatialProbe direct/queued=0, hooks=1, drifts=0.
- `reGeoMark`: x=348.329 z=387.960, player-position, pre-contact area; `reGeoSnap beforeAbsolute` reports main unit 1.000m, 25 coarse MAIN-height samples and 289 dense samples **of the same MAIN API**, not a fine-mesh readback; rutDebt=none, nearby history cells=0; no wheel contacts or other edits near mark.
- `reTerrainTrial absoluteCheck`: READY for exactly nine native vertices around x=348,z=388; center before height 152.529190m; request -0.001500m; map vertical quantum still `UNVERIFIED`.
- `reTerrainTrial absolute`: setter pcall succeeded and returned nil; after immediate readback **center -0.003891m**, max raise 0, **1/9 vertices moved**; status `quarantined=true`, `WITNESS status=READY_NOT_SAVED`. This corroborates earlier 29 Oct observed ~3.891mm MAIN height step; a second agreeing outcome is still **not** an engine/whole-map quantization certificate.
- Zero RE automatic wheel-native submissions, zero recovery native jobs confirmed, SHADOW sources=0 vertices=0, fine wheel displacement passive samples=12, wheels=4, scale=1 in all sampled cases. This **does not** establish behavior of a loaded wheel over the edited point.
- `reTerrainTrial absoluteVerify`: `NO_WITNESS_SAVED_IN_THIS_COPY`. **Expected**: log has no invocation of `absolutePersist COPY`, no witness saved, nor any actual reload between setter and verify. The log then shows quit savegame, not saved witness. User's directory includes `savegame2` but that string does not prove it is a copied disposable slot; future destructive/saved test must use a confirmed separate clone.
- **Still blocked:** save/reload persistence, fine deformation/collision, and cultivator recovery.

## 2. Actual code bug uncovered by `reTerrainTrial contact`

Live log: `RE Terrain Trial | Wheel contact probe refused: MISSION_VEHICLE_LIST_UNAVAILABLE` at 00:03:20. The experimental `TerrainWheelCollisionProbe.scanMark` erroneously retrieved `mission.vehicles`. GIANTS FS25's `VehicleSystem` owns `self.vehicles` and is attached as `mission.vehicleSystem`: source https://gdn.giants-software.com/documentation_scripting_fs25.php?category=91&class=897&version=engine (see `VehicleSystem:onVehicleBuyEvent` and `VehicleSystem.new`). Independent corroboration: FS25_Tardis client code refers to `g_currentMission.vehicleSystem.vehicles`.

**Fix:** Prefer `mission.vehicleSystem.vehicles`, retaining `mission.vehicles` only as a legacy/test fallback; make the selected source visible in the observer report. No auto per-frame scan or write. Regression harness mocks a mission that has `vehicleSystem.vehicles` with one real vehicle but empty `mission.vehicles`, verifies 1 wheel contact and `vehicleSource=VEHICLE_SYSTEM`, fallback, and missing-list fail-closed. **CI success:** https://github.com/rafaaelalves/FS25_RealismExtensions/actions/runs/41570196978 for source commit `98098f31`. User's tested build predates this fix, so its contact refusal is **already explained**, not evidence of a geometry/collision failure.

## 3. Separate stack health — do not conflate with geometry

Current installed stack: MR 0.26.10.08, Mud 1.3.9.0, RMS 0.13.0.1, RC main 0.2.0.9 from 19 Oct, RE experimental #64. RC StackRisk explicitly warned `BRIDGE_MRMudDraft`, `BRIDGE_MRRMS`, `BRIDGE_MudRMS` as UNSUPPORTED (unverified version combinations). This does not certify a drivetrain fault, but **does** prevent claiming full MR/RMS/Mud bridge compatibility. Current RC Nov audit PR #49/#51 are separate unmerged work; do not label them active on the player's stack or merge without review. ModMixer reports MR and Mud wheel physics overwrites, RMS drivetrain hooks, and live 59 hooked targets. These conflicts predate the new read-only collision probe; no concrete heightmap write proven by this scan.

Unrelated game errors in session: FS25_CBI6800CT registers eight built-in vehicle specializations twice during mod load; `FS25_manualAttach/src/core/DetectionHandler.lua:65` calls `delete(nil)` on exit, as proven by Lua stack. Neither stack implicates RE terrain. The latter is a **real unload error**, but not the cause of `MISSION_VEHICLE_LIST_UNAVAILABLE`.

## 4. Decision and next strictly bounded player test

No need to replay farming-cycle tests. Safest current conclusion: **immediate MAIN setter localization is demonstrably improved; physical collider/reload/recovery are unknown**. Keep `TerrainPermanentActuator="SHADOW"`, #64 draft and RC/RE mains unchanged.

When ready, download a **new CI build containing commit 98098f31** (not the user's older run 41564084900). For non-writing collision observer, mark an area with an actual loaded wheeled vehicle nearby and run `reTerrainTrial contact`: now resolves `vehicleSystem.vehicles`. For persistence, use *a confirmed separate disposable clone*, then one `absolute` + explicit `absolutePersist COPY` + manual save + actual quit/reload + `absoluteVerify` on that clone. If native collision probe is still untrusted/ambiguous, collect its exact report; never force a frame interpretation or write more soil to compensate. No need to do either now.

**Source evidence from user files does not establish permission to create new writes on savegame2.** The documented experiment does not prove normal gameplay acceptance.
