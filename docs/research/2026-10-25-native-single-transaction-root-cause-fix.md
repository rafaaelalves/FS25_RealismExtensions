# 2026-10-25 — Native causal write isolation and accurate damage accounting

## Correction: clipping screenshot has no corresponding uploaded log
The user explicitly clarified that the screenshot from a session with RE disabled was from another game session whose log was not uploaded. The latest uploaded log belongs to a separate session where RE was active. Do not conflate them or dismiss the RE-off visual observation.

## What the runtime logs established
RE submitted a 2.4mm lowering command but sampled max native-vertex lowering values including 7.8mm, 58.4mm, 112.8mm and 147.9mm. The 1m native journal samples total changes within the callback window. The log does not prove the GIANTS brush alone originated these changes.

## Confirmed source bugs corrected
1. TerrainWriter previously grouped multiple callback-bearing LOWER brushes into one native job (up to eight). Their different journal callbacks then each compared heights after the whole batch, corrupting one-brush attribution. Native batching also rounded a 2.4mm brush to 2.5mm. The causal mode now submits exactly one callback-bearing LOWER per job at its exact requested depth, preserving ordinary no-callback batch performance.
2. Even separate RE jobs could be in flight simultaneously across frames. In experimental causal mode, TerrainWriter now submits at most one RE-native deformation job at a time, including direct recovery TARGET jobs, and waits for its native callback before submitting another. This is a deliberate temporary throughput tradeoff to establish honest native before/after attribution; other mods are not covered by this lock.
3. TerrainDeformationEngine capped the mechanical SpatialHistory rut debt to the original command even when the journal confirmed a larger native lowering. That made some deep owned ruts invisible to monthly maintenance (which requires at least 3mm mechanical history). The mechanical proxy now records the confirmed max native lowering; the per-native-vertex journal remains the authoritative recovery reference.
4. TerrainCausalRecovery formerly started its 4.5s timeout at queue acceptance and freed locks even when the native job had not started or its callback was merely slow. TerrainWriter now notifies submission through onSubmitted; the timeout begins only then. A late callback raises one timeout alert but retains locks until the real callback, intentionally failing closed rather than silently losing ownership.

## Verification
Added/extended deterministic tests: single brush exact depth, asynchronous native exclusion across frames, physical 12mm response from a 3mm request maps to >=12mm logical history, recovery queued >4.5s cannot time out before submission and late native callback retains lock. Existing CI must pass for the exact final commit.

## Not yet solved
These fixes eliminate specific attribution and lifecycle defects but do NOT prove the native 147.9mm jump came from batching, or provide a safe 2.4mm-in / 2.4mm-out guarantee. External terrain writers and 12.5cm physical deformation channels can still differ from the 1m journal sampled heights. Do not remove the provisional 10cm/12cm protection, declare a release, or claim clipping is fixed. Monthly NPC/public maintenance and simultaneous cultivation/RE wheel damage remain unproven in live game, despite prior deterministic tests. No new game save cycle is required for this source repair; future validation can be short and incidental to normal play.

Main branch remains untouched; PR #64 stays draft.