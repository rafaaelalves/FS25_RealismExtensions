# 2026-10-25 — Stack concurrency hypothesis: native terrain writers, wheel-physics wrappers and provenance

## Why this audit exists

User raised a valid risk hypothesis: MR, Mud, Reifen, TerraFarm, RE and others may change wheel radius/traction/sink or issue overlapping terrain commands. One RE 1.7mm native ADDITIVE request coincided with an observed 58.4mm 1m MAIN heightmap loss, triggering session quarantine. Previous samples 2.4/3mm→~7.8–19.5mm, 119/129 queue jobs observed no principal-vertex lowering. **The callback observed changes; it does not identify which source authored every change between preflight and postread.**

This audit distinguishes two mechanisms that must not be conflated:

1. **Physical input/geometry of wheel** — MR/Mud/Reifen/RMS/RC can change sink/radius/load/friction; these feed RE's pressure/yield request *before* writer submission, plus native 0.125m ground displacement from wheel collision. Such composition can influence demand, but cannot alone prove multiple main-heightmap brushes were submitted.
2. **Asynchronous independent native writes** — RE uses `TerrainDeformation.new`, ADDITIVE soft-circle and `g_terrainDeformationQueue:queueJob`. GIANTS' own PlaceableLeveling and rice-field gameplay also enqueue `TerrainDeformation` jobs; TerraFarm can apply direct machine terrain deformation. RE's `nativeCausalPending` serializes *RE jobs*, but **does not lock the whole engine against other mods/base-game operations**.

## Source inspection, 2026-10-25

- **RE** `TerrainWriter:flush` with `TerrainCausalRecovery=true` limits one GIANTS job at a time. Callback-bearing LOWER requests have their own distinct group with original requested amount and are not coalesced into multi-brush jobs. `tests/terrain_writer_harness.lua` already asserts each job contains only one RE wheel brush, and async RE submissions await callback. This significantly weakens the hypothesis that **RE itself** applied N additive brushes inside one nominal causal callback. It does not rule out independent native wheel displacement or another author's job.
- **RC main, integrations directory**: all 16 current integration Lua files were scanned for literal native terrain setter, ADDITIVE brush, `TerrainDeformation.new`, native queue and wheel displacement setter symbols; no direct call found. This is limited static search, not a proof no other connected component performs geometry writes through an alias. RC MRMud specifically contains structural radius/wheel support width, local wetness and rolling resistance coordination.
- **MR/Mud**: supplied-session ModMixer log reports multiple shared `WheelPhysics` overwrite/append chains, including `updatePhysics`, `updateTireFriction`, `serverUpdate`. This validates **wheel-physics composition risk** but is NOT a trace of duplicate `TerrainDeformation` commands. The last runtime `MRMud` summary observed 45,813 structural radius overrides, 44,134 updateFriction calls, no direct heightmap writers reported. These are callback counts, NOT rut counts.
- **Mud 1.3.7 source-based RC audit** `docs/audits/2026-10-18-mud-1.3.7.0-update-audit.md`: no 1.3.7 changes to local wetness, main sink/slip friction, shared radius combiner, pressure, or Reifen bridges; new particle feature doesn't issue terrain-height edits. It specifically states TerraFarm deliberate landscaping and RE geometric writes have separate owners. **Does not prove** Mud or any third party never edits ground by a different path.
- **TerraFarm** `docs/audits/2026-10-02-terrafarm-full-stack-audit.md`: active direct landscaping and machine-terrain writer; possible overlap with AI native tracks, FarmKit, RE recovery. No evidence in the 20:08 session that TerraFarm's machine actively wrote at the exact anomalous coordinate.
- **Other mods** (FarmKit, WaterInDeepTireTracks, native FS25 fine displacement, AI tracks, map-specific mechanics): cannot be exonerated or blamed from ModMixer hook list or the existing terrain-main callback telemetry alone.

Official GIANTS script example, PlaceableLeveling calls `g_terrainDeformationQueue:queueJob(...)`:
https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=745&version=script

## New actual source defect identified and fixed

**Pre-fix**: in `TerrainDeformationEngine` wheel LOWER `onApplied`, `journal:complete(token, success)` *optimistically* marked every downward-changed main grid vertex `owned=true`. Immediately afterward, RE committed its entire `physical.maxLowerM` into 0.2m SpatialHistory *before* checking the magnitude mismatch and quarantining future writers. Consequently a 3mm RE request followed by an unexplained 12mm native loss became RE-owned and potentially eligible for **unjustified automatic recovery**, even if the source was third-party or a nonlinear native operation. The first 58.4mm event had the same exposure. Quarantine of **future** RE writes did not invalidate provenance of the already amplified result.

**Fix**:

- `TerrainGeometryJournal` tokens now record owning journal and successful completion; new `invalidateCompletedFootprint(token,reason)` marks **all** affected observed vertices untrusted, preserves immutable original height without recovery authority, refuses forged/stale/repeated tokens, never issues an inverse terrain write and records revoked counts.
- `TerrainDeformationEngine` checks **excessive lowering (`maxLowerM > request + 2mm`) or unexpected simultaneous rise** *before* any SpatialHistory debt commit. On suspicious output, revokes geometry ownership and skips physical debt while retaining native telemetry and strong-session quarantine for >max(25mm,8×request). Clean bounded readbacks still commit normally; zero-effect unchanged.
- `Core` prints cumulative `nativeOwnershipRejected` and `trustedVerticesRevoked` on normal one-minute TerrainHealth log. These are actual ownership vetoes, NOT native geometry restores.
- Updated `tests/terrain_deformation_engine_harness.lua`: 12mm after 3mm request must be rejected, clean <=3mm command still accepted, and 55mm event must quarantine and be untrusted. `tests/terrain_geometry_journal_harness.lua`: 55mm burst has no `getRecoverablePoint`, immutable original retained, invalidation idempotent and token-scoped.

The unit harnesses use mocked GIANTS geometry. A green CI is source integrity evidence, not live diagnosis of the true writer or physical displacement amplitude. The existing experimental additive actuator remains *unsafe for mainline*; this fix addresses provenance of the failure, **not** first-event native overshoot.

## Next technical decision

Do **not** install a global unconditional `TerrainDeformationQueue.queueJob` overwrite in RC/RE based only on this hypothesis. That would alter global engine behavior and might miss direct `TerrainDeformation.apply` calls (e.g. TerraFarm). If continued investigation warrants it, use a strictly optional, pointer-integrity-checked, pass-through observer that records bounded timestamps/owner candidates and warns about overlap with an in-flight RE journal, while recognizing that queue overlap is not proof of same-coordinate write.

Prioritize physically deterministic control/provenance (native fine displacement for transient effects, separate verified absolute/quantized main-height ownership for permanent ruts). Only request A/B game testing after a specific falsifiable mechanism and safe rollback/backup protocol exist. No new gameplay test is justified merely by this speculative stack conflict.

RC main and production RE main unchanged. Experimental RE PR #64 remains draft, no merge.
