# 14-Nov-2026 — fresh wheel-damage epoch after measured MAIN recovery (research-only)

## Scope and motivation

Prior development proved **one isolated quantized MAIN lowering** in actual FS25 on 11 Nov, and its native MAIN height **persisted after save/reload** on 12 Nov. It did NOT prove upward recovery, adjacent field repair, 0.125m wheel-displacement persistence or playable traffic. The 13 Nov code made a geometry-journal-issued, one-use recovery proof synchronize the physical remaining depth of `TerrainQuantizedHeightBudget`, with `recoveryEpochPending=true` freezing stale wheel demand.

A remaining flaw in the future writer contract was that `recoveryEpochPending` had **no independent, conservative re-entry protocol**. Clearing it on any subsequent frame, bool, logical tillage result or old `SpatialHistory.rutDepthM` could immediately re-excavate just-repaired ground.

This change introduces a **limited in-memory epoch admission and funding protocol**, not an automatic terrain writer, in the existing **draft PR #64** only. RC and production RE main remain unchanged.

## Changes implemented

1. `TerrainGeometryJournal:consumeRecoveryProof` now returns the same already independently validated native MAIN position and heights (`x,z,originalY,afterY`) with before/after physically measured depths. It remains a **single-use** receipt tied to its owning journal.
2. `TerrainQuantizedHeightBudget.VERSION=6` captures an in-memory recovery anchor only after that authenticated receipt. The old cumulative demand stays blocked while `recoveryEpochPending`. No stale history value or caller bool can clear the fence.
3. `observeFreshDamage(key,journal,sample)` admits a potential new post-repair wheel generation only after a monotonic server clock has moved beyond the recovery callback; independent native height readback still equals the recovered height (10µm tolerance); the MAIN reference is still owned if partly depressed; an explicitly grounded wheel supplies a **continuous** measured path, its footprint is classed `MAIN_RESEARCH_CANDIDATE`, and samples are inside the same grid vertex. The **first** post-recovery sample is only a baseline. A later timestamp and larger sample sequence from the **same** wheel, at least 20cm (or 0.2 map unit) away within 0.7 map unit, must show additional positive *post-recovery* cumulative modeled damage.
4. That later qualifying sample creates an in-memory **identity-bound** epoch ticket with a bounded target: **actual remaining RE-owned MAIN depth plus newly measured/post-baseline modeled damage**. A valid new sample may only enlarge it when both sequence and newly accumulated model damage increase; duplicate sequence and replayed model values are refused.
5. `requestTarget` and the explicitly gated research `TerrainAbsoluteVertexCandidate:applyOne` accept an optional ticket. **Without the exact ticket**, old three-argument calls remain rejected after recovery, even if a stale old depth happens to numerically equal a currently funded depth. Even WITH a ticket, the requested absolute cumulative target must equal the target funded by the new post-repair source, not an old arbitrary target. The existing strict full-quantum spending check, 3×3 native collateral check, exclusive write gate and 10–12cm limits remain unchanged.
6. An independent foreign MAIN edit >10µm or a different journal/owned baseline fails closed. Successful native single-step settlement updates the anchor only after the real readback, so the next sample sees the correct observed geometry.

## Lua regression scope

New `tests/terrain_fresh_damage_epoch_harness.lua` uses the actual journal, budget and absolute candidate classes with an **entirely mocked** native grid/setter and a simulated monotonic clock. It exercises initial verified lowering, partial recovery, old replay refusal, baseline admission, narrow or discontinuous contact refusal, wrong wheel, duplicate sequence, no travel, no new model growth, forged ticket, exact bounded q-funded write(s), no further repeat write, full recovery, ticket invalidation/new epoch and 20µm foreign edit quarantine.

The initial harness intentionally exposed a near-q arithmetic boundary: a second quantum must **not** be spent on slightly under-q remaining authorized budget, even when the original native readback differs from nominal q by ~59nm. The fixture now explicitly funds that margin; it does NOT relax the safety tolerance or round damage UP.

## IMPORTANT: what is *not* solved

- **No trusted gameplay producer exists yet for `sample.freshCumulativeDamageM`.** A future adapter must originate from newly observed actual wheel contact and truly incremental post-repair plastic damage; it must NOT submit historical virtual rut depth, a copied shadow target, independently additive overlapping 0.20m sources, wheel visuals, UI data or client-authored claims.
- `observeFreshDamage` checks *form and temporal/geometric consistency of caller-provided evidence*; it does **not independently authenticate a wheel identity, its internal odometry or a physical 0.125m fine rut**. This is an internal research protocol, **not sufficient authorization to enable the production setter**. Only the separate research candidate exposes an explicit manual write interface, with preexisting safety gates.
- The current runtime does **not** install `RealismExtensionsTerrainRuntime.absoluteHeightBudget` or call `observeFreshDamage` from the wheel engine. Normal `TerrainPermanentActuator="SHADOW"` means no automatic MAIN writes and no causal recovery writer. Do not casually wire these together.
- The recovery fence and post-recovery ticket live in **RAM only**. On process restart the journal can restore only RE-owned geometry, not an authenticated *recovery generation*. A fully restored vertex has no journal rut entry. Before ANY automatic long-running/reload writer, persist a versioned recovery epoch/tombstone or conservatively deny old-target replay after load; do not infer the new generation from legacy SpatialHistory.
- Native **UPWARD** quantized restitution remains mocked, not shown in real FS25. 1m MAIN does not faithfully represent normal narrow tire marks or the separate 0.125m native fine physical channel. No full harvest/cultivate/seed gameplay acceptance, save/MP/collision verification, performance, or depth-cap removal is justified.
- Post-repair modeled exposure may be **sub-quantum**. It must accumulate under the original q spending discipline rather than drive a premature physical step. New model demand and native geometry remain separate ledgers.

## Next focused engineering work

1. Design and integrate a server-owned wheel-source counter that resets on **actual, journal-verified tillage recovery**, uses real contact/path/pressure/plastic-yield data, and cannot replay virtual history, reuse a wheel sample sequence, or multiply overlapping logical cells. Keep it read-only and SHADOW.
2. Persist/reconcile recovery-epoch identity across save/load without fabricating baseline heights for legacy ruts.
3. Only after the contract is independently tested, implement a small limited physical upward/round-trip test on a verified disposable career. It must check native MAIN 3×3, one-q amplitude, immutable RE baseline, collision, and reload; no repetitive field-scale tests.
4. Investigate separately whether the native 0.125m wheel displacement admits a true Lua read/save/restore path; do not claim it based on MAIN API or `TireTrackSystem`.

Links: [13-Nov handoff](2026-11-13-native-main-one-step-recovery-and-epoch-handoff.md), [12-Nov actual persistence](2026-11-12-main-one-quantum-save-reload-confirmed.md), [terrain release blocker #63](https://github.com/rafaaelalves/FS25_RealismExtensions/issues/63).
