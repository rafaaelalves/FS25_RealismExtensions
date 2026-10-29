# Etrigo Hand Throttle 1.4.0.0 — full-stack source audit against RE PTO and RC/MR/RMS

**Audit date:** 2026-10-29. **User-supplied ZIP:** `Etrigo_HandThrottle.zip`, **18,815 bytes**, 5 entries, SHA-256 **`6eac9bcf49be641af122e3be30deebc77cb56f5308e63fd40f49a0e7df1e0934`**. CRC PASS; all three Lua files parse via `texlua`; XML parses. Manifest: Etrigo, `1.4.0.0`, `descVersion=104`, multiplayer declared. [Official release v1.4.0.0](https://github.com/etrigo1/Etrigo-FS25-HandThrottle/releases/tag/v1.4.0.0), 2026-10-24 19:17 UTC: downloadable asset same name/size as supplied ZIP; no independently published hash to prove byte-for-byte official identity. [Source at release tag](https://github.com/etrigo1/Etrigo-FS25-HandThrottle/blob/v1.4.0.0/scripts/HandThrottle.lua) and [README](https://github.com/etrigo1/Etrigo-FS25-HandThrottle/blob/v1.4.0.0/README.md). No license allowing code/assets reuse found in package or tag.

**Evidence classification:** static exact ZIP and independent Lua harness verified; no live FS25, MR/RMS integration, client/server or savegame field-test performed. **Decision:** learn/consider selective reimplementation of a *unified operator engine governor*, **not direct simultaneous production installation** with RE native PTO hand throttle; no RC compatibility patch or build. The user-provided updated RMS package is excluded from this audit by request; RMS remains separate next work.

## 1. Functional architecture and precise semantics

| Mode | Executable path | What is controlled |
| --- | --- | --- |
| Manual **percent** | `HandThrottle.updatePedal` / `Drivable.updateVehiclePhysics` | A minimum accelerator input: `axisForward=max(axisForward,spec.pedal)` on nonnegative input, pedal ramps at most 1.5 units/sec to selected percent. Does not enforce fixed RPM; a loaded motor can slow naturally. |
| Manual **RPM** | PI servo in `updatePedal` | Uses `base=(target-minRpm)/(maxRpm-minRpm)`, normalized error `(target-actual)/rpmRange`, `KP=1.5`, `KI=0.8/sec`, integral anti-windup when saturated or overridden, pedal rate limit 1.5/sec and gear-change freeze. It **actively changes input throttle based on measured RPM**. It does not synthesize power/fuel/torque. |
| CVT / auto **speed** | `applySpeedMode` | With no operator axis, `motor:setSpeedLimit(min(existingLimit,targetSpeed))` and returns `axisForward=1`. Separate forward/reverse target state; current speed on activation, 1 km/h stationary. This is a speed cap + full input, not an independently modeled CVT. |
| All gears **RPM limit** | `applyRpmLimit` and global `VehicleMotor.getRequiredMotorRpmRange` wrapper | Sets `motor.handThrottleRpmLimit`, clamps requested range maximum and then minimum to maximum. Neutral positive pedal is also scaled. This **does not itself prove a hard physical engine overspeed limiter for all MR/GIANTS paths**. |

Architecture: `RegisterHandThrottle.lua` prepends `TypeManager.validateTypes` and inserts specialization on all `Motorized+Drivable` vehicle types except Locomotive. `HandThrottle.lua` globally wraps `VehicleMotor.getRequiredMotorRpmRange` (scope via per-motor field); registers `Drivable.updateVehiclePhysics` override calling `superFunc`; onUpdate is client-side pause for braking and excessive player speed; motor physics runs server-side. Mode steps default 5%, 50 RPM, 1 km/h; optional analog lever accumulates input at 5 steps/sec with 0.1 deadzone, sending only step transitions. Settings in per-player `modSettings/Etrigo_HandThrottle.xml`; one-line movable HUD and button repeat. Vehicle mode/target/paused state is streamed and event-replicated but **not saved across game sessions**; on operator exit or engine stop the mod moves active mode to OFF retaining `lastMode` for the current session.

## 2. Source-tested findings

**HT-01 HIGH: independent engine-RPM policy overlaps RE native PTO and RC MRPTO.** RE `PTOModel.handThrottleRpm` creates a target **minimum** engine RPM from operator percent; RE `PTOPhysics` scopes GIANTS `getRequiredMotorRpmRange`, and RC `MRPTO` scopes MR `controlVehicle` while preserving genuine PTO torque, power, fuel and under-speed response. Etrigo supplies a distinct closed-loop throttle servo and a global **ceiling**. They are not interchangeable. In a Lua stub with another controller requiring range **1700–2400 RPM** and Etrigo limit=1200, wrapped output is **1200–1200 RPM**, eliminating the prior minimum. The actor that wins in actual MR depends on hook dispatch/order and per-instance scoped overrides. **Never promise both motor requests are respected** without a priority and ownership contract.

**HT-02 HIGH: unattended PTO lifecycle differs deliberately.** Etrigo `onLeaveVehicle` and `onStopMotor` pause its own mode unconditionally, including RPM. RE ADR 0006 deliberately keeps a configured hand throttle active for **unattended, non-AI stationary PTO** after operator exit. Lua stub confirms Etrigo mode RPM=2 becomes OFF=0 and lastMode=2 on exit. This is intended behavior in Etrigo, not a universal Etrigo bug; its mode/exit policy conflicts conceptually with RE. A unified owner may choose HOLD for eligible stationary PTO and PAUSE for travel-speed mode, without changing worker auto-governor.

**HT-03 HIGH: HandThrottleEvent lacks request authorization.** `HandThrottleEvent:run` forwards incoming client request from server to others **before** checking the vehicle and only checks `getIsSynchronized` plus setter existence before applying state. No farm/controller-user/connection validation. Isolated Lua harness: fake requesting client farm=1, vehicle owner farm=2, event percent=91, mode=1 -> server applied 91 and broadcast. This proves an unguarded handler path, **not a real network exploit**. RE `PTOStateEvent` already contains per-controller user authorization and would be a stronger precedent. Do not deploy on untrusted public multiplayer without upstream fix.

**HT-04 MEDIUM/HIGH: speed cap may outlive mode.** `applySpeedMode` lowers `motor:setSpeedLimit` but no explicit saved-old-limit restoration on OFF/pause/exit. If engine or other mods do not replace the speed limit on subsequent ticks, a low cap may persist. Source risk, **not proven in FS25**. Test target=13, switch OFF, then full acceleration to 25; repeat with Courseplay/AutoDrive and MR. No speculative global reset patch.

**HT-05 MEDIUM: RPM PI tuning and transmission categorization.** Gains are universal; feedback is `motor:getLastMotorRpm()`, not explicit MR physical/non-clamped telemetry. Gear-change freeze and integral handling are positive. Saturation is expected under insufficient engine torque and must not be compensated with synthetic power. It classifies manual transmission using `forwardGears/backwardGears` and `getUseAutomaticGearShifting()`, which may not represent every MR CVT/hydrostatic transmission or non-tractor machine injected. Validate one manual and one CVT before claims of universal correctness.

**HT-06 MEDIUM: local client settings vs authoritative physics.** Per-user mode enabled/step/brake and memory policies are client-local; motor and event state are global. Client requests are not validated against server mode permissions. A future engine control contract should separate UI/keybinding preferences from authoritative physics and avoid unauthorized client-side changes.

**HT-07 LOW/MEDIUM: cursor / HUD composition.** The movable HUD is a useful example of minimal information and optional analogue control, but manually toggles global mouse cursor, which could conflict with other UI modal windows (RMS, Interactive Control) during interrupted cleanup. No crash proven.

## 3. Isolated harness results (not game validation)

- CRC, Lua parse 3/3 and XML strict parse: PASS.
- PI: actual motor=1400 RPM, operator target=1800 RPM, dt=100ms, pedal starts at zero: `updateVehiclePhysics` produces pedal/axis **0.15** (rate limited); retained integral accounts for reset. This confirms source PI, not engine steady-state RPM.
- Combined range hypothetical: `getRequiredMotorRpmRange` [1700,2400] and Etrigo limit 1200 -> **[1200,1200]**, confirming conflict policy in request domain.
- Client-origin vehicle event on other-farm vehicle: sends one broadcast and changes server mode=1/percent=91 without farm check in source handler.
- Operator exit: RPM mode→OFF with paused lastMode retained.
- Speed mode target 13 km/h: `axisForward` becomes 1 and motor speed limit set to 13. No verification of restoration after OFF in GIANTS.

## 4. Stack ownership matrix

| System | Relationship and action |
| --- | --- |
| **RE native PTO V1.6** | Owns PTO shaft gear selection, persisted hand-throttle **RPM floor**, AI/unattended mode. Etrigo doesn't select PTO ratio or identify actual connected consumers. Simultaneous RPM/ceiling commands conflict semantically. **Avoid direct primary-save addition.** |
| **RC MRPTO / MR** | Converts RE hand floor to MR canonical engine management without removing PTO torque or fuel load; Etrigo wraps GIANTS motor-range and direct accelerator input. No general RC workaround without measured dispatch and source-specific arbitration. |
| **RMS 0.12 baseline** | Owns engine/mechanical faults/wear. Control policies should never make broken engine/clutch artificially work. Newly uploaded RMS is **not audited yet**. |
| **Mud, Reifen, terrain** | No direct writes to wheel radius, friction, terrain, wetness, or physical rut state; altered traction can arise indirectly from acceleration. No terrain/RC bridge required. |
| **RH, Courseplay/AutoDrive** | May share motor speed-limit and driver/AI control pathways with Etrigo. Pausing when player exits is helpful but old speed-limit restoration is unproven. |
| **MP / RE PTO events** | Unlike RE controller/farm authorization, Etrigo event handler lacks server ownership verification. |

## 5. Learning: a real, selectable expansion for RE, not another rejected idea

**Architectural option:** a unified `OperatorEngineGovernor` / `EngineControlPolicy` service above GIANTS/MR with explicit channels: `throttleLeverPercent`, `requestedMinRpm`, `requestedTargetRpm`, `requestedMaxRpm`, `currentPhysicalRpm`, `activeOwner`, `requestSource`, `onExitPolicy` and hardware support. PTO becomes a consumer/request origin, **not a second separate owner**, while engine physical torque/load/fuel remain GIANTS/MR's responsibility.

**Near-term best experiments:** one clean-room PI prototype behind a switch, comparing same manual tractor + PTO implement under constant and variable material load against **existing RE hand-RPM floor**, measuring actual RPM, throttle/pedal, MR PTO torque/load/fuel, over/under speed and stability. Do not run two PI governors simultaneously. An RPM ceiling must define arbitration when ceiling < floor, especially while PTO nominal demand is active. Separately evaluate percent lever, configurable +/-50/100 RPM and analog binding; lightweight UI states should distinguish target vs physically observed motor and shaft RPM.

**Important non-adoptions:** do not copy proprietary code/UI, whole-mod specialization, unvalidated global RPM-limit hook, speed cap that might leak, or unguarded MP event. An implementation of the above *ideas* should be independently authored and feature-gated. If RE's current MR-controlled floor already behaves realistically under PTO load, a second PI may not be worth its complexity; accept empirical outcome.

**Minimal standalone A/B on cloned save:** (1) Etrigo solo, manual tractor, neutral/field/PTO load modes and exit; (2) RE PTO alone, same tractor/crop/load; (3) CVT speed mode and OFF speed-limit recovery; (4) no two owners in the same first trial; (5) authorization-aware dedicated MP only after upstream event fix; (6) watch MR/RMS input, fuel and temperature, AI handback.

**Decision:** **research valuable and selectively absorb concepts**, external mod optional for isolated test only. **No RC/RE production code modified, no build, no version change, no merge.** RMS updated ZIP remains untouched pending next independent audit.
