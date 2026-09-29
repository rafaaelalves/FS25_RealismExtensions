# Capability retirement policy

Updated: 2026-09-29

This document records when RC/RE should disable an existing calculation instead of merely neutralizing its result.

## Principle

A supported capability may be in one of four states:

1. **OWNER** — keep the specialist calculation and consume its state.
2. **COMPLEMENT** — keep it because it provides a consequence RE does not own.
3. **REPLACED** — disable the old calculation at its earliest safe gate.
4. **TRANSITION** — suppress conflicting writes now, but keep remaining logic until RE provides an equivalent or better replacement.

A calculation should not remain active merely because its output is later overwritten.

## Current decisions

### MoreRealistic

Status: OWNER.

Keep drivetrain, wheel dynamics, base traction and baseline rolling resistance. RE consumes normalized state; it must not build a parallel vehicle-dynamics model.

### MudSystemPhysics

Status: OWNER / COMPLEMENT.

Keep:
- local physical wetness;
- sink state;
- sink/slip/excavation resistance;
- stuck/mud behavior where not otherwise assigned;
- tire-pressure/load state currently consumed by RC/RE.

RC removes overlapping baseline resistance but does not disable Mud's genuine terrain-resistance calculation.

### Reifenverschleiss

Status: OWNER.

Keep permanent tire wear and permanent structural-radius consequence. RC composes those results into MR; RE consumes them.

### FarmKit wheel/ground core

Status: REPLACED.

When MR/Mud/Reifen/RE owners are present, RC disables:
- FarmKit wheel physics/grip core;
- FarmKit engine RPM mode;
- FarmKit ground-physics core;
- FarmKit wheel dust when Mud owns it;
- FarmKit load spill when RealPhysics owns it.

This uses FarmKit's own enable gates where possible so the discarded calculations do not continue merely to have their effects overwritten.

### FarmKit plowing/furrow system

Status: TRANSITION.

Keep furrow detection/plowing behavior because RE does not yet replace it. RC suppresses only the competing suspension write so MR remains suspension owner.

Future work: audit whether the useful furrow/collider behavior can consume RC state directly without running redundant FarmKit wheel calculations.

### True AI Tracks 2.2.0.1

Status: TRANSITION / source audit required.

Current public description states that the mod makes AI vehicles leave tracks and deform ground, processes wheels individually and supports implement wheels. Version 2.2.0.1 fixes the old scan interval units bug.

Once RE TerrainDeformation is validated for player, AI and implement wheels, True AI Tracks' **ground-deformation ownership** is expected to overlap RE.

Do not disable the whole mod yet. First determine whether:
- AI/native visual tire tracks can remain enabled independently;
- its TerrainDeformation writes can be selectively suppressed;
- attached-implement visual tracking provides anything RE/native code still lacks.

Preferred end state:
- RE owns physical terrain deformation for player + AI + implements;
- native/AI visual track generation remains if it is complementary and separable;
- redundant TerrainDeformation jobs are disabled at source.

## Decision test for future integrations

Before adding a bridge, answer:

- Is this calculation authoritative state we need?
- Is it a distinct consequence we still need?
- Is it duplicated by another owner?
- Can the duplicate be disabled before it performs expensive work?
- If not, can we safely bypass only the expensive branch?
- Are we preserving a visual/UI consequence that is independent of physics?

Document the answer before adding permanent compatibility code.
