# RE Terrain — measured wheel-path continuity and native fine-surface contract

**2026-11-02.** Experimental [PR #64](https://github.com/rafaaelalves/FS25_RealismExtensions/pull/64), issue [#63](https://github.com/rafaaelalves/FS25_RealismExtensions/issues/63). This code is a source-level **safety and evidence milestone**, not approved permanent terrain deformation/recovery. RE/RC production `main` untouched; `TerrainPermanentActuator="SHADOW"` still prohibits automatic native RE writes. Do not request another full plow/sow/harvest cycle for this change.

## 1. Found in current RE code, before changing anything

`TerrainDeformationEngine.processWheel` already interpolated from `state.lastX,lastZ` to current contact position at a 250ms sample cadence, bounded to 6 samples/tick. It updated the anchor before interpolating. It had **no effective discontinuity screen** for reset-to-shop/teleport/missing update frame. A vehicle jumping 100m could cause six RE sample positions on a fictitious 100m chord (though the SHADOW actuator currently prevents physical native excavation). This is a real source bug and an unacceptable future write path; adding a new swept-volume model on top of it would have amplified a false provenance problem.

## 2. Implemented in this branch

- `scripts/terrain/TerrainWheelPathContinuity.lua`: stateless pure-Lua movement admission based on true previous/current wheel contact, bounded elapsed time, displacement distance, estimated body speed in km/h and absolute speed ceiling. Returns `RESET_ANCHOR`, `STATIONARY`, `CONTINUOUS`, `UNDER_SAMPLED`, or `REJECT`. Only measured non-stationary `CONTINUOUS` is complete enough to support a footprint research candidate. `UNDER_SAMPLED` still gives controlled up-to-six discrete samples but **never pretends the entire chord is observed**.
- `TerrainDeformationEngine` adopts the pure policy before interpolation. On reset, sample **only the actual current wheel contact**, never the intermediate invented path. Clear path evidence on the first contact and during the separate loaded-contact refresh; future normal movement starts from the new anchor. A paused 5-second update is not five seconds of proven soil contact: a reset passes at most one normal sample interval to the soil model.
- `TerrainMainFootprintGate.evaluate` now requires `pathContinuity=true` in addition to the 75%-coverage research heuristic. Otherwise it returns `GEOMETRY_UNKNOWN/NO_BOUNDED_MEASURED_PATH`; neither a complete path nor a high width/length ever grants a native write. `TerrainAbsoluteHeightPlanner` records that verdict in volatile SHADOW state.
- `TerrainNativeWheelBridge.nativeSetterCandidate` was previously manually callable with only physics + new scale, despite the source comment promising an explicit research policy. It now requires mode `EXPLICIT_ISOLATED_WHEEL_RESEARCH`, explicit acknowledgement of exclusive control and cloned save, and an exact verified expected **Lua** displacement scale immediately before touching the wheel shape. This prevents accidental candidate use, **not** adversarial invocation, server-authoritative arbitration, or native-geometry readback. No automatic RE code invokes this setter.
- Tests updated/added: `terrain_wheel_path_continuity_harness.lua`, `terrain_deformation_engine_harness.lua`, `terrain_main_footprint_gate_harness.lua`, `terrain_absolute_height_planner_harness.lua`, `terrain_native_wheel_bridge_harness.lua`. Cover normal/reversed/diagonal travel; stationary wheelspin; teleport; slow-body/high-wheel-position jump; 5-second time gap; interpolation-cap saturation; missing path evidence; no-lease/no-owner refusal; prior standard terrain tests.
- NO new `TerrainWriter` or `TerrainGeometryJournal` logic, physics owner, persisted SHADOW height or smoothing. No new RC modification.

**Deliberate constraints:** the 750ms maximum elapsed interval, up to 50m/s physical ceiling, 3x estimated body-speed slack, 0.75m positional margin, and 6 interpolated samples are *provisional defensive implementation constants*. Not empirically calibrated to all tractors/trailers/steered implements. RE currently obtains `vehicle:getLastSpeed()` (GIANTS documents km/h) and actual world wheel contact coordinates; this is more useful than inferring movement from tire rotation, but still not guaranteed continuous collision/terrain evidence.

## 3. Exact publicly documented native engine facts, not conjecture

The official GIANTS interview (https://www.farming-simulator.com/newsArticle.php?campaignIndex=5&country=cl&lang=en&news_id=569) says:
- 0.125m terrain-deformation grid for wheels/tool operations; collision reaction to it; sparse compressed density-map tiles; adaptive quadtree render and normal mapping at distance. This is the **native fine dynamic deformation surface**; it is distinct from a coarse heightmap coordinate.
- The article explains **in-memory storage**, not durable persistence of specific fine deformations through save/reload. Do **not** read the word 'stored' as a savegame persistence warranty.

GIANTS Developer Network, FS25 script v1.20:
- [getTerrainHeightmapUnitSize](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=28&function=812&version=engine) reports the **main** heightmap unit, found to be 1m on the user's test map; it does not report fine wheel-deformation cell size.
- [getTerrainHeightAtWorldPos](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=28&function=811&version=engine) reports **terrain height**. Sampling it every 0.125m interpolates the same exposed terrain height API, NOT proof of reading the separate fine 0.125m displacement surface.
- [WheelDestruction:smoothHeightAtPosition](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=93&class=906&version=script) calls `smoothDensityMapHeightAtWorldPos` for height type/material handling; [getDensityHeightAtWorldPos](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=29&function=823&version=engine) operates on a **fillDataPlaneId** (deposited density height), so neither API is automatically a wheel-deformation reader/writer.
- [Vehicle:getLastSpeed](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=91&class=888&version=script) multiplies `lastSpeed*3600`. This supports interpreting the output as km/h under usual GIANTS semantics, rather than engine `m/ms`.

**Result of the source audit:** a user-space Lua hook to read individual native fine 0.125m wheel-deformation height cells, save them without loss, then reapply them with correctly matching physics/collision has **not** been proven. Do not invent its availability or claim VMT/Soil Deformation Save's replay into MAIN solves it. This remains a specific release-blocking research question.

## 4. Ownership map: avoid conflating four terrain-like APIs

| Surface | Known writers/readers | What this pass changes |
|---|---|---|
| Native high-resolution wheel deformation and physics | GIANTS `WheelPhysics` displacement; `setWheelShapeTerrainDisplacement` controls a wheel parameter, **not arbitrary per-cell restitution** | Passive capability observation; manually accessible setter now gated |
| MAIN coarse persistent heightmap | GIANTS terrain height API, native writer, TerraFarm/manual landscaping and legacy RE tests | **No writer enabled**; still SHADOW |
| Density height for tipped bulk/placed materials | `g_densityMapHeightManager`, `smoothDensityMapHeightAtWorldPos`, `getDensityHeightAtWorldPos(fillDataPlaneId,...)` | No reuse as rut recovery |
| Surface/grass/field density | Mud 1.3.9 TurfDamage cultivated-ground conversions, others | Not a heightmap writer; source labels and cache invalidation remain future work |
| TireTracks/surface rendering | Native visual tracks, VMT-like overlay systems | Not validated collision nor persistent terrain geometry |

Also respect RC/MR/RMS/4x4 differential owner, Mud sink, Reifen structural radius, HSS suspension, SoilCompaction agronomic accumulation; path continuity must not grab any of these fields.

## 5. Gates that remain — ordered, bounded and actionable

1. **Source/game-engine capability identification:** find documented exact fine-displacement readback and save/restore/collision parity *before* promising it as the permanent rut owner. If unavailable, treat this as an explicit limitation and avoid fake reconstruction on MAIN.
2. **Geometry model**: the current evidence is a single bounded straight chord. Full swept-support union would need guaranteed same-wheel provenance, turn curvature/steering, overlapping contact raster and terrain-unit origin. It MUST NOT increase a source's cumulative vertical rut because six adjacent footprints were sampled.
3. **Single short cloned-save calibration only when ready**: verify a controlled native absolute height edit with before/after, collision and persistence; independent outsider edit invalidates RE authority. Confirm map origin/resolution, not just a presumed 1m MAIN unit.
4. **Actual gameplay acceptance** remains two-phase: a newly authored rut that is safely recoverable through one real primary and at most one secondary appropriate cultivation pass, preserved through save/reload and without damaging natural slope/foreign edits. This **is not delivered** by Lua CI.

**No request for new player test now.** Once CI passes this code, it can be regarded as a validated source-level safety milestone, not a playable permanent rut release.
