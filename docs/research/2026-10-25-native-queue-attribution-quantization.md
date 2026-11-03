# 2026-10-25 — Native deformation attribution: evidence, observer, limitations

## Answer to the user's hypothesis

**Yes, it is mechanically plausible** that several independently loaded systems can interact with a wheel's sink and radius, or that other terrain writers can submit native geometry operations between RE's preflight and callback. But the current RE logs show **a before/after difference in sampled main-height vertices**, *not the source of each change*. The source of the 58.4mm event remains **unattributed**. Do not infer that Mud is to blame, or that the RE additive brush alone caused all 58.4mm.

The last 20:08:59 in-game run used RE **`4d9fbec85`**, map Estância São Carlos, Mud 1.3.7.0, TerraFarm 1.6.5.0, MR 0.26.10.08, and RC main. There were 129 native RE jobs, 119 main-height no-ops, 10 with lowering, a 1.7mm request followed by a 58.4mm callback delta, and the existing RE session quarantine stopped further RE wheel writes. RE's own `TerrainWriter:flush` with `TerrainCausalRecovery=true` already serializes one RE native job and one wheel brush per callback (tested in `terrain_writer_harness.lua`).

## Quantization makes the former 'amplified' count partly misleading

For this exact observed main-height channel, six exact height pairs align to integer multiples of `q≈255/65535m≈3.89105mm`, but there is **no direct verified terrain.I3D heightScale**. The old threshold used for diagnostics/ownership, `observed>requested+2mm`, means a **single** q step after a 1.7mm request crosses the boundary (3.891mm > 3.7mm). Thus `nativeAmplified=8` out of 10 positive events cannot be treated as eight unusually dangerous *multi-quantum* events. This conservative veto is safe but may reject legitimate single-grid-step rut provenance; without a trusted map quantum or documented native scale semantics, don't silently lower it or mark a single q as safe on all maps. Conversely, the 58.4mm event is ~15q and **cannot be explained by one quantum of rounding**.

The next geometry controller should separate output classes, requiring proven map quantization and absolute delta size, before it decides which outputs are attributable to RE and recoverable. The current trial deliberately continues to reject uncertain writes rather than invent restore authority.

## Source cross-check

- Official GIANTS FS25 interview: dynamic wheel/terrain collision displacement uses 0.125m geometry. This is NOT the main 1m heightmap sampled by `getTerrainHeightAtWorldPos`.
- Official GIANTS scripting engine Terrain Detail exposes material firmness and viscosity properties influencing native tyre depression. This is a physical input channel, not an explicit persistent `TerrainDeformation` job.
- Public GIANTS script `PlaceableRiceField:performTerrainDeformation` calls `g_terrainDeformationQueue:queueJob`, proving non-RE participants in the shared native queue.
- TerraFarm 1.6.5.0 source `scripts/landscaping/LandscapingInput.lua` calls `TerrainDeformation:apply(false,...)` **directly**, outside `queueJob`. `LandscapingInputFlatten.lua` applies directly too. Therefore observing `queueJob` alone can never attribute all native geometry edits.
- RC main's 16 integration Lua sources were scanned for native height-changing writer calls; none contains a literal `TerrainDeformation.new`, `setTerrainHeightAtWorldPos`, `setAdditiveHeightChangeAmount`, or `g_terrainDeformationQueue` call. RC does have tire radius/sink/wetness mediation. Static source search is not a comprehensive cross-process call graph and cannot exonerate every external mod.

References:
- https://www.farming-simulator.com/newsArticle.php?news_id=569
- https://gdn.giants-software.com/documentation_scripting_fs25.php?category=29&function=818&version=engine
- https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=756&version=engine
- https://github.com/scfmod/FS25_TerraFarm/blob/main/scripts/landscaping/LandscapingInput.lua
- https://github.com/scfmod/FS25_TerraFarm/blob/main/scripts/landscaping/LandscapingInputFlatten.lua

## New opt-in pass-through observer

`scripts/terrain/TerrainNativeQueueProbe.lua` is included in the experimental mod but **`Config.modules.TerrainQueueSubmissionProbe=false`**, explicitly opt-in. On enable, `Core:update` installs a pointer-safe wrapper around `g_terrainDeformationQueue.queueJob` only when it exists, never installs any editor/physics hook, and `Core:deleteMap` disables/restores the wrapper if possible. The wrapper:
- forwards the exact original self, deformation, preview, callback name, target and any varargs with original return values/errors;
- recognizes RE's own native jobs through `target.owner==runtime.writer` and `target.deformation==deformation`, classifying everything else merely as `other`, **not as a named mod**;
- counts submissions by others while `writer.nativeCausalPending` is true, with up to 12 bounded callback-name strings as **hints only**;
- never reads/writes any physical vertex or changes native queue semantics;
- includes tests verifying unchanged args, returns, error propagation, pointer drift, late wrappers and unload behavior.

`TerrainDeformationEngine` now snapshots the optional other-submission counter at RE job submission and reports `otherQueuedWhilePending=N` on its bounded `TerrainNativeDelta` and `TerrainNativeQuarantine` diagnostics, with `unobserved` when probe off. This is a correlation **in time**, not proof of spatial overlap or that the other job lowered main height. Even zero concurrent queued jobs does **NOT** rule out TerraFarm's direct apply, native wheel displacement, or engine-internal nonlinear brush behavior.

`tests/terrain_deformation_engine_harness.lua` specifically synthesizes one other queue submission during a mocked RE callback and checks this annotation appears, without granting ownership or altering quarantine.

## Separate uncertainty: what exactly does the height accessor return?

The GIANTS engine documentation for `getTerrainHeightAtWorldPos(terrain,x,y,z)` only promises **"Get terrain height at world pos"**; unlike `getTerrainHeightmapUnitSize`, it does NOT specify in that entry whether fine physical displacement is included or ignored in the returned height. Sampling at integer-spaced positions and observing 3.891mm steps strongly suggests principal-height quantization, but this is **not a formally proven native-vs-fine channel separation**. Do not interpret every observed height change as a direct modification of the permanent main-heightmap file until this behavior is tested or documented by the engine.

Source: https://gdn.giants-software.com/documentation_scripting_fs25.php?category=28&function=811&version=engine

## Verdict and next gate

- Current source evidence **does not prove duplicate RE native write submission**; its own causal queue serialization already prevents it.
- **The actual root cause remains open**, but we've prevented disproportionate callbacks from granting geometry-restoration authority and invalidated old v1 journal restore authority.
- No new user manual test is justified simply by the optional queue tracer. A later specific one-save A/B needs to observe both queue jobs and direct `apply` operations, without globally changing their behavior, or use a genuine native physical isolation scenario on a disposable save. This must be designed before asking for another gameplay cycle.
- `main` unchanged, RC unchanged, experimental RE PR #64 draft.
