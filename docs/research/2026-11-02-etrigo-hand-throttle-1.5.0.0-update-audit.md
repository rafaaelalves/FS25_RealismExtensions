# Etrigo Hand Throttle 1.5.0.0 — incremental exact ZIP / input ownership / RE PTO audit

**Audit date:** 2026-11-02. **Exact submitted ZIP:** `Etrigo_HandThrottle (1).zip`, 20,792 B, SHA256 **`42d2e6026441e8bbe6017230aa2cea1e9c1fc965f1bf23d1b5a7565b6a419366`**, author Etrigo, modDesc **1.5.0.0**, descVersion 104. Previous exact uploaded `Etrigo_HandThrottle.zip` v1.4.0.0, 18,815 B, SHA256 `6eac9bcf49be641af122e3be30deebc77cb56f5308e63fd40f49a0e7df1e0934`. New archive **six entries, five files**, ZIP CRC PASS; **3/3 Lua compile** (`texlua --luaonly loadfile`) and **1/1 XML strict parse** PASS. **Official release** [GitHub v1.5.0.0](https://github.com/etrigo1/Etrigo-FS25-HandThrottle/releases/tag/v1.5.0.0) dated 2026-10-31 18:37:13 UTC publishes **the exact same SHA256 digest**, confirming user ZIP provenance. Source level only; no actual FS25/vehicle/MP run.

**Historical baseline:** prior detailed [RE PR #70 — Etrigo 1.4 source audit](https://github.com/rafaaelalves/FS25_RealismExtensions/pull/70) remains an unmerged document review at audit time; its [ADR 0006 addendum](https://github.com/rafaaelalves/FS25_RealismExtensions/blob/docs/audit-etrigo-handthrottle-1-4-2026-10-29/docs/decisions/0006-pto-manual-engine-governor.md) is also unmerged. This update should preserve that old audit as the technical PI baseline rather than reprint it or imply it is already on main.

## 1. Exact update

Two files modified, three byte-for-byte identical, no added or removed:
- `modDesc.xml` 7391→7930 B: version to 1.5.0.0; adds cruise/Vehicle Inspector mutually exclusive description; **renames actions** `HT_TOGGLE_MODE/ON/VALUE_UP/VALUE_DOWN/MOVE_HUD/AXIS` to `ETHT_TOGGLE_MODE/ON/VALUE/MOVE_HUD`; merges up/down into **one FULL-axis** action with positive/negative keyboard bindings and hardware-axis support. Users MUST rebind custom keys, previous `HT_*` inputBindings entries will no longer address registered actions.
- `scripts/HandThrottle.lua` 40214→44147 B: three-state input ownership, cruise action muting, updated bindings/callback and unified button/analog logic; no change to the underlying PI gains, getRequiredMotorRpmRange hook, power/torque/fuel or ratio provider.
- **Byte-identical:** `scripts/HandThrottleEvent.lua`, `scripts/RegisterHandThrottle.lua`, icon DDS. The v1.4 multiplayer authorization omission and specialization registration behavior remain unchanged.

Official tag [source compare](https://github.com/etrigo1/Etrigo-FS25-HandThrottle/compare/v1.4.0.0...v1.5.0.0) also modifies three Markdown README/CHANGELOG documents absent from shipped ZIP; never claim docs in new ZIP.

## 2. Input-control semantics and actual source

Explicit `HandThrottle.getIsSystemOn(spec)` is true when **either** `spec.mode ~= MODE_OFF` (active) **or** `spec.lastMode ~= MODE_OFF` (paused). All other actions return to vanilla/Vehicle Inspector only when **both** are OFF: an important UX clarification vs prior 1.4 where pause and complete stop were not consistently treated for cruise input.

- `HandThrottle:onUpdate` runs for current client-controlled vehicle, calls `updateCruiseControlActions(vehicle,isSystemOn)` **even when `spec.mode=OFF`**, and, if the system is active/paused but cruise is on via API, calls `vehicle:setCruiseControlState(OFF)`.
- `updateCruiseControlActions` accesses `vehicle.spec_drivable.actionEvents` with two vanilla action keys `TOGGLE_CRUISE_CONTROL`, `AXIS_CRUISE_CONTROL` and optionally `vehicle.speedControl.actionEvents` with four Vehicle Inspector keys; stores the actionEventId it blocked in `spec.blockedActionEvents`, disables via `g_inputBinding:setActionEventActive(id,false)`, then sets **true** when local system completely releases control. It also reacts to recreated action ids.
- `onRegisterActionEvents` now registers **one** `InputAction.ETHT_VALUE` full axis (keyboard up is positive and down negative). `actionEventValue` branches on `isAnalog`; button processing keys repeat by positive/negative direction, analog accumulates magnitude at up to 5 steps/s with deadzone 0.1. This can support a lever and button without two separate action slots.
- Remaining physical mechanics **unchanged**: manual percent lever, manual PI target-RPM servo, CVT speed cap/full pedal, maximum RPM requested-range limiter; server physics remains `updateVehiclePhysics`. `onLeaveVehicle` still pauses; **RE** intentionally preserves an unattended, non-AI PTO RPM request, hence governor authorities/lifecycle remain incompatible without mediation.

## 3. Reproduced source concerns (tiny texlua harness, not FS25)

**HT150-01 MEDIUM/HIGH — foreign action restoration does not preserve prior state.** `setForeignActionsActive` never queries an action's previous active status before its first `setActionEventActive(id,false)`, but records the id as if it had exclusively disabled that action. When the Etrigo system turns fully OFF it executes `setActionEventActive(id,true)`. In a mocked scenario in which an unrelated mod had *already* disabled the cruise action, Etrigo temporarily blocks and later **forces it enabled**, violating the prior owner's intention. Test reproduced calls `51:false` then `51:true`. This is a **genuine ownership-protocol defect by source**, not an observed FS25 conflict. Correct general design requires state-aware arbitration or an authority/capability contract; blindly remembering an event id is not an ownership token.

**HT150-02 MEDIUM — action events may remain muted if input focus is lost before release.** The muting/restoring call is inside `HandThrottle:onUpdate` *after* `not isActiveForInputIgnoreSelection` early return. `onLeaveVehicle` merely pauses the mode (leaving `lastMode` populated); it does not restore previously blocked action ids. Harness: block id 51, switch complete state OFF, call update with input focus false → no `id:true` restoration. Whether FS25 removes/replaces the inactive vehicle actionEventId during vehicle change must be established in-game; do not assert persistent real-game hotkey loss.

**HT150-03 MEDIUM — rotating/recreated event ids leave stale prior id un-restored.** Source remembers only the latest `blockedActionEvents[actionName]=actionEventId`. Harness: block 51 → vehicle system replaces with 52 → block 52 → release 52, resulting calls `51:false,52:false,52:true`. This is safe if 51 was destroyed/recreated and dangerous if both event IDs remain live; requires actual action lifecycle capture. The strong narrow conclusion is **old id is not intentionally restored**, not a guaranteed live-game defect.

**HT150-04 HIGH for MP — previous unguarded event preserved.** `HandThrottleEvent.lua` byte-identical to 1.4.0.0, previously source-tested to accept and broadcast a client-origin state request without verifying requesting user's controller/farm. No claim of successful live multiplayer misuse. RE `PTOStateEvent.lua` is stronger model with user/controller authority checks. Do not recommend Etrigo unmodified on untrusted public dedicated MP.

**HT150-05 MEDIUM — saved input bindings migration.** `InputAction.HT_*` old names no longer exist in modDesc; existing manually assigned keys will not migrate automatically, although defaults are provided. Player must rebind keys in FS25 Options. Note that copying the old settings XML affects local mode parameters and HUD, **not** the renamed action ids stored in game key bindings.

**HT150-06 MEDIUM — cruise conflict is broader, not the RE PTO conflict solution.** Full cruise exclusivity affects **all manual modes including RPM limit**, and paused mode; this may surprise users expecting a speed controller and RPM limiter simultaneously (intentional Etrigo design). It suppresses native cruise and optionally Vehicle Inspector actions; it does **not** negotiate with RE's PTO governor or MR's load/engine RPM owner. Existing v1.4 `VehicleMotor.getRequiredMotorRpmRange` ceiling/floor and CVT speedLimit restoration question remain. Changing action names doesn't solve dual-controller physics.

### Isolated harness observations

- Confirmed action transition: mode OFF + lastMode 2 (**paused**) mutes native cruise; complete OFF + OFF re-enables it; active mode also mutes.
- Pre-disabled action re-enabled on release (HT150-01).
- Focus-loss early return prevents restore (HT150-02).
- Re-registration id rotation leaves previous id unused (HT150-03).
- All exact 3 Lua sources pass syntax; no game input, gear or physics/MP tests occurred.

## 4. RC/RE opportunity and decision

**Positive design candidate:** explicit operator control states `OFF / PAUSED / ACTIVE`, separating vehicle hand-control from cruise driving policy; one signed continuous input action compatible with keyboard and hardware; compact targeted HUD with requested and observed RPM; canonical `requestedRpmFloor / requestedRpmTarget / requestedRpmCeiling` semantics. These are useful **even if RE never imports the Etrigo PI controller**. On exit, different control domains need different policies: RE unattended stationary PTO **HOLD**, travel cruise **PAUSE**.

**DO NOT copy** global foreign-action setters, UI assets or upstream implementation, and do not introduce a third RPM owner into RC/MR. For RE, implement a **cooperative input-action lease** concept if ever adding direct driving/cab controls: restore only the state explicitly owned by this module, notice other modules' locks, and never unconditionally force foreign actions enabled.

**Runtime gates:** if user wants the Etrigo standalone experience, cloned save, RE native PTO disabled for that vehicle / experiment, manual gearbox RPM under controlled PTO load, CVT speed limit OFF release, pause→OFF and input-action restoration with Vehicle Inspector and another GUI, multiple enter/exit / controller re-registration, check keyboard/gamepad/axis rebind. If public MP, upstream server-side authorization fix first.

**Conclusion:** **update worthwhile for control UX**, no evidence of new physically superior PTO implementation; old RE native PTO preferred as primary stack owner. No RC or RE runtime code patch justified by upstream 1.5.0.0, **documentation-only**.
