# Terrain Recovery design study — intent-safe recovery

Updated: 2026-10-04
Status: **DESIGN / MEASUREMENT FIRST — NO TARGET-WRITER AUTHORIZED**

## Problem statement

The user-visible goal is not "restore every terrain sample to the original map elevation".

The goal is:
> when an agricultural implement works an area, remove/reduce wheel-created rut relief according to that operation's physical capability, without undoing intentional terrain shaping.

Observed facts:
- vanilla landscaping Smooth can produce a lower average field while still removing the objectionable wheel channels;
- RE v22 can report roughness improvement while deep rut channels remain;
- a fixed original-height target risks undoing player landscaping, TerraFarm work or other intentional terrain edits;
- the new loaded-contact safety guard currently blocks ~98% of eligible recovery candidates and must be corrected before comparing smoothing strategies.

## Separate the problem into three layers

### Layer A — eligibility / safety

Question:
**Is it safe to alter this patch now?**

This layer knows:
- loaded wheel contacts;
- active combination ownership;
- work-area position;
- pending/deferred recovery;
- other dynamic objects.

It must not decide target geometry.

### Layer B — recovery intent / reference

Question:
**What change is legitimate for this agricultural operation?**

This layer knows:
- deformation attributable to RE wheel traffic where available;
- current local topography;
- operation type and working depth;
- evidence of authoritative external/player terrain edits;
- local slope/shape.

It must not directly write terrain.

### Layer C — terrain operation

Question:
**How should the allowed correction be applied?**

Candidate actuators:
- native GIANTS SMOOTH;
- bounded RAISE/LOWER redistribution;
- hybrid target-assisted smoothing.

Choice remains open until measured.

## Do not use map-start height as universal truth

A frozen original heightmap cannot distinguish:
- wheel rut;
- player landscaping;
- TerraFarm excavation/grading;
- deliberate drainage/road construction;
- another mod's authoritative terrain work.

Restoring that value would eventually undo legitimate gameplay.

## Stronger concept: causal deformation debt

Instead of storing "where the terrain should always be", store **what RE believes its own wheel deformation contributed**.

Conceptually per spatial cell/patch:

```
observed terrain
= current authoritative baseline
+ outstanding RE deformation debt
+ unclassified/external change
```

Recovery may attempt to cancel only the outstanding RE-attributable rut/shear component.

### Why this is safer

If the player intentionally changes terrain, that edit can establish a **new authoritative baseline** rather than being treated as damage.

RE then stops trying to restore the pre-edit shape.

### External edit policy

Preferred hierarchy:

1. **Known authoritative terrain edit event**
   - player landscaping;
   - TerraFarm machine work;
   - other explicitly integrated terrain owner.
   - Action: rebase/invalidate affected RE recovery reference/history as appropriate.

2. **Observed unexplained geometry discontinuity**
   - actual terrain changed substantially without an RE writer transaction.
   - Action: fail conservative:
     - mark reference uncertain;
     - do not aggressively restore old height;
     - optionally rebase/clear stale recovery debt after validation.

3. **No external-edit evidence**
   - use RE causal history + local shape to guide recovery.

The exact invalidation rules require runtime proof; do not assume every external height change erases all physical history.

## Local shape still matters

Causal history alone is not enough:
- old saves may lack complete history;
- deformation can be modified by other owners;
- a wheel may revisit an already shaped field.

Use a local surface estimator as **evidence**, not absolute truth.

Possible measurements:
- cross-track valley depth;
- valley width;
- shoulder/berm excess;
- robust boundary plane;
- low/high quantiles relative to that plane;
- curvature / second derivative across the channel;
- current roughness.

Important:
- roughness is secondary;
- absolute center movement sign is secondary;
- the primary rut metric should describe **channel relief relative to surrounding local surface**.

## Native smoothing remains a serious candidate

Do not discard GIANTS smoothing.

The user reports the vanilla tool produces the desired qualitative result:
- surface may become lower;
- rut channels disappear;
- field becomes smooth.

Therefore the next experiment should determine why machine recovery differs.

