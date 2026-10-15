# Terrain reconstruction V3 — source-backed diagnosis, best-path design and isolated instrumentation

**Date:** 2026-10-15  
**Target:** FS25 RealismExtensions experimental R1/R7 terrain+PTO integration tested in `log(20261015-010719).txt`, exact base commit `14ebb9c961a4437153148ab632fc29edffbd057c`.  
**Research branch:** `research/terrain-predeform-reference-v3-2026-10-15`. **This branch is NOT a validated physical recovery build**. All new pre-deformation height references are **observational only**.

## 1. What is proven versus inferred

**Observed in the user's gameplay log:**
- Four tillage passes were `CULTIVATOR/SHALLOW_DISC`, not `PLOW`. `workAreaCalls=2892`, `worked=2891`, `intentMaxRut=0.010m`.
- 1,179 structural attempts scheduled, only 73 native TARGET operations applied; of these 58 center no-ops, 12 improvements, one deterioration and two center-target results. `targetPlaneCompleted=3`, 3 historical cells reconciled; max reference-relative residual ~0.1245m unchanged.
- 25,780 reference V2 evaluations rejected, 74 accepted. All failures labeled `CURVED_OR_INCONSISTENT`, **not independent locations**. The code rejects when the fitted inner-ring and outer-ring plane intercepts differ by more than 0.035m.
- 18,666 intentional terrain-rut suppressions during active cultivation. The recorded new rut-author is exclusively S780 (435 -> 456 across the tillage window). The tractor itself is **not** implicated as an RE height-writer by this log.
- At 22:04:08 the last successful save preceded the tillage passes. Do not infer the final experimental geometry survived exit.
- The period-driven TerrainMaintenance ran early in the session, separately from tillage. It did not coincide with the four tillage passes but must share a future write-ownership contract.

**Source-derived facts:**
- `RecoveryReferenceV2` fits planar regressions to clean-ish *post-deformation* samples in two rings and compares center intercepts. Curved natural grade or corrupted ring selection can legitimately disagree; raising the threshold indiscriminately would re-enable earlier dangerous mounding.
- `TerrainWriter` uses GIANTS set deformation with a sub-meter `TARGET` soft-circle brush (the SHALLOW_DISC profile uses 0.45m radius, 0.18 hardness, 0.30 strength). Some calls complete with unchanged interpolated center height.
- The engine reports heightmap resolution 4096 in this session, **but the actual world-space grid spacing is not logged in the old build**. Thus insufficient vertex coverage / brush falloff is a testable hypothesis, *not a confirmed root cause*. The research build logs `getTerrainHeightmapUnitSize`.
- `SpatialHistory` has a 0.2m logical cell grid; this is *not* necessarily the GIANTS heightmap vertex spacing. `rutDepthM` stores accumulated simulation demand/accepted brushes and is not a verified true surface-elevation deficit.
- `TerrainPersistence` already writes `#surfaceHeightM` **at save time** only to validate that GIANTS geometry and the sidecar loaded consistently. This value is emphatically **NOT the original un-rutted height** and must never be used as a restoration target.
- `SoilMassTransport=false` in the tested config, so an exact material-conservation promise is not supportable from the current active system.
- For comparison, TerraFarm uses GIANTS `setHeightTarget`, `enableSetDeformationMode`, additive intensity and `addSoftCircleBrush(...,-1)`. Matching that API shape does **not** prove matching geometry outcomes with a smaller RE brush. TerraFarm's default flatten/slope strength and full work-area point selection differ.
- The user's tillage's `SHALLOW_DISC` classification follows GIANTS cultivator specialization with `spec_cultivator.useDeepMode == false`. A `PLOW` profile cannot be claimed validated here.

## 2. Decision: hybrid, ownership-safe and heightmap-aware reconstruction

### Track A — newly formed RE ruts: exact historical reference, not retrofitted plane guessing

For **new** rut geometry only, record an immutable *candidate* terrain-height reference **before** the first RE lowering command affecting an appropriate spatial cell. The active research commit captures the pre-write height at the 0.2m `SpatialHistory` snapped cell and keeps it through snapshot/save/reload. It never uses that anchor to change heights.

Why only candidate? Because overlapping brushes and delayed engine callbacks may already have changed a nearby vertex before a new spatial cell is observed; external TerraFarm edits also invalidate a stored target. This must be checked against exact heightmap vertex sampling, native job chronology and unload/reload geometry before promoting a height to authoritative.

