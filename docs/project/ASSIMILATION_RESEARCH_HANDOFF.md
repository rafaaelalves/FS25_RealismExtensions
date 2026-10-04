# Assimilation research handoff

Updated: 2026-10-04

Status: **PAUSED AFTER STATIC AUDIT — RETURN LATER**

This handoff preserves the current decision boundary before terrain runtime validation resumes.

## Completed research

### Hydraulic Suspension System
Exact audit:
- `docs/audits/hydraulic-suspension/README.md`
- `STATIC_FINDINGS.md`
- `ASSIMILATION_OPPORTUNITIES.md`
- `RUNTIME_TEST_PLAN.md`

Decision:
- active/self-leveling suspension is a genuine **CANDIDATE_ABSORB / REDESIGN** capability;
- do not port the external implementation;
- do not suppress MoreRealistic suspension ownership;
- implementation remains blocked on a clean passive-suspension baseline/composition contract with MR/RC.

### Realistic 4x4 Traction System
Exact audit:
- `docs/audits/4x4-traction/README.md`
- `STATIC_FINDINGS.md`
- `ASSIMILATION_OPPORTUNITIES.md`
- `RUNTIME_TEST_PLAN.md`

Decision:
- **do not absorb the physical drivetrain solver**;
- RMS remains the physical 2WD/4WD/differential/topology owner;
- retain/redesign only the traction-demand / AUTO / lock decision ideas;
- preferred destination is an upstream RMS AUTO improvement or a normalized demand-advisor contract;
- reject the bundled CTIS/radius/tire-visual ownership because Mud already owns pressure/CTIS in the target stack.

## No implementation started from these two audits

No Hydraulic Suspension or 4x4 physical code should be added merely because the audits are complete.

Return to implementation only after:
- Hydraulic: MR suspension composition boundary is proven;
- 4x4: runtime comparison shows which decision semantics materially improve RMS AUTO/lock.

## Current development priority

The active implementation branch remains:
`feat/assimilation-tracks-vmt`

Its pre-runtime checkpoint is closed and ready for in-game validation.

A separate terrain-recovery issue is now under investigation:
- cultivator initially recovers/deforms terrain correctly;
- after some operation, large/deep ruts can remain visibly untreated even after repeated passes.

Do not infer a fix until the runtime log is analyzed.

Potential classes of failure to discriminate:
1. recovery stamp/cooldown consumed before effective geometry change;
2. writer queue/budget rejection or later starvation;
3. loaded-contact guard blocking more area/time than intended;
4. TerrainDeformation callback reports success while deep geometry remains;
5. logical SpatialHistory recovery diverges from actual terrain geometry;
6. smoothing depth/radius is insufficient for large ruts;
7. repeat-pass dedup prevents legitimate additional recovery;
8. another terrain owner reasserts/deepens geometry after recovery.

## Priority rule after the next runtime session

If the terrain-recovery log shows a **correctness blocker in the core physical terrain lifecycle**, fix recovery before expanding assimilation work.

If the recovery issue is not reproduced or is an isolated tuning matter, continue the remaining assimilation audits first and batch implementation decisions afterward.

Core terrain correctness outranks adding new absorbed capabilities.
