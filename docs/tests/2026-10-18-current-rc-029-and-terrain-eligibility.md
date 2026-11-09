# Terrain R1 eligibility evidence and current RC 0.2.0.9 integration

**Date:** 2026-10-18 (America/Sao_Paulo). **Scope:** small, read-only developer diagnostic on top of `research/terrain-predeform-reference-v3-2026-10-15@fb3063b`. No physics, reference-plane, TARGET actuator, save schema, RC bridge, or PTO change.

## Deployed builds recovered from October 18 game logs

| Session (local) | Actual RE artifact | Actual RC artifact | Meaning |
| --- | --- | --- | --- |
| 20:52–20:57 `log(20261018-235757).txt` | `53/merge@fee104b9` Actions 38665763521 | `main@672ba7ec` v0.2.0.8 Actions 39175573598 | 320 rut brushes, 46 native jobs; recovery idle |
| 21:09–21:11 `log(20261019-001120).txt` | same PR53 | same RC v0.2.0.8 | **510 PLOW physically worked areas, 0 candidates, 0 TARGET jobs** |
| 21:28–21:30 `log(20261019-003103).txt` | same PR53 | `main@546806b7` v0.2.0.9 Actions 39180478840 | diagnostics smoke; no terrain recovery workload |
| 21:37–21:39 `log(20261019-003921).txt` | same PR53 | same RC v0.2.0.9 | 10 bridges ACTIVE, `rcHooks` and `rcRisks` commands observed; no tillage |

Current RC `main@c04a5cc` adds only documentation after the last executable RC commit `60d060fc`; runtime source is unchanged versus the installed `546806b7` artifact. RE `main@a48e7da` advanced only docs since `51c32d6` and still deliberately disables experimental terrain. The PR53 RE artifact is the **correct experimental research family**, but NOT a successful R1 recovery build.

### The central PLOW 510 discriminator

Last real plow sample shows:
- `restored terrain history cells=30298` globally. Not evidence of 30298 *ruts within that field*.
- `TerrainRecoveryTools PLOW=510/0/0/0`; `intentEmpty=510`; reference V2 evaluations = **0**, so the failed operation **never reached the estimator or TARGET actuator**.
- `workArea width=1.32..1.33m depth=4.02..4.04m`, `changed=429 repeat=81`; the GIANTS work-area entrypoints were invoked successfully.
- RE persistent rut writer `brushesAccepted=0` in that plow session, expected partly due to active tillage suppression, not evidence of a broken state provider.
- An entirely reasonable explanation is *no eligible RE-owned rut-history cell inside that exact plow work-area* (the existing 30k cells may belong elsewhere). Alternatives are a below-3mm history debt, a work-area geometry mismatch, or legacy heightmap depression without historical debt. The log cannot differentiate these.

### Current branch corrective diagnostic: measure the missing stage

`SpatialHistory.getRecoveryCandidatesParallelogram` now optionally populates an evidence table during the **same existing scan**. It reports:
- bbox scanned, active history in bounding rectangle, active history in *actual parallelogram*;
- rut debt >= 3mm in bbox versus inside actual work area;
- in-area history with debt below threshold;
- cooldown-blocked cells and candidates;
- strongest in-area rut debt, whether the 512-cell candidate budget stopped enumeration.

`TerrainRecovery` collects the first 24 and every 16th worked-area event **only when verbose developer diagnostics are on** and aggregates as `TerrainEligibility | ...`. These are repeated scan samples, not unique world-space cells. A field may have no RE-debt even if the mesh visually contains a depression; that case is NOT silently repaired.

Interpret:
- `emptyNoHistory>0` and `historyArea=0`: no historical RE cell under sampled plow footprint. This does not prove why (different field/save, loss, edited terrain, unsupported legacy).
- `emptyOffFootprint>0`, `rutBBox>0` and `rutArea=0`: near rut debt exists but current work-area boundary misses it; inspect actual geometry against implement and brush positions.
- `emptyLowRut>0`, `historyArea>0` and `rutArea=0`: historical cells exist, but the stored depth is below 3mm.
- `emptyOther>0`, `rutArea>0`: cooldown/candidate discrepancy or other search issue; inspect `cooldown`, truncation and candidate limit.
- `rutArea>0` with `intentPoints=0` globally indicates the next stage (clustering or selection) rather than footprint lookup is failing.

