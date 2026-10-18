# DynamicDrive Pro 1.0.1.0 — negative terrain-writer examples for RE V3

**Date:** 2026-10-18  
**Source:** User's exact `FS25_DynamicDrivePro.zip` SHA-256 `bf7fff1f1167dcf6c28a877da08ae1a2a8c3e5382407e0b4cde64457f632c52f`, 18 entries (16 Lua, modDesc and DDS). Original author Papa_Matze / [ModHub v1.0.1.0](https://www.farming-simulator.com/mod.php?mod_id=352451).  
**Primary RC analysis:** [DDP exact ZIP / full-stack audit](https://github.com/rafaaelalves/FS25_RealismCompatibility/blob/docs/audit-dynamicdrivepro-1.0.1-2026-10-18/docs/audits/2026-10-18-dynamicdrivepro-1.0.1.0-full-stack-source-audit.md).  
**Decision:** **Do not port its runtime. No code change in RE.** Harvest robust negative tests and geometry-writer requirements for our existing [terrain V3 research](https://github.com/rafaaelalves/FS25_RealismExtensions/blob/research/terrain-predeform-reference-v3-2026-10-15/docs/research/2026-10-15-terrain-reconstruction-v3-design.md).

## 1. The major distinction from TTD and from our RE writer

TTD 3.7 primarily used `wheel.physics.radius` and native wheelshape displacement, not a proven heightmap writer.

**DDP contains code that attempts to rewrite terrain height** in `DDP_terrainDepth:onWheelSink`:

- `h = getTerrainHeightAtWorldPos(terrain,x,0,z)`; `newH=h-sink*0.02`; `setTerrainHeightAtWorldPos(terrain,x,newH,z)`.
- Appends `{x,z,newH}` to an array (max 50,000).
- Reloads `reaTerrainDepth.xml` and directly reapplies each stored `h` via the same setter when the map starts.

This is only **an attempted write**: whether that exact native function exists/changes the actual GIANTS FS25 heightmap is **not authenticated by this ZIP or a game log**. If it exists and works, it is dangerous without native mesh resolution, source owner, actor permissions, a bounded radius, authority, first-touch original height or an explicit reconstruction phase.

RE's writer is qualitatively different: it uses native `TerrainDeformation` brushes, role/mode limits, a scheduled/server-controlled queue, logical history, and feedback measurements. The existing V3 research is **still observational**, not proven real PLOW/CULTIVATOR recovery; do not confuse better architecture with already-functional physical convergence.

## 2. Source-proven failures to convert to test requirements

| DDP defect observed in source | Evidence | Proposed original RE check |
| --- | --- | --- |
| Scope/hook reachability | In `DDPwheels_fixed.lua`, `ddpHookWheelPhysics` is local inside `clamp` due to misplaced `end`; `DDPwheels.onUpdate` calls nonexistent global and fails in isolated Lua probe | Compile all Lua **plus** test callable hook targets in a runtime-like stub. Validate registered specialization methods and loaded source list; no false success from syntax-only CI |
| Uninitialized spatial map | `DDP_terrainDepth.new` never initializes `trackCells`; `onWheelSink` immediately indexes it | Verify writer/history/cache construction after fresh map load and save import; nil table should fail CI before an engine mutation could occur |
| Undefined intermediate | `finalSink` used in rut/fatigue calculations without assignment | Original source variable sanity checks and purpose-built branch tests before any native write |
| Wrong time scale | DDP uses `dt` directly to increase sticking/compaction where another function divides milliseconds by 1000 | Test units and frame-rate invariance at 16, 33, 100, 250ms and high server dt; cumulative geometry budget must not depend on frame rate |
| Cumulative downward without reference | Every callback lowers **current** center by `sink*0.02`; no original baseline | For same native vertex, repeated stationary/small-speed passes must remain within bounded rut depth and conservation budget. No unbounded writes to already-lowered ground |
| Height replay destroys provenance | DDP saves **post-effect `h`** and reapplies to whatever live terrain exists | Never reinterpret saved current height as `preDeformHeightM`. Keep authored geometry owner, epoch, confidence, before/after signatures, version migration; invalidate on TerraFarm/foreign edits |
| Sprawling write authority | DDP has wheel friction hooks, engine torque writer, direct vehicle rotation, heightmap raw writes, no field-local composition | RE remains geometry-owner only; Mud/MR/Reifen/RMS author motion/sink/traction/torque and SoilCompaction owns agronomic compaction |
| Unbounded save buffer / cost | DDP records every per-wheel contact point and removes index 1 when full | Use coalesced terrain-unit-aligned histories, short budget queues, capped work per tick; no O(n) 50k list shift every wheel callback |
| No MP protocol proof | DDP declares `multiplayer supported=true`, but raw height XML replay and per-wheel listener do not define deterministic geometry replication | Authoritative server-only writer; native terrain deformation replication, snapshot/merge hash, double save/reload and join-in-progress checks |
| No validated terrain API | Direct `setTerrainHeightAtWorldPos` without existence/type check or result measurement | Verify actual native GIANTS heightmap vertex spacing and actuator, callback result, displaced volume and geometry min/max; abort safely if unavailable |

## 3. Highest-value experiments for our current Terrain Recovery V3 blocker

1. **Geometry actor gate:** On a disposable save, instrument RE native `TARGET` plus additive `LOWER`: record actual input vertices, world-position alignment, brush radius relative to `getTerrainHeightmapUnitSize`, observed per-vertex change and callback result. Compare with an original reference and record no-op or drift. No raw DDP height setter should be introduced.
2. **Reference identity test:** Construct two otherwise identical field cells: one rut made by RE with authenticated *pre-rut* original height, one pit intentionally made by TerraFarm. Both may have the same current `h`; only RE's authenticated cell is a recovery candidate. Raise only within bounded target and realistic tool disturbance.
3. **Repeated update invariant:** Same stationary vehicle for 1s, 10s, 60s, and different FPS; depth growth converges/clamps and does not scale with callback count alone. Keep Mud transient sink distinct from RE rut debt.
4. **Save/reload integrity:** For mixed original RE rut plus TerraFarm edit, serialize RE provenance; load twice; **do not replay historical post-deformation heights** or undo more recent edits. Include map grid/terrain-root hash or localized epochs and old-sidecar migration.
5. **Subsurface vs surface compaction separation:** DDP calls wheel-specific sticky memory “compaction”; our RE must not convert transient wheel difficulty into SoilCompaction's persistent agronomic compaction. Cultivator restores some rut geometry with supportable pass and tool ownership; tests distinguish SHALLOW_DISC vs PLOW vs SUBSOILER.
6. **Hooked-source integration:** Test delayed GIANTS initialization, specialization registration order, server/client dispatch and third-party mod load order. A script sitting in a ZIP but missing from `extraSourceFiles` is not live evidence. A hook can be syntactically valid but absent or error on its first real callback.

**Recommended deliverable when terrain recovery work resumes:** a **small standalone safety/actor harness**, not a new wheel model: initialize production RE history writer, feed synthetic unit-consistent terrain probes and attempted jobs, assert bounded depth/no side effects/no foreign replay, and log verification of native TARGET moved vertices in FS25 for the remaining engine-dependent tests. Gate actual RE changes on V3 experimental evidence rather than choosing DDP's additive formula.

## 4. Optional longer-term ideas, not next implementation

- Combine **source-labeled read-only surface/tyre observations** with TTD research. Road/agricultural/wide/narrow/track, wet/dry, contact mode and slope can be useful **metadata** for RE-owned geometry and a diagnostic HUD, but do not reuse DDP hardcoded tire friction multipliers.
- Cargo/load/sloped trailer dynamics: DDP attempts trailer sway and direct body roll but writes vehicle root transforms. **No RE root rotation** and no competing trailer force law until GIANTS hitch/joint forces, load distribution and existing MR owner are understood.
- Audited source scope: three DDP files are not listed as sources (`DDP_main`, `DDPDynamicSuspension`, `DDP_drawbarResistance`); other features (`DDPsoilTracks`) depend on a `DDPwheels` specialization the in-ZIP register does not add. This is useful evidence to improve **our** source-registration/CI testing.

## 5. Decision and non-goals

**NO INSTALL** with MR 0.26.10.08, Mud 1.3.7, Reifen 1.2.2.70, RMS 0.12, SoilCompaction, RC 0.2.0.6, RE PTO V1.6/Terrain V3, TerraFarm. **NO RC DDP version bridge. NO RE absorption of DDP code. NO change to default `TerrainDeformation=false` production baseline.**

Priority remains **RE terrain V3 true geometry, references and tillage recovery**. DDP gives a particularly useful *negative example*: an archive can be CRC/XML/Lua clean, advertise persistent ruts, and still lack initialized source state, validated engine write capability, provenance and recovery correctness.

**Original evidence:** uploaded ZIP SHA above, [official ModHub release](https://www.farming-simulator.com/mod.php?mod_id=352451), [normative RE ownership](../project/OWNERSHIP.md), [existing V3 plan](https://github.com/rafaaelalves/FS25_RealismExtensions/blob/research/terrain-predeform-reference-v3-2026-10-15/docs/research/2026-10-15-terrain-reconstruction-v3-design.md).
