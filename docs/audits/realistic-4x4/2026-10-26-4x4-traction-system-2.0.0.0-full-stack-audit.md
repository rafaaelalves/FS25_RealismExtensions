# 4x4 Traction System 2.0.0.0 — exact-ZIP / RC–RE / MR–Mud–RMS–Reifen audit

**Date:** 2026-10-26. **Input:** exact user-supplied `FS25_4x4TractionSystem(1).zip`. **Author:** Zasty Chalk. **Purpose:** update an earlier FS25_4x4TractionSystem **1.7.0.0** source decision, see [ADR 0005](../../decisions/0005-four-wheel-drive-hydraulic-suspension-selective-reimplementation.md) and [historical 1.4 preliminary](PRELIMINARY.md). **Important comparison limitation:** previous exact **1.7 binary not recovered for byte-by-byte diff** in this audit. Changes below are based on current 2.0 source vs dated, source-derived prior 1.7/1.7.0.1 findings, not a claimed exhaustive 1.7→2.0 diff.

**Decision:** **meaningful positive architectural learning, but do not activate unchanged 2.0.0.0 in the user's established MR + Mud + Reifen + RMS + RC stack.** Optional standalone/disposable-save testing with other differential/radius owners absent is reasonable. **No whole-code absorption**, no speculative RC bridge, no changes to RE physics or PTO, and no ZIP build. The main issue is **competing live differential topology and tire structural radius authority**, not merely imperfect UX.

## 0. Provenance and integrity

