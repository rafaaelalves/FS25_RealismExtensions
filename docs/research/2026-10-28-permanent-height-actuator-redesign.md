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

The unit-tested alternative is NOT wired into production or mapped to the wheel response yet. A forced switch without runtime proof would merely exchange a known unstable actuator for an unproven one.

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
