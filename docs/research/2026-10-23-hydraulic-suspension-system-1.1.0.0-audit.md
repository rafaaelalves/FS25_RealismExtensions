# Hydraulic Suspension System 1.1.0.0 — source audit and potential RE capability

**Date:** 2026-10-23 (Brazil). **Mode:** research and target-stack evaluation, **not an implementation**. This document is intentionally **docs-only**; RE runtime/CI build must not be triggered by it.  
**Decision:** **GO for isolated singleplayer A/B with backup; HOLD on absorbing into RE** pending source-owned spring/damper contract, measured behavior and independent licensing. No new RC bridge and no code changes.

## Exact source and delta

| Archive | Version (modDesc) | SHA-256 | Size | Files |
| --- | --- | --- | ---: | ---: |
| Previously uploaded `FS25_HydraulicSuspensionSystem (1).zip` | 1.0.0.0 | `b338a28d13cadfe8b00949c7d0461079a04f6ee29a5afdd6fc79c3567038d40e` | 180,304 bytes | 43 |
| New user `FS25_HydraulicSuspensionSystem(1).zip` | **1.1.0.0** | **`0c014805e1dc8dd981f7f2d6c34903578a90daa0b1b94db4120d7a335381cf59`** | **224,582 bytes** | **45** |

Exact ZIP diff: **2 added** (`sounds/hssSounds.xml`, `sounds/hssValve.ogg`), **41 modified**, **0 removed**, **2 bitwise unchanged**. Modified source: `HydraulicSuspension.lua`, `HydraulicSuspensionConfig.lua`, `HydraulicSuspensionModeEvent.lua`, `HSSLoader.lua`, `HSSHud.lua`, `HSSSettingsMenu.lua`, `ZCSettingsMenu.lua`, `Injector.lua`, plus `modDesc.xml`, 25 translations, HUD DDS and changelog. New archive has **9 Lua**, **27 XML** (including 25 translations), seven DDS and sound. Both ZIPs CRC PASS, all 27 new XML parse, and all 9 Lua pass `texlua loadfile` syntax. The modDesc dynamically loads its eight secondary Lua files via `scripts/Injector.lua`. **No FS25 gameplay test or full dedicated MP test** was run during the audit.