- ZIP **170,996 bytes**, SHA-256 **`e66ae578790df3eadc358b68c5cd215a290d50ef844475e4f5c6c2130d5f3320`**; 57 entries incl. directory entries. `testzip()` CRC PASS.
- `modDesc.xml`: **version 2.0.0.0**, **descVersion 95**, author Zasty Chalk. **16 Lua scripts all pass Lua parse** using `texlua --luaonly loadfile`; **26 XML files strict parse**. Many translations and DDS assets plus explicit modular scripts.
- Initial loader `scripts/GlobalInjector.lua` registers/injects `fourWDTractionSystem` via `TypeManager.validateTypes` for all `Drivable + Motorized` types, then filters at vehicle load. It dynamically loads decision, vehicle classifier, persistence, UI, CTIS, and six event/control modules.
- Web context: published earlier [KingMods v1.7.0.1](https://www.kingmods.net/pt/fs25/mods/81736/sistema-de-tracao-4x4-realista) and [public 1.7 notes](https://www.huntersformods.com/fs25/mod/bb25a82b/sistema-de-traccion-4x4-realista). Current exact **v2.0.0.0 ZIP** is authoritative: source comments still label parts `1.5`, `1.7`, `2.3`, `2.4`, and these are **not dependable package versions**. Public pages or mirrors are not exact-ZIP digest attestations.
- No license allowing copying into RE/RC found. Prior author notes prohibit reuploading without permission. Learn from patterns, implement independently.

## 1. Functional inventory / version evolution

**Substantive expansion from prior tractor-focused design:**
- Modular `FourWDVehicleClass.lua` categories: tractor, truck, car, UTV, loader, telehandler, harvester, generic; configurable `switchable`, `permanent`, `fulltime`, `tandem`, `rwd` architectures; primary driven axle and front/rear wheel-group detection.
- `DriveModeConfig.lua` class-specific speed, lock and mode limits; configurable vehicle-pattern overrides and transmission-derived tractor mode classification (`manual` / `semiauto` / `auto` / `smart`).
- Decision in separate `FourWDTractionModel.lua` consumes real rear/front wheel slip, steering, braking, field position, implement-down state, speed, slope and available draft; hysteresis, launch/brake suppression, steering/speed and hold conditions. `computeDemand` compares modelled tractive demand to rear-axle traction capacity; reads optional Soil & Draft Physics or MR `mrLastForce`; otherwise uses approximations including vanilla **global wetness**.
- `FourWDTractionSystem.lua` applies physical drivetrain state to GIANTS: server controlled `removeAllDifferentials(motorizedNode)` + `addDifferential(...)` from `spec_motorized.differentials`, replacing torque ratios / max-speed ratios per requested state; throttled rebuild at **120 ms minimum**. Fallback `updateDifferential`; no stable RMS-owned request API. Also performs CTIS/manual tyre pressure by **writing `wheel.physics.radius`** down to 96.5% of a captured current baseline; native `WheelVisualPartTire.update` wrapped to add visual morph.
- VCA (Vehicle Control Addon) detection permits **command VCA**, **yield**, or **ignore**. In command mode uses `vcaSetState` keys and yields actual differential writes to VCA; good **capability-level handoff** idea, but it is only implemented for **VCA, not RMS**.
- Custom `FourWDUI.lua` presentation library with nine-slice/ring/pixel reusable primitives, virtual height coordinates, input hitboxes, cursor/camera management, cleanup. `FourWDWindow.lua` displays top-view driveline topology, contextual axle locks, pressure bars, per-vehicle telemetry and settings. The separate `FourWDTexts.lua` and translations are meaningful UX work; source presence does not validate responsive UI/gamepad/full-scale runtime.
- Extra per-unit showroom upgrade `FourWDAutoUpgradeConfig.lua` offers `semiauto`→`auto` for eligible named vehicle profiles at **6,500 game currency**. Dynamic specialization injection is global; consider shop conflicts before installation.
- Per-save `FourWDSaveState.lua` identifies vehicles by `uniqueId`, serializes mode, diff state, CTIS and counters; `FourWDAutoStateEvent` broadcasts telemetry/levels; other events request/confirm controls. `onlyPlayerVehicle=true` yields to AI and resets physics when no player controls the vehicle; beneficial mitigation but can trigger handback/ownership hazards.

## 2. Source findings / severity / evidence

### 4WD20-01 HIGH — direct physical differential-topology ownership competes with RMS, and with RC's MRRMS metadata synchronizer

`rebuildDifferentials` at `FourWDTractionSystem.lua:958-997` executes `removeAllDifferentials(node)`, loops through the vehicle's `spec_motorized.differentials`, resolves wheel shapes and `addDifferential` **for every differential** (not only its target). It also calls `updateMotorProperties`; `flushDifferentials` can repeat this at intervals while ramps or slip-biased torque ratios move. RMS 0.12 has its own drivetrain graph / fault lifecycle, restore and reconstruction operations. RC `MRRMS` explicitly reconciles MR's driven-wheel set on RMS handback/rebuild, but has no evidence of tracking a third topology writer. Thus last writer may defeat RMS faults, topology/indices, or MR wheel metadata. **Source-confirmed same-physical-resource ownership; effect not observed in game.** A v2 refactor of *decision policy* does not make its actuator safe with RMS. No version allowlist or generic "late load" rewrite solves authoritative graph responsibility.

### 4WD20-02 HIGH — CTIS radius writes compete with Reifen permanent wear, Mud sink and RC structural wheel semantics

`scanWheelRadii` snapshots `pw.radius or pw.radiusOriginal` exactly once (line ~794). `applyTirePressure` sets `entry.physics.radius=entry.r0*(1-(0.035*drop))` and marks `isPositionDirty`. `releaseToGame` restores **`entry.r0`** when AI takes over / player leaves (line ~1392). Reifen 1.2.2.70 exposes its authoritative structural worn radius; RC `MRTireWear.getPermanentStructuralRadius` / `MRMud.getStructuralRadius` intentionally distinguish permanent tire wear from temporary Mud sink and inflation. Restoring a stale `r0` can overwrite a later Reifen wear progression or another temporary effect. The source comment even prescribes writing to "win tug-of-war" with Mud/TTD — **not a compatibility protocol**. The reduction from the old 15% to 3.5% and split pressure-from-SoilDraft are physically more plausible values, but do **not** resolve owner collisions.

### 4WD20-03 HIGH — inconsistent authority for vehicle-scoped MP controls (Lua harness reproduced)

`FourWDToggleEvent:run` and `FourWDModeEvent:run` check requester's farm against `vehicle:getOwnerFarmId()`. However **`FourWDPressureEvent:run`** and **`FourWDCtisEvent:run`** execute modifications on **every received client→server request without validating caller farm/vehicle control**, then broadcast to others. In isolated `texlua` stub with server connection from farm 1, vehicle farm 2, pressure request set `manualTarget=0.15` and broadcast; CTIS request set `ctisPresetRoad=true` and broadcast. The same source-derived mode event rejects the other-farm change. This is an **authorization omission reproduced in the relevant event handlers, not a verified live-game exploit**. No production MP acceptance without fixing upstream or obtaining trustworthy GIANTS-level authorization evidence.

### 4WD20-04 HIGH — some 6×4 trucks can be classified as switchable rather than tandem

`FourWDVehicleClass.analyseDrivetrain` sets truck `layout="tandem"` **only if both examined differential subtrees contain no steering wheels** (`noSteerBoth`). Normal steered-front 6×4 chassis can have driven subtrees with steerable wheels, depending on actual topology; `DriveModeConfig.layoutPatterns={}` defaults empty. Isolated source harness: 3-wheel representative layout, **one steering front and two nonsteering rear, truck category -> `switchable`**, same graph with two nonsteering subtree sides -> `tandem`. This is a fragile inference (not a universal truck behavior proof). Make actual differential graph, axle position and number of driven rear axles the authority, not the absence of steering alone.

### 4WD20-05 MEDIUM/HIGH — all-compatible dynamic injection and physical graph freshness

The mod dynamically adds specialization to all motorized drivable types before vehicle-specific category/exclusion checks. It caches central position, side sets, and baseline `spec_motorized.differentials` after scanning. Another mod that modifies vehicle differentials later (RMS, MR, specialty drivetrain mods) may invalidate layout/index semantics without a subscribed topology generation counter. The source has physics re-entry and VCA handoff logic; these are positive lifecycle mitigations, **not a general RMS differential graph contract**. Unsupported 2-track, hydraulic independent drive and articulated equipment require precise per-machine test beyond shop category strings.

### 4WD20-06 MEDIUM — global wetness and duplicated traction-demand predictor

`FourWDTractionModel.groundWetness` calls `weather:getGroundWetness()`. It optionally reads `mrLastForce` and SoilDraftPhysics data, but does not consume RC normalized **Mud local physical wetness** or MR/Mud authoritative sink/wheel resistance. `computeDemand` uses an independent simplified rolling/slope/soil-grip predictor, which is reasonable as a **policy signal** only when provenance and units are understood; it should not become a **second traction solver**. In our current stack, steering/brake/slip sensor decisions could be ported conceptually as read-only. Favor RC-provided consistent sensor snapshots with source/age tags.

### 4WD20-07 MEDIUM — global HUD and camera hooks can overlap UI mods

`FourWDUI.lua` installs global `VehicleCamera.zoomSmoothly` and `PlayerInputComponent.onInputZoomInOut` overwritten wrappers to suppress zoom while modal window is open. It changes camera `isRotatable`, player input locks and mouse cursor state on show/close. This is a valid interactive design concept but may conflict with DashboardLive, HSS cab view, vehicle cams, Interactive Control and other windows if modal lifecycle is interrupted. Conditional restore and texture deletion are positive; verify actual GUI owner and multi-map lifecycle before adopting a similar control pattern.

### 4WD20-08 MEDIUM — speed limits/drive mode assumptions are not universal hardware facts

The class tables embed generic engage maxima (20 km/h tractor, 30 truck, 80 car), automatic work triggers, and locked center bias. These are user-configurable gameplay heuristics, not model-specific hardware specifications. Some powered harvesters use hydraulic final drives and have different controls; 4-track vs 2-track machines need distinct physical APIs. Per-vehicle capability evidence and verified gear/diff topology should supersede broad presets. The shop upgrade for automatic mode adds gameplay choice but does not prove the real tractor can acquire such an upgrade.

### 4WD20-09 MEDIUM — persistence/telemetry and MP gates

Sidecar stores per-vehicle `uniqueId` and control state, but changes to RMS diff construction, vehicle sale/reset, AI takeover and late join are not physical revalidation. Setting `onlyPlayerVehicle` relinquishes differential/radius authority when a worker controls the machine; `releaseToGame` restores **cached** baselines (4WD20-02). Client state broadcasts use thresholded intervals (150 ms for discrete, 1000 ms for analog), useful bandwidth reduction. The owner's `isMasterUserConnected` UI guard isn't per-connection authoritative setting sync. Save/load and MP test are required; a declaration of MP support is not a proof.

### 4WD20-10 LOW/MEDIUM — provenance hygiene

Internal comments refer to `v2.3`/`v2.4` techniques in a `2.0.0.0` ZIP, and event file banners still say `1.7.0.0`. These are not evidence of malformed ZIP or malicious edits; package version and SHA are authoritative. They do justify auditing the exact code instead of relying on comments or changelogs.

## 3. Stack ownership crosswalk

| Stack owner | Interaction in v2 | Source decision |
| --- | --- | --- |
| **RMS 0.12 + RC MRRMS** | competing real differential graph reconstruction; potential last-writer and driven-wheel state drift | **Do not combine as-is**. RMS remains graph owner. Seek an RMS-owned command/capability API before adding an RE policy client. |
| **MoreRealistic** | v2 reads `mrLastForce` and GIANTS wheel slip and rewrites native differential graph below MR; MR wheel-drive caches can become stale | Read-only source signals may be reused if stable. Do not add a third gear/drivetrain mutation owner. |
| **Mud 1.3.7** | independent pressure/radius adjustments and local wetness; v2 reads global weather wetness, not Mud local | Conflict risk. No duplicate physical traction correction in RE; no unconditional RC tire patch. |
| **Reifen 1.2.2.70 + MRTireWear** | permanent structural tire radius can be overwritten by v2 snapshot/restore/ramp | **High** source-verified overlapping writable field. Requires one authoritative wear/pressure/sink composition contract. |
| **RE PTO V1.6** | no new PTO shaft ratio / torque/gear physics; UI/policy architectural lessons could support future instrumentation | No direct PTO patch. |
| **RE terrain V3 / spatial history** | 4WD decisions/wheel drive change wheel loads/slip, hence input to Mud/RE ruts; no direct `TerrainDeformation` heightmap writer | No direct terrain writer collision; altered wheel behavior invalidates A/B comparison of rut depths. |
| **AI/Courseplay/AutoDrive** | user-only physics default returns to native/RMS baseline upon worker possession | Good intent; risk of graph/radius restore to stale pre-wear/modified snapshots. |
| **HSS and VCA** | HSS indirectly touches load/height/suspension; VCA has explicit delegation modes | **VCA delegation = strongest constructive integration precedent**, but not validated as equivalent to RMS provider. |
| **HUD/UI modlist** | custom draw/input and global camera zoom wrappers | Isolate for test only if actively installed, not generic RC integration. |

## 4. Evidence and isolated checks

- ZIP CRC PASS; **16/16** `loadfile` syntax PASS and **26/26** XML parse PASS.
- `FourWDPressureEvent.run` isolated mock: foreign-farm actor changed `manualTarget=0.15`; server broadcast count incremented.
- `FourWDCtisEvent.run` isolated mock: foreign-farm actor set `ctisPresetRoad=true`; server broadcast count incremented.
- Control sample `FourWDModeEvent.run` isolated mock: foreign-farm actor denied, `driveMode` unchanged, no extra broadcast.
- `FourWDVehicleClass.analyseDrivetrain` isolated three-wheel/fake-driveline example: `truck + steered front + two rear driven` returned `switchable`; nonsteered subtree sides returned `tandem`.
- No GIANTS runtime, actual wheel graph capture, slip force measurement, 2× save/reload, full-stack log or multiplayer JIP was performed. **Do not label gameplay behavior VERIFIED.**
- Differential/radius conflict conclusions are grounded in **overlapping writes and missing ownership negotiation**, not a reproduced live stack crash.

## 5. Learnings / selective functional adoption options

**Most immediately reusable principles (no code port required):**

1. **Decouple sensors → capability-filtered policy → owner-specific actuator → observed physical state → HUD.** `FourWDTractionModel` is a useful example of separating model decisions from implementation; VCA delegation demonstrates an actual policy/actuator split. For our stack, actuation should remain **RMS-owned**, and RC might provide a versioned read-only sensor or optional command adapter only with upstream API and runtime evidence.
2. **Vehicle powertrain capability matrix**, not blanket classes: physical differential topology, primary driven axle, permanent/AWD/tandem, supported lock capability, speed/usage bands, pressure hardware and AI ownership. Report `SUPPORTED`, `READ_ONLY`, `UNSUPPORTED` per vehicle. Vehicle-type heuristics can seed detection but must not impersonate real hardware.
3. **Telemetry with reason codes:** slip per axle, current demand, lock request, actual center/axle state, selected automatic mode, active vs unsupported hardware, hours and decisions. This is useful both for debug and immersive RE user-facing feedback. UI should distinguish a request from a physically confirmed differential change.
4. **Presentation patterns for the RE PTO UI:** composable self-contained 2D drawing primitives, status schematic tied to telemetry, input hitboxes, tabs for "State / Telemetry / Settings," independent translated labels, and a lifecycle-bound cursor. This is a *strong* learning opportunity given the user's interest in better UI, but asset and source licenses preclude copying.
5. **Steering/brake/launch gating, hysteresis and reason priority** are testable *pure policy* functions, not necessarily a new dynamics simulation. Differential automation should respond to RC/MR/Mud actual state and avoid unnecessary torque/friction writes.
6. **MP event authorization:** validate user/farm/control in *every* client→server operation, including innocuous-looking pressure/UI requests. Server should confirm canonical accepted state; preserve single owner for physical drivetrain.

**What NOT to absorb:** `removeAllDifferentials` engine graph replacement, full per-frame-radius CTIS behavior, assumed pressure→radius based on one saved `r0`, generic every-drivable injector as a promise that every type is supported, duplicate traction coefficients, or unlicensed Lua/UI assets.

## 6. Test recommendations, scope and admission

**For current gameplay stack:** keep RMS/MR/Mud/Reifen/RC as existing physical owners. Do **not** add this unchanged v2.0.0.0 to the same save alongside RMS and Reifen. No current RE code or RC bridge is justified to paper over whole-graph rebuilding and wheel-radius write collisions.

**If exploring v2 as specialist:** use cloned disposable save with a single known tractor and no RMS/Reifen/Mud first, proving 2WD→4WD and axle lock affect torque/wheel speeds; then compare individually with MR, and with VCA in `command` mode. Treat outcomes as experiments, not promotion. For 6×4 truck, validate actual `spec_motorized.differentials`, front steering and tandem detection; high-priority because test reproduced wrong classification on a representative topology. Test client→server pressure/CTIS permissions on a dedicated test server (do not do this against other players' vehicles).

**If contemplating future functional adoption:** first inventory which RMS 0.12 drivetrain commands already provide AUTO/2WD/4WD/diff-lock and wear failure states. If an ergonomic auto policy gap remains, pursue upstream RMS API or narrow RC mediation. Prototype *read-only decision reasons* + RMS request first, leave physics with owner. When adopting UI patterns, start with PTO HUD (separate scoped UI workstream), not new tire or differential physics. No reason to rebase current terrain-recovery experiment on v2 changes.

**Status:** source audit and design recommendation only. **No runtime code, tests, version gates or ZIP build produced.** Store exact checksum and keep original 1.7 decision, but update it with the v2 positive policy/UI modularization and stronger evidence of pressure/MP/categorization failure.
