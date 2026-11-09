# 2026-10-25 — Passive native-wheel displacement runtime bridge

## Grounded API interpretation

FS25 `WheelPhysics` initializes `displacementScale=1` and `displacementAllowed=true`. The server-side `updateBase` passes `displacementAllowed and displacementScale or 0` to `setWheelShapeTerrainDisplacement(wheel.node,wheelShape,value)`, while `setDisplacementAllowed` can update an existing wheel shape immediately.

**Do not** assume assigning `wheelPhysics.displacementScale` alone refreshes the current native collision shape; `updateBase` is not guaranteed to be called just because the Lua field changed. The new bridge's *optional research setter* calls this native function with source-verified argument order, but **no runtime caller invokes it**. It requires an existing wheel shape, server-side vehicle already added to physics, supported wheel sinking, displacement allowed, engine setting not explicitly disabled, a native setter function, and a multiplier 0..2. It is not a production actuator yet.

The native wheel displacement channel is different from visual TireTrackSystem decals and from permanent `TerrainDeformation` changes on the primary 1m heightmap. Independent developer of Deep Ruts specifically notes the stronger *native* ruts are session-based and **may reset on reload**. Therefore this channel is a possible replacement for *ordinary physical small rut response*, not automatically a replacement for RE's requested persistent deep ruts and tillage recovery. The latter still needs a separately verified, permanent terrain mechanism.

References:
- https://github.com/grevef/fs25-lua-apis/blob/main/vehicles/wheels/WheelPhysics.lua (function `WheelPhysics:updateBase`, `setDisplacementAllowed`)
- https://github.com/SecondChanceGaming3709/FS25_DeepRutts (reference mod, external behavior)
- https://secondchancegaming3709.itch.io/deep-ruts-fs25 (author's session-persistence qualification)
- https://www.kingmods.net/en/fs25/mods/73208/mud-system-physics (Mud System Physics author removed previous Visual Mud Tracks compatibility; use at own risk)

## Implementation

- `scripts/terrain/TerrainNativeWheelBridge.lua` is a source-backed *read-only observation module*. The only side-effect of `observe(vehicle,wheel)` is updating RE counters and weak-keyed per-wheel last-read state. It DOES NOT update `WheelPhysics` or call `setWheelShapeTerrainDisplacement`.
- Loaded via `modDesc.xml`; config `modules.NativeWheelDisplacementObservation=true` on **this experimental terrain branch only**. The main production branch remains untouched.
- `TerrainDeformationEngine.processWheel` samples it **after** the RE 250ms context+grounded gate, before footprint eligibility, including loaded stationary wheel contact; no global `WheelPhysics` overwrites, hooks, native calls, or extra per-frame iteration.
- Every ~60s existing `TerrainHealth` cycle logs one bounded `TerrainNativeWheel` cumulative snapshot with server/type capability, availability of native `wheelShape` and setter, number of already non-default scales, value changes, baseline counts and observed min/max. A non-default value is only an *external ownership candidate*, not a proven attribution to MR, Mud, Deep Ruts or any named mod.
- Native setter candidate remains dormant and requires deliberate explicit call; source is not an entrypoint for automatic engine writes or physics shifts.

## Validation and release gating

- `tests/terrain_native_wheel_bridge_harness.lua`: no native calls from repeated observation, non-default externally scaled wheel not overwritten, missing shape / node / client / disabled sink fail closed, exact native call argument order tested with stub only.
- `tests/terrain_deformation_engine_harness.lua`: now runs the actual vehicle specialization with the observer enabled once to verify correct sampling and subsequent disabling, without altering the existing wheel/terrain effects in mocked runtime.
- Underlying policy `TerrainNativeWheelDisplacementPolicy` remains separately disabled, and its unit tests cover external-scale rejection and safe release.
- These are **Lua mock tests only**: no actual GIANTS wheel displacement output, 0.125m geometry readback, GUI visibility, save/reload, source-value timing, multiplayer or MR/Mud interactions have been verified.
- No new user-facing validation requested now. A future targeted real-game test should only be proposed after the native scale ownership and update-path instrumentation is sufficient to isolate actual physical response and its persistence.

## Next technical gates

1. Compare existing runtime scales and owner candidates via `TerrainNativeWheel` *after* the next genuinely needed game session; do not solicit a test merely for one counter.
2. Design an explicit fine-vs-main *read/write ownership* contract. Treat native wheel response as short-lived until its savegame lifecycle is proven. The persisted heightmap cannot be safely replaced by visual tracks or an unverified native scale.
3. Preserve RE CausalRecovery/GeometryJournal's immutable first-touch and soil-work-area logic. Never entrust restoration authority to speculative 0.2m spatial rut debt or native visual-track points.
4. Develop a bounded heightmap-actuation A/B with real C++ callbacks and third-party writer isolation before enabling `TerrainAbsoluteVertexCandidate` (currently unregistered) or disabling causal safeguards.
5. Keep old additive main-heightmap rut actuator flagged **experimental** and default-off on production main; its sub-quantum output and 15-step anomalies are not solved by this observer.
