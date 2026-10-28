# 2026-10-28 — Permanent terrain rut actuator redesign, shadow implementation

## Why change the actuator

Previous FS25 runtime calibration (2026-10-27 21:34):
- One independent native `TerrainDeformation` ADDITIVE soft-circle LOWER, requested **0.0015 m**, radius 0.45 m, yielded measured **0.00778 m** on a native principal-height vertex (5.19x) and reported volume `0.005859375` in the GIANTS callback. Main-height snapshot confirmed a significant local change.
- Queue observed one RE submission and no unrelated queue job. The GIANTS queue's eventual `apply` must not be falsely classified as another independent direct mod job.
- The actuator argument is a command **input**. It is not a certified millimeter-perfect output; no compensating inverse/additive correction is justified from one sample.
- 255/65535 m = ~3.891 mm and two such levels ≈7.782 mm is a **hypothesis**, not a map-independent proven vertical quantum. The 1m MAIN grid in this map is separate from fine wheel displacement.

## Actual code changes

This branch's config sets `TerrainPermanentActuator = "SHADOW"`. `TerrainDeformationEngine.processSample` performs the supported soil/plastic response calculations but **returns before writing geometry or committing logical rut history**, regardless of whether the trial-console protection is separately active. It does NOT disable Mud/MR dynamic sink or visual tracks.

`TerrainAbsoluteHeightPlanner.lua` adds a pure no-write model linked to the live RE causal geometry journal's measured `unitM`. Each 0.2m logical rut cell is assigned to a principal-grid vertex. It retains the **greatest cumulative response target**, avoiding artificial accumulation on each game frame; it can also seed its baseline from previously persisted logical rut history, avoiding accounting the entire old rut again. It refuses changes when a logical source ambiguously maps to a different native vertex; this is intentionally conservative, not a declaration that either geometry engine is wrong. Demands stay **volatile in memory** and are not restored or treated as RE-owned physical geometry.

If a verified quantum is supplied, this planner can classify whether accumulated demand is still sub-quantum or reaches a hypothetical single-step threshold; **neither classification writes terrain**. The experimental default is **UNVERIFIED** and makes no assumption from the single GIANTS calibration.

`TerrainAbsoluteVertexCandidate.lua`, a separate pre-existing research alternative to additive brushes, is still **disabled by default**. It proposes one grid-aligned world-space absolute-height target at a time, with:
- existing `TerrainQuantizedHeightBudget`: finite verified quantum, one step, no double-spend, ledger and overshoot quarantine;
- existing `TerrainGeometryJournal`: original-height provenance, footprint vertex locks, pre-submit validation and post-write changed-vertex scan;
- newly mandatory explicit exclusivity gate, checked before and immediately before native invocation;
- native adapter returning boolean `false` is failure, not successful write;
- no spontaneous fallback to ADDITIVE after any native setter or readback failure.

The research-only `TerrainAbsoluteHeightExperimentalBackend.lua` now loads the budget and candidate modules with the RE and provides an actual injectable engine-setter bridge, accepting only a caller-supplied, externally verified quantum, explicit research permission, disposable-save confirmation, an idle local singleplayer writer, and a single-use budget. It passes `terrainNode, x, 0, z, absoluteHeight` to the GIANTS absolute-height setter and reads back affected vertices. Even a successful mock-verified write is marked **untrusted for automatic recovery**. No ordinary gameplay path instantiates this backend or calls `applyOnce` yet.

The unit-tested alternative is **NOT wired into production or mapped to wheel responses**. Merely having an available scripting API cannot prove its multiplayer/save synchronization, collision safety, or visual compatibility. A forced switch without runtime proof would replace a known unstable actuator with an unproven one.

## 2026-10-28 continued audit: overlapping sources and native neighborhood safety

### Prevent a second height-amplification bug

