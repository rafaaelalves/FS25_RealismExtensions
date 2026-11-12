# 12 Nov 2026 — cumulative MAIN height writes across reload, and truthful physical recovery closure

## Decision

Prior FS25 tests on Estância São Carlos have established **ONE q-sized MAIN vertex write and actual save/reload persistence** (x=348,z=387, ~3.890991mm lowering). That does not yet certify repeated driving, broad field geometry, native sparse 0.125m fine ruts, or recovery. Do **not** turn on a production writer from that isolated sample. This development round is about correctness *between separate native operations*, not another single-point calibration or more visual track capture.

## Real source-level deficiency: the cumulative ledger is per-process

`TerrainQuantizedHeightBudget` stores `committedM` in RAM only. The `TerrainGeometryJournal` independently persists `preREHeightM`, current native `observedHeightM`, and the strict `owned` bit across saves. Without reconciling the two, a new process with an empty ledger could request the same q-sized damage again, and native MAIN could be excavated twice despite the old physical rut still existing.

### Implemented (research branch, not main)

- `TerrainQuantizedHeightBudget.VERSION=4` implements `seedOwnedTarget(key, measuredCommittedDepthM)`: initializes the target-mode ledger from **independently measured RE-OWNED MAIN geometry**. The initial `demandTargetM` and `committedM` are set to the actual depth below the immutable `preREHeightM` (not to a model wheel target, not to the reported visual track `groundDepth`, and not to the nominal q). Zero physical write, zero added debt.
- On subsequent calls it checks that the ledger's committed depth still agrees with physically owned MAIN height within 10µm; otherwise it quarantines that experimental budget (`OWNED_GEOMETRY_LEDGER_DRIFT`). Do not reset on unverified logical decreases.
- `TerrainAbsoluteVertexCandidate:applyOne(..., "CUMULATIVE")` calls this reconciliation after the existing 3×3 geometry ownership/budget preflight and before funding a new full q step. A legacy INCREMENTAL item still rejects a CUMULATIVE request as `MIXED_DEBT_CONTRACT`.
- **Contract scope:** `CUMULATIVE` refers to total desired depth relative to the **original trusted pre-RE baseline across game sessions**. A caller providing a *new, post-reload/session-local wheel delta* must add it to the independently owned, remaining baseline depth; it is NOT equivalent to a cumulative target. This bridge is not yet connected to production wheel-deformation loop and is NOT authorization for automatic digging.

### Regression

`tests/terrain_absolute_cumulative_reload_harness.lua` simulates two neighboring 1m MAIN vertices, q-sized repeated cumulative requests, multiple q steps, journal export/import with an entirely new process budget, and refusal of redundant writes on BOTH vertices. Only new cumulative depth authorizes another step. The mock reproduces a 59nm under-q readback consistent with the first real FS25 engine sample, and accounts by actual before/after heights rather than rounded nominal q. A 20µm foreign edit blocks a subsequent write; a full-q stale loaded saved ownership record remains diagnostic-only, not eligible for another dig. A manually divergent ledger is quarantined.

The initial harness runs exposed precise near-boundary floating-point cases. We kept strict full-q funding (NO epsilon that could authorize an overdig) and adapted test assertions to actual readback. Full Lua/XML CI **green** at code commit `d3148bc4`: https://github.com/rafaaelalves/FS25_RealismExtensions/actions/runs/43274050773 .

## Physical recovery closure: one remaining q is NOT restored

Review found another quantization hazard in `TerrainGeometryJournal:finishRecovery`: it previously called `completed=true` if `afterDeficit<=4mm`. On Estância MAIN, ~3.891mm is a WHOLE native height step; this could declare an entire remaining quantum fully restored and erase RE ownership.

- The experimental completion threshold is now **1.1mm**; it is conservative and below the observed Estância q. It does not claim this is a universal definition of "physically flat" across all other map scales. True per-map quantum completion policy remains future work.
- `completed` now ALSO requires `safe=true`. A brush that changed a neighboring vertex by >10µm or changed the center outside the interval [before−10µm, original+10µm] loses ownership and CANNOT declare the recovery closed. No speculative reverse operation is issued.
- Partial recovery one q below baseline stays owned with its immutable reference, so it remains eligible for another legitimate worked-area operation. `TerrainCausalRecovery.DEFAULTS.minDeficitM` is 3mm (formerly 4mm) to avoid stranding an entire ~3.891mm step. It is still gated by true RE-owned geometry, the real GIANTS work-area authorization, local eligibility, and `TerrainPermanentActuator~="SHADOW"`.
- If the brush's smoothing mock converges only partially and stops at ~2.46mm residual, its remaining geometry stays recorded but `physicallyClosed` does NOT advance. This is an unresolved physical residue, not a passing recovery test.
- `tests/terrain_exact_recovery_completion_harness.lua` simulates two q-sized recovery steps; first reduces 2q→q and MUST NOT complete, second q→0 completes. Invalid 20µm neighbor side-effect, q-sized overraise and no-effect recovery stay untrusted/incomplete. `tests/terrain_causal_writer_integration_harness.lua` now asserts a realistic partial brush response is NOT falsely called fully restored. Full CI **green** at commit `2641c7b4`: https://github.com/rafaaelalves/FS25_RealismExtensions/actions/runs/43274778835 .

## Release gates and limitations

These are nontrivial safety and functional pipeline advances, but still **MOCK Lua tests** for multiple steps/vertices and recovery. The previously proven actual live FS25 data remain ONE actual persisted MAIN vertex q-step only. We have NOT yet verified post-load multi-step sequences in-game, the native fine wheel rut surface, or end-to-end recovery while plowing.

The coarse MAIN 1m grid is unsuitable for automatically writing every fine Fiat tire print when footprint coverage is just 6.6%. Restore of a physical MAIN rut must not derive ownership from the visual TireTrack archive or a virtual 0.2m history cell. Keep `TerrainPermanentActuator=SHADOW` and the 10–12cm safety caps for now. Do not merge PR64 into the updated RE main without branch reconciliation and explicit review; RC changes are a separate scope.

No additional user game test is necessary THIS STEP. When the engine test becomes justified, it should cover a small, proved-safe multi-vertex/partial-restore protocol on a disposable cloned career, not a repeated plow/sow/harvest grind on the user's actual save.