The proposed next step is a **sparse native-heightmap vertex anchor cache**, keyed by GIANTS terrain-unit coordinates, with:
- first-touch geometry samples taken before writes that could affect each vertex, preferably over the *entire native brush footprint*;
- owner provenance (`RE_LOWER` only), capture timestamp/geometry epoch, post-apply correspondence, and explicit invalid/unknown state;
- no synthetic anchors for old/legacy history; no `originalHeight = currentHeight + rutDepth`;
- bounded retention/LRU (separate from 0.2m mechanical debt grid), compact optional persistence, versioned format and geometry identity check;
- invalidation when the local heightmap differs for unaccounted reasons; preserve intentional edits made using TerraFarm or construction tools rather than undoing them;
- interpolation to shape the local pre-rut terrain surface without forcing a global planar grade on curved maps.

### Track B — legacy rut surfaces: conservative multi-scale estimator or explicit non-action

For old 29k-history-cell saves where no first-touch reference exists, use multi-radius *robust* local surface estimation only in patches where clean support and uncertainty justify it. A curvature-aware (quadratic in local x/z, with robust fitting and angular coverage) estimator is a candidate to test against synthetic slopes, ramps, crowned roads, concave field bowls, parallel ruts and rut+berm profiles. A fitted quadratic **by itself is not proof of the original height**, because disturbed samples can yield an entirely plausible curve. Reject areas with contaminated support, conflicting gradients or uncertain original topography. Failing safely is better than making mounds. Do not globally relax the 3.5cm test.

If a safe reference does not exist, an explicitly bounded *finish/smoothing* action may be acceptable agronomically, but must never be labeled an exact historical restoration.

### Track C — actual GIANTS actuation: mesh-calibrated, closed-loop, measured

Separate finding a valid **target** from successfully **moving** the native heightmap:
1. Measure `getTerrainHeightmapUnitSize(terrain)` and grid alignment at the exact work location.
2. On a **disposable save and precisely isolated patch**, A/B a fixed target with 0.45m current radius vs broader radius relative to the terrain unit; compare 0.30 strength to stronger but bounded settings **one variable at a time**. Include on-lattice and half-lattice positions and differing slope. Do not assume low callback error implies success.
3. Sample center **and native heightmap vertices/patch** before/after. An unchanged interpolated center can miss vertex movement elsewhere; an altered interpolated center can reflect neighboring movement. Record job state, local delta min/max, moved vertices and displaced volume.
4. A successful actuator must respect an explicit per-step displacement budget and an aggregate error cap derived from a **verified** target. Never retry a native no-op by turning into unbounded additive `RAISE` (historically produced 22–84cm mounds).
5. Make geometry changes server-owned, serialized and bounded, and confirm client/save reload. If GIANTS TARGET can only move coarse vertex increments, the algorithm must converge to a tolerance informed by actual mesh resolution.

### Track D — agronomic realism, not indiscriminate leveling

Keep the domain split:
- `PLOW`: turnover/rough primary tillage, closes/reworks some existing wheel grooves but can leave a rough furrowed surface. It must **not** turn any slope into a plane or claim a perfectly prepared seedbed.
- `SHALLOW_DISC`/`CULTIVATOR`: moderate rut reduction and seedbed surface finish, capacity depends on tool geometry, soil moisture and rut magnitude.
- `POWER_HARROW`: strong finishing of small-scale roughness, not arbitrary deep-rut filling.
- `SUBSOILER`: primarily subsurface compaction relief and shallow localized disturbance, *not* strong visible rut levelling.
- `PLOW_PACKER`: primary tillage + partial immediate surface consolidation.

Retain Mud ownership of wetness, traction and transient sink; SoilCompaction owns deep agronomic compaction; RE owns only its own persistent rut **geometry**; RC remains normalized state/provider, not a recovery hotfix bag. Tractor/implement rut suppression during physical work is retained, and only independent verified writers may add new ruts.

### Track E — work scheduler and CPU costs

The old log reports ~25.8k rejected references vs 74 accepted, repeated within a few minutes. Before broadening the estimator:
- Add measured rejection **drift statistics** (implemented in this research branch) and count unique rejected spatial keys separately from repeat attempts.
- Instrument native heightmap reads, V2 mesh-unit-alignment and cost of the *deferred retry loop*, which may be omitted from the `TerrainPerf recovery=969.4ms` figure.
- Add short TTL/negative caching for identical rejected keys, invalidated on localized geometry/history epochs, to stop wasting ~33 heightmap probes plus debt-neighborhood scans per failed attempt. Avoid indefinite suppression: changing soil must allow re-evaluation.
- Maintain one active terrain geometry owner/serialized job queue across tillage recovery and period-driven TerrainMaintenance.
- Enforce generation/recovery balance with per-pass measurable counters, not only aggregate writer counts.

