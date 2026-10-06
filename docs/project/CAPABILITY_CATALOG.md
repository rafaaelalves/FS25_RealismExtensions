# Capability catalog

Updated: 2026-09-29

This catalog defines what the target stack currently provides, what RealismExtensions plans to own, and what external systems are candidates for functional absorption.

Status vocabulary:
- `EXTERNAL`: keep an external specialist as owner.
- `PLANNED`: RealismExtensions intends to own this missing phenomenon.
- `CANDIDATE_ABSORB`: an external feature/system may be reimplemented clean-room because ownership/UX/integration gains can justify it.
- `EVALUATE`: interesting but insufficient evidence.
- `DO_NOT_DUPLICATE`: explicitly outside Extensions ownership.

| Capability | Current owner | Status | Direction |
|---|---|---|---|
| base drivetrain / gearbox | MoreRealistic | DO_NOT_DUPLICATE | consume authoritative state |
| base traction/friction | MR + Mud + RC | DO_NOT_DUPLICATE | consume slip/grip state |
| physical ground wetness / sink / terrain resistance / stuck | MudSystemPhysics | DO_NOT_DUPLICATE | consume terrain/contact state; do not conflate with agronomic/material moisture |
| agronomic field moisture | MoistureSystem | EXTERNAL/BRIDGE | keep specialist; consume for crop/field systems |
| material moisture | MoistureSystem | EXTERNAL/BRIDGE | keep specialist; consume for piles/bales/storage/quality |
| tire/track wear state | Reifenverschleiss | CANDIDATE_ABSORB | RealTireWear 1.6 + Reifen audits support a clean-room RE `RunningGearWear` target: server-authoritative typed running-gear units, better physical wear inputs, relative grip provider and explicit structural/failure state; Reifen remains owner until parity/runtime retirement gate |
| visual tire/track wear | Reifenverschleiss / RealTireWear custom shader paths | EVALUATE | both prove feasibility; build new RE shaders/assets with dirty/lifecycle ownership rather than reusing ambiguous external assets |
| mechanical system degradation | RMS | EXTERNAL | keep specialist; Extensions may surface normalized state |
| diesel ignition / glow-plug / start UX | Realistic Diesel Start | EXTERNAL/BRIDGE | keep specialist; RDS 1.4 natively owns ADS-aware key/hard-start coexistence while RC composes only remaining thermal/readiness overlap |
| truck compressed-air reservoir / spring-brake state | Realistic Diesel Start | EXTERNAL | keep specialist; native narrow API to Realistic Brakes is preferred over RC mediation |
| active/self-leveling front suspension | no dedicated target-stack owner; MR owns passive WheelPhysics/spring baseline | CANDIDATE_ABSORB | research clean ActiveSuspension controller with load/ride-height feedback; implementation requires explicit MR baseline composition and must not suppress MR suspension writes |
| 2WD/4WD/differential behavior | RMS | EXTERNAL + IMPROVE | keep RMS physical topology/lock owner; exact 4x4 audit confirms only demand/decision semantics are worth redesigning (dt-normalized slip, traction reserve, explainable reasons, richer lock demand), preferably upstream in RMS or via a normalized advisor |
| PTO modes / live PTO RPM / hand throttle | Dynamic PTO + RC bridges | CANDIDATE_ABSORB | strong candidate for native Extensions module |
| PTO-to-MR/RMS composition | RC | EXTERNAL/BRIDGE | retain compatibility boundary even after PTO absorption |
| persistent agronomic compaction | SoilCompaction | EXTERNAL | keep specialist |
| harvest process realism | RealisticHarvesting | EXTERNAL | integrate only where a new module consumes its state |
| player geometric wheel ruts | RE TerrainDeformation; FarmKit capability suppressed | PLANNED | keep RE physical owner; integrate VMT lessons for monotonic rut writes, sink handoff, stable contact anchoring and loaded-wheel recovery guards |
| persistent visual tire tracks | Persistent Tracks demonstrates feasibility; RE has no owner yet | CANDIDATE_ABSORB | reimplement as native-track journal + spatial streamer, integrated with TerrainDeformation/recovery; do not copy unlicensed source |
| AI native visual tire tracks | True AI Tracks currently exposes GIANTS AI tire-track gating | CANDIDATE_ABSORB | absorb into the future NativeTireTrackAdapter/Persistent Visual Tracks layer; keep separate from physical terrain deformation |
| AI/implement physical terrain deformation | RE TerrainDeformation supersedes True AI Tracks architecture | PLANNED | same physical law for player/GIANTS AI/Courseplay/AutoDrive; close with runtime AI/implement matrix before removing dependency |
| lateral tire scrub deformation | no active owner | PLANNED | TerrainDeformation |
| freeze/thaw deformation response | no active owner in target profile | PLANNED | consume Mud/environment state |
| furrow wheel/collider interaction | FarmKit | CANDIDATE_ABSORB | later clean-room FurrowInteraction |
| speed/load/wetness crop damage | FarmKit | CANDIDATE_ABSORB | later CropInteraction |
| crop destruction outside owned fields | CropDestructionAnywhere / vanilla rule | CANDIDATE_ABSORB | likely small part of CropInteraction |
| off-field grass/meadow physical damage | FarmKit | CANDIDATE_ABSORB | later CropInteraction research |
| wheel dirt/mud state and particles | Mud | DO_NOT_DUPLICATE | keep Mud owner |
| dry/wet mud-spray presentation | Mud Sprayer / Mud effects | EVALUATE | exact-source audit found coarse rain/global-state logic and namespace collision; replace only if Mud leaves a real presentation gap |
| implement dust | FarmKit | EVALUATE | can be improved/calibrated later; no immediate ownership conflict |
| road water spray | FarmKit | EVALUATE | useful visual effect; asset strategy required |
| engine sound spatial propagation | FarmKit | EVALUATE | audit against soundExpansionMP before ownership decision |
| extra operational/MP sound behavior | soundExpansionMP | EXTERNAL | keep external by submodule; cruise/reverse controls are separate capabilities, not sound ownership |
| rollover spill | RealPhysics LoadSpill / Loose Load overlap | EVALUATE | keep one external owner now; exact source supports later unified clean-room replacement |
| loading overflow / cover containment | Loose Load | EVALUATE | distinct from rollover spill; candidate for future unified material system |
| discharge dynamics | RealPhysics LoadSpill | EXTERNAL | keep specialist for now |
| spill presentation | Loose Load / RealPhysics | EVALUATE | separate visuals/sound from physical spill ownership |
| straw refeed | FarmKit | EVALUATE | unique; future bridge to RealisticHarvesting before replacement |
| planner / PF field material overview | FarmKit | EVALUATE | useful but not a first-wave realism-physics feature |
| persistent surface contamination / dirt color | RealDirtColor + Mud visual state | CANDIDATE_ABSORB | plan clean-room SurfaceContamination using authoritative contact state and GIANTS dirtColor backend |
| tyre-pressure / CTIS state | MudSystemPhysics currently owns target-stack pressure state | DO_NOT_DUPLICATE | keep Mud owner unless a concrete capability gap appears; use VMT only as research reference |
| unified realism HUD | fragmented | PLANNED | only after normalized authoritative state exists |

## Absorption rule

A capability may move from external ownership to `CANDIDATE_ABSORB` only when at least one concrete benefit exists:
- removes duplicate/conflicting writes or hooks;
- removes a compatibility bridge that exists only because of the external implementation;
- allows materially better authoritative inputs;
- reduces fragmented UI/input/settings;
- improves performance architecture;
- enables one coherent system across player/AI/implements;
- removes an otherwise unavoidable dependency on a monolithic feature bundle.

Mod-count reduction alone is not sufficient.
