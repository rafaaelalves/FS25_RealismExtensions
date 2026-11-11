# RE terrain: STOP repeating old 1.5mm tests; perform one quantized acceptance

Date: 2026-11-10. Draft PR #64. Maintains `TerrainPermanentActuator="SHADOW"`, `TerrainControlledWriteTrial=true`. No production writer, no release of persistent fine wheel ruts yet.

## Why this is a release gate rather than another indefinite research cycle

The user has repeatedly observed two isolated **1.5mm** absolute height requests produce **3.891mm** measured MAIN lowering and wants the terrain module playable and robust, not endless logs. That outcome is consistent with a quantized coarse MAIN map, not proof of an RE multiplication bug. Several newer Lua harnesses already bound cumulative model requests, ensure one quantum is funded, and quarantine overly large/foreign writes. However **none verifies actual FS25 setters and save/reload**, and `MAIN` is not the separate sparse high-resolution engine-native wheel-rut channel.

The old CLI `reTerrainTrial absolute` is now deliberately disabled to avoid repeating the known sub-quantum experiment. The older Lua `Cal.run()` remains only for regression tests.

## NEW opt-in one-quantum acceptance path

`reTerrainTrial absoluteStep <candidate_q_m> COPY` calls `TerrainAbsoluteSetterCalibration.runOneStep`, which invokes the guarded `TerrainAbsoluteVertexCandidate` / `TerrainQuantizedHeightBudget`:

- requires singleplayer/server, current `SHADOW` profile, explicit literal `COPY`, safe 3x3 MAIN footprint, healthy pass-through observers, no queue and no loaded wheel near the mark;
- takes an explicitly entered **CANDIDATE** vertical quantum, in meters, from independent map evidence; does NOT attest the actual map `heightScale` or authorize future production writes. For the repeated Estância São Carlos hypothesis the mathematical `255/65535`m is `0.0038910505836576`m, but still unverified for this map;
- tests exactly ONE budget-funded q-sized *cumulative* depth, with an absolute setter proposed inside the next lower quantizer cell (0.75q);
- checks MAIN height readback, budget tolerance **distinct** from excavation spending allowance, *all nine* vertices including diagonals and small collateral movements, plus pending queue/foreign edits before submission;
- consumes its one and only game-session opportunity **before any setter can run**, disables any ordinary RE native geometry writes after the experiment, and revokes research-created geometry ownership so causal recovery/municipal maintenance cannot treat it as a trusted rut;
- only when result is fully `verified=true` captures a non-writing 3x3 witness (`READY_NOT_SAVED`). The new witness stores a **10µm** save/reload drift limit versus the old exploratory 500µm tolerance. A failed test or wrong-map/neighbor discrepancy does not produce a witness and must not be silently retried.
- requires a SECOND explicit `reTerrainTrial absolutePersist COPY` to save the witness through the game save callback. This second confirmation is separate from physical write permission and does not prove the user's save folder is a genuine disposable copy.

## ONE deliberate in-game acceptance sequence — not needed until the user can safely test

**Only on a separately created, verified DISPOSABLE CLONE. Never on the user's normal farming save.**

1. On foot, mark an unloaded/clear soil patch with `reGeoMark` then `reGeoSnap beforeAbsolute`.
2. `reTerrainTrial probe` ensures the native observers are installed; `reTerrainTrial absoluteCheck` must say safe. Optionally run `reTerrainTrial lattice` (read-only) for candidate evidence; it does NOT certify map `heightScale`.
3. Assuming separately verified candidate q, run `reTerrainTrial absoluteStep 0.0038910505836576 COPY` **at most once**. This is a physical write to the disposable cloned save. Its results must be ONE exact measured MAIN vertex lowering <= authorized q (with only tiny accounting roundoff) and ZERO neighboring movement >1µm. Otherwise stop; quarantine is correct behavior.
4. If the log prints `ONE STEP RESULT ... matched=true ... witness=READY_NOT_SAVED`, optionally run `reTerrainTrial absolutePersist COPY`, MANUALLY SAVE the cloned game and confirm a `WITNESS SAVED` line. Quit, reload that **same cloned** save, then run `reTerrainTrial absoluteVerify`. Any changed center/neighbor >10µm fails. If witness not armed, quit WITHOUT SAVING the cloned test.
5. Send that **single log** back. No tillage, seeding, harvest or repeated driving loop is required. If the test is blocked by an unmet safety gate, the refusal code is actionable evidence; do not force it.

Passing this proves only one MAIN quantized lower operation and the test-specific saved MAIN state. **It does not prove native sparse 0.125m ruts, physical wheel contacts, collisions, MP synchronization or autonomous terrain recovery.**

## What could actually ship

- **Playable RE native-first profile:** keep GIANTS native fine wheel deformation and existing RE non-terrain systems, with RE auto MAIN writer disabled; do NOT claim permanent RE-created ruts. This is already possible on the experimental profile, but it is not an equivalent replacement for full terrain module.
- **Broad MAIN earthworks:** only if the above acceptance passes, and only for physically broad footprints with actual >1m support and verified real requested depth; never approximate a narrow tire patch by cutting a whole 1m cell.
- **Persistent native fine ruts:** independently prove a supported sparse fine-heightfield read/restore path. GIANTS's public FS25 architecture confirms a sparse 0.125m wheel deformation representation but does not establish a Lua setter/readback pair. `WheelDestruction:smoothHeightAtPosition` uses `g_densityMapHeightManager:getTerrainDetailHeightUpdater` for **density height material smoothing**; this is NOT evidence it writes/readbacks the sparse wheel deformation surface. Visual `TireTrackSystem` events are not physical height witnesses. Inspecting the recent third-party `Soil Deformation Save` code may provide independent design lessons, but its author publicly warns restored depressions can be weaker on 1m maps and MP clients do not see them; do not copy unlicensed source.
- **Recovery:** cannot ship automatic geometry raising until ownership and exact saved physical geometry are proven. This includes municipality/neighbors and tillage; do not activate based on model history.

## Verification

Source changes in `scripts/terrain/TerrainAbsoluteSetterCalibration.lua`, `scripts/terrain/TerrainControlledWriteTrial.lua`, `scripts/terrain/TerrainAbsolutePersistenceWitness.lua`; new `tests/terrain_absolute_one_step_calibration_harness.lua`. Existing old calibration tests remain intact. New harness covers explicit COPY, malformed q, wheel overlap refusal, exact single center q, witness save/reload, 20µm post-reload neighbor drift refusal, 20µm over-authorization and 20µm collateral instant quarantine. All are **mock Lua tests**, not an engine test.

Do not generate a user-facing build just for documentation; physical test only when a NEW TESTED code revision is truly needed. No merger into RE/RC main without explicit review/approval. Continue prioritizing a **concrete playable milestone**, not endless telemetry expansion.

References:
- GIANTS native sparse 0.125m detail terrain architecture: https://www.farming-simulator.com/newsArticle.php?campaignIndex=10&country=ua&lang=en&news_id=569
- GIANTS `WheelDestruction:smoothHeightAtPosition` source: https://gdn.giants-software.com/documentation_scripting_fs25.php?category=93&class=906&version=script
- Third-party RMark Soil Deformation Save stated behavior/limitations: https://www.kingmods.net/en/fs25/mods/83563/soil-deformation-save