**No new heightmap reads, no new full-field scans, no change to root histories or physical tolerances.**

## New audit crosswalk, exact-source and ownership

| Audit/update | Verified relevance to RE R1 | Decision |
| --- | --- | --- |
| Mud System Physics 1.3.7.0 | Local wetness/sink/structural-radius provider source unchanged from 1.3.6; improved puncture/HUD/optional shedding | Current RC 0.2.0.9 already gates exact 1.3.7; retain Mud ownership, no terrain formula transplant |
| RMS 0.12.0.0 | RC fixed narrow MRRMS hand-back/ownership and updated exact gates; no geometric recovery function | No direct terrain rewrite; RC source-compatible, not fully physically certified |
| RH 1.6.4.0 + WA Clogging 1.4.1.0 | Cutter/AI ownership, motor-speed/throughput and crop escrow can change harvester travel/behavior, not original rut mesh | Avoid upgrade-as-fix; controlled RH+WA A/B later, do not mix it with recovery geometry experiments |
| RDS 1.4.1.0 | Revised starter lifecycle invalidates old RDSADS semantic assumptions under ADS; current RC intentionally exact-version denies it | Keep RDS separate from terrain; native RDS/RMS coexistence future test, no RC force-enable |
| TTD 3.7 | Wheel radius/temporary contact displacement and weak relative-pothole classifier, **not a verified persistent rut restorer** | Test its false-positive cases; no hooks or physics absorption |
| DynamicDrivePro 1.0.1.0 | Attempted direct height setters and absolute-height save replay lack provenance/validated native writes | Negative tests for invalid source/restore/actor ownership; no code absorption |
| AutoSwitch 1.0.0.58 | Global hook/physics arbitration risks; inventory ideas belong to future parts feature | No install or global RC arbiter; not part of recovery |
| TerraFarm 1.6.5.0 | Native landscaping TARGET precedent; deliberate external excavations must retain their own ownership | Preserve native `TerrainDeformation` writer, never auto-repair third-party pits |
| Broadphase research branch `perf/terrain-recovery-history-broadphase` | Existing conservative occupied-tile skip may avoid huge negative searches | Revisit **after** sampling confirms many empty search AABBs; do not merge old-branch optimizer blindly |

### Architecture decision preserved

Use native `TARGET`, never return to unbounded additive `RAISE`; retain R6 patch reconciliation, R7 tool profiles, RE-only geometric authority, RC normalized per-wheel provider v2, and existing read-only PR53 first-touch observations. The RE experimental branch uses the v2 contract currently exported by RC. Current production RE `main` contains the same principal PTO V1.6 implementations; continue experimentally without merging terrain into production.

**Next physical correction after this diagnostic:** If history is absent, no reference-plane algorithm (R5, V2 or V3) fixes that stage; decide whether/how to support **legacy geometric recovery** without rewriting a natural hollow or TerraFarm pit. If history is present and a valid reference is repeatedly refused, analyze unique V2 reject keys and curvature. If target attempted but actual vertices unchanged, controlled native mesh footprint A/B. Each outcome has a separate acceptance gate.

## CI versus game acceptance

The new `tests/terrain_eligibility_evidence_harness.lua` asserts uninstrumented/instrumented candidate equivalence, in-area versus outside-AABB rut, below-threshold debt, cooldown, no-history safety, shear-only state and truncation. GitHub CI proves Lua/static regressions only. Gameplay gate is one short PLOW pass over a **known physical depression** on a cloned save, with `TerrainEligibility` line and same tool, without requiring a full 30-minute repeated attempt. Avoid implying that a diagnostic-only build already repairs the rut.

No other system is authorized to write RE terrain, no global RC hook rewrites and no `main` changes in this work.
