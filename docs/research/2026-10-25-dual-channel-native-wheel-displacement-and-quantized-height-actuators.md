# 2026-10-25 — Dual-channel terrain actuator research: native fine-wheel displacement first

## Motivation: measured main height is not native fine wheel displacement

The 2026-10-25 20:08:59 RE experiment generated 129 native journal jobs, 119 with no main-vertex lowering and 10 with some lowering; 8 of those 10 exceeded request + 2 mm and one 1.7mm request coincided with 58.4mm observed. The 6 exact main-grid changes fit multiples of q = 255/65535 m = 3.891mm. **No single callback proves RE exclusively caused a given measured delta.** The experimental session-quarantine behavior worked, and this makes the existing 1m main-height ADDITIVE soft-circle route unsuitable for proportional 1–3mm normal wheel ruts.

The developer's published FS25 engine interview states that ground displacement is simulated on a **0.125m (12.5cm) fine grid**, and wheel physics reacts to its terrain collisions. The 1m *main heightmap* height sampled by RE is **not** proven to include every fine-wheel displacement state: repeatedly calling that same API every 0.125m does not constitute a distinct fine-channel accessor.

## More promising VERIFIED source-level control path

We reviewed the publicly visible FS25 `WheelPhysics.lua` source mirror (grevef/fs25-lua-apis) and the public independent `SecondChanceGaming3709/FS25_DeepRutts` implementation. Relevant FS25 code behavior:

1. `WheelPhysics.new` initializes `displacementScale = 1` and `displacementAllowed = true`.
2. `WheelPhysics:loadFromXML` checks `supportsWheelSink`, server state and the `Platform.gameplay.wheelTerrainDisplacement` setting to configure physical collision with terrain displacement.
3. `WheelPhysics:updateBase` passes `self.displacementAllowed and self.displacementScale or 0` to `setWheelShapeTerrainDisplacement(self.wheel.node, self.wheelShape, ...)`; `WheelPhysics:setDisplacementAllowed` also calls this native function when the physics shape is present. **Writing only the Lua field might not immediately update an existing physics shape.**
4. The published Deep Ruts mod controls exactly `WheelPhysics.displacementScale`, with scalar presets from baseline 1.00x to 2.50x, not the 1m terrain heightmap. This validates a controllable *capability*, not its safe calibration in RE or retention across saves and platforms.
5. GIANTS engine docs separately publish `setTerrainHeightAtWorldPos(terrainId,x,0,z,height)` as an **absolute main-heightmap setter**, potentially a better-controlled rare/deep geometry path than additive soft-circle. But public API docs do not establish main+fine coherence, collision rebuild, snapshot safety or MP replication for this use.
6. `TireTracks.addTrackPoint`/native tire-track visual system is **not** equivalent to the 0.125m wheel-collision displacement subsystem. Do not conflate visual shader tracks with physical permanent ruts.

**Important compatibility rule**: MR/Mud/other modules may modify the wheel physics; never install an intrusive unconditional overwrite on `WheelPhysics` or keep multiplying a non-1 external value. Ownership of `displacementScale` is a capability requiring read/recheck/release semantics.

References:
- https://www.farming-simulator.com/newsArticle.php?news_id=569
- https://github.com/grevef/fs25-lua-apis/blob/main/vehicles/wheels/WheelPhysics.lua
- https://github.com/SecondChanceGaming3709/FS25_DeepRutts
- https://gdn.giants-software.com/documentation_scripting_fs25.php?category=28&function=816&version=engine

## New safely isolated prototypes

All three are source files that are **NOT registered in modDesc.xml, NOT referenced from Core.lua, and NOT called by the live terrain engine**. They only run in standalone Lua harnesses until a deliberate integrated test plan and compatibility contract are approved.

- `scripts/terrain/TerrainQuantizedHeightBudget.lua`: per-native-vertex physical demand ledger. Below-one-quantum requests accumulate without 1m writes; permits **only one quantum for each verified native transaction**, preserves unused debt after readback, respects remaining first-touch safety budget, and quarantines excessive/noisy results. The quantum is **required configuration**, never globally assumed 255/65535. It is logical demand, not a physical height/soil volume/RE-owned recovery reference.
- `scripts/terrain/TerrainAbsoluteVertexCandidate.lua`: optional, **disabled-by-default** proof of a bounded, readback-confirmed **absolute** main-vertex target (not additive soft brush). Invoker must explicitly supply `explicitWrite=true` and an injected `writeHeight` function; it uses `TerrainGeometryJournal`'s first-touch, native-grid, neighboring-vertex scan and drift preflight, calls a one-quantum target and fails closed on unexpected collateral or excess. It is not an acceptable production actuator until real GIANTS source/scene semantics, multiplayer, persistence and local shape are verified. Never auto-'fix' excessive outcomes by blind TARGET/RAISE backtracking.
- `scripts/terrain/TerrainNativeWheelDisplacementPolicy.lua`: candidate owner-aware policy around `WheelPhysics.displacementScale`, prioritizing FS25's 0.125m fine physical displacement. Only plans a bounded, **not yet calibrated** factor, rejects absent/non-server/non-sinking wheels and already externally scaled wheels, rechecks values at mutation time, and returns to base only if it still owns the value. No built-in GIANTS call: applying requires `researchWrite=true` plus injected `writeNative`. A policy test mocks the actuator but does **not** prove real change to engine shape, field effects or persistence.

Harnesses:
- `tests/terrain_quantized_height_budget_harness.lua`
- `tests/terrain_absolute_vertex_candidate_harness.lua`
- `tests/terrain_native_wheel_displacement_policy_harness.lua`

Validated by GitHub Actions at code commit `4dd98574248212c216ea96b859a42f48c0d7f932`: `Build and test mod` run `40230968638` **SUCCESS**. The tests run against mocks, not the physical GIANTS engine. The temporary build artifact from CI has unchanged live terrain behavior; it is not being requested as a user test.

## Architecture recommendation (conditional, not yet shipped)

1. **Normal/small ruts:** Leave the native FS25 physical 0.125m wheel-displacement subsystem in control, with bounded RE policy adaptation to real plastic/soil conditions **only after** explicit MR/Mud compatibility and a reliable native update path have been verified. Normal visual tire marks may already be good; do not invent a cosmetic correction.
2. **Rare deep permanent ruts:** Only where the fine system cannot satisfy persistence and recovery goals, use a separately proven main-heightmap absolute one-quantum write with immutable baseline, full native-vertex side-effect audit, physically grounded demand, no third-party ownership drift and a verified save/load contract.
3. **Recovery:** Native fine tillage/work-system behavior first, journal-owned exceptional main-height edits under CausalRecovery. Don't treat historical speculative R1/R7 rut debt as authority to bulldoze the landscape. NPC/municipal policy stays conservative and causal.
4. **Compatibility:** Mod-specific tire physics remains MR/Mud/Reifen owned via RC, and RE should not replace tire radius, traction, brake, sink or pressure. A native displacement-scale ownership conflict must fail closed.
5. **Verification before asking user to drive:** A small, explicit instrumented A/B on a disposable save must compare native displacement on/off without mixing 1m brush writes, with exact build IDs, compatible low-level wheel refresh and save/reload, and a zero collateral/sudden-hole gate. Only then request one targeted test. Don't demand a full plow/sow/harvest cycle.

**Decision**: Keep the existing PR #64 a draft, production main terrain disabled, and the 10/12cm provisional native safety guards. Do not merge or claim the normal rut actuator is solved until game-level validation. The isolated prototypes are real development work that narrows the engineering design without changing current playable builds.