Possible causes to measure:
- insufficient spatial coverage;
- per-patch cadence/cooldown;
- brush path differs from manual cursor movement;
- brush radius/hardness/strength;
- work-area centers miss the rut centerline;
- the loaded-contact guard suppresses most passes;
- native landscaping may invoke smoothing at a denser temporal/spatial rate.

A target-based writer is only justified if equivalent native smoothing still cannot remove the measured channel relief.

## Loaded-contact guard redesign requirement

Current implementation checks:

```
overlapsCircle(recoveryPoint, smoothRadius=2m)
```

and vetoes the **entire** recovery brush if any recent loaded-wheel footprint overlaps that circle.

Follow-up runtime:
- coverage candidates: 14,552;
- stamp skips: 874;
- contact queries: 13,678;
- contact-blocked: 13,409;
- actually enqueued: 269.

Thus ~98.0% of queried candidates were blocked.

This is not acceptable normal recovery behavior.

### Why retry-on-next-work-area is insufficient

A patch blocked while the implement occupies it can cease receiving work-area callbacks once the implement moves away.

"Do not claim the stamp" is therefore not enough: there may be no later callback for that same patch after it becomes safe.

### Candidate safety designs

#### Option 1 — deferred patch queue (preferred research direction)
When a worked patch is blocked:
- record that cultivation legitimately requested recovery there;
- defer execution;
- retry for a short bounded lifetime after loaded contacts leave;
- retain work-operation identity/capability;
- expire safely if conditions become ambiguous.

Pros:
- preserves loaded-wheel safety;
- does not leave permanent holes;
- keeps current work-area semantics.

#### Option 2 — geometric clipping
Apply recovery only to the subregion not overlapping the loaded contact footprint.

Pros:
- immediate;
- physically local.

Cons:
- GIANTS soft-circle primitive may not provide exact clipping;
- multiple tiny brushes may be costly/complex.

#### Option 3 — same-combination directional exception
Allow areas proven to be *behind* all relevant loaded contacts of the active combination.

Pros:
- efficient.

Cons:
- complex with implement gauge wheels, reversing, articulated/nested equipment;
- not sufficient alone.

A deferred queue is the safest general baseline; directional knowledge can later optimize it.

## Candidate recovery strategies to compare

### Strategy S — improved native smoothing
- keep GIANTS smoothing;
- fix guard/defer behavior;
- emulate vanilla spatial/cadence characteristics more closely;
- measure rut-relief convergence.

This is the lowest-complexity preferred candidate.

### Strategy H — history-guided smoothing
- native smoothing remains the actuator;
- RE history identifies where rut relief is expected;
- smoothing continues until channel-relief target is met or operation budget exhausted.

No absolute height restoration.

### Strategy R — bounded redistribution
- explicitly raise deficits and lower shoulders using local/casual reference;
- conserve/limit volume;
- optional final light smoothing.

Most powerful, highest risk.

Use only if S/H cannot reproduce a credible agricultural result.

## Operation capability

Recovery target must depend on work type.

Cultivator example:
- remove/reduce wheel channels within working depth;
- repeated passes may converge;
- do not erase large intentional landscape features.

A deeper tillage tool may have a larger correction budget.

A roller may primarily reconsolidate/high-spot smooth rather than restore deep ruts.

Do not use one global "recovery strength".

## Proposed measurement phase

Before new physical writes, add diagnostics/probes for:

1. **rut cross-section**
   - sample perpendicular to known wheel path;
   - valley depth relative to shoulders/local plane;
   - valley width.

2. **native smooth response**
   - before/after channel depth;
   - mean elevation shift;
   - roughness change;
   - number of applications to convergence.

3. **coverage**
   - distance from recovery sample centers to actual rut center/history cells;
   - how often a rut cell receives a smoothing brush.

4. **safety**
   - block reason/contact owner;
   - current-combination vs foreign vehicle;
   - defer latency;
   - eventual completion rate.

5. **reference confidence**
   - RE-caused deformation history present?;
   - unexplained/external terrain edit observed?;
   - local boundary plane confidence.

## Test matrix

