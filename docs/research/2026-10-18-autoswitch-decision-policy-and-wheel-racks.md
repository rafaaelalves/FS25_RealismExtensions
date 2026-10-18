# AutoSwitch 1.0.0.58 — RE research: wheel-set inventory, RMS AUTO policy and surface actions

**Date:** 2026-10-18. **Mode:** DESIGN-ONLY, not a feature, no code or version change.  
**Primary source:** exact uploaded `FS25_AutoSwitch.zip`, SHA-256 `ee20772aeddde5c567d99f004f9282541b7d50a634c7146fc21ac7cf38ce3c25`, modDesc v1.0.0.58. [Companion RC full-source audit](https://github.com/rafaaelalves/FS25_RealismCompatibility/blob/docs/audit-autoswitch-1.0.0.58-2026-10-18/docs/audits/2026-10-18-autoswitch-1.0.0.58-full-stack-and-architecture-audit.md). Source author `Fabien`; public [KingMods v1.0.0.5](https://www.kingmods.net/en/fs25/mods/82844/autoswitch) attributed to `bibifr`. Version/public ZIP equivalence not verified.

## Decision

Do **not** import AutoSwitch or its generic `Arbiter`. Its embedded veto registry and wheel/soil/motor physics writes overlap current MR+Mud+Reifen+RMS and RE ownership, and it mandates DDP+TTD, both already rejected for target stack adoption. Learn from the **requirements and operator workflow** instead.

## 1. Physical reusable wheel assemblies (promising, later)

This mod solves an important part of a previous RE capability discussion: it has **real front/rear wheel racks, player-on-foot initiation, in-game per-tire mounting time, storage inventory and a replacement of the vehicle's wheel configuration** (not a free/instantaneous purchase). A tractor can retain an owned set for reuse. This is a compelling basis for an eventual **vehicle parts inventory / configuration workshop** *concept*.

Actual implementation is not suitable to copy:
- `AS_DualRack:doSwap` serializes the tractor and attached vehicles into an ephemeral save XML, removes original physics, globally `simulatePhysics(false)`, asks `VehicleSystem` to reload all affected vehicles, then deletes the originals on success. On failure it tries to re-add original physics. This is a whole-vehicle transaction with many foreign mod-owned states; crash-safe atomicity is unverified. The author explicitly restricts wheel swaps to singleplayer.
- It stores original/target `wheelSaveId` in `AS_DualRack` sidecar keyed by vehicle unique ID; front/rear racks store counts, a job hides/reveals wheels over 15 in-game minutes per tire, and the tractor is locked against entry/tab/AI until done.
- The UI requires the tractor in a marked service zone and a matching manufacturer/configuration. It does **not** create arbitrary new wheel configs that don't already exist in the vehicle XML.

**Original RE design direction** (after recovery milestone):
1. **Inventory item:** a wheel-set asset with brand, axle, diameter, width, rim/tire pairing, health/wear (Reifen), pressure (VTP/Mud if available), owner, stored position, exact paid cost and current reservation; ballast weights similarly reusable, but other vehicle structural configurations require a distinct rule.
2. **Vehicle adapter:** query native GIANTS configuration mechanisms before choosing any save/reload strategy. If reload is unavoidable, require stable identity mapping of motorized/attached graph, safe preserve/restore of all mod data, no pending repairs/jobs and explicit failed-state rollback. One transaction / one side-effect owner.
3. **Order/workshop state machine:** DRAFT → RESERVED → WAITING_SERVICE → APPLYING → VERIFIED → COMMITTED; ABORTED/ROLLBACK on any failure, with persisted job record. No duplicated wheels or overwritten tractor, no inventory disappear on cancel.
4. **Physics authority:** Reifen owns wear/structural radius; Mud owns tire pressure/sink response; MR owns wheel friction; RMS owns drivetrain and maintenance. RE acts only as **item registry and service workflow**, not independent physics.
5. **MVP:** a singleplayer tractor with two authentic shop wheel configurations, an owned spare set, a rack and one job. Verify save/reload and vehicle identity; expand only after this passes. No multiplayer promise before server authoritative item ownership, atomic save and synchronised job state.

**Why prioritize later?** It is a valuable independent feature but not a solution to current Terrain V3 no-op recovery. Architecture and tests can be planned now; implementation shouldn't displace the terrain recovery milestone.

## 2. AUTO diff/4WD control as recommendation (potential future RMS partnership)

AutoSwitch infers which axle is powered via `spec_motorized.differentials`; chooses 4WD on field/natural material and 2WD on asphalt/concrete; engages rear lock before front at distinct slip thresholds (~15%/~30%), with unlock thresholds around half, steering angle interlock, dwell timers, manual override, and return to AUTO on AD/CP handover. It uses EnhancedVehicle private `vData.want` as actuator.

The **policy** (not the EV actuator) is valuable and aligns with previous Realistic 4x4 traction research. For RE:
- First ask whether RMS 0.12 (current physical diff/park owner) has an already supported public command to request drive mode and lock. If absent, propose to upstream an explicit **request/acknowledge** API; do not write EV `vData.want`, GIANTS differential arrays, or RMS private graph.
- **Inputs**: read-only driven-wheel slip *relative to local tire ground velocity*, road class, axle wheel load, steering angle/turn radius, speed, mode and available locking hardware; confidence unknown → **no change**.
- **Recommendation output**: a reasoned `4wd_request`, `front_lock_request`, `rear_lock_request`, `release`, or `hold`, plus evidence and a denied-reason state; the actual gearbox/axle shift remains RMS's owner.
- **Policy**: debounce/hysteresis; respect manufacturer-safe engage speed, steering, driveline windup and torque under load; manual override persists until explicit operator/AI handoff, never auto-unlock a player's manual lock without policy.
- **Testing**: 2WD/4WD across surface changes, two slip thresholds, left/right local wheel slip in curves, disabled RMS graph, manual mode, Courseplay takeover, engine off/reload, client request permissions, actual wheel activation and sync through RC `MRRMS`.

This is **future scope**; not a reason to revive EnhancedVehicle driveline authority concurrently with RMS.

## 3. Further lessons

**Surface and tyre state** — AutoSwitch leverages Mud `FieldLocalWetness.getEffectiveWetnessAt` and per-wheel profiles, computes slip relative to ground speed and derives surface classes for AD speeds. These are good **observational signals**, but `AS_WetGrip` additionally writes direct wheel friction and adds numerical diff lock/VTP bonuses and a worn-road tire grip increase. Those are **not** appropriate RE physics. If per-wheel surface metadata is missing, extend current RC StateContract/TerrainResponseModel *read-only*, without parallel state caches.

**Physical wheel-track decals** — 60,000 historical points at 0.5m sampling saved to a sidecar and redrawn in batches; these are **visual traces, NOT structural ruts**. Their memory/serialization budgets and native artist's effects can inform a future optional visual persistence module, but no coupling to RE `SpatialHistory` or `preDeformHeightM`.

**Agriculture/vegetation** — `AS_GrassTrample` uses contact width, speed and wetness to regress grass growth stages or cut vegetation, `AS_SeedProtect` prevents unintended destructive seed effects, `AS_DirectResow` updates native sowed area. Worth a discrete vegetation/field-damage owner audit when current terrain work is stable; take care not to negate authentic crop damage, plant diseases or soil compaction. Any future RE implementation must be independent and calibrated to actual farming consequences and map growth mechanics.

**Mud drag on passive wheels** — AutoSwitch claims to restore Mud drag on unbraked trailers with a `brakeFactor` wrapper and private `__mpMudBrakeExtra`; this might expose a true realism gap. But first instrument wheel forces under MR, Mud and Reifen on a loaded trailer. Never add synthetic drag without force/numerical proof.

**Automatic VTP pressure** — field/road + AI/manual handover is a neat controller, but VTP (if selected) must own actual tire pressure and Mud/Reifen/MR must own wheel response. Avoid separate `frictionScale` or tire pressure rewrites in RE.

**Global arbiter** — AutoSwitch uses `Utils.overwrittenFunction` interception, veto lists for MR/UseYourTyres/DDP and temporary global Mud/TTD writes. Our RC per-bridge contract/explicit confidence/fail-closed ownership already solves a more appropriate problem. There is no reason to copy this implementation or widen RC into a generic mod manager.

## Proposed ordered next steps

1. **Current priority unchanged:** RE terrain V3 vertex-aware recovery tests and calibration; no new features coded for this study.
2. **Later, one research milestone**: verify RMS command/authority contract and compare AutoSwitch AUTO policy with Realistic 4x4 source.
3. **Later, separate parts milestone**: model wheel inventory and transaction state machine; test native GIANTS reconfiguration API; small singleplayer MVP if feasible.
4. **Later optional:** vegetation trampling and true trailer drawbar resistance; add only if an observable unowned phenomenon and reproducible test exists.

**Safety and reuse:** The exact ZIP contains no bundled license file; public KingMods page advertises CC BY-NC-SA 4.0 for its older release. Do not import code, UI assets or rack models into RE without confirming applicable reuse terms/attribution and resolving any derivative licensing; prefer clean-room original implementations from source-observed concepts.

**No code or configuration changes** in RE by this research.
