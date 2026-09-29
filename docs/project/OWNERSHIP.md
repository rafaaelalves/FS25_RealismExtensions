# Ownership matrix

This file is normative. When implementation and this table disagree, stop and resolve the ownership decision explicitly.

| Phenomenon | Current owner | RealismExtensions role |
|---|---|---|
| Drivetrain / gearbox | MoreRealistic | consume only |
| Base traction / friction | MR + Mud + RC composition | consume only |
| Local wetness / mud ground state | MudSystemPhysics | consume |
| Wheel sink / terrain resistance / stuck | MudSystemPhysics | consume |
| Tire wear / structural radius | Reifenverschleiss + RC | consume |
| Persistent agronomic compaction | SoilCompaction | consume |
| Mechanical subsystem degradation | RMS | consume |
| PTO mode / effective PTO state | Dynamic PTO + RC | consume |
| Harvest processing realism | RealisticHarvesting | consume/bridge only when justified |
| Player slip/scrub geometric ruts | currently unowned in target profile | **planned owner** |
| AI/implement geometric tracks/deformation | True AI Tracks currently | **candidate replacement/owner** |
| Speed/load/wetness crop interaction | FarmKit optional / vanilla baseline | candidate future owner |
| Off-field vegetation damage | fragmented | candidate future owner |
| Wheel dirt/mud particles | Mud | do not duplicate |
| Implement dust | FarmKit currently | evaluate, not first prototype |
| Road water spray | FarmKit currently | evaluate, not first prototype |
| Spatial engine sound | FarmKit currently; soundExpansion unresolved | audit before touching |
| Load spill | RealPhysics LoadSpill | keep external for now |
| Unified realism HUD | no authoritative single owner | future consumer of normalized state |

## Rule

If a proposed feature requires RealismExtensions to overwrite a current specialist owner, it needs an explicit ADR before implementation.