At minimum:
- fresh flat field + one deep rut;
- same rut on slope;
- repeated rut passes;
- narrow deep rut;
- broad shallow rut;
- berm/shoulder;
- player landscaping raise/lower before rut;
- player landscaping after rut;
- TerraFarm reshaped area;
- field edge / road boundary;
- cultivator with gauge/support wheels near work area;
- reverse travel.

## Decision gates

### Keep native smoothing if
after fixing eligibility/cadence:
- channel depth converges acceptably;
- no pathological terrain erosion;
- performance remains good;
- result matches vanilla-quality expectation.

### Add history-guided target if
native smoothing is qualitatively good but stops before removing a known RE rut.

### Add explicit redistribution only if
measured native/hybrid smoothing cannot satisfy rut removal without unacceptable collateral lowering.

### Never restore frozen original terrain if
there is credible evidence the authoritative terrain baseline changed intentionally.

## Current recommendation

1. fix/redesign **eligibility/deferred recovery** first;
2. instrument **channel-relief measurements**;
3. compare native smoothing under fair coverage;
4. only then choose S, H or R.

This intentionally postpones the "target surface" implementation. The correct target may be a **rut-relief target**, not an absolute elevation target.


## Implementation checkpoint — deferred safety + robust relief probe

Implemented after the 2026-10-04 over-blocking runtime:

### Layer A: deferred safety

Blocked worked patches are no longer abandoned.

New behavior:
- blocked recovery request becomes one spatially coalesced deferred patch;
- queue is bounded (`maxDeferredPatches=2048`);
- retry cadence is bounded (`200 ms`);
- lifetime is bounded (`5 s`);
- per-update checks are bounded (`16`);
- a patch is revalidated against the LoadedContactRegistry before execution;
- if another direct/deferred brush already handled the patch, the queued request is discarded as superseded;
- protection/rut suppression behavior remains separate.

Harness proves:
- a blocked patch can complete after the contact clears with **no new Cultivator work-area callback**;
- repeated blocked callbacks coalesce rather than duplicating queue entries;
- the stationary loaded-contact safety invariant remains intact.

### Layer B diagnostics: RecoverySurfaceEstimator

A pure `RecoverySurfaceEstimator` now measures local shape relative to a robust boundary reference plane.

Important semantics:
- the center/rut sample is **not** used to define the reference plane;
- the outer ring estimates local slope/shape;
- boundary outliers can be rejected using MAD-based filtering;
- uniform vertical shift of the whole field does not count as rut recovery or worsening.

Metrics include:
- center deficit;
- valley depth;
- peak height;
- relief range;
- roughness;
- mean elevation;
- boundary inlier/confidence signal.

This is diagnostic only. It does not define an absolute target and does not change the terrain operation.

### Layer C unchanged

Terrain actuation remains GIANTS native `SMOOTH` with the existing:
- amount;
- radius;
- hardness;
- strength.

No target-height writer, explicit raise/lower redistribution, or strength increase has been authorized.

### History reconciliation remains provisional

Logical SpatialHistory still follows the existing roughness-success rule for this checkpoint so the deferred-safety change can be isolated.

The new relief metrics are collected specifically to decide whether that rule should be replaced.

Next runtime should compare:
- roughness reduction;
- relief/valley reduction;
- deferred creation vs eventual application;
- queue expiry/drop rate.

Only then decide whether Strategy S is sufficient or H/R are needed.


## Runtime checkpoint — deferred recovery succeeds

Build:
- `ef47be75f31205e831647e39b984e991bae46b4d`
- 2026-10-04 combined tracks/recovery session.

### Deferred safety: PASS

End of active recovery session:
- deferred created: 3,284;
- deferred applied: 3,176;
- deferred expired: 51;
- deferred superseded: 57;
- deferred rejected: 0;
- deferred dropped by capacity: 0;
- queued at rest: 0;
- peak queue: 56.

Therefore:
- ~96.7% of created deferred patches eventually executed;
- ~1.6% expired;
- ~1.7% became unnecessary because another path already handled the patch;
- no queue-capacity failure occurred.

This closes the previous over-blocking lifecycle defect. Loaded-contact safety can remain without losing almost every worked patch.

