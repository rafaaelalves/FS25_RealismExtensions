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
| tire/track wear state | Reifenverschleiss | CANDIDATE_ABSORB | audit logic, persistence, visuals and workshop separately |
| visual tire/track wear | Reifenverschleiss custom shader/material path | EVALUATE | asset/shader strategy required before replacement |
| mechanical system degradation | RMS | EXTERNAL | keep specialist; Extensions may surface normalized state |
| 2WD/4WD/differential behavior | RMS | EXTERNAL + IMPROVE | keep RMS physical owner; study richer AUTO/lock decision provider from audited 4x4 ideas |
| PTO modes / live PTO RPM / hand throttle | Dynamic PTO + RC bridges | CANDIDATE_ABSORB | strong candidate for native Extensions module |
| PTO-to-MR/RMS composition | RC | EXTERNAL/BRIDGE | retain compatibility boundary even after PTO absorption |
| persistent agronomic compaction | SoilCompaction | EXTERNAL | keep specialist |
| harvest process realism | RealisticHarvesting | EXTERNAL | integrate only where a new module consumes its state |
| player geometric wheel ruts | FarmKit capability currently suppressed | PLANNED | TerrainDeformation module |
| persistent visual tire tracks | Persistent Tracks demonstrates feasibility; RE has no owner yet | CANDIDATE_ABSORB | reimplement as native-track journal + spatial streamer, integrated with TerrainDeformation/recovery; do not copy unlicensed source |
| AI/implement terrain tracks/deformation | True AI Tracks | CANDIDATE_ABSORB | exact-source audit confirms strong full functional-absorption target for TerrainDeformation |
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
| tyre-pressure / CTIS state | fragmented / 4x4 hack writes radius | EVALUATE | separate future capability; never fight radius ownership directly |
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
