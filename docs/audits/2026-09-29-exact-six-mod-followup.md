# Exact-source follow-up — six external mods

Date: 2026-09-29

This document supersedes the provisional source-level parts of the initial six-mod audit. It is based on the exact ZIPs supplied by the user and cross-checked against the completed RC FarmKit/Mud/Reifen ownership audits.

## Source provenance

| Package | Version | SHA-256 |
|---|---:|---|
| FS25_MoistureSystem | 2.0.0.8 | 46b16c68575aed893167e9fb4cb5c120cb5bfee2081554fe14634a5b042600b8 |
| FS25_aiTracks | 2.2.0.1 | b04b46c08c3c84e0b32a73c3f90939dd572db8742cd18e29ac3c8b98c97c3fb4 |
| FS25_RealPhysics_LoadSpill | 1.0.0.0 | f5e6884007b76a00f05fc02a1513d12628f1477bf40fe97c3d294f4d4b6fc2ff |
| FS25_LooseLoad | 1.0.0.0 | 484f42e1ec729bab5931cf0ebc1d2f430163aa90bd9cb88baa1cc0455400913c |
| FS25_Mud_Sprayer | 1.0.0.0 | 154328f69001d159e80d6f014411f4b9e35f96aa49dd351b8de794961b79fd47 |
| FS25_soundExpansionMP | 1.2.0.0 | 51c428cb12d975ee8b7cb555eea4d142b81b0574bc89de63e13c27999b0ca8f4 |

## True AI Tracks

Decision: CANDIDATE_ABSORB into TerrainDeformation. Keep external only until parity is proven.

Exact source confirms a very narrow product: force AI tire-track permission, force WheelPhysics displacement for AI/attached implements, and periodically rediscover/process AI wheels.

Important findings:

- The advertised 150 ms scan fix still appears inverted. The code adds FS dt to lastCheckTime, but compares against CHECK_INTERVAL / 1000, so 150 becomes 0.15 while the normal dt domain is milliseconds. This likely keeps the mission-wide vehicle scan effectively every frame.
- The scan walks every mission vehicle, recurses through attached implements, and traverses wheel collections. RE can avoid this global polling by using one vehicle/wheel deformation pipeline.
- main.lua registers its AIVehicleTracks wrapper twice, but these wrappers are mostly dead/no-op rather than duplicate scan owners: they look for aiGround / aiTracks globals that the actual source does not expose under those names. The effective deformation scan comes from AIGroundDeformation's own listener.
- WheelPhysics displacement methods are globally replaced around captured originals. There is no capability/provider boundary.
- AI inference is broad (isAI, AI specialization, type-name matching, Courseplay/AutoDrive table presence, attachment ancestry).

Architectural opportunity: one RE TerrainDeformation owner can handle player, GIANTS AI, Courseplay and implements with authoritative wetness/slip/footprint state and bounded work.

No explicit reusable-code license was found. Clean-room implementation only.

## RealPhysics LoadSpill

Decision: keep as interim specialist, but rollover/discharge behavior is a strong candidate for later clean-room absorption into a unified loose-material system.

Exact source confirms:

- fill-ratio-aware rollover behavior beginning from 15 degrees and reaching the full curve near 120 degrees;
- 15 degrees of cover protection and cover failure/opening above 60 degrees;
- server-authoritative ground deposition and fill removal;
- approximately 30 percent intentional gameplay loss rather than ground deposit;
- normal discharge speed and discharge presentation length driven by tip-animation progress.

This confirms the RC audit: RealPhysics' intentional-discharge model is materially better aligned with trailer tip state than FarmKit's ground-speed heuristic.

Source defect found: the single spillCheckTimer is consumed inside the loop over supported fill units. Each fill unit adds the same frame dt; whichever iteration crosses the threshold resets the timer. On multi-fill-unit vehicles, one fill unit can repeatedly win that threshold and another can be starved from spill evaluation. The interval gate should be vehicle-scoped before the fill-unit loop.

Dynamic tip flow also performs absolute runtime writes to dischargeNode.emptySpeed and discharge info length, so a future unified owner should expose this as a separate dischargeDynamics capability.

No explicit reusable-code license was found. Clean-room implementation only.

## Loose Load

Decision: do not treat it as a RealPhysics replacement or complement wholesale. It exposes distinct capabilities worth preserving conceptually, but a unified RE system is the cleaner long-term direction.

Exact source confirms:

- rollover spill above a fixed 55-degree threshold with configurable spill rate;
- optional 15-percent remnant;
- only actually deposited material is removed from the fill unit in the normal spill path;
- a closed cover completely prevents rollover spill;
- a separate TrailerOverfill specialization handles full-target overflow and loading into a covered target after a grace period;
- overflow rate follows the source discharge node;
- fill-colored dust and looping spill sound.

The source license explicitly states all rights reserved and prohibits use/copying/modification/publication/redistribution without prior consent. No code/assets may be reused.

RealPhysics and Loose Load disagree on cover physics: finite protection + failure versus absolute containment. They also duplicate rollover ownership, while Loose Load uniquely adds loading overflow and RealPhysics uniquely adds tip-animation discharge dynamics.

