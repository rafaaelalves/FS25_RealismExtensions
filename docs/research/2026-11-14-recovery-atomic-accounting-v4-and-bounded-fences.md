# 14-Nov-2026 — crash-safe fail-closed recovery provenance, v4 paid accounting and bounded MAIN fences

## Scope

This continues draft [PR #64](https://github.com/rafaaelalves/FS25_RealismExtensions/pull/64) without changing RE/RC main. It implements code/harness improvements to the existing **SHADOW-only terrain experiment**, not an actual GIANTS physical restitution proof or a release. The 11–12 Nov one-quantum MAIN **LOWERING** and save/reload observation remains the only physical positive experiment. Native **UPWARD** quantization, tillage gameplay, wheel collision and the distinct fine 0.125m displacement field remain unproven.

## Found safety hole

The v3 `Journal:finishRecovery` recorded a trusted recovery fence immediately after positive native MAIN readback, BEFORE the `QuantizedHeightBudget` checked that the *previously paid* depth equaled the physical depth before recovery. A failed budget synchronization, process crash, or recovering with no budget could leave a saved physically genuine fence that a later new wheel source might treat as a paid recovery generation.

Another path: the isolated absolute lowerer checked `getLoweringBudget`, which previously rejected **untrusted** fence geometry but did not reject a physically trusted, **unaccounted** recovery. A fresh process could reconstruct a new ledger from old ownership and potentially replay old wheel demand without the verified post-recovery source authorization.

## Changes made

- `TerrainGeometryJournal.VERSION=4` stores **two independent facts** per vertex: `trusted` means the native MAIN height and RE-owned reference match; `accounted` means the physically observed recovery was reconciled to the previously paid source ledger. A newly recovered height starts with `accounted=false`, even if `trusted=true`. A finished recovery with a requested receipt retains `pendingProof=true` in RAM until budget reconciliation.
- `TerrainQuantizedHeightBudget.VERSION=9` now first calls **read-only** `journal:verifyRecoveryProof(proof)` and compares `beforeDepthM` to its already committed physical amount. ONLY if that succeeds does it consume the one-use receipt, at which point `journal:consumeRecoveryProof` stamps `accounted=true`. On a mismatch, the budget is quarantined and the receipt remains available for diagnosis; it is not silently counted as reconciled. Old replays remain denied.
- `seedPersistedRecovery` requires `trusted=true` AND `accounted=true`; otherwise it quarantines the attempted bootstrap. More importantly, the native journal `getLoweringBudget` now independently rejects any recovered MAIN vertex (and protected neighborhood) with `accounted~=true`, refusing `UNACCOUNTED_RECOVERY_EPOCH` **before the absolute setter can plan a write**, even if the caller tries to seed a new RAM-only budget.
- Geometry XML adds `#accounted` to each recovery fence. V1 retains conservative ownership revocation; V2 geometry remains loadable but contains no recovery generation; **V3 fences load only as physically trusted (if independently observed), never accounted**, since V3 lacked an authenticated persisted accounting bit. In particular, a V3 trusted recovery tombstone is **not upgraded** to a paid v4 source by migration. V4 keeps separate full/partial original MAIN height, last measured MAIN height, accounted/trusted status.
- Recovery fences are capped by a configurable `maxRecoveryFences` (default 50,000, experimental). On saturation, `Journal:beginRecovery` refuses a **new** vertex BEFORE a native recovery call; no LRU deletion or expiration is used. Oversized imported fence arrays are rejected as an entire import rather than losing only the overflow. Already tracked vertices can be updated without increasing the count.
- `Journal:invalidateCompletedFootprint` now revokes BOTH source observations and any physically trusted/paid recovery fence in the entire 3×3 anomalous native transaction envelope, even if its target center did not visibly move. `Journal:reset` clears counts/proofs on map teardown, but does not claim that resetting the in-memory ledger erases persistent file records.

## Tests

- New `tests/terrain_recovery_accounting_fence_harness.lua`: mocked native 2q depression, 1q partial recovery with a deliberately *wrong* paid ledger (fails without consuming proof or making a paid fence); correct ledger reconciliation; save/reload/old-target freeze; V3 migration lacking `accounted`; no-ledger recovery; capacity at one registered fence; oversized import rejection; native lower-gate refusal; anomalous callback revocation.
- Updated `tests/terrain_recovery_epoch_persistence_harness.lua`: verifies the observed recovery can be physically true before the budget accounts for it, then checks partial/full v4 save/load after synchronized receipt.
- Updated journal and persistence harnesses for v4, including V1/V2 backward compatibility. Prior fresh wheel-source, quantized budget, exact completion, causal writer, 3×3 collateral and no-write shadow tests remain in the CI suite.

## Limits / next engineering

1. **Crash consistency, not atomic writes:** this patch is fail-closed under replay/mismatch/interruption. It does **not** prove the GIANTS save and RE XML save are on one atomic transaction. Future release would need a separate durable save-generation handshake or native save barrier and a live test; do not claim crash-atomicity.
2. **50k cap is an experimental refusal limit, not a production policy:** reaching it would stop authorizing new recovered vertices. Designing long-term lifecycle, compaction, spatial partitioning, and server performance without losing old-generation deny markers remains open.
3. The journal's physically genuine but unaccounted recovery fence stays visible for research. No post-reload paid source ticket or new native lower from it is allowed.
4. Nothing here validates upward one-q setter quantization, physical soil restitution, collision, save-atomicity, multiplayer, or the separate fine tire deformation layer.
5. Do **not** enable `absoluteHeightBudget` in normal gameplay or bypass `TerrainPermanentActuator="SHADOW"`. No release merge or user in-game test is justified by these Lua tests alone.