The initial shadow planner **summed** the fresh rut depth from multiple 0.20m logical history cells that map to one 1m main-height vertex. That would make 25 × 2mm = **50mm** of demanded height at one vertex, despite those cells potentially all sampling the same tire pass. This has now been changed to aggregate the **maximum new depth** among sources that map to the same vertex, never the sum of their heights. We still count both total individual source growth and per-vertex height demand separately, with sourceCount metadata, so a later physical footprint model can be validated. This is an intentionally conservative provisional approximation and does NOT prove the physically correct kernel of a rut. The 25-source harness checks 2mm stays 2mm and one growing source can bring the per-vertex demand to 4mm.

The model still never writes the heightmap or changes the persisted RE geometry/journal. Stored pre-existing rut depths are used as a baseline; loading a 24mm cell and observing an unchanged 24mm target creates no new excavation demand. A future tillage/recovery epoch reset still needs design; do not mistake the volatile shadow ledger for recovered soil state.

### Close actuator preflight and collateral holes

- The experimental backend rechecks **singleplayer and mission identity** at the last possible instant before the absolute-height API. A switch to MP after initial authorization aborts, releases the native journal lock, and sends **zero** setter calls.
- The native vertex candidate formerly covered only cardinal neighbors because journal radius `0.30 * unit` plus journal's `0.75 * unit` reach yields `1.05 * unit`. Diagonal neighbors are at `sqrt(2) * unit`, so they escaped. Radius now `0.70 * unit` ensures `1.45 * unit` coverage: **all 9 vertices in the 3×3 neighborhood** are sampled before/after. A changed diagonal invalidates the trial and quarantines subsequent writes.
- A footprint already marked `UNTRUSTED_EDIT` or `EXTERNAL_EDIT` is now rejected **before** the quantized budget accumulates latent damage; otherwise an external landscaping edit could leave a hidden future write.
- Official GIANTS FS25 engine LUADOC confirms the absolute setter signature `setTerrainHeightAtWorldPos(terrainId,x,y,z,height)` and describes `height` as absolute meters; `y` can be zero: https://gdn.giants-software.com/documentation_scripting_fs25.php?category=28&function=816&version=engine. This confirms API *signature*, NOT persistence, MP replication, engine mesh/physics update, resolution or absolute setter fidelity.

Mock suites cover each regression and the Action build parses Lua. **No run against GIANTS C++ terrain for the new setter has happened yet**; automatic rut geometry remains disabled in SHADOW mode and the draft PR must not merge.

## Remaining engineering / validation gates

1. Verify actual FS25 `setTerrainHeightAtWorldPos` availability and exact effect in live gameplay (not only GE/editor), syncer, collisions, persistence across save/reload and true singleplayer/multiplayer semantics. An exposed API name does not prove appropriate ownership/synchronization.
2. Establish each map's **vertical quantum** with independent vertex readbacks, and distinguish the 1m main heightmap from the 0.125m native fine wheel-displacement channel.
3. Decide physical fidelity policy: changing isolated 1m main vertices can introduce large/coarse depressions, so narrow tread detail must remain with native wheel/visual systems. A permanent 1m deformation should correspond to accumulated, significant wheel load, not every tiny slip contact.
4. Bind a proven actuator into the `TerrainDeformationEngine` with strict sample-to-cell lifecycle, periodic budget, ownership, and terrain recovery (tillage, neighbors, municipal work), while proving no overlapping foreign geometry overwrites.
5. Test on disposable save, verify map reload, MP, coexistence with Mud/MR/TF, and regressions before enabling even experimentally outside a controlled command.
6. Keep `main` and RC untouched until the above functional gates pass. PR #64 remains DRAFT.

## Tests

`tests/terrain_absolute_height_planner_harness.lua` covers invalid inputs, unknown map quantum, same-target de-duplication, target growth, logical-source vertex drift, capacity and old-save baselines.

`tests/terrain_absolute_vertex_candidate_harness.lua` covers missing/lost exclusivity, correctly rounded one-step mock setter, neighboring vertex side effect, exaggerated native displacement and explicit setter refusal. All are **mock/Lua tests**, not proof of GIANTS runtime physics.

**Operational policy:** no user test requested at this stage. The branch remains no-write for automatic wheel terrain edits, safe for continuing code development; do not call this a released geometry fix.