Current settings do not provide a clean composition profile for "RealPhysics rollover + LooseLoad overflow": Loose Load has one global core enabled flag plus a separate overfill flag, but no independent rollover-off switch while leaving the rest of the mod active.

Future RE opportunity: LooseMaterialConsequences with sub-capabilities rolloverSpill, loadingOverflow, coverContainment, dischargeDynamics, spillPresentation and materialRules. Research material-specific angle of repose/cohesion, finite cover strength and conservation-first handling rather than copying either implementation.

## Mud Sprayer

Decision: do not integrate it as another wheel-ground owner. Keep MudSystemPhysics as the authoritative wheel/soil particle/contact owner; only reimplement missing presentation if there is a demonstrated visual gap.

Exact source findings:

- mudhook.loadMap replaces g_currentMission.wheelDirt with a new table, which is an avoidable global-state collision;
- wet/dry state is driven mainly by current rain rather than persistent/local physical wetness;
- Mud compatibility reads a coarse mission fieldSinkAmount instead of a per-wheel/per-position provider;
- when Mud is present, its own wet particle system is already suppressed, acknowledging overlapping ownership;
- emitter sizing reads raw/original wheel radius rather than the RC/Reifen/Mud structural-radius hierarchy;
- particle speed is calculated and then capped with math.min(speed, 0.001), which appears likely to be an inverted clamp and can force extremely small particle velocity.

Useful concepts only: dry vs wet spray, soil-contact gating, movement/footprint scaling and contacted-material color. If RE needs them, implement them from Mud/RC authoritative state with original RE assets.

No explicit reusable-code/assets license was found.

## Multiplayer Game Sound Expansion

Decision: KEEP external by default, but stop classifying it as one sound capability.

The package is an eight-module script pack:

- reverseDirectionFix: reverse pedal semantics + AIR consumption;
- reverseGearFeedback: reverse lights/warning based on selected gear;
- realisticCruiseControl: throttle override while cruise remains active; brake disables cruise;
- treeFallFix: multiplayer/spatial tree-fall sound;
- ragbBlowOffCompat: realismAddon gearbox blow-off compatibility;
- blowOffLocalSoundFix: blow-off locality/sample handling;
- soundFix: AIR/blow-off/operating sound MP synchronization;
- passengerInteriorSoundFix: passenger interior/exterior acoustic state.

The sound synchronization paths are reasonably cohesive and generally preserve superFunc. Exact source supports the RC conclusion that MR remains the underlying engine/load/RPM sound owner.

No competing SoundManager.updateSampleAttributes ownership was found, so no direct source-level collision with FarmKit's spatial drivetrain propagation is proven. Keep the focused runtime smoke.

The important non-sound exception is realisticCruiseControl: during positive-throttle override it deliberately bypasses the previous Drivable.updateVehiclePhysics implementation and reimplements part of the base path, directly calling WheelsUtil.updateWheelsPhysics. This can preserve lower-level WheelsUtil wrappers but bypasses any behavior owned specifically in the previous Drivable chain. Treat cruise-control semantics as its own EVALUATE capability and audit it against live MR/RC before relying on it.

reverseDirectionFix is likewise a vehicle-control patch, not an acoustic system. Keep external unless a concrete collision motivates a dedicated controls capability.

No explicit reusable-code license was found.

## MoistureSystem

Decision: KEEP specialist + BRIDGE.

The exact supplied ZIP is 2.0.0.8 and contains 52 Lua files. It is a mature agronomic/material subsystem, not a simple wet-ground effect.

It owns:

- regional/weather-driven field moisture;
- irrigation;
- crop moisture/quality/pricing;
- material/object moisture;
- pile/bale/storage state;
- tedding/drying/hay conversion;
- ground material and bale rotting;
- withering;
- GUI/hand tool;
- persistence and MP events.

Exact getMoistureAtPosition behavior confirms agronomic semantics: global field moisture + monthly climate clamp + small elevation variation + irrigation boost, cached on a 5 m grid.

That must remain distinct from Mud physicalGroundWetness.

Performance architecture is notably deliberate: the ground-property drying/rot pass uses a maintained sweep snapshot with a fixed SWEEP_BUDGET of 64 entries per frame, 500 ms active-set cadence and O(1) swap-removal rather than uncapped full-list bursts.

No direct named integration with MR, Mud, RC, Reifen, SoilCompaction, RealisticHarvesting or FarmKit was found. The right next step is provider integration, not replacement.

Recommended normalized domains remain:

- physicalGroundWetness -> Mud;
- agronomicFieldMoisture -> MoistureSystem;
- materialMoisture -> MoistureSystem.

No conventional reusable-code license was found. Treat source as integration evidence.

## Resulting priority

1. TerrainDeformation: True AI Tracks is now source-confirmed as a strong functional-absorption target.
2. State/provider design: Mud physical ground state + RC composed wheel state + MoistureSystem agronomic/material state.
3. SurfaceContamination/effects: do not duplicate Mud Sprayer physics; absorb only missing presentation concepts.
4. LooseMaterialConsequences: strong later clean-room candidate because two current mods split/duplicate/conflict at capability level.
5. soundExpansionMP: keep external by submodule; separately audit cruise/controls only if they collide with MR/RC or become RE product goals.
6. MoistureSystem: keep specialist; bridge rather than reproduce.