### Native smoothing: positive but not yet sufficient evidence for closure

At 3,338 verified recovery brushes:
- roughness improved: 2,856 (~85.6%);
- worsened: 117;
- neutral: 365;
- local relief improved: 2,871 (~86.0%);
- worsened: 222;
- neutral: 245;
- gross relief reduction: 7.9875 m across all probes;
- gross relief worsening: 1.2402 m;
- net sampled relief reduction: ~6.7473 m, ~2.0 mm per brush on average.

Important:
- center moved down in 2,858 callbacks and up in only 77;
- native smoothing is therefore mostly reducing high material/shoulders, consistent with the earlier user observation that a smoothed field can end lower while becoming flatter;
- worst observed local relief remained very large (`1.6866 -> 1.6833 m`), so maxima/outliers are not a useful success metric by themselves.

### Diagnostic cost

When thousands of recovery geometry probes ran:
- TerrainWriter flush averaged roughly 1.07 ms;
- callback averaged roughly 0.27 ms.

In the later no-recovery part of the same process:
- flush averaged ~0.18 ms;
- callback ~0.003 ms.

The cost is associated with before/after height probing at recovery scale, not with deferred queue management alone.

Do not leave full 9-point before/after probing on every production brush.

### Design consequence

Strategy S (blind/full-width native smooth) has now taught us enough to advance research toward Strategy H:

**history-guided native smoothing**.

Preferred intent:
1. SpatialHistory identifies patches with RE-attributable rut debt;
2. current local surface estimator measures whether high-frequency relief/valley remains;
3. native GIANTS SMOOTH remains the physical actuator;
4. repeated pulses are bounded and converge on local relief, not an original absolute height;
5. broad slopes/player landscaping remain baseline unless RE history marks recoverable deformation.

Do not implement absolute original-height restoration.


## Implementation checkpoint — Strategy H1 history-guided native smoothing

Status: **implemented / automated harness green / runtime pending**

This step changes recovery **intent selection**, not the physical terrain actuator.

### What changed

Recovery no longer creates a uniform grid of smoothing brushes across every physically processed cultivator work area.

Instead:
1. query `SpatialHistory:getRecoveryCandidatesParallelogram()`;
2. accept only cells whose persisted RE `rutDepthM` exceeds the recovery-intent floor;
3. spatially cluster nearby candidate cells at native-smoothing scale;
4. retain the deepest candidate in each cluster;
5. sort by rut debt and cap the number of brushes;
6. use the selected history cell itself as the GIANTS SMOOTH center.

The actuator remains:
- GIANTS TerrainDeformation native smoothing;
- 0.05 m amount;
- 2.0 m radius;
- 0.20 hardness;
- 0.50 strength.

### Why this is safer

A cultivator passing over:
- intentional landscaping;
- natural broad slope;
- a field region never deformed by RE

does **not** authorize RE to smooth it merely because it lies beneath the work area.

SpatialHistory is the ownership/intention signal.

Current terrain geometry remains the physical truth and the native Smooth primitive remains the actuator.

This still does not freeze or restore an original terrain height.

### Deferred integration

A deferred patch is now revalidated against SpatialHistory before execution.

If its rut debt disappeared while the request was waiting for a loaded wheel to leave:
- the request is discarded;
- no stale smoothing occurs;
- `intentDeferredGone` records the event.

### Automated gates

Harness now proves:
- history debt produces smoothing candidates;
- no history debt produces zero smoothing even when the cultivator is physically working;
- loaded-contact deferred recovery still completes after contact clears;
- stale deferred recovery is discarded if its rut debt vanishes;
- repeat-pass/stamp behavior remains bounded.

### Runtime questions

Next runtime must answer:
- how much full-width brush count falls relative to v23;
- whether the visible wheel channels receive enough repeated native smoothing;
- whether `intentEmptyWorkAreas` grows as expected on already-clean field;
- whether the reduced brush count naturally removes the expensive geometry-probe cost;
- whether history-guided centers improve convergence compared with blind full-width coverage.

Do not introduce explicit RAISE/LOWER or original-height restoration until this phase is measured.
