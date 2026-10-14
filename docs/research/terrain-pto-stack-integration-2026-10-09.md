# RE integration candidate: native PTO + terrain plastic yield (2026-10-09)

**Branch:** `feat/terrain-pto-integration-2026-10-09`  
**Base parent:** RE `main@2534cec4530b4839b608613c0c80453fc1bc5d58` (PR #33 native PTO, PR #34 terrain disabled default).  
**Terrain parent:** PR #36 `feat/terrain-plastic-yield-v1@8ea0efd7b8dfc77001e6879e7c16e50201cab5ee` with physical recovery and pass tracker.

## Explicit merge policy

This **experimental branch** preserves `scripts/pto/`, `scripts/api/PTOContract.lua`, PTO HUD assets and operator input bindings from main; preserves `scripts/terrain/`, `scripts/tracks/`, Core runtime, provider 1/2 contract, and terrain harnesses from the terrain PR; and merges `modDesc.xml` + `scripts/Config.lua` (including PTO HUD with `PTOControl=true`, `TerrainDeformation=true`, `TerrainRecovery=true`, `TerrainPlasticYield=true`). Main branch remains unchanged and terrain-default-off.

The `scripts/Core.lua` carried from terrain is newer for terrain services than main's `Core.lua`; PTO registration/control is independent in `PTOBootstrap`, while `modDesc.xml` retains all PTO loaders. CI main workflow is retained, generating the PTO UI texture and executing all PTO and terrain harnesses. On failure, no game test is authorized.

## Provider and external versions

RC `main@ad7461fb77776...` is API=2 wheelContext=2, compatible with the feature's negotiation for the pair. MR `0.26.10.08` has SOURCE_COMPATIBLE RC per-module gating and local-Mud wetness draft (new `MRMudDraft`) and PTO bridges, but no full physics VERIFIED stamp. The older RC 0.2.0.2 should not be used with MR 0.26.10.08 and native PTO; use updated RC main 0.2.0.4 build.

Recent known in-game versions: Mud 1.3.6.0, Reifen 1.2.2.70, RMS 0.11.0.0, SoilCompaction 1.0.0.0 and MR 0.26.10.08. Other installed mods/updates cannot be certified by repo contents; compare a new log/ModMixer report before marking a new dependency set validated.

## Runtime gate

Back up the save because RE edits heightmap; use one sole `FS25_RealismExtensions.zip`, one RC 0.2.0.4 main build, and **disable external Dynamic PTO if testing RE-native PTO**. Confirm `BuildIdentity` for both, provider active v2, PTOControl active, and no startup errors. Gameplay sample: first verify single PTO activation / AI RPM (no duplicate owner), then ordinary field harvest→cultivate→seed, then wet slip/stuck rut stress; check `TerrainPlasticYield supported/yielded`, native terrain writer callbacks, recovery, save/reload. No claim of tested FS25 runtime is made by CI alone.

**Migration note:** newer RE main head may move; this branch is pinned to the listed parent SHA, and future source updates should be reviewed rather than blindly overlaid. PR #36 remains open, and neither the PTO nor terrain experimental branch is merged into stable main here.
