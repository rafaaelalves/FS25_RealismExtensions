# Context

Updated: 2026-10-02

## Read this first

This is the stable project orientation. For exact current implementation/test state, always continue with `CURRENT_HANDOFF.md`.

### Purpose

FS25 Realism Extensions adds realism phenomena missing from the specialist stack without becoming another owner of drivetrain, traction, instantaneous sink, tire wear, mechanical systems, agronomy or PTO simulation.

RealismCompatibility (RC) and RealismExtensions (RE) are separate:
- RC coordinates ownership/adapts specialist mods and exposes normalized state.
- RE consumes normalized state and creates missing persistent consequences/effects.

### Target stack ownership

- MoreRealistic (MR): drivetrain, healthy transmission, base vehicle/wheel dynamics and base traction.
- MudSystemPhysics (Mud): local wetness, instantaneous sink, terrain resistance, mud/stuck behavior and wheel-ground effects.
- Reifenverschleiss: persistent tire wear and structural radius.
- SoilCompaction: persistent agronomic compaction.
- RealisticMechanicalSystems (RMS): mechanical subsystem state/load.
- Dynamic PTO: PTO mode/RPM ownership.
- RealisticHarvesting: harvesting-process realism.
- RealismCompatibility: composition/adaptation between those owners.

RE consumes those facts; it does not recalculate competing versions.

### Clean-room / precedent rule

External source audits are used to understand phenomena, architecture, engine contracts and failure modes. Do not blindly copy another mod's policy/constants and do not create a dependency unless explicitly justified.

### Active capability

TerrainDeformation is the active capability:
- persistent wheel ruts;
- pressure/wetness/slip/plasticity response using normalized specialist state;
- longitudinal/lateral exposure;
- implement/AI coverage;
- physical terrain recovery from agricultural work;
- future crawler/track support and controlled soil transport.

It is runtime-active on the development branch but not complete.

### Development rule

Development is evidence-first. Read `docs/DEVELOPMENT_PROCESS.md`.

Use one active branch per capability. TerrainRecovery currently continues on:
`feat/terrain-recovery`.

Do not infer physical success from an API success code or from a changed logical history counter. Measure the physical state and attribute the change to a writer/operation.

### Current next action

Read `docs/project/CURRENT_HANDOFF.md`. It contains the v22 recovery bug/fix, runtime test protocol, new five-second causal telemetry and the current TerraFarm architecture audit.

For design rationale use `docs/decisions/`; for external precedents use `docs/audits/` and `docs/research/`.