Source manifest `author=Zasty Chalk`, declared `multiplayer supported=true`; public [v1.1 changelog](https://fs25.net/hydraulic-suspension-system-v-beta/) reports broadly the same functions but provides no authenticated per-binary SHA. Exact ZIP is source of truth. No LICENSE/COPYING is included; do not copy Lua, sound or artwork into RE without appropriate reuse rights.

## What the mod actually changes

It implements a **controlled hydropneumatic-style suspension on native wheel physics**, not a new grip/tire-wear simulator. It reads `wheel.physics.spring`, damper compression/relaxation, positionY/restLoad/suspTravel, actual wheel contact force, spring length and slip; chooses type/mode, changes spring/damping through `setSuspensionMultipliers` or raw wheel coefficients and `isPositionDirty`, and moves `positionY` to compensate measured load. Profiles distinguish per-system AUTO/WORK/LOCKED/MANUAL and include relative axle motion, visual steering geometry, loader arm / suspension and cab camera filtering. These coefficients remain **gameplay approximations** in the author's configuration rather than verified real nitrogen/oil pressures, fluid flow, pump energy or precise manufacturer shock dyno data.

In v1.1, the high-value additions are:
- **Class-aware behavior:** heavy/eligible tractors receive self-leveling; light/simple tractors can instead receive **pendular unsprung front axle**, respecting minimum 5t, 120hp (unless explicit model profile), front wheel travel and track exclusion; no artificial leveling on every small tractor.
- **Loader and telehandler Ride Control:** own boom spring and mass-dependent response above 6 km/h, rigid below; tractors with attachable frontloader get independent enable/disable by `Ctrl+Alt+L`. Loader vehicle classes use no simulated axle suspension. Includes detection of certain wheel-loaders whose vehicle type contains `tractor`.
- **Rear JCB Fastrac** auto-leveling and hitch height compensation; **road damping** above 30 km/h / relaxes below 22 km/h; anti-dive and transient WORK mode from implement-down and measured draft through Soil Draft or optional MR `mrLastForce`.
- **Visual and UX:** side-view HUD, actual independent vs pendular axle visualization, cab camera filtering, low-front-ballast (front share below 20%) and bump stop warnings, audio hydraulic valve and new menu controls.
- **Stability:** pendular wheel-shape rebuild threshold ~2mm and time budgeting ~120ms, plus special same-frame spring/height transition, designed to reduce jitter; beta 1.0.0.1 fixes are included in the 1.1 package.

## Specific cross-mod and lifecycle risks

**HSS-01 — Wheel-suspension ownership bypass (**source-confirmed mechanism; real-game effects pending**).**
`HydraulicSuspension.lua` function `claimWheel` replaces each controlled physics object's `setSuspensionMultipliers` with an instance wrapper. Calls with `pw.hssCalling` pass through; *every other mod's call* is recorded in `hssExternalSpring/hssExternalDamp` but **not forwarded**. This code is **identical to 1.0.0.0**. An isolated Lua extraction of the exact function verified external calls remain suppressed **even after** the simulated HSS `release` resets spring 1/1; the wrapper and `hssClaimed` are not removed. **This is not proof the MR and HSS live coexistence is incorrect**; it is proof that they do not negotiate per-call behavior. If RE adopts a suspension owner, it must use a defined lease/token, preserve other systems' current values and cleanly return actuator authority on vehicle exit, AI, module disable and physics rebuild. Don't add a blanket RC hook arbiter.

**HSS-02 — Parked/AI behavior is more subtle than marketing.**
`playerDriven` restricts continuous server update to a controlled player, but `onUpdate` calls `applyNow` **on first physics addition even for uncontrolled vehicles**, and preserves HSS current settings when the player leaves. The optional `releaseWhenParked=true` is checked but has **no enabled default in the 1.1 Config**, and even when it runs does not remove `claimWheel`. Thus “AI/parked use exactly vanilla” is not established by code; verify the actual live state and physics ownership.

**HSS-03 — MP event trust (**source-level authorization gap**).**
`HydraulicSuspensionModeEvent:run(connection)` validates existence of the vehicle/spec only; it does not validate whether the client controls, owns, or is allowed to change that vehicle before calling `setMode` and rebroadcasting. Server-side validation/clamping of `manualOffset` is also absent from this event path. Declaring multiplayer support in modDesc is insufficient; **do not adopt this net protocol** in RE.

**HSS-04 — User settings reset on this update.**
`HydraulicSuspensionConfig.settingsVersion` changes **7→12**. On older stored schema, `loadUserSettings()` deletes/recreates the config XML with new defaults/profiles, losing prior custom edits. **Back up `modSettings/FS25_HydraulicSuspensionSystem.xml` before first launch**; compare re-generated profiles and manually port tuning values after upgrading. This is openly acknowledged in the bundled changelog.

**HSS-05 — New loaderOff save requires FS25 proof.**
The HSS specialization now saves and reads `#loaderOff`, but `Injector.lua` registers only `#mode` and `#manualOffset` in `Vehicle.xmlSchemaSavegame`. The save call is `pcall` guarded, so a schema-write problem can be missed. Test toggling loader damping OFF, save, exit, reload twice and check any “Path not registered” log.

**HSS-06 — Wheel mutation hot path may outrun its nominal budget.**
An initial pendular optimization requests a wheel rebuild after ~2mm and max ~120ms, but `moveStep` also sets `e.posForce=true` when changing spring/height, which bypasses timing guards in those frames; may legitimately prioritize smoothness at cost of extra dirty wheel physics. Benchmarks needed on plowed rough ground, articulated tractor, dual tires and switching presets. A stable FPS in a parking lot does not prove no wheel-physics spikes under load.

**HSS-07 — Model/vehicle eligibility heuristics and attachment ownership.**
Injection requires a motorized/wheeled type whose name contains `tractor` or known loader fragments; front wheels are selected from model-local Z, suspension travel and track classification. Custom carrier layouts, articulated tractors, reversed cabs, unusual rear axle IDs and multi-wheel/triple support may be incorrectly classified. `HSSLoader.armSim` writes animated movingTool rotation and may compete with GIANTS/frontend loaders; `HSSCab` modifies camera presentation. Test them separately; avoid importing those behaviors into RE with no active owner.

## Current stack owner matrix

| System | HSS connection | RC/RE decision |
| --- | --- | --- |
| **MR 0.26.10.08** | Front/rear spring/damper via native API; optional MR `mrLastForce` WORK hint | **Primary unresolved physical conflict**. Need A/B HSS on/off and player→AI→park; no speculative RC bridge. |
| **RMS 0.12** | Chassis forces, wear and shock/differential graph can alter wheel physics/response | Source does not establish dedicated HSS/RMS conflict or safe cooperation; test, no new degradation model. |
| **Mud 1.3.7** | Contact force, wheel wet slip and sink/pressure react indirectly to changed axle response | Mud remains local wetness/sink/rolling authority; no new friction writer from HSS. |
| **Reifen 1.2.2.70** | Tire wear / structural radius affect geometric contact with changed suspension height | Retain Reifen radius/wear owner; test worn/dual wheels and HSS clearance. |
| **RC 0.2.0.9** | No existing bridge owns wheel spring/damp; `rcHooks` monitors different functions | No RC source changes/version bump; propose a narrow MR/HSS contract **only if** actual lost behavior established. |
| **RE PTO V1.6** | Hydraulic/visual front axle and PTO shaft motion; no actual power mode computation added | Mechanical PTO remains RE+RC/MR/RMS owner; no RE PTO code change. |
| **RE Terrain V3 / TerraFarm** | Altered dynamic wheel loads, **no new persistent heightmap writer** | RE geometric rut provenance stays independent; any HSS input effect is indirect and needs controlled comparison. |
| **AI/Courseplay, frontloader mods, Manual Attach/IC** | Controlled-player gate, joint moves, selected tool, key bindings/camera | Smoke on exact installed stack, not certification from code comments. |

## Test acceptance plan before an RE design decision

On a *disposable copy* of the save, with **one HSS version**:
1. **Config/preflight:** backup `modSettings`, old ZIP and save; verify log shows HSS 1.1.0.0; capture profile migration and any UI/schema warning.
2. **Vanilla behavior:** John Deere 8R ILS vs axle-pendular small tractor; weight 0/large front ballast, bump, steep incline, field, 22/30 km/h road state; measure wheel/axle/cab effect and FPS.
3. **MR/HSS A/B:** the same 8R and Fendt with MR enabled and HSS OFF/ON; find change of spring/damper, movement/height and front traction. **Critical:** park/switch tractor/hire Courseplay, check whether MR's requested multipliers are truly restored/active while HSS is parked.
4. **Full stack:** RMS, Mud, Reifen present, worn tire and dual front wheels; rolling, sink and pressure changes, interference with articulated steering and varied draft/implement load. Do not use RE Terrain V3 as a test variable initially.
5. **Loader/Fastrac/PTO:** Fastrac rear axle, loader tool with payload and on/off ride control at 6 km/h, unload tool; front PTO on while changing manual height if applicable. Confirm suspension spring and visual motion do not corrupt implement joints.
6. **Save and future MP:** double save/reload of mode/manual height/loaderOff and config; MP must remain **unverified** until server event authorization and state sync are demonstrably safe.

**Adoption gate:** Implement **RE SuspensionControl as opt-in, singleplayer MVP only if** its physical benefit over vanilla+MR/RMS is measured, unique suspension behavior is accepted as an unowned domain, and we can define explicit per-wheel ownership with safe reset and separate physics/visual/loader modules. Prefer an original implementation driven by the observed requirements, not copying third-party material.

**Status:** Research completed, no code changes. A static source audit does **not** prove the user's preferred tractors look/feel correct, and these findings should be revisited after the first comparison log.