## 3. Changes that are actually implemented NOW

In this research branch, **without changing height actuation or estimation admission rules**:
1. `TerrainDeformationEngine.lua`: when a new RE rut brush is accepted for a zero-depth history cell, sample the snapped logical-cell height **before** native write; preserve an existing recorded height and do not retroactively infer one for old deformed cells. Observational counters distinguish captures from legacy/no-reference.
2. `SpatialHistory.lua`: optional `preDeformHeightM` field in export/import snapshots; `VERSION=7`. Dormant/recovered histories still retire as before.
3. `TerrainPersistence.lua`: write/read optional `#preDeformHeightM`; retain compatibility with old format-2 XML files that lack this field. The old `#surfaceHeightM` geometry guard is not repurposed.
4. `RecoveryReferenceV2.lua`: preserve rejection policy and return the measured inner/outer drift as **optional third return**, on curvature rejection only.
5. `TerrainRecovery.lua`: accumulate rejected-drift mean/max and rejected-above-100mm counts without changing decisions.
6. `Core.lua`: emit read-only diagnostic line `TerrainPreDeformReference`, including actual native mesh-unit size.
7. `tests/terrain_reference_observation_harness.lua`: old snapshot import, optional baseline persistence, clean-plane acceptance, highly curved-surface rejection/drift third return.

**Safety:** No new source modifies `setHeightTarget`, increases brush intensity, bypasses current `CURVED_OR_INCONSISTENT` or changes `applyRecoveryAt`. This line is a **diagnostic groundwork**, not a fix to use on a production save.

## 4. Evaluation stages

**Gate 0 — static/CI:** luac parsing, harness, declared files, unchanged production main branch. Any harness failure must be corrected before sharing experimental ZIP.

**Gate 1 — controlled original snapshot:** disposable save, separate small dry field patch, vehicle stationary/isolated. Capture one fresh RE rut with no other active harvester. Validate pre-reference captured once at correct snapped coordinates, retained through repeat passes, and old history still has no fabricated reference.

**Gate 2 — geometry/provenance:** verify surface height before-and-after at native mesh vertices and rut center; check reference vs observed depression and whether native brushes actually touch vertices. Record the difference between 0.2m logical grid and true heightmap resolution. Test overlapping wheel passes and intentional TerraFarm grade: a foreign modification must invalidate restoration target.

**Gate 3 — actuator-only benchmark:** fixed known target from clean geometry, control radius/strength/height target/mode; no farm harvest work mixed into this benchmark. Prefer `TARGET` or constrained `SMOOTH` only after proving effects; no unbounded `RAISE`.

**Gate 4 — guarded recovery V3:** only enable verified pre-reference targets with per-cell and footprint displacement caps; ensure positive measured gain and no mound/overshoot. Old references still fail closed; add curvature-safe fallback separately after synthetic+field evaluation.

**Gate 5 — practical farming acceptance:** identical saved field segments; controlled AI/player harvesting and actual distinct SHALLOW_DISC vs PLOW implements, with stable speed, repeat passes, terrain reconditioning, and meaningful ability to seed again. Measure *terrain height before/after* and physical trail quality, not work-area callback counts. Verify save/reload; no concurrent S780 writing during isolated recovery test.

## 5. Promotion/merge decision

**NOT READY TO MERGE INTO `main`.** The source work in this branch instruments a promising architecture while leaving the failed R1/R7 actuator unchanged. The real gate is proving physical mesh-compatible correction and no damage to old saves. Never market it as a completed recovery or ask the user to repeat the full failing plowing sequence without first resolving Gate 3.

## 6. External contracts referenced

- GIANTS FS25 `getTerrainHeightmapUnitSize` and `getTerrainHeightAtWorldPos`: official GDN API.
- TerraFarm `LandscapingInputSlope.createTerrainDeformation` and `LandscapingInputFlatten.apply`: comparison precedent for `setHeightTarget`, `enableSetDeformationMode`, `addSoftCircleBrush(...,-1)`, explicit machine-grade up/down policy. We use these as API examples, not code to copy into RE.
