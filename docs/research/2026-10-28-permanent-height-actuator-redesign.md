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

## 2026-10-28 continued implementation: shadow-demand lifecycle after tillage

The 1m principal-height shadow ledger must evolve with **real accepted recovery**, not only with wheel loading. This work adds:

- A reversible `unappliedDemandM` per logical 0.20m source, while each 1m vertex keeps the **maximum** (not sum) of its constituent sources. A source's first observation seeds from its actual existing SpatialHistory depth, avoiding duplicate damage after load.
- `Planner:onHistoryRecovered(sourceKey,remainingRutM,appliedM)`, which decreases only the affected source's outstanding *shadow demand* by at most the confirmed logical-history reduction, then recomputes the vertex's maximum from remaining active sources. An unverified falling wheel-response target **cannot** silently clear the ledger.
- An optional `SpatialHistory.onRecovery` observer emitted only **after** successful `applyRecoveryAt`, `applyRecoveryCircle` and `recoverParallelogram` mutations. The runtime connects that callback to the current map's shadow planner. A callback exception is caught and counted by `recoveryObserverFaults` so diagnostic code cannot interrupt legitimate tillage or change its return value.
- Capacity control: zero-demand/unchanged wheel targets do not allocate shadow sources. Fully settled demand frees its source and empty vertex even following a **partial** repair of a pre-existing legacy rut. Future wheel traffic creates a fresh epoch using the actual remaining history depth rather than a permanently stale maximum.
- New integration tests with the REAL `SpatialHistory` Lua implementation (still **not** GIANTS C++) exercise partial point recovery, circular recovery, tillage/parallelogram recovery, two concurrent sources sharing one native vertex, new demand after tillage, failing observers, churn through 30 recovered epochs, and partial restoration of previously persisted ruts.

Crucial safety boundary: these are **logical-history notifications only**, not evidence that GIANTS repaired main or fine displacement geometry. The `SHADOW` profile still blocks all automatic RE native height writes; the planner's in-memory debt must never be passed to a setter before map-specific vertical quantum and physical synchronization are independently verified. In particular, a future calibrated permanent writer must reconcile proven native height changes with the same journal and must **not** grant recovery ownership from this shadow counter.

## 2026-10-28 further development: virtual model exposure and worked-area reset

### The missing feedback loop was real

With `TerrainPermanentActuator="SHADOW"`, `TerrainDeformationEngine.processSample` returned before `SpatialHistory:commit`, correctly avoiding fake persistent rut ownership. However, `TerrainResponseModel.compute` uses the previous history's `deformationExposure`, shear distance and slip-excavation distance to advance over successive contact passes. Reading only the real persisted history on each call therefore recreated near-first-pass behavior and prevented convergence of the predicted model.

**Now** `TerrainAbsoluteHeightPlanner` holds a volatile per-logical-source `modelHistory` with selected scalar model fields (rut depth, exposure, longitudinal/lateral shear distance, slip-excavation distance and pass count). On a SHADOW wheel contact, `TerrainDeformationEngine` reads a *copy* of that virtual history, invokes the unchanged response model, and feeds its `nextHistory` back into the shadow. The physical `SpatialHistory` remains untouched until a real, independently verified actuator response exists. This is NOT committed to saves and is not treated as geometric provenance.

Importantly, the model's possible rut target (bounded here to 1.0m for virtual validation) is **not** the maximum permitted geometry lowering (the separate demand budget still caps at 0.10m). A real model target beyond 10cm must not be silently discarded merely because the RE persistent writer is constrained to 10cm.

### Containing stale memories across work areas

The existing logical-history recovery event still clears the shadow's prior exposure after confirmed logical repair. But SHADOW's predictions may exist without a single native or persisted RE rut. Physical tillage can therefore leave no logical-history cell to reconcile. `TerrainRecovery.recoverWorkedArea` now calls the planner's `onWorkedArea` after a **GIANTS-verified physically working + processedArea>0** work-area callback. Only the planner's **volatile** per-source model state/demand inside the actual parallelogram is removed; no height setter, saved history, recovery ownership or first-touch journal field changes. The calculation checks the rotated basis (not a bounding-box approximation), includes a half-0.20m-cell interior clearance and refuses unbounded work-area scans (default 4096 principal vertices). A rejected/nonworking implement cannot clear model exposure.

### Verification coverage

- `terrain_shadow_model_progression_harness.lua` uses the actual pure `TerrainResponseModel` over 10 sequential wheel passes; depth and exposure increase from a previous virtual state, while 10 calls with nil persisted history would otherwise repeat the first prediction. Copy isolation and recovery invalidation are asserted.
- `terrain_absolute_height_workarea_harness.lua` checks polygon-only virtual retirement, conservative border exclusion, rotated work-area shape, virtual memory reset and large-area refusal.
- The existing `terrain_recovery_harness.lua` verifies that only a physically processed GIANTS work-area **mock** calls the shadow observer; an idle/rejected work-area is ignored.
- `TerrainAbsoluteHeightPlanner:summary()` now differentiates virtual model reads/writes, work-area resets and pending coarse-vertex demand. No native-write claims are made.

**Boundary:** Passing these pure Lua / mocked GIANTS callbacks cannot prove wheel-track physics, absolute setter fidelity, map persistence, collision synchronization, or multiplayer. The `SHADOW` config still blocks all automatic native wheel and recovery writes. A single disposable-save absolute-height API test remains required later, before any physical actuator promotion. This iteration does **not** require repeating an agricultural play cycle now.

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
