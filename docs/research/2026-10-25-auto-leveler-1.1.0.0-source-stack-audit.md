# Auto Leveler 1.1.0.0 — exact-ZIP, terrain-writer and RC/RE architectural audit

**Audit date:** 2026-10-25. **Owner:** JogaDim. **Input:** user-supplied `FS25_AutoLeveler.zip`. **Intent:** study as a source of ideas, not an adoption request. **Verdict:** **RESEARCH ONLY / NO PRIMARY-STACK INSTALLATION / NO RC BRIDGE / NO RE PORT AS-IS**. Source inspection, static checks and isolated Lua experiments; **no FS25 in-game, MP or savegame test**. Documentation only; **no build or runtime code changes**.

## 1. Reproducible provenance and inventory

- `modDesc.xml`: `version=1.1.0.0`, `author=JogaDim`, `descVersion=114`, `multiplayer supported=true`. The final script's console print unexpectedly claims `v1.2.0.6` (line 1810); **the manifest, not the debug print, is the supplied package version**.
- SHA-256: `89e88b58c01d84df6885991b6cccfd15a086ab184bfb69b1a462ae4622d15d79`, **122,428 bytes**, **four ZIP entries**: `modDesc.xml`, `icon_AutoLeveler.dds`, folder `src/`, one executable `src/AutoLeveler.lua` (~1,813 lines). ZIP CRC passes; XML strict-parses; Lua source passes `texlua --luaonly` `loadfile` parse. The script is the one declared `extraSourceFiles` item.
- No reuse license accompanies the four entries. Source availability for inspection does **not** grant permission to copy Lua, assets, artwork or translations into RE.
- Public ModHub [official listing](https://www.farming-simulator.com/mod.php?mod_id=375360) and [KingMods 1.1 changelog](https://www.kingmods.net/en/fs25/mods/82575/auto-leveler-landscaping-terraformer-slopes-roads) describe flat polygons, ramps, and new curved-road mode. Listings identify releases, **not exact ZIP SHA**.

## 2. Capability and data-flow inventory

**Not a soil mechanics/erosion simulation.** It is an interactive *terrain authoring/construction tool*. The operator creates geometry and confirms an immediate world mutation.

- **Planar sites:** an XZ polygon (raycast-picked cursor points, orthogonal/45° snap, point editing), fixed elevation from the first control point or Up/Down. `calculateArea` uses a signed-area/shoelace variant, `pointInPolygon` uses ray-crossing, `distToPolygonBoundary` measures shortest segment distance.
- **Ramps:** two points, extruded width 2–30 m, target elevation linearly interpolated along centerline projection, rectangle-like polygon and adjustable endpoint heights. HUD reports nominal slope, not earthworks grade constraints.
- **Dirt roads (added in 1.1):** 2+ control points, chord-length-parameterized Catmull–Rom XZ interpolation, re-sampling at 1 m increments, local tangents/perpendiculars, 3-point lateral terrain-height average, bounded nine-sample moving mean, ribbon sampling at 0.5 m, dirt/gravel/asphalt paint-layer fallback and crop/field/stones clearing. Width 3–8 m.
- **Presentation:** debug-line points/posts, planar target grid/edges, road center/edges, single HUD with length/area and simple cost. Geometry preview is separated from `executeLeveling`. Road preview renders **the existing terrain elevations**, not the smoothed proposed road heights (lines 1262–1287 versus 970–1004).
- **Execution:** direct synchronous `setTerrainHeightAtWorldPos` for flat/ramp/road positions; `TerrainDeformation.new(...):addArea(...):applyDeformation(false)` is used to **paint road texture**, not to write the road heights. No volume-of-earth calculation or staged excavation.
- **Mutation side effects:** repeated `FSDensityMapUtil` removal of field, crop, weed, stone, tire track/decorations; site mode additionally uses `DensityMapHeightUtil.clearArea`; collision-map refresh; road mode also calls `aiSystem:setAreaDirty`. Farm balance is checked and a formula-priced debit is applied **after** physical changes; no earthmoving material inventory.

## 3. Exact source mechanics and important findings

### Useful patterns

1. **Declarative spatial plan vs world writer.** A polygon/polyline target, preview and explicit commit are useful *ideas* for future RE/RoadCraft-style earthworks; keep project controls, target surface and execution separate.
2. **Geometry toolkit.** Arc-length re-sampling, per-point normal/perpendicular, point-in-polygon, distance-to-boundary, smoothstep blend and basic grade estimation are accessible computational patterns to independently implement and test. Curved-road path quality needs additional curvature, intersection and width-validation constraints.
3. **Read-before-write terrain sample.** Sampling center+two road edges before road edits is conceptually preferable to sampling height after mutations. It is **not** an original un-rutted reference surface and should not be imported into RE's pre-deformation reconstruction.
4. **Operator-focused instrumentation.** Preview grid, corner controls, snap guides and area/length/cost feedback are meaningful UI lessons for a future engineering mode, without adopting its render loop or aesthetics.

### Source-visible design defects / evidence limits

**AL-01 HIGH — competing heightmap ownership; RE stale rut history.** Flat/ramp/road modes call `setTerrainHeightAtWorldPos` directly (lines 875–877, 1003, 1167, 1175). RE `SpatialHistory` stores independent rut/shear exposure and `TerrainPersistence` persists/checks surface-height samples; the external writer does not negotiate RE state or restore pristine-reference provenance. On the same cells, an intentional Auto Leveler construction cut/fill may leave the RE cell history describing a different surface. This is a **source-confirmed missing protocol**, not a reproduced FS25 corruption. RC should **not** add a generic heightmap-hook shim without a demonstrated active integration case. A future RE-owned world-mutation invalidation/reconciliation contract may be valuable even without Auto Leveler installed (e.g., TerraFarm and vanilla landscaping).

**AL-02 HIGH — non-transactional, synchronous large edits.** The 0.5 m site raster runs in a nested loop with repeated polygon/boundary checks, native height queries/sets and at each inside point *six* potentially expensive FSDensityMap/height-util operations (lines 1157–1181, 882–912). A 200 m square has ~160,801 candidate positions and ~643,204 point-in-polygon vertex comparisons before clears. Road ribbon writes multiple overlapping cells for each 0.5 m longitudinal and transverse step. No queue, frame budget, cancel/undo, bounded terrain transaction, preflight of cut/fill or rollback on partial failure. This is an **architectural performance/correctness risk**, not measured frame-time.

**AL-03 HIGH — server authority, ownership, MP not established.** The manifest advertises MP; the sole Lua file contains no `g_server`/`g_client` gate, event definition, user/farm ownership/land-permission check or explicit authoritative terrain command. UI callbacks directly invoke world writes and farm money APIs (lines 917–1207, 1780–1809). Whether GIANTS native APIs replicate these changes implicitly requires FS25 MP testing; **do not claim proven client desynchronization**. Never reuse this execution protocol in RE.

**AL-04 MEDIUM — road heights are editable but ignored by the output profile.** `adjustHeight` changes selected `points[i].y` in ROAD mode (lines 665–675), whereas `sampleRoadCenterline` carries only XZ/s, and `computeRoadProfile` receives the *current terrain heightFn* (970–972, 186–209). Isolated Lua harness: with user point heights 0/20/200 and constant terrain 10, all computed road sample heights remain 10. Need deliberate grade control source if developing a road planner.

**AL-05 MEDIUM — invalid topology accepted.** `calculateArea` may return zero for self-crossing bowtie polygon, while `pointInPolygon` returns inside for subregions, making the minimum-priced flattening geometry possible. Isolated Lua harness confirms bowtie area `0` and nonempty inside-test. No preflight for segment intersection, repeated/degenerate points, out-of-map bounds, touching owned land, collision with objects or max cut/fill angle.

**AL-06 MEDIUM — economic model is disconnected from volume.** Site/ramp charge is max(50, floor(area * 2.5)); road is max(50, floor(length * width * 1.5)). There is no distinction between cutting 0.1 m vs 5 m; no cut/fill volume estimate, storage, haulage, replacement materials, scheduled construction or equipment. Useful as light-gameplay ergonomics, not a mechanical blueprint for RE.

**AL-07 MEDIUM — road edge geometry and render differ from write.** The preview uses *unmodified* source elevations at road boundaries (lines 1256–1288); source writer interpolates tangents (`s1.px` to `s2.px`) without explicit re-normalization (lines 994–1003), which can narrow the apparent half-width around sharp bends. Height smoothing has fixed 4 m neighborhood, no grade limit/vertical curve control or drainage/crossfall. Values represent a drawing heuristic, not surveyed earthwork design.

**AL-08 MEDIUM — destructive density effects / incomplete mutation completion signaling.** Flat/ramp mode clears vegetation/field and density-map-height data per interior lattice point; road mode clears crops/fields/stones and paints over the new road. Side effects include deletion of agricultural state and potentially heap/height-layer information (exact density-height semantics still require GIANTS verification). Road code marks AI dirty; site/ramp only explicitly refreshes collision map. No recovery metadata or old-state snapshots.

**AL-09 LOW/MEDIUM — global ConstructionScreen/Input hooks and lifetime.** `init` installs multiple prepended/appended/overwritten class-level hooks and one overwritten `ConstructionBrushSelect`/`ConstructionBrushTerraform` primary action (lines 1780–1809). The mod's `removeBrushActionEvents` and `updateActionTexts` callbacks are no-ops (872–873), while registration appends a custom set to `self.brushEvents`. Base-game removal may still clean those events; hook-call order and duplicate registration require runtime observation. Construction/menu/contract/UI mods may touch the same functions; **not a proven collision**.

**AL-10 LOW — source provenance warning.** `modDesc.xml` states `1.1.0.0`, but init prints 'Carregado v1.2.0.6' (1810). Not grounds to relabel the package or claim compromise; illustrates why logs alone are not a source-version authority.

### Isolated executable checks (outside GIANTS)

- ZIP CRC and XML/Lua parse PASS.
- Straight 10 m line: 11 samples, last arc-length 10 m.
- Road points have modified Y while constant terrain is 10 m: output Y remains 10 m (height-control omission).
- Bowtie polygon points (0,0), (10,10), (0,10), (10,0): signed area is zero while point-in-polygon contains (2,2).
- Mocked source `executeLeveling` with injected terrain-write failure on fourth call: 3 direct writes were executed before exception; no transactional rollback; charge did not occur. This is an **isolated control-flow proof**, not a FS25 runtime claim.
- Full 200 × 200 m site at 0.5 m sample step: ~160,801 candidate samples (computed count, no benchmark).
- No reliable evidence of savegame, real-time physics, dedicated MP synchronization or native engine job success. No in-game verification completed.

## 4. Cross-stack ownership and interaction

| Capability / participant | Source-level interaction | Decision |
| --- | --- | --- |
| **RE TerrainDeformation / SpatialHistory / TerrainPersistence** | External persistent heightmap cuts/fills while RE maintains independently versioned rut exposure, surface-height sanity snapshots and native brush queue | **Main concern**: future generic mutation-history reconciliation; no speculative immediate code. |
| **TerraFarm / mining & earthworks** | Similar world terrain modification but different excavation/material/equipment ownership | Keep TerraFarm specialist; explore a common surface-change notification/provenance concept before any RE construction authoring. Do not conflate leveler instant cuts with actual excavated soil mass. |
| **GIANTS Landscaping/ConstructionScreen** | Same construction menus/mouse/brush/hotkeys and terrain space | Potential hook conflicts and authoring permissions; isolated UI/game test if installed, not a reason for an RC bridge now. |
| **Courseplay / native AI** | Road invokes AI area-dirty and collision-map updates; other modes only collision map. Road geometry may alter planned paths | Future tests for navigation replan and surface access; no direct Courseplay adapter justified. |
| **FarmKit / SoilCompaction / Precision Farming** | Deletes/rewrites field, fruit and stone density layers; does not operate on compaction/agronomic model contract | Avoid accidental crop/soil-domain erasure; distinguish construction from tillage recovery. |
| **MR / Mud / Reifen / RMS / PTO / HSS** | No WheelPhysics friction/radius/spring/gear/PTO hook in supplied source | No source-evident direct drivetrain/suspension overlap. Indirect mobility changes from edited geometry are expected. |
| **RC 0.2.0.9** | No current Auto Leveler bridge, version gate or risk rule; broad ConstructionScreen hooks are outside current RC role | Leave RC unchanged; support only if a concrete, enabled pair has a reproduced conflict. |

Relevant documents: [RE ownership](../project/OWNERSHIP.md), [RE TerrainWriter](../../scripts/terrain/TerrainWriter.lua), [RE SpatialHistory](../../scripts/terrain/SpatialHistory.lua), [RE terrain persistence](../../scripts/terrain/TerrainPersistence.lua), RC [TerraFarm source audit](https://github.com/rafaaelalves/FS25_RealismCompatibility/blob/main/docs/audits/2026-10-02-terrafarm-full-stack-audit.md) and RC [change policy](https://github.com/rafaaelalves/FS25_RealismCompatibility/blob/main/docs/project/WORKFLOW.md).

## 5. Useful clean-room research roadmap (NOT implementation approval)

### A — Highest-value, cross-cutting RE safety: world surface mutation provenance

**Hypothesis:** independent terrain writers (RE rut geometry, external landscaping, TerraFarm, future mining/road construction) need a source-labeled notion of *external world geometry change*.

1. First inspect GIANTS native terrain operation callbacks and exact `RE TerrainWriter`/`TerrainPersistence` behavior; test same-cell construction edits with rut memory on a backup map and reload. Do not presume all external height changes invalidate an entire region or that native brush completion means the same thing as direct setter calls.
2. Propose a small **read-only terrain mutation epoch/bounds/provenance observation** or an RE-owned reconciliation hook; distinguish a planned engineered surface from an old virgin/pre-rut reference. Preserve prior history where non-overlapping; invalidate/rebase only affected provenance.
3. Require terrain-authority and budget evidence before altering RE code; avoid blanket hooking `setTerrainHeightAtWorldPos` or a second terrain writer/physics model inside RC.
4. Investigate route/AI dirty-region updates on actual successful height mutation.

### B — Future earthworks editor, if separately prioritized

Build independently as `PlanGeometry -> TerrainSnapshot -> SurfaceTarget -> ConstraintValidation -> CutFillBudget -> Preview -> AuthorizedJob -> TerrainCommit -> HistoryNotification`. Use:
- validated simple polygons and resampled polylines; explicitly bounded curvature, width, slope/crossfall/longitudinal grade;
- terrain height **snapshot pre-commit**, no recursive read-after-write contour bias;
- cut/fill m³ and material/storage/haulage rules rather than instant area-only deductions;
- server-owned requests, farm/land validation, geometry/volume bounds, save and MP contracts;
- chunked native TerrainDeformation operations, collision/AI dirty regions, rollback or recoverable checkpoints, explicit provenance.
- Preview **target** geometry and cost using the same plan evaluation used by commit; never allow drawing logic to diverge from execution.

This is a candidate for a **separate future infrastructure/construction module**, not permission to extend the current experimental RE rut branch before its soil-recovery acceptance gates.

### C — Test suite ideas derived from this source

- Bowtie, hole/concave/self-touching polygon and winding invariance.
- Straight, S-bend, hairpin, zero-length control points, tight curvature and width consistency.
- Height-control application and preview–commit numerical parity, ramp grade and drainage thresholds.
- Large bounded work budgets and cancellation mid-commit.
- Pre-rutted/reference changes, save/reload, TerraFarm pit and old-save reference provenance.
- Construction land rights/farm debit, two client simultaneous edits, denied commits, AI navigation refresh.
- Crop/field/heap density effects explicitly scoped to construction, not routine tillage.

## 6. Decision and closure

**KEEP AS STUDY**, not as active stack dependency; **FUNCTIONAL ABSORPTION = NOT APPROVED**. The most valuable architectural lesson is **planning a target surface separately from mutating the heightmap**; the most valuable RC/RE interaction is **cross-writer terrain provenance and history reconciliation**. In particular, **do not** port synchronous world writes, crop destruction, point-by-point UI draw calculations, flat area-only charge, or unverified MP/authorization model.

**Changes made by this audit:** documentation-only. No RC or RE runtime modifications, no build ZIP, no new version allowlist, no recommendation to activate Auto Leveler in the current playthrough.
