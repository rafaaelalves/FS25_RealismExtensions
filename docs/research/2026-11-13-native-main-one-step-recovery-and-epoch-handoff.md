# 13-Nov-2026 — native MAIN recovery step and physically verified recovery-epoch handoff

## Purpose

The terrain project's objective is a playable, accurate RE, not an infinite sequence of 1.5mm native API trials. We already have real FS25 evidence from 11–12 November that ONE exact native MAIN height quantum (~3.890991mm measured) persists in a saved Estância São Carlos career. That certifies neither continuous wheel passes nor physical restoration.

This development addresses the remaining *opposite physical direction*: restoring a trustworthy, owned MAIN depression without falsely marking the operation finished and without allowing the OLD wheel model target to immediately re-dig it.

## Real bugs / risks addressed

1. **Missed diagonal collateral**: `TerrainGeometryJournal:beginRecovery` previously used journal radius=0.56u, with `enumerateVertices` expansion 0.75u. This totals 1.31u, less than the sqrt(2)u diagonal vertex distance. A recovery writer could move one of four diagonal neighbors by 20µm and the journal would incorrectly call it safe. The provenance scan now uses radius=0.70u, so all nine 3x3 MAIN vertices are locked/read. The **physical brush radius is unchanged**. New regression explicitly changes a diagonal.
2. **Partial/uncertain brush recovery**: prior 65% smoothing brush mock can leave measurable depth after multiple passes. `TerrainAbsoluteRecoveryCandidate.lua` is a NEW **research-only** inverted one-quantum actuator: for a verified map quantum q and an independently RE-OWNED native MAIN hole, proposes an absolute UPWARD target at `before+1.25q`, intentionally inside the next higher quantization cell for floor and nearest modes when properly lattice-aligned. A full 3×3 journal preflight and post-write check must confirm a single q-sized rise within tolerance, *no* unintended center overraise beyond q (except tiny numerical comparison slack), no neighboring changes, and no height above the immutable RE original. A false or throwing setter quarantines and discards physical recovery authority, not followed by a speculative reverse operation. **One shot, only with explicit disposable research permission, NOT gameplay wired.**
3. **Stale wheel demand after recovery**: `TerrainQuantizedHeightBudget` previously tracked committed q-sized lowering independently from recovery operations. A legitimately recovered hole could still have an older cumulative target and be dug again on the very next frame.
   - `TerrainGeometryJournal` can now issue an **opt-in, one-use recovery proof** only after a safe REAL native height readback with positive gain, tied to the actual journal object/MAIN position, original baseline and live current readback. An invalid, forged, reused or stale proof fails. This is intentionally in-memory, never a persisted ownership substitute and not issued for no-effect callbacks.
   - `TerrainQuantizedHeightBudget.VERSION=5` `syncVerifiedRecovery(journal,proof)` verifies the proof against the paid pre-recovery depth, then updates `committedM` to the actual remaining owned physical depression and resets the stale demand. `recoveryEpochPending=true` blocks any replay of the *old* target with `NEW_DAMAGE_EPOCH_REQUIRED_AFTER_RECOVERY`. This is the safe **closed** state, not permission to dig again.
   - The former `retireTarget(key,true)` boolean shortcut is now rejected. Even full recovery keeps a blocked in-memory epoch tombstone, not an immediately reusable empty ledger.
   - `TerrainAbsoluteRecoveryCandidate` optionally accepts a matching budget and synchronizes its one-step successful journal proof in the same operation.
   - `TerrainCausalRecovery` has an OPTIONAL handoff when `runtime.absoluteHeightBudget` exists; it requests the proof at submission and synchronizes after the actual native writer callback. This property is **not installed** by any enabled production controller in current SHADOW mode, so normal gameplay and builds remain unchanged.
4. **New damage AFTER recovery**: a genuine fresh wheel-source epoch after tillage must eventually be bound to the prior physical baseline. This **fresh source epoch handshake is not yet wired** to the shadow planner and is deliberately not assumed from an arbitrary frame/update or boolean. We do NOT permit stale source replay merely to keep the game moving. This is a clear next integration task, not something falsely marked resolved.

## Simulated test coverage (no new gameplay tests requested)

- `tests/terrain_exact_recovery_completion_harness.lua`: detects a previously invisible +20µm diagonal edit; 2q→q remains incomplete and q→0 truly closes; rejects neighbor collateral, overraise, no effect.
- `tests/terrain_absolute_recovery_candidate_harness.lua`: one-q rising under FLOOR and NEAREST quantization, two-step full restoration, no owner, two-q overshoot, native false return, late foreign edit, optional paid-depth budget handoff.
- `tests/terrain_recovery_proof_ledger_harness.lua`: two q-sized lowering events, partial q physical restitution + one-use journal receipt, old target replay rejection, final physical restoration, forged/duplicate/no-effect receipt refusal. The pure Lua quantizer reproduces the 59nm native readback offset seen on 11 November; no unauthorized epsilon permits q-funding.
- `tests/terrain_causal_writer_integration_harness.lua`: optional native brush callback handoff synchronizes the measured residual through five physical-ish mock callbacks, retains the remaining ~2.46mm as NOT restored, blocks replay of the old wheel source. No production geometry is written by tests.

**CI green** for latest source commit `a30ea8d2`:
https://github.com/rafaaelalves/FS25_RealismExtensions/actions/runs/43446353385

## Safety boundaries and actual launch work

- No new in-game RE test this round. MAIN written once and persisted in the previous actual FS25 trial, but **UPWARD** native quantized recovery remains **simulation-only**. It is not safe to present as physically validated.
- The separate 0.125m native fine wheel deformation cannot be reconstructed from the 1m MAIN samples or `TireTrackSystem` visual marks.
- Neither normal `TerrainPermanentActuator=SHADOW` nor the 10–12cm safety depth caps were relaxed. The experimental recovery candidate has no automatic console/action wiring, so merely updating the research build cannot raise the user's terrain.
- PR64 remains draft and divergent from current RE main; no RC changes and no main merge.
- **Next focused development**: authenticate a NEW live wheel-source generation after verified physical recovery (not stale model history), derive the new epoch's cumulative target from already-remaining owned physical depth, then connect actual broad MAIN footprint/quantum gate. Separately plan one controlled upward/roundtrip FS25 acceptance when code is ready, without another repeated farming cycle. Do not interpret CI as release.

Conclusion: the new work makes physical restitution a first-class, measured operation and prevents a verified repair from instantly becoming a duplicate rut, with an explicit remaining source-epoch integration boundary.
