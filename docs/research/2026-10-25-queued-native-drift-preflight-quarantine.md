# 2026-10-25 — Recheck native geometry at submission and quarantine excessive lowering

## Trigger / evidence

The 2026-10-25 19:17 game session ran corrected single-brush/single-RE-job isolation at code commit `a8740d4a8` yet observed six native callback lowerings of 58.4, 97.3, 81.7, 11.7, 15.6, 19.5 mm in reply to 2.4–3.0 mm commands. Those values correspond almost exactly to 15, 25, 21, 3, 4, and 5 steps of `255/65535m`; the exact Estância São Carlos `heightScale` and whether the FS25 runtime editing path is quantized at this resolution are **not confirmed**. A 16-bit map and `heightScale=255` are publicly documented common precedents, not facts about this specific map.

Source review revealed a confirmed attribution gap: `TerrainGeometryJournal:begin` samples the native 1 m grid **at wheel encounter/enqueue time**, but `TerrainGeometryJournal:complete` computes lowering **at GIANTS callback time**. The earlier strict `TerrainWriter.nativeCausalPending` lock prevents overlapping **RE native jobs**, but does not stop edits during the initial writer queue wait, nor concurrent non-RE edits during the GIANTS queue wait.

## Changes (PR #64 draft only)

- **`TerrainGeometryJournal:validateBeforeSubmit(token)`** samples every token vertex just before `TerrainWriter` constructs the native job. If any vertex differs by more than 2 mm relative to enqueue-time snapshot, reject the operation, invalidate any affected owned recovery reference, and never dig at this stale location. For stable vertices, refresh `beforeY` to submission-time measurements, improving callback delta attribution. New counters `submitChecks`, `submitDriftRejected`, `submitHeightUnavailable`, `submitMaxDriftM`.
- **`TerrainWriter`** accepts an optional `beforeSubmit` hook for callback-bearing brushes. This hook is executed before allocating `TerrainDeformation`. Failed hooks result in `onApplied(false)` (existing failure semantics) and release journal token locks. This path is not used by legacy/recovery commands unless opt-in.
- **`TerrainDeformationEngine`** uses the journal preflight for causal LOWER operations only. When a callback observes native lowering > `max(0.025m, requested*8)`, latch **`nativeDamageQuarantined=true`** for this game session and deny further native RE LOWER commands at both new wheel encounter and queued submission. This is deliberately conservative because the source of extra height change is not yet proven. It does **not** undo the first abnormal event, erase old ruts, or stop Mud transient physics/recovery.
- The first six `TerrainNativeDelta` diagnostics now include the most-changed native vertex key and **exact `beforeY` / `afterY`** to assess vertical step quantization without relying on 0.1mm printed summaries.
- New automated cases for stale queue changes, sampled vertex identity/exact callback delta, preflight callback cleanup, and quaratine after simulated 55mm native lowering.

## Validation

- Real RE source/test changes committed at code SHA `4d9fbec85e101733707cf4e9714dd0395d62d9d5`.
- GitHub Actions `Build and test mod`: **green** `40226720436` (parsing Lua, full harness suite, XML validation, ZIP build).
- Native GIANTS terrain semantics / third-party race windows **cannot be simulated authoritatively by the Lua harness**; the game is the release criterion.

## Remaining problems / do NOT claim solved

- `validateBeforeSubmit` narrows the queue-wait window but cannot guarantee an external system did not modify the same vertex **after** preflight and **before** GIANTS callback. Serial RE jobs are not a global native terrain lock.
- `maxLowerM` is max observed main-height vertex movement per operation, not physical depth of a visual rut or unique terrain volume.
- A first severe anomaly may still occur on experimental saves; quarantine prevents **subsequent RE lower submissions**, but is not a hard native output clamp. Do not test on only copy of a long-running game.
- No verification yet of Estância São Carlos's exact `heightScale` (public ModHub release v1.4.0.0 ~948MB), fine displacement mesh ownership or built-in terrain editing behavior.
- No new tillage recovery, monthly maintenance or game save roundtrip was exercised in the uploaded 19:17 session. Do not confuse this guard work with solving those issues.
- Do not merge terrain into main or remove provisional 10cm/12cm guards.

## Minimal next user validation

1. Optional, no gameplay needed: in installed `FS25_Estancia_Sao_Carlos.zip` locate the map `.i3d` `<TerrainTransformGroup ... heightScale="…" unitsPerPixel="…"` line, and send this line only. This can validate the expected vertical step but cannot by itself prove native editing quantization.
2. On a **DISPOSABLE BACKUP OF THE SAVE**, install the artifact from successful GitHub Actions run `40226720436` (code SHA `4d9fbec85`). Drive **one very short path** on already wet, previously problematic land; do not repeat plowing/sowing/harvest. Watch only whether the log shows `TerrainNativeDelta`, `TerrainNativeQuarantine` or `geometryJournalQueueDriftRejected`. Stop and upload `log.txt` and ModMixer log. Do not save altered experimental ground over the original save.
3. Interpret: if queue drift is rejected, initial attribution was contaminated by wait; if first isolated callback still reports many verified 3.89mm steps, investigate GIANTS brush semantics/foreign writers after submission and test independent read-only/no-RE-write controls. A quarantine event is **not** proof RE caused the entire displacement and is **not** a solved rut actuator.

The test is short and bounded; no player needs to redo a full field cycle.
