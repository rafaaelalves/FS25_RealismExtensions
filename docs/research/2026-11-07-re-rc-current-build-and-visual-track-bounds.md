# 07-Nov-2026 — PR64 + RC52 live log; memory-bounded native TireTrack capture research

## Evidence from the user (not from a controlled actuator test)

Full game log `log(20261108-014940).txt` (2599 lines); ModMixer log `ModMixer(20261108-014940).log` (143 lines). FS25 1.25.1, Estância São Carlos 1.4.0, savegame2 (a directory name does **not** prove the save is a disposable copy).

**Actual runtime identities:**
- RE `branch=64/merge commit=b8ba663c5ff3e1d482ab5569e37562f3686ffcc9 run=42434260960` (this branch's recent code/test build; *not* a new physical writer).
- RC `branch=52/merge commit=218f218aa3a35f399d03306c2ca7b20e6f63fb68 run=42421033802` (stacked RC PR #52).
- MR 0.26.10.08 / Mud 1.4.0.0: `MR+Mud ACTIVE SOURCE_COMPATIBLE`, `MR+Draft ACTIVE SOURCE_COMPATIBLE`, `Mud+Soil ACTIVE SOURCE_COMPATIBLE`, `MR+Tire ACTIVE SOURCE_COMPATIBLE`, `MR+RE PTO ACTIVE SOURCE_COMPATIBLE`.
- RMS 0.13.0.1: `MR+RMS UNSUPPORTED`, `Mud+RMS UNSUPPORTED`, `RMS+RE PTO UNSUPPORTED`. RC MRMud widthRadius integrity pointer drift=false may be safe wrapper, and MRMud telemetry shows `supportWidthRadiusCorrections=0`; cannot infer breakage or correctness without exact hook/source evidence. Don't alter RC source gates from a game log alone.

**Terrain runtime:** `TerrainTrial OBSERVE_ONLY`, `TerrainAbsoluteShadow mode=NO_WRITE quantum=UNVERIFIED unit=1m`, no native jobs, no wheel-accepted/confirmed write, no lowered vertices, `nativeAmplified=0`, no recovery. `sources=13 vertices=8 samples=31 targetIncreases=18 sourceGrowthSumM=0.009871 vertexDemandSumM=0.008098 mainFootprintSamples=18 mainFineOnly=15 mainResearchCandidates=0 mainGeometryUnknown=3 maxMainCoverage=0.066`. Shadow demand != physical rut. Wheel native capability observed passively 632 times / four wheel identities, displacementScale=1.0 throughout; **not a native fine height readback**.

Neither `reTerrainTrial lattice` nor the isolated setter/save/reload commands were used, so **quantum and setter fidelity remain unverified in the real FS25**. Loaded `VisualTrackCapture` from early bootstrap and installed `NativeTireTrackAdapter`, but no VisualTrackCapture stats appeared because the former summary was verbose-only.

**ModMixer:** `BOOT CONFIRMED HEALTHY`. Eight duplicate specialization-registration errors in CBI6800CT and `manualAttach delete(nil)` on game exit remain unrelated to the height controller; do not attribute the cause of visual clipping to RE or ModMixer without a controlled comparison.

## Why visual TireTrack capture merits further engineering

The documented GIANTS FS25 `TireTracks:updateTireTrackNode` uses `wheel.physics:getGroundAttributes()` returning `groundDepth`, then calls `spec.tireTrackSystem:addTrackPoint(...,dirtAmount,groundDepth,...)`. The RE adapter already observes the real `createTrack/addTrackPoint/cutTrack` API without modifying the original return values. These **visual track point events do not measure the engine's permanent fine displacement heightmap** and are not proof of physical persistence or collision. Reference: https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=811&version=engine .

Existing source issue discovered: `VisualTrackChunkStore` accumulated finalized fragments/point refs/chunks indefinitely; `VisualTrackJournal` runtime observer (with retainClosedFragments=false) released point payloads but retained empty fragment metadata. Very long uninterrupted visual ruts could grow indefinitely before a `cutTrack`. That undermines any future long-duration capture/persistence work.

## Changes implemented on PR64 research branch only

1. `VisualTrackChunkStore.VERSION=2`: default bounded **8192 spatial chunks**, **40000 finalized fragment references** and **160000 point references**. Oldest finalized chunks/fragments are evicted together when limits are crossed; empty chunk containers removed. Oversized single fragment is rejected as a whole rather than truncated into a fake continuity. Eviction stats and overflow flags exposed. Overlapping chunk endpoints stay duplicated for visual continuity.
2. `VisualTrackJournal.VERSION=3`: maximum **1024 accepted points per open fragment**, with bounded `BOUNDED_SEGMENT` split and one carry-over endpoint; closed visual fragments are removed from runtime track metadata after being handed to chunk storage, and reused native track IDs replace old track metadata instead of appending retired generations. A cap on **number of distinct concurrently known native track IDs** is a further potential concern if hostile/unusually many IDs are observed; this change bounds heavy fragment/point growth rather than claiming a total process-level memory guarantee.
3. **Ground-depth telemetry:** records observed terrain-contact `groundDepth` arguments min/max and nonzero counts, explicitly named **visual ground depth**. Does not infer physical mesh deformation from these numbers.
4. `VisualTrackRuntime.getDiagnostics` exposes resource and eviction counters. `Core.lua` prints bounded `VisualTrackCapture` telemetry in the ordinary existing periodic diagnostic cadence even with verbose diagnostics disabled. This is one line per existing diagnostic interval, not per native point.
5. Harnesses extend `visual_track_chunk_store_harness.lua` (1000 fragmented simulated additions, caps, FIFO reclamation, oversized rejection, clear) and `visual_track_runtime_harness.lua` (continuous 150-point path, segmentation and released metadata, 100 native-ID reuses, recorded visual-depth range). These are simulated Lua tests, not runtime physical validation.

**Safety:** no direct terrain MAIN or native wheel write, no visual track replay into the engine, no persistence sidecar write, no mainline merge. Mod remains `SHADOW`. This is a precondition for a safe persistence pipeline, **not** a release of persistent physical ruts.

## Next release steps

- Verify runtime capture counts/visual depths in a future log using the updated build; no reason to ask user to perform any manual test now. Even active visual capture might be empty if the game never calls the observed methods in that short scenario.
- Isolate true native fine displacement behavior separately from TireTrackSystem and MAIN heightmap: no scientifically trustworthy fine-rut write/readback has been identified yet.
- Only after that, design a bounded save/replay model with ownership, rehydration, and tillage invalidation (and MP caveats). Avoid pretending visual mark replay restores actual physical geometry.
- Retain broad-`MAIN` actuator as separate optional earthworks path with map-specific quantization, strict full-step budget, anti-amplification and disposable-copy save/reload proof. Do not turn on main writes for 6.6%-coverage Fiat wheel contacts.
- Keep RMS 0.13.0.1 source audit on RC's separate roadmap; MR+Mud source gates are now active for 1.4.0.0 under PR #52.

PR64 stays draft, RC PR52 separately stacked, RE and RC mains unchanged.
