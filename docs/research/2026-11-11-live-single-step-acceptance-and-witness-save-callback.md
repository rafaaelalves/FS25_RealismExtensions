# 11 Nov 2026 — real FS25 single-quantum setter acceptance, witness callback fix

## Two real user-supplied sessions

- Session 1: `log(20261111-101911).txt` (3,069 lines), `ModMixer(20261111-101910).log` (142). Short Fiat drive only; no controlled terrain write. 1,501 terrain-history cells restored and 937 native geometry-journal cells restored, no journal rejections. `TerrainHealth` had zero native height writes, zero amplification. Wheel displacementScale remained 1.0. ModMixer booted normally.
- Session 2: `log(20261111-103156).txt` (4,843 lines; includes a genuine quit/reload of savegame2), `ModMixer(20261111-103156).log` (142). Both sessions loaded RE branch `feat/terrain-native-transaction-v1-2026-10-23` code commit `cfda2d873ff4aba2611047631b3f07b010db945d`, build run `42949187146`. RC PR #55 merge build `e306b5c767ae01f86f9187eb5b5fbfcca3140b01`, run `42948137248`; MR 0.26.10.08, Mud 1.4.0.0, RMS 1.0.0.0-beta.1, RH 1.6.5.0. Active MR+Mud, MR+Draft, MR+RMS, Mud+RMS and RMS+RE PTO. RC HIGH risk: `BRIDGE_RMSRH FAILED: awaiting RMS public wear provider registration` (out of scope for RE height transaction).

### Actual isolated physical height transaction

From user's second game log, original session before the game's save at 07:28:54:

1. 07:25:56 `reGeoMark` (player position 347.791, 387.187); 07:26:02 `reGeoSnap beforeAbsolute` (25 MAIN and 289 denser interpolated readings; no trusted nearby rut history).
2. 07:26:10 `reTerrainTrial probe`; 07:26:20 `absoluteCheck` READY with 3×3 MAIN vertex center at `x=348,z=387`, `beforeY=152.50973510742188`, `unitM=1`.
3. 07:26:27 `reTerrainTrial lattice`: **81** read-only MAIN sampled vertices, observed range 0.17511m, status **ONE_LATTICE_CANDIDATE** within seven hypotheses. Best `heightScaleM=255`, `q=255/65535=0.0038910505836576m`, max residual 0.00001377m, 16 adjacent pairs, 29 distinct levels. Candidate strongly corroborated; actual map I3D property still not independently authenticated.
4. 07:27:25 `reTerrainTrial absoluteStep 0.0038910505836576 COPY`: `matched=true error=nil`, **actual main center lower = 0.0038909912109375m**, `afterY=152.50584411621094`; difference from requested q approximately **-0.00000005937m** (59 nanometers, about 0.000059mm). The explicit code's 3×3 strict collateral and authorized-depth checks passed; this validates a SINGLE controlled native absolute setter call's immediate MAIN height readback and implies no detected neighboring movement beyond 1µm during this event. No evidence yet of native sparse fine-wheel rut read/write.
5. At 07:28:09: `TerrainHealth journalJobs=1 lowered=1` is the one research calibration. Production wheel actuator remained `SHADOW` and no wheel-intended terrain writes happened. `TerrainAbsoluteShadow quantum=UNVERIFIED` is *correctly unchanged*, since one accepted research quantum is not permission to change production defaults.

### Persistence callback failure: NOT proof the game failed to save geometry

- 07:28:43 player ran `reTerrainTrial absolutePersist COPY`; log says `WITNESS SAVE ARMED`.
- 07:28:54 normal game save ran; RE saved **938** journal cells instead of 937 before trial, 0 unknown. The witness callback **REFUSED** with `WITNESS_SAVE_SESSION_CHANGED`; FS25 subsequently reported `Game saved successfully (savegame2)`. The native research event did not get a witness sidecar.
- 07:30:08 game quit; 07:30:37 same save loaded again with 938 journal cells; 07:30:58 `absoluteVerify` reported `NO_WITNESS_SAVED_IN_THIS_COPY`. **No post-reload center height was logged.** An extra journal record is NOT independent proof the physical 3.891mm MAIN change survived; the persistence criterion was simply not evaluated.

### Corrective source patch

The old `Cal.saveWitness(info)` unconditionally demanded `info==g_currentMission.missionInfo==Cal.witnessOriginInfo` by Lua object identity. `FSCareerMissionInfo.saveToXMLFile` can supply an equivalent save callback context rather than the exact object captured earlier. In game the **WITNESS_SAVE_SESSION_CHANGED** group was triggered; the specific failed predicate was not logged, so object identity mismatch is a **strong hypothesis**, not proven cause.

**Fix:** accept a distinct callback object only when all concrete identity and safety conditions are met:
- exactly the same `g_currentMission` as the authorized one-shot experiment;
- identical, nonempty career save directory across the original, active mission and callback;
- identical nonempty map identity across the pending witness, original mission, current mission and callback;
- each context `isValid=true`, authoritative server, still singleplayer, still `TerrainPermanentActuator=SHADOW`.
- consent is consumed at FIRST callback regardless of success, no retries; any mismatch reports a **specific refusal** (`WITNESS_SAVE_DIRECTORY_CHANGED`, `WITNESS_SAVE_MAP_CHANGED`, `WITNESS_SAVE_MISSION_CHANGED`, `WITNESS_SAVE_CONTEXT_INVALID`, `WITNESS_SAVE_POLICY_CHANGED`).
- same 10µm readback fidelity remains; witness is not geometry recovery authority.

Tests in `tests/terrain_absolute_one_step_calibration_harness.lua` now simulate a valid DIFFERENT save callback object with identical map and path and exercise invalid career/map/session/invalid contexts with one-shot consent consumption. Tests for original `Cal.run()` remain. CI success for source commit `eeb56e5f`: https://github.com/rafaaelalves/FS25_RealismExtensions/actions/runs/43005210775 .

## Interpretation, next minimal acceptance, and backup safety

**Supported now:** A single native absolute MAIN lowering for an explicit one-step q can achieve within ~59nm of requested, with the STRICT no-overbudget and no-visible-neighbor-collateral checks passed in real FS25 1.25.1. This is the first actual live evidence that a q-sized setter request is **not systematically amplified**. Sub-quantum 1.5mm requests still cannot be guaranteed and must remain debt until a representable full step is authorized.

**NOT proven:** Save/reload physical height persistence, fine 0.125m native wheel geometry restoration, any vehicle driving over the new geometry, robust mass transport/tillage recovery or multi-map behavior. Do not declare the whole terrain module released.

User stated they intentionally tested on their current save with a plan to restore an OLDER backup. A full old backup must restore the **entire career directory** (game heightmap/density files + RE sidecars/history + vehicle/placeable and mod state), rather than mixing old and new files. The backup predates installing several mods; missing vehicle/placeable mods or incompatible career structures may cause load migration or warnings. Keep a separate untouched copy of both careers. The test event produced one real native MAIN change in the currently loaded game and the save callback did write updated RE journal metadata before rejecting the *witness*; do not assume a normal in-game save will undo the one-step terrain edit.

Once the new CI-successful code build is available, the minimal recheck of persistence is **one test** on a genuinely disposable copy of the current career, not a plow/sow/harvest cycle: isolated one-step, arm witness, manual save, confirm `WITNESS SAVED`, quit/reload, `absoluteVerify`. If callback still refuses, the new specific reason will directly identify the missing guard. No repeated destructive tests on normal farm saves; no production native auto-writes.

No merges to RE/RC main, no premature release or runtime quantum-autovalidation.
