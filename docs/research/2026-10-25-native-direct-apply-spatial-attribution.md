# 2026-10-25 — Experimental native direct-apply/overlap attribution, no terrain write

## Problem and evidence

Observed on map Estância São Carlos in session 2026-10-25 20:08:59: RE issued tiny additive main-terrain wheel commands (one at 1.7mm) and the height accessor later reported either no movement or multi-quantum movement, including 58.4mm coincident with a single RE callback. The callback compares heights before/after **but cannot prove which writer caused the delta**. Observed main-grid increments around `q=255/65535m` make the +2mm threshold conservative: even 1 × q can exceed 1.7mm + 2mm. A 15q anomaly cannot be explained by a single quantum.

User's hypothesis that multiple mods may multiply wheel physics requests or directly write native terrain is credible. Code audit of RE's `TerrainWriter` shows **one native causal wheel job at a time and one brush per callback**, but this does not serialize other mods. Source audit of TerraFarm's `scripts/landscaping/LandscapingInput.lua` and `LandscapingInputFlatten.lua` finds `deformation:apply(false,...)` directly, independently of the global queue. The previously implemented `TerrainNativeQueueProbe` observed only `queueJob`. The additional module below addresses part of that gap.

## Implemented, opt-in and fail-closed

Source:
- `scripts/terrain/TerrainNativeSpatialProbe.lua` **new**.
- `scripts/terrain/TerrainNativeQueueProbe.lua` extended for correlation.
- `scripts/terrain/TerrainDeformationEngine.lua` now logs concurrent queue/direct and spatial overlap candidate counts on bounded `TerrainNativeDelta` / `TerrainNativeQuarantine` events.
- `scripts/Core.lua`, `modDesc.xml`, `scripts/Config.lua`: module loaded in experimental branch, but **`modules.TerrainQueueSubmissionProbe = false`** so no instrumentation hooks unless explicitly enabled.

When *explicitly enabled*, the probe installs pass-through wrappers (via guarded assignment) on exposed Lua `TerrainDeformation.addSoftCircleBrush`, `addSoftSquareBrush`, and `apply`. It records original nominal circles (or a square's enclosing circle), bounded to 24 shapes per native deformation object; a weak-key table prevents holding deleted engine instances alive. Larger operations have a bounded aggregate region envelope and an explicit `broad` classification, **never falsely claimed to have precise sampled-brush overlap**.

On an RE native submission, `TerrainNativeQueueProbe` sets the RE footprint from the single causal wheel brush. It then records when independent operations in the same *submission window* use brushes whose requested footprints intersect that RE envelope. Queued and direct-apply submissions are counted separately. Time/footprint overlap is *evidence of potential contention*, not proof of a changed vertex or confirmation of a particular mod. Painting, preview, no-effect native callbacks and direct physical wheel-displacement collision may all be different phenomena.

Any available Lua caller site is recorded only as a sanitized `modDirectory/LuaBasename.lua`, with a max of 12 unique sites. Source paths, drive letters, user directories and arbitrary absolute filesystem paths are never emitted. When `debug.getinfo` is absent, everything still works with `sourceHintsUnavailable`. **A wrapped call may originate from a peer wrapper rather than the true geometry producer**; labels are hints, not ground truth.

The actual GIANTS pass-through retains original argument ordering, return values and error propagation, including varargs on the queue. Guarded method installations roll back partial patches on failure, never rewrite a peer's later wrapper, and turn older retained hook generations inert after map load/unload. If GIANTS does not expose class methods on the Lua table, the probe refuses to install and logs unavailable coverage. **A clean GitHub Actions mock does not prove engine method hookability.** The optional observer is therefore not enabled by default.

## NEW independent callback outcome signal

`TerrainWriter:done` already obtains a GIANTS `displacedVolume` parameter, converted by `TerrainWriter` to an absolute callback volume. `TerrainDeformationEngine` previously accepted only `state` and discarded that native metric. On an anomalously large wheel LOWER it now records:

- `nativeCallbackVolumeM3`: volume delivered to the specific RE callback, or `missing`.
- `nominalCylinderM3 = pi*brushRadius^2*requestedDepthM`: merely a normalization/reference, not the expected native soft-brush excavation amount.
- `volumeRatio = nativeCallbackVolumeM3/nominalCylinderM3`, or `missing`.
- `otherQueuedWhilePending`, `otherDirectWhilePending`, `overlappingQueueBrushes` and `overlappingDirectBrushes`: per-RE callback window counters; `unobserved` if the relevant probe is disabled/unavailable.

This creates **two different observations**: engine-reported volume for the RE job vs. height changes measured after the job. If the volume is small but height changes massively, concurrent terrain edits, quantization or another geometric channel become stronger candidates. If the volume is abnormally high even with no detected foreign writer, RE's own native ADDITIVE brush semantics deserve focus. The callback volume is not a proof of exact geometry, nor are these scenarios mutually exclusive.

## Validation

Standalone harnesses:
- `tests/terrain_native_spatial_probe_harness.lua`: actual Lua class method wrapping with stubbed GIANTS behavior, soft circles/squares, direct `apply`, far-vs-overlapping candidate, per-deformation weak-key state, multi-return and native error propagation, class pointer drift and old-generation map lifecycle. Sanitized Lua callsite hints tested with a mock `debug.getinfo`, including missing debug library.
- `tests/terrain_native_queue_probe_harness.lua`: native queue pass-through / optional hook coexistence and unloading, peer wrapping.
- `tests/terrain_deformation_engine_harness.lua`: injected simulated external queue and direct submit during anomalous RE wheel callback, verifies new `TerrainNativeQuarantine` correlation and native volume annotation. There is no real GIANTS terrain engine in these tests.

Previous safeguards retained: anomalous outcomes invalidate geometry journal ownership **before** any physical rut debt is committed, v1 native sidecars are loaded as untrusted observations and cannot auto-restore old dubious native edits, and >25mm/8× discrepancy quarantines the remainder of that RE session.

## Scope and what the next real-game experiment must answer

These source changes are diagnostic and do **not** resolve the first anomalous physical terrain edit or make permanent ruts reliable. They reduce the next testing uncertainty:

1. Confirm whether the GIANTS class methods are script-writable/hooked (probe `hooks` / `unavailable`, not a guess).
2. For an **isolated RE stroke** on a copied save, read RE job native volume and main-height change, with spatial/direct overlap candidates alongside. Do not repeatedly plow/sow/harvest.
3. Correlate a second baseline with RE native height brushes suppressed but vanilla physical wheel displacement/Mud left active. A matching hole could implicate a non-RE writer or engine channel, not the RE ADDITIVE request. Do not automatically blame Mud.
4. Validate the absolute quantized main-vertex prototype and its interaction with native fine wheel displacement in a limited proof before production write integration; fine physical displacement may be temporary while permanent main geometry needs causal restoration.
5. Maintain separate ownership for MR wheel grip, Mud wetness/sink, Reifen structural radius, TerraFarm landscaping, and RE persistent mechanical consequences. RC main and RE main remain unchanged.

No manual test requested until a precise isolated A/B can discriminate competing explanations. The branch remains **experimental draft PR #64**.
