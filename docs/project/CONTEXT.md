# Context

Updated: 2026-09-28

## Read this first

This is the shortest canonical handoff for a new contributor or a new ChatGPT conversation.

### Purpose

FS25 Realism Extensions adds realism phenomena that are missing from the user's specialist stack. It must **not** become another owner of drivetrain, traction, sink, tire wear, mechanical systems, agronomy or PTO simulation.

The project is separate from FS25 Realism Compatibility (RC):
- RC coordinates ownership and adapts specialist mods.
- RealismExtensions consumes normalized state and creates missing consequences/effects.

### Target stack ownership

- MoreRealistic (MR): drivetrain, healthy transmission, base vehicle/wheel dynamics and base traction.
- MudSystemPhysics (Mud): local wetness, sink, terrain resistance, mud/stuck behavior and wheel-ground effects.
- Reifenverschleiss: persistent tire wear and structural radius.
- SoilCompaction: persistent agronomic compaction.
- RealisticMechanicalSystems (RMS): mechanical subsystem state/load.
- Dynamic PTO: PTO mode/RPM ownership.
- RealisticHarvesting: harvesting-process realism.
- RealismCompatibility: composition/adaptation between those owners.

RealismExtensions should consume those facts; it should not recalculate competing versions of them.

### Clean-room rule

Do not copy FarmKit source/assets into this project. FarmKit was audited to understand phenomena and architectural gaps, but new implementations must be independently designed and written.

### First product direction

The first active module is planned to be TerrainDeformation:
- player vehicle wheel ruts;
- longitudinal-slip excavation;
- lateral scrub;
- deformation driven by authoritative wetness/sink/slip/load/footprint;
- GIANTS AI, Courseplay and implement wheels through the same deformation engine.

If successful, this can functionally absorb True AI Tracks and recover the most important FarmKit behavior lost when its monolithic wheel/ground core is suppressed.

### Current state

Version 0.0.1.0 is foundation-only.

A capability/absorption audit is now active on `research/capability-audit`:
- Dynamic PTO 1.1.2.0: strong clean-room absorption candidate;
- Reifen 1.2.2.67: candidate by layers; state/economy attractive, visual parity requires a shader/material project;
- FarmKit: capability + asset audit recorded; priority lost features (ruts/furrow/crop interaction) are not blocked by custom assets;
- Realistic 4x4 Traction System 1.4.0.0: exact ZIP audited; do not run beside RMS, but use its stronger decision-model ideas to improve RMS-facing AUTO/lock control.
- Real Dirt Color 1.1.5.0: exact ZIP audited; strong candidate for a clean-room SurfaceContamination replacement with no custom runtime-asset blocker.

Foundation status:
- repository/bootstrap exists;
- CI/build exists;
- diagnostics exists;
- normalized StateContract v1 exists;
- no gameplay module is active.

### Next action

1. Continue candidate-mod capability/asset audits.
2. Define StateContract v1 wheel/terrain fields from real source/runtime evidence.
3. Research GIANTS TerrainDeformation lifecycle/cost model.
4. Design and prototype TerrainDeformation without changing traction/sink ownership.
5. In parallel, design SurfaceContamination state and an RMS-facing drivetrain decision-provider proposal.

For current detail use PROJECT_STATUS.md. For design rationale use ARCHITECTURE.md and decisions/.
