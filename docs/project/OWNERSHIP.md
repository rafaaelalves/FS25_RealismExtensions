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
| Operator-selected mechanical PTO mode / effective gearbox ratio, hand throttle and PTO HUD | **RealismExtensions PTO V1.6** | **authoritative owner**; native GIANTS standalone adapter |
| PTO conversion into MR / RMS canonical motor ratio | **RealismCompatibility** | publish compact, source-backed PTO state; RC scopes MR/RMS compatibility only |
| PTO mechanical load / engine torque and fuel | **MoreRealistic** (GIANTS fallback) | **no duplicate synthetic PTO load** |
| PTO gearbox/clutch wear and failure | **RMS** (when active) | read/compose only; no second failure simulation |
| External Dynamic PTO controller | **alternative owner, not simultaneous** | native RE PTO mutually exclusive; maintain RC legacy bridge separately |
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

## Current stage after PTO V1.6 (2026-10-13)

The PTO entries above supersede the historical Dynamic PTO ownership notes in earlier audits. `RealismExtensionsConfig.modules.PTOControl=true` and `TerrainDeformation=false` on `main`; the terrain module stays an experimental geometry writer until field recovery is validated. See [current roadmap review](2026-10-13-POST-PTO-V16-ROADMAP-REVIEW.md). Real-world MP safety remains untested; RE issue #46 tracks it without a deadline.
