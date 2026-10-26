# Soil Deformation Save 1.0.0.0 — exact-ZIP persistence, native displacement, physical geometry and RC/RE audit

**Audit date:** 2026-10-26. **Supplied input:** `FS25_SoilDeformationSave.zip`. **Author:** Rónai Márk / RMark. **Intent:** learn and evaluate selective clean-room design value, **not** ask to install it. **Verdict: RESEARCH ONLY / DO NOT ENABLE WITH EXPERIMENTAL RE TERRAIN / DO NOT ABSORB AS-IS**. A narrow standalone disposable-save demonstration could help validate GIANTS native displacement if needed. No RC bridge, source port, code changes or build.

## 1. Reproducible provenance

- Exact supplied ZIP SHA-256: `5f561c9a44fface036de3330819e3950aee4150f1da7df0b5155bfc105052eeb`; **86,888 bytes**, 3 entries, ZIP CRC **PASS**: `modDesc.xml` (3,262 bytes), `icon_SoilDeformationSave.png`, `scripts/SoilDeformationSave.lua` (82,973 bytes; **2,133 lines**).
- `modDesc`: `version=1.0.0.0`, `descVersion=115`, author Rónai Márk, MP-supported **declaration**. XML strict parse and executable Lua `texlua --luaonly` / `loadfile` parse PASS. No independent packaging dependency, no declared missing Lua.
- The author's English description explicitly acknowledges: it operates server-side / host; **joining MP clients do not see replayed traces**. Native displacements and rendered tracks must not be described as confirmed deterministic multiplayer.
- **Explicit rights restriction** in the header *and* mod description forbids copying, modifying, redistribution or incorporation in other mods without written permission. Treat all insights as engineering precedents for an independently written solution, not a source of importable Lua or assets.
- Public release [KingMods Soil Deformation Save V1.0.0.0](https://www.kingmods.net/en/fs25/mods/83563/soil-deformation-save) published 2026-10-26; not independently hash-matched to the user ZIP.

## 2. Three separately persisted phenomena — do not collapse them into a generic "rut"

| Channel | Source / capture | Save | Restore | Ownership |
| --- | --- | --- | --- | --- |
| Wheel native sink/displacement estimate | Appended `WheelPhysics.serverUpdate`; estimate `getTerrainHeightAtWorldPos(x,z) - physics.lastContactY` when field/ground contact, 0.5 m travel gating, 1.5 s stationary resample | Quantized cell grid, reference absolute height + relative depth + age; chunks in `soilDeformationSave.xml` | After 2 s and streamed read, direct **absolute `setTerrainHeightAtWorldPos`**, not native displacement recreation | Competes directly with **RE native heightmap writer**, unlike a render-only track recorder |
| Tread-mark strips | Proxy to `spec_tireTracks.tireTrackSystem` on `TireTracks.onPreLoad`; wraps `createTrack/addTrackPoint/cutTrack/destroyTrack` | Segment width, atlas, colored/dirt/depth/ground/blend point attributes; Y stored relative to local ground | Recreate `tireTrackSystem` strips *after* geometry replay, reposition Y against present ground | Visual native engine system; distinguish from geometrical rut |
| Plow share native trench | Captures `FSDensityMapUtil.updatePlowShareArea` parameters with post-call wrapper | Spatial work parallelograms / command log | Calls **`updatePlowShareArea` again**, potentially affecting foliage/soil; skips if five sampled points indicate fruit | Native plow displacement/density operation; **not** equivalent to RE tillage recovery |

The README's central claim is an *inference*: GIANTS keeps some transient displacement in a native layer which is not exposed to Lua persistence. The ZIP's source captures wheel contact offsets as a proxy and writes an entirely different **persistent heightmap** on replay. The source cannot demonstrate exact identity between native transient rut shape and reconstructed physical surface. GIANTS public FS25 [ground-deformation description](https://www.farming-simulator.com/newsArticle.php?news_id=569) supports physical response to native ruts, **not the equivalence of two storage/replay layers**.

### Lifecycle/operational details

- `MIN_DEPTH=0.012 m`, `MAX_DEPTH=0.30 m`, `unit` from engine heightmap (default 0.5 m), `SAMPLE_DISTANCE=0.5 m`, `MAX_SEGMENT=8 m`, `MAX_CELLS=150,000`, `TRACK_MAX_POINTS=40,000`, `PLOW_MAX_AREAS=12,000`.
- Save uses 50 serialized cells per XML text attribute and legacy `rutMemory.xml` compatibility; saves on hooks to `FSBaseMission.saveSavegame` and `FSCareerMissionInfo.saveToXMLFile` with two-second deduplication. Backup auto-save every 60s if neither hook installs.
- Load is a multiframe state machine: parse chunks / legacy data / sort roughly by 64 radial camera-distance rings of 40 m, then replay up to 100 fixed / 4000 max cells per frame with 6 ms time target and two-second initial delay. Visual track and plow replay start **after** terrain replay. Heals up to 100 positions/frame.
- Soil-work erasure wraps 11 `FSDensityMapUtil.update...Area` functions; includes direct seeding exception `updateDirectSowingArea` (erases stored plow shapes but *not* wheel ruts/visual tire tracks) and previous-pass plow furrow "bury" age (>15 seconds).
- `recordCell` tracks a baseline `ref` and `applied` amount separately. On load `applyLoadedCell` computes `ratio=(ref-currentHeight)/depth` and classifies approximately pristine (-0.3 < ratio < 0.3), already-deformed (0.7–1.5), otherwise foreign edit / skip. These are **heuristics**, not a robust transaction or change-provenance protocol.

## 3. Source-tested defects and risks

**SDS-01 CRITICAL in the RE terrain profile — double ownership of physical ground geometry.** SoilDeformationSave directly writes absolute heightmap points on startup and heals to the historical reference during tillage/expiry. RE writes native additive/deformation brush jobs and tracks independent `SpatialHistory`/persistence. The two systems have no source/epoch/ownership handshake. Installing both could cause unintended cuts, reference overwrites, removal of legitimate RE-deformed terrain or sidecar divergence. No justification for a generic RC bridge: this is not a pairwise normalization problem but competing *world terrain write ownership*. This is a **source-confirmed architectural collision**, not a reproduced in-game fault.

**SDS-02 HIGH — physical-change success vs function-call confusion, reproduced in Lua.** `wrapDensityFunction` preserves `r1,r2,r3` from the native ground-work function and calls `t:onTillage(...)` **unconditionally**, without inspecting `changedArea` or whether any terrain vertices were actually moved. Harness: the mocked `updateCultivatorArea` returned `0,100` (0 actual area changed); one captured stored rut inside the area was still deleted (`cellCount 1 → 0`). This matters directly to RE's current issue of **work-area activity without successful geometric recovery**. Import the *negative lesson*: update recovered/cleared rut history only when an actual physical soil operation is verified with trustworthy source-side output or post-write geometry, not merely a called API method. In game the meaning of each function's return must be verified, and valid-work events may differ by implement.

**SDS-03 HIGH — "near-pristine" replay creates an extra cut on already altered terrain, reproduced.** For saved `ref=10.00`, `depth=0.10`, actual current terrain `9.98`, `ratio=0.2` falls inside "pristine" threshold; `applyLoadedCell` writes absolute `9.90`, another **0.08 m** cut. On exactly flat 10.00, expected result 9.90. The guard is heuristic and does **not** know whether the existing 2 cm change is caused by RE, TerraFarm, GIANTS persistence or world edit. Another case, current 9.95 yields `ratio=0.5` and **drops** the saved rut state; neither reliably merges nor rebases relative deformation. Treat tolerances with physical units + provenance rather than broad ratios.

**SDS-04 HIGH — healing can erase foreign geometry.** `processHeal` writes **the old absolute `ref` height** if `(ref-current)/applied` is 0.5–1.5. An external land edit matching that range, independently of SDS ownership, can be "healed" to obsolete terrain. Direct changes bypass native deformation job/queue constraints and do not signal RE's recorded history or other consumer caches.

**SDS-05 HIGH — replay transforms engine-native transient sink into a permanent heightfield cut.** Sampling one point's `lastContactY` minus the queried terrain height does not establish a complete rut cross-section, dynamic tire-shape displacement, pre-rut reference, terrain-cell precision, or actual volume conservation. `recordSection` paints the same measured depth across the entire wheel width, potentially flattening shoulder/berm geometry. Sampling `ref` at each rounded grid-cell position while measuring depth at an unrounded wheel-contact position can bias target shape on slopes. RE must not regard this as a verified alternate soil deformation model.

**SDS-06 MEDIUM/HIGH — plow replay is not a pure graphics restore.** It re-executes `FSDensityMapUtil.updatePlowShareArea`, which can affect vegetation. `plowAreaHasFruit` only inspects five points (corners and center), not every affected density pixel or adjacent crop. Tillage hooks are global, and multiple mods can operate the same functions (crop/soil specialist, contracts, field ownership). Client replay absence further disqualifies "same appearance for every participant."

**SDS-07 MEDIUM/HIGH — visual tire-track proxy/lifecycle side effects.** It replaces a vehicle's `spec_tireTracks.tireTrackSystem` with a Lua proxy delegating unknown methods to the underlying native object. May compose poorly with extensions retaining the original native userdata or expecting exact object identity; needs reload + two-map tests. Global `Utils.appendedFunction` lifecycle stores a target pointer and one-time guard, but does not check whether another mod replaced methods later. No proven crash. This is a strong reference for **decoupled visual track persistence**, not a wholesale replacement of the native track object in RE.

**SDS-08 MEDIUM — insufficient save provenance/atomicity.** XML stores map cell size but on load `ld.unit=self.unit`, ignoring saved `#unit`; map identity/geometric epoch is not checked (RE persistence **does** store map ID, geometry samples and format version). On resolution/map changes a saved coordinate may re-quantize into a neighboring cell. Separate sidecar write after save hooks has no verified atomic checkpoint with native heightmap save; loading abandoned/older sidecars can trigger conditional replay based on stale reference. Compatibility for legacy data is positive; robust checkpoints still missing.

**SDS-09 MEDIUM — timing/performance is partially bounded.** Restoration is deliberately frame-budgeted and camera-prioritized, positive precedents. But `save()` loops up to **150,000** cell records, tire track strips and 12,000 plow areas synchronously; `snapshot()` and `prune()` also iterate/sort synchronously. Large save-time pauses and memory pressure are source-level hypotheses requiring benchmarks. The 150k-cell + 40k-visual-point budgets are nontrivial for RE. Source comment estimates ~0.3 KB/cell; this is not measured heap usage.

**SDS-10 MEDIUM — MP declaration is limited.** Mod code explicitly returns from `loadMap` unless server/host. Author says connected clients do not see rebuilt marks. No custom event replicates replay state. Heightmap edits *might* be replicated by GIANTS APIs; do not infer a working multiplayer consistency guarantee from `multiplayer supported=true`.

**SDS-11 MEDIUM — global wheel and density hook stack interactions.** Appended `WheelPhysics.serverUpdate` observer (no friction/engine mutation) composes structurally better than a writer, but callbacks inspect contact/density fields modified/derived by Mud, MR, Reifen and RC. Capture may be valid but changing friction/wheel geometry changes its inputs. Global density calls can come from ordinary farm operations, modded field processing, or automated workers. No direct PTO/engine/fuel code found.

## 4. Most actionable new RE finding from CROSS-READ of current `main`

**RE-ASYNC-01 HIGH / needs investigation on active terrain branch** — `scripts/terrain/TerrainDeformationEngine.lua` `Engine.processSample` calls `writer:enqueue(brush)`, then **immediately** `historyStore:commit(... appliedDepth)` if the enqueue accepts the brush. However, `scripts/terrain/TerrainWriter.lua` **submits a separate asynchronous native TerrainDeformation job**; only in its callback does it count failed jobs and optionally sample before/after terrain for `geometryZeroChangeSamples` and `geometryShallowSamples`. Thus `history.rutDepthM` is currently **intent/accepted-queue depth**, not necessarily *committed physical depth*. If the native job fails, blocks or accepts with zero realized height change, `SpatialHistory` may overstate the actual rut. This was independently established by reading RE default-branch source at audit time; the user's concurrently developed experimental branch may have a different implementation and **must be checked separately**.

**Why this is worth investigating before treating it as a bug fix:** Some history fields (slip/shear/exposure) legitimately advance without any geometric write. Separate *desired/queued/applied/observed* channels and acknowledge native operations by source-labelled per-job completion or geometry verification, without holding expensive geometry samples permanently. Add regression: queue accepted → native no-op/failure → no durable increase in *physical* rut depth, while exposure/shear may persist; queue accepted → actual partial movement → bounded reconciliation. Beware competing wheel paths, merged/coalesced brushes and callback ordering; no naive per-brush expected-depth update can be assumed from one post-sample.

RE persistence currently stores **domain state** in `realismExtensionsTerrain.xml` and checks up to 512 physical terrain-height samples at reload (5 mm tolerance; ≥10% discrepancies rejects the history). It does **not** intentionally replay a previous native displacement layer as arbitrary direct absolute height edits. Maintaining that distinction is correct. First validate the native terrain persistence contract in-game before designing recovery-on-load fallback.

## 5. Stack owner crosswalk and suggested reuse

| Owner / mod | SDS interaction | Decision |
| --- | --- | --- |
| **RE TerrainDeformation, TerrainWriter, SpatialHistory, TerrainPersistence** | Strong duplicate terrain writer; unrelated persistent reference and cell history, direct absolute cuts/heals, global tillage clearing | **Do not run simultaneously**. Preserve RE as candidate sole geometric owner. Adopt separate *ideas*: explicit applied-vs-expected state, staged replay/reconcile and operation-provenance test fixtures. |
| **True AI Tracks** | SDS observes every wheel and separately recreates tire strips; True AI Tracks can already be responsible for native AI/implement deformation | Need source/stack parity if testing. No reason to overlap native AI geometry writers. |
| **Mud / MR / Reifen / RMS / RC state provider** | Reads wheel contact/density/shape, does not set friction, sink, torque or drivetrain; geometry changes later affect contact state | Indirect observed-sink provenance is not a substitute for Mud/RC physical wetness or calibrated RE rut response. No current RC bridge justified. |
| **SoilCompaction / Precision Farming** | Deletes stored rut memory based on tillage call, without verifying actual soil-state/physical work | Mechanical recovery and agronomic soil-work effects are different domains; direct drill exception useful as *provisional source policy*, requires observed vanilla and target-stack verification. |
| **TerraFarm / Auto Leveler** | Can rewrite absolute terrain in same cells; SDS old reference-based healing and restore risks overwrites | Reinforces world-surface mutation provenance and event-based history reconciliation, not pairwise mod wrappers. |
| **Water in Deep Tire Tracks / MapFlood** | Both consume surface height/geometry; SDS can alter reference heights after water meshes, tiles and basin caches have initialized | Stale hydrologic/visual geometry and resource updates; confirm ownership/change notifications before combining. |
| **Plow furrows / TireTracks** | Separately replay native density/displacement operations and native decorative marks | **New research opportunity**: distinguish persistent RE physical soil history from native transient **visual track/plow-displacement presentation** before assuming one replay path is needed. |

## 6. Reproducible isolated Lua harness

`texlua --luaonly` loaded the exact mod script with mocked `addModEventListener`, height queries/setters and one `FSDensityMapUtil.updateCultivatorArea`. No FS25 runtime was invoked.

1. Initial cell with `ref=10.00 m`, `depth=0.10 m`, `current=10.00 m` → replay set height to **9.90 m** as designed.
2. Same cell with `current=9.98 m` → replay set height to **9.90 m**, a further **8 cm** cut despite an existing **2 cm** depression (heuristic "pristine" branch).
3. Mock native cultivator returned **`changedArea=0,totalArea=100`**, yet callback erased a valid recorded rut inside the parallelogram (`cellCount:1→0`).
4. Restore-then-heal replay: applied 10 cm rut at 9.90 m; `processHeal` set it back to **10.00 m**, demonstrating its absolute-baseline semantics, not geometry-neutral history pruning.

These results confirm control-flow behavior under selected conditions; neither the actual GIANTS callback's semantics nor performance/multiplayer behavior are certified.

## 7. Concrete RE opportunities and gates

**Near-term highest impact:**
1. Audit the *active experimental branch* against **RE-ASYNC-01**; trace queue admission → GIANTS callback → actual observed geometry → committed persistent depth and matching tillage recovery, with telemetry for no-op and partial writes. Do not mistake source inspection of main for a diagnosis of a different experimental branch.
2. For recovery, require an explicit **successful work-area/soil-change** contract (including native return status, verified changed area and/or sampled post-state), not merely a named update...Area call. Distinguish harmless skipped/blocked work from effective cultivation and from planting with direct drill.
3. Investigate native tire track and plow displacement **visual persistence** separately. This mod's proxy/event journaling teaches how to capture their input, but reproducing it should only be considered after deciding whether those native layers are missing/valuable in RE and verifying rights/ownership.
4. Add regression fixtures: fresh/pristine geometry, pre-existing partial rut (2cm out of 10cm), pre-existing exact rut, foreign TerraFarm/landscape cut/raise, no-op native tillage call, direct seeding, overlapping plow passes, interrupted writer job, duplicate replay after reload, and nonmatching map/unit.
5. Keep save format version, map ID, geometry checkpoint, consistent units, and separate desired/pending/applied state. Persist *canonical soil history* and reconciliation metadata; do not blindly replay physical cutting instructions.

**Deferred:** Treat user-visible tire marks and plow-share geometry as potentially different owners. Explore whether a separate visual-only persistent strip player is warranted after confirmed native behavior; do not introduce a second world heightmap writer into RC or RE.

## 8. Disposition

**Do not add this ZIP to the active RE experimental terrain stack. Do not functionally absorb it whole.** It competes with terrain write ownership and replay. **Selective conceptual absorption strongly justified** for (a) physically verified vs requested height, (b) idempotent/reconciled per-cell reload, (c) stream/budgeted restore patterns, (d) multi-channel ownership of physical rut, track decal and plow-share operations, and (e) soil-work success gates.

**Documentation only**: no RC/RE runtime code modification, no ZIP/build, no version/bridge policy change. Separately follow up on RE-ASYNC-01 as a focused source/log research question in the ongoing terrain-development chat.
