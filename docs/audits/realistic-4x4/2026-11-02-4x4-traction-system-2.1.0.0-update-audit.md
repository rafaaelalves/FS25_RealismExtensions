# 4x4 Traction System 2.1.0.0 — exact 2.0.0.0 → 2.1.0.0 source update

**Audit:** 2026-11-02 (Brazil). Input exact user ZIP: `FS25_4x4TractionSystem (1)(1).zip`, **177,803 bytes**, SHA-256 **`b856763b3e4b0f8ff18bf42d4126682f3d4ff0770c63fe43d8c0df3fd395b48e`**, `modDesc.version=2.1.0.0` author Zasty Chalk. Previous exact user ZIP: `FS25_4x4TractionSystem(1).zip` v2.0.0.0, 170,996 bytes, SHA-256 `e66ae578790df3eadc358b68c5cd215a290d50ef844475e4f5c6c2130d5f3320`. **ZIP CRC PASS; 16/16 Lua syntax PASS (texlua loadfile); 26/26 XML strict parse PASS.** No FS25 in-game or MP tests.

**Full ZIP diff:** 6 modified files: `modDesc.xml`, `scripts/DriveModeConfig.lua`, `scripts/FourWDSettings.lua`, `scripts/FourWDTexts.lua`, `scripts/FourWDTractionSystem.lua`, `scripts/FourWDWindow.lua`. One newly included `LEIA-ME.txt`; 47 byte-identical files, zero removed. **Physically critical code files unchanged:** `FourWDVehicleClass.lua`, `FourWDTractionModel.lua`, `FourWDPressureEvent.lua`, `FourWDCtisEvent.lua`, `FourWDModeEvent.lua`, `FourWDToggleEvent.lua`, `FourWDSaveState.lua`, `FourWDAutoStateEvent.lua`, `FourWDUI.lua`, and global injector.

## 1. Actual functional update

- New `DriveModeConfig.simpleMode=true` **default**, saved through `FourWDSettings.GENERAL_KEYS` in `modSettings`. Exposed as **Simple / Realistic** in settings tab of the own in-game 4x4 window. UI instructs **game restart/reload** after changing because eligibility and vehicle mode are resolved at vehicle initialization.
- **Simple**: eligible only `tractor`, `loader`, `telehandler`; tractors default to `auto` unless their factory mode is `smart` (Fendt special), and unrecognized tractor gearbox heuristics are deliberately skipped. `getEngagedMaxSpeed` immediately returns nil, eliminating its old 4WD engaged-road-speed cap. Manual CTIS pressure is **not auto-granted to a tractor lacking CTIS**. The rest of CTIS and differential code remains present; this is not a safe mechanical isolation switch.
- **Realistic**: preserved 2.0 model-specific driveline classes, factory mode selection, road speed limits, CTIS/manual tyre controls and additional eligible vehicle categories. **Recommended default for isolated study** because it preserves the differentiated behavior the author previously implemented.
- HUD bug fix: before calling `string.format` to display max speed, checks that `getEngagedMaxSpeed(spec) ~= nil`. Fixes invalid argument on permanent-4WD/6×4 or other uncapped layouts noted by author in the intermediate 2.0.0.1 release. Cannot assert all format errors cured without game.
- Input bindings in `modDesc.xml` change to nested `<inputBinding><actionBindings>...`; this is an XML-schema/layout change whose GIANTS binding behavior deserves a single new-install hotkey smoke. XML well-formedness is not input-registration proof.
- No new physical force model, controller sophistication, differential topology renegotiation, pressure contract, or multiplayer authorization. The revised public [2.1 announcement](https://www.fs25modhub.com/realistic-4-4-traction-system-v2-1/) confirms Simple/Realistic intentions; exact ZIP is analysis authority.

## 2. Carry-forward source ownership issues, not automatically repaired

**4WD21-01 HIGH — topology:** `FourWDTractionSystem.lua` still fully rebuilds the physical differential graph using `removeAllDifferentials` / `addDifferential`; RMS 0.13.0.1, MR and RC `MRRMS` expect RMS to own graph topology/return and MR driven-wheel cache. **Simple mode changes eligible vehicles, not the physical owner.** No generic RC last-writer patch or direct admission in target stack.

**4WD21-02 HIGH — tire radius:** CTIS still writes/restores `wheel.physics.radius`, while Reifen structural worn radius, Mud temporary sink/pressure and RC `MRMud/MRTireWear` each have defined meanings. Simple merely skips *manual CTIS addition* for models without CTIS; it does not remove all CTIS/radius writes for equipped tractors. Potential stale baseline on AI/player handoff remains.

**4WD21-03 HIGH for untrusted MP — events:** `FourWDPressureEvent.lua` and `FourWDCtisEvent.lua` are **byte-identical** with v2.0, including previously reproduced missing server-side requesting-farm/vehicle-ownership validation, unlike guarded `FourWDModeEvent`. No new live exploit test; carry forward earlier isolation harness and caution.

**4WD21-04 MEDIUM — conservative modeling:** Default Simple universally enables auto 4WD for most tractors and removes its speed limit; this improves convenience, not evidence of manufacturer-specific driveline correctness. Smart Fendt exception is retained. Never conflate automatic detection of real wheel slip with independent calibrated friction or torque modeling.

**4WD21-05 MEDIUM — persisted policy / UI authority:** `simpleMode` is per-user `modSettings` rather than per-save normalized physical policy; admin UI check may be insufficient for independent clients with different mode settings. Static source alone does not establish multiplayer consensus. Reload required; setting change in place does not automatically rebuild every vehicle's capabilities.

## 3. Stack cross-audit and productive learnings

| Owner | v2.1 outcome |
| --- | --- |
| RMS 0.13.0.1 + RC `MRRMS` | Same conflicting differential graph writer. New RMS stuck-4WD/engage-failure symptoms strengthen the importance of the *actual* graph as source-of-truth. Do not combine unmodified v2.1 with current RMS in primary save. |
| MR + Mud + Reifen + RC | Source-documented CTIS radius ownership risks unchanged. No RC physical patch justified by this update. |
| RE PTO V1.6 / RE terrain | Does not write PTO torque/ratio or terrain heightmap. Traction changes could alter rut inputs indirectly, making terrain A/B unfair. No RE implementation changes. |
| UI/vehicle policy | Positive reusable concepts: clearly labeled **convenient vs mechanically detailed** profiles, transparent per-vehicle capability, a mode-to-actual-state panel and reload gate. |

**Decision:** No direct install in the **primary MR+Mud+Reifen+RMS+RC+RE** profile. Isolated test with **REALISTIC** is still useful if user wants to evaluate UI/traction alone. **Selective concept absorption** through a future versioned RMS 4WD command API, *not* direct differential writes. Keep prior [v2.0 deep audit](2026-10-26-4x4-traction-system-2.0.0.0-full-stack-audit.md) and [ADR 0005](../../decisions/0005-four-wheel-drive-hydraulic-suspension-selective-reimplementation.md) active.

**Tiny verification:** one tractor profile and one loader, compare SIMPLE vs REALISTIC after two actual load cycles; 2WD/4WD at speed and under slip, engaged-max-speed HUD, no format errors; CTIS radius only on supported hardware; buttons after fresh install; server/client settings only in controlled test. Not necessary to repeat the entire 2.0 campaign just for this update.

**Repository discipline:** documentation-only PR; no RC/RE runtime code, no build, no merge, no source/assets transplanted from the unlicensed external ZIP.
