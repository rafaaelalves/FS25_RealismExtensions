# Water in Deep Tire Tracks 0.9.1.5 — exact-source and RC/RE terrain-water audit

**Date:** 2026-10-25. **ZIP:** `FS25_WaterInDeepTireTracks_MrHunter.zip` supplied by user. **Author:** Mr.Hunter. **Status:** source/static analysis and isolated Lua checks only. **Decision: RESEARCH / EXTERNAL-OPTIONAL TEST, NOT ACTIVE STACK; NO RC BRIDGE OR RE PORT AS-IS.** No FS25 runtime, savegame or MP acceptance test; no code changes or builds.

## Provenance

- ZIP SHA-256 `d34a565510dd85e52ee7eb306c3f18a1546f46849443771182e8439f51317b5f`, 4 files, CRC OK.
- `modDesc.xml` = `version 0.9.1.5`, `descVersion 113`, MP supported. One 1,873-line Lua source (`scripts/WaterInDeepTireTracks.lua`), German README, DDS icon. XML parses; source parses with `texlua`.
- [KingMods listing](https://www.kingmods.net/en/fs25/mods/83524/water-in-deep-wheel-tracks) advertises shallow-water interaction, rain/snowmelt, optional RWSM local moisture and client-local visual computation. This listing is not independent verification of GIANTS engine behavior.
- ZIP contains no standalone reuse license; learn from algorithms and interfaces, but do not copy third-party code or DDS/assets into RE absent permission.

## 1. Functional decomposition: what the executable build actually does

**This is a rendering/interaction consumer of existing ground geometry, not a persistent rut creator, terrain volume solver or water-mass hydrodynamics implementation.** Source contains no `TerrainDeformation`, `setTerrainHeightAtWorldPos`, `setAdditiveHeightChangeAmount` or MR/Mud/RE write calls.

1. Enumerate nearby vehicles (up to 800 m from camera) every client frame, including implement/trailer wheels where exposed by `spec_wheels`. For moving wheels, sample an axle raycast, two lateral ground contacts and a min-rut-depth threshold (configured 2.5 cm, precheck actually 60% of it).
2. Activate 6 m tiles in a 5×5 neighborhood (nominal ≥12 m margin) around qualifying points, with 9-point field test for boundary tiles. Allow up to 4,000 tiles.
3. Infer background reference surface per tile-corner as **median of 3×3 height samples** (±0.8 m), cache at tile vertices and build 2 triangles per tile. Draw water planes just below that estimated surface. Actual ground surface occludes triangles except where the ground has a depression. This is a clever raster/geometry presentation method, not an exact water-edge contour or prior pre-rut height map.
4. Use per-4-connected-tile cluster fill fraction. Fill target from moisture (0.10–1.0 linear), rain (+up to 0.30), snowmelt (+0.50); freeze at ≤−1°C stops changing target. Convert fractional fill into depth offset below reference: 25 cm dry, minimum configured 6 cm at maximum fill. Cluster approach approximates visual continuity, not basin volume, spill elevation, infiltration or transport.
5. Create shapes via `createPlaneShapeFrom2DContour` using rice-field water material or optional `FS25_WorldPuddlesBMP` material. Register nearby, **nearly level only** triangle shapes into native `g_currentMission.shallowWaterSimulation`; on-source eligibility is `tri.slope <= 0.01` and distances 70 m enter / 100 m release, max 256 shapes.
6. Client-only player graphics model is offset down toward the bottom of narrow ruts and `PlayerCamera.focusOnPosition` is wrapped to adjust viewpoint. This does not move the player's collision capsule or change vehicle traction.
7. Save client-computed tile / reference vertex / cluster fill data in `waterInDeepTireTracks.xml` via `FSCareerMissionInfo.saveToXMLFile` append; load requires format ≥6. A dedicated server does not run the water simulation; no custom network events.

## 2. Source-inferred issues and precise evidence

### WIT-01 HIGH — moisture/physical-state authority mismatch

`getMoistureAt(x,z)` tries multiple **RWSM** global/environment tables and heuristically matches many method/field names. When no source resolves, `readMoistureAt` falls back to `weather:getGroundWetness()`; **does not read MudSystemPhysics local wetness, RC normalized provider or RE wheel context**. The currently documented target stack takes physical wetness from Mud and feeds RE via RC provider; agronomic RWSM moisture and physical Mud contact wetness are different semantic domains. Consequently visible rut-water levels may not agree with Mud's resistance/sink or RE's rut evolution. This is a contract gap for an optional visual consumer, not justification for another RC moisture owner.

The heuristic `normalizeMoisture(v)` divides values >2 by 100 but accepts 0–2 as fractions, which cannot distinguish a saturation percentage, normalized wetness, or nFK without an audited source schema. Prefer a versioned, provenance/units-labelled adapter to an opt-in provider.

### WIT-02 HIGH — local water bodies are not hydraulically constrained

The 6 m triangulated "water sheet" slopes with terrain; each **connected tile cluster** shares a fill *fraction* but the displayed surface height is the interpolated local reference minus a shared offset. There is no horizontal free-water elevation in a connected closed basin, no priority-flood/lowest spill sill, no water volume, catchment drainage or conservation. This can visually mimic seepage or standing water in ruts on slopes but is not a physical water distribution solver. In fact header lines 6–24 still describe an older 20 cm `Priority-Flood` design; current active flow after line 1138 is a different v4 tiled sheet.

### WIT-03 HIGH — large client-side scene/per-frame work with incomplete budgets

`recordVehicles()` iterates **all vehicles every rendered frame** (distance filters after vehicle enumeration) and their visual wheels; `updateTiles()` loops all live tiles every frame, and `refreshSWS()` loops all tiles/shapes every second. Four thousand 6 m tiles may create up to **8,000 triangle shape objects**; tile builds limited to two per frame, but complete job/render/update budgets are not established. Source has ≥114 config keys, approximately **69 referenced only in the config declaration** (legacy flood/station/survey controls), so advertised `maxRaycastsPerFrame`, `meshStepsPerFrame` and `floodStepsPerFrame` are **not active runtime safeguards**. Do not infer a measured FPS regression; test frame times with tile counts and SWS registration.

### WIT-04 MEDIUM/HIGH — geometry/history provenance and stale activation

`getVertex` caches surface reference heights indefinitely until `witClear`, and `activateAround` marks `activatedCenters` before tiles are tested/allocated; already activated centers never retry automatically. Cultivation, new RE deepening, TerraFarm leveling or changing field boundaries can leave cached reference elevations or activation eligibility stale. Water meshes are occluded by live ground geometry, so some ground changes still change the visible water, but that **does not guarantee** the water target reference or coverage remains correct. Future RE surface-mutation observation/reconciliation should not be implemented solely for this beta.

### WIT-05 MEDIUM — disconnected cluster centroid after merging

`activateTile` merges linked clusters by assigning `c.parent = cluster` and deleting merged entry, but **does not aggregate the merged child's `sx`, `sz` and `n`**. These accumulators are used in `updateFill` to sample moisture at the connected cluster centroid. Isolated Lua experiment: tiles (0,0) and (2,0) are independent; adding (1,0) connects them. Final root cluster metadata reports `sx=3,n=2` → x-centroid 1.5 tiles, whereas actual three tile centers have tile-x centroid 1.0. This is a **tested algorithmic bookkeeping error outside GIANTS**, with unknown gameplay severity. Also `cluster.fill` gets max of former bodies rather than hydrologically mixing volumes, expected for visual heuristic.

### WIT-06 MEDIUM/HIGH — savegame and MP semantics not certified

Update path exits when `getIsClient()` false. The save append writes XML **only if** `WIT.isClient` and initialized; no server authority, client-to-server event, shared activation snapshots or deterministic cluster order synchronization. Dedicated-server save persistence and join-in-progress coherence require actual FS25 testing. This may be acceptable for a *client-local decorative effect* but should not be ported to a mechanical system or described as verified deterministic multiplayer.

### WIT-07 MEDIUM — shallow-water coverage is narrower than marketing

`refreshSWS()` registers only displayed triangles with `slope <= 0.01` within 70 m and at most 256 registered shapes. Thus visually sloping rut water is **not guaranteed** to receive native waves/splash interactions. Source-proven limitation; actual effect/threshold needs game testing.

### WIT-08 MEDIUM — leftover source/command state

`WIT:getFillTarget` is defined twice (line ~566 and again ~1171); the latter active method overrides the former. At moisture 0.30, no rain: later model returns 0.2222 fill (sheet depth ~20.78 cm), whereas first-stage dead model would return 0. `WIT:consoleShader` iterates `self.shapeBase`, initialized but never populated in the shipped source, so the console shader command is **not source-proven to refresh existing shapes** despite changing saved settings. Many `resetState` fields correspond to abandoned models. Should avoid porting dead branches or untested instrumentation as architecture.

### WIT-09 LOW/MEDIUM — visual player offset, not capsule physics

`updatePlayerSink` samples radial support (eight rays), then alters player graphics root and an overwritten camera method. This improves apparent foot placement, but no PlayerCCT/capsule height/contact physics change is implemented; potential visual clipping/camera conflicts with player mods remain an A/B question, not a proven bug.

## 3. Stack crosswalk and ownership

| System | Exact source interaction | Current disposition |
|---|---|---|
| **RE experimental terrain (TerrainResponseModel, TerrainWriter, SpatialHistory)** | WIT reads visible/collision terrain and renders water; **no heightmap writer**. Needs actual deep ruts; main RE has TerrainDeformation disabled. Overlay can remain independent. Cached tile baseline may become stale after RE terrain edits. | Keep RE as rut geometry owner. Future optional water presentation consumes RE/RC measurements. No absorption now. |
| **RC state provider and MudSystemPhysics** | RC resolves wheel wetness/slip/sink; WIT independently falls back to vanilla global wetness (unless RWSM). | Important semantic mismatch. Evaluate narrow versioned **read-only** wetness provider if standalone beta is ever tested with stack; no speculative global RC hook. |
| **MR / Reifen / RMS / PTO / HSS** | WIT doesn't patch wheel friction, tire radius, load, drivetrain or PTO. Only read-only wheel sampling and visual/camera changes. | No demonstrated direct physics collision; performance, track reconstruction and player-camera composition remain runtime gates. |
| **SoilCompaction / RWSM** | SoilCompaction agronomic compaction and RWSM water-management moisture differ from Mud physical wetness; WIT optionally probes RWSM heuristically. | Explicit units/domain/schema contract required; no automatic "moisture percentage" equivalence. |
| **TerraFarm / native landscaping** | Another terrain writer may shift height relative to WIT's stale cached vertex baselines. | Cross-writer provenance is the same research opportunity raised by Auto Leveler. |
| **MapFlood (exact provided ZIP inspected only superficially here)** | Also from Mr.Hunter and uses rice-field material and `shallowWaterSimulation` water planes; WIT makes no direct MapFlood source dependency. | Potential shared rendering/SWS capacity/overlap, but **requires separate full MapFlood audit**. Do not infer proven mutual compatibility or incompatibility. |
| **WorldPuddlesBMP** | Optional material load from `i3d/waterPlane1.i3d`. | Asset provenance and loaded lifetime should be confirmed before relying on this fallback. |

## 4. Useful RE design opportunities (separate from adoption)

**A. Overlay/WaterInRuts presentation prototype, after terrain V3 recovery validation:** A generic RE-owned `RutSurfaceWater` *candidate* may consume a documented rut-depth/reference/elevation surface and physical wetness from RC/Mud. Preserve a separate provenance/epoch for deforming terrain and no second traction/wetness model. The water shape should be a rendering layer, not necessarily a physical new gameplay subsystem. Prefer native materials and SWS if measured safe and if license permits.

**B. Better terrain-reference validation:** The mod's 3×3-median at 6 m vertex is a cheap *local terrain estimate*, not RE's pre-rut reference. Include asymmetric berms, steep slope, overlapping furrows and hills in reference-surface fixtures; do not adopt its median as a reconstruction truth.

**C. Hydrology upgrade only with real evidence:** For actual water accumulation and drainage, represent connected depressions, spill saddles, controlled water-budget conservation, infiltration and topographic slope; align with planned MapFlood source audit before defining one owner. Standing water in a basin should be level rather than one sheet perfectly following the hillside.

**D. Performance/lifecycle lessons:** geometry tiles, SWS radius hysteresis and rebuilding only selected tiles are useful patterns. The production design must additionally cap visible meshes, rays, scan cadence, tasks and save data, and release/restore resources properly on map exit or server migration.

## 5. Source checks (outside GIANTS)

- Integrity: 4 entries, ZIP CRC OK; Lua parse PASS; metadata matches external beta 0.9.1.5.
- `texlua` harness with only `addModEventListener` stub:
  - moisture 0.10 → fill 0, water baseline 25 cm below reference;
  - moisture 0.30 → fill 0.22222, ~20.78 cm below reference;
  - moisture 1.0 → fill 1, ~6 cm below reference;
  - temperature −2°C → target nil, reason frozen;
  - forced adjacent cluster test exposed incorrect centroid stats (`sx=3, n=2` for three tile positions).
- Source grep confirms **0 terrain writer calls** and **0 RC/Mud wetness provider calls**, while `addWaterPlane` and `raycastClosest` paths exist. Isolated tests do not certify GIANTS callback contracts, physics engine visuals, MP or savegame.

## 6. Suggested decision/testing gates

**Current disposition:** no full absorption; not necessary to add to primary stack to study it. For optional disposable-save A/B (not mandatory before continuing other audits):

1. Start with known physical ruts in isolated RE terrain experiment; compare WIT disabled/enabled at constant terrain geometry and native weather. Main RE default disabled cannot alone validate WIT overlay.
2. Compare 0.30/0.60/0.90 **Mud local wetness** vs WIT's actual chosen vanilla/RWSM source at same (x,z). Do not manipulate weather to force a match without tracing domains.
3. Test three cases: modest rut/berm, steep field with intermittent sws activity, rut recovered by plow/cultivator or re-shaped by terrain modification; check stale vertex reference and border gaps.
4. Record tile count, created meshes, SWS active shapes, 800 m vehicle sweep cost, repeated map reload and actual SWS interactions.
5. Optional MP: dedicated server + two clients, save, reload and join-in-progress; visual divergence may be acceptable as presentation but must be called out.
6. Test with **MapFlood separately** only after its exact source review, especially overlapping surface mesh and water-plane resource allocation.

**Engineering action:** **documentation only**; no runtime code, no RC bridge, no ZIP/build, no active mod/version gates. Keep the existing terrain recovery blocker highest priority; this audit supplies research and future integration tests, not new production scope.

## 7. Decision refinement — **approved for controlled experimental-stack trial** (2026-10-25)

The source-only **NOT ACTIVE IN PRIMARY STACK** decision is not a prohibition on trying the mod. After comparing the two water mods and the user's aim to learn through real gameplay, this audit now **recommends testing the unmodified Water in Deep Tire Tracks 0.9.1.5 ZIP as a provisional visual consumer of the RE experimental rut build**, on a cloned save. No RC bridge, code port, physics ownership change or production compatibility claim is implied. The original source limitations above remain open.

**First A/B gate:** Use exactly the same game save/build and a known real RE rut before and after enabling WIT; retain RC/Mud. Record gameplay screenshots, frame time and logs, WIT tile/SWS stats when available, wetness source and observed rut geometry. Inspect dry versus rain and after plow recovery; test with MapFlood absent. If the water looks plausible and no overlapping resource or performance problems appear, keep WIT as a *provisional optional experiment* for further play and targeted validation. On real geometry shifts, use available `witClear` only as a manual diagnostic, not a proven permanent cache-fix. No requirement to complete all RE terrain architecture work before conducting this trial.

**Potential future replacement:** A clean-room `RutSurfaceWater` renderer/subsystem consuming normalized terrain and wetness with provenance, distinct from a new soil moisture/traction solver; consider only after visual value, costs and geometry contracts are measured. Until then, external ownership is a valid positive outcome.
