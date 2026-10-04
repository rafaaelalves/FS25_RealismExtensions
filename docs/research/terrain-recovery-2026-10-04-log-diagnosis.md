# Terrain Recovery runtime diagnosis — 2026-10-04 cultivator log

Source session:
- FS25 runtime log: `log(20261004-111606).txt`
- ModMixer log: `ModMixer.log`
- RE build: `feat/terrain-recovery` commit `7d5a41e8bf7c0c0ae2ae288f48b87251eb78501c`
- recovery implementation: v22
- observed symptom: cultivation initially visibly repairs terrain, then deep/wide wheel ruts remain after repeated passes.

## Executive diagnosis

**The main failure is not that recovery stops being called. It is that v22 defines successful physical recovery as local roughness reduction while using native smoothing as the only terrain operation.**

For a deep rut, smoothing can reduce roughness by lowering the surrounding/high samples rather than raising the depression.

The log proves this is the dominant behavior:
- final recovery brushes/callbacks: 9,991;
- roughness improved: 8,009;
- center raised: only 95;
- center lowered: 8,602;
- writer rejected: 0.

Therefore a large fraction of brushes classified as "improved" did not fill a rut. They flattened local relief mainly by lowering terrain.

Once a wheel rut becomes a broad smooth depression:
- the local roughness metric becomes small;
- native smoothing has little remaining local gradient to act on;
- repeated passes can produce little/no visible recovery;
- yet SpatialHistory may already have been reduced because roughness previously improved.

This matches the reported user-visible symptom.

## Evidence that the recovery loop did not stop

At the end of the session:
- work-area calls: 8,856;
- physically worked calls: 8,421;
- repeat calls: 7,576;
- coverage samples: 50,786;
- recovery brushes enqueued: 9,991;
- callbacks: 9,991;
- writer rejects: 0;
- machine smoothing jobs: 4,993.

Repeated cultivated ground remained active:
- repeat processed area: 480,879 units;
- latest windows still contained repeat work and smoothing callbacks.

Therefore this is not primarily:
- a missing repeat-pass callback;
- queue starvation;
- writer rejection;
- a hard cessation of cultivation recovery.

## Stamp skips

Final `stampSkips=40,795` looks large, but it is not evidence by itself that recovery stopped.

The work area is reported every update and coverage brushes overlap heavily. v22 intentionally applies a 750 ms world-space cooldown.

Thus many coverage points are expected to be suppressed while the same physical patch is still inside a continuous pass.

The important evidence is that despite the skips, brushes continued to enqueue and callbacks continued to complete.

This mechanism may still deserve redesign for path/passage identity, but it is secondary to the geometric-recovery flaw.

## Core semantic flaw

The callback does:

1. sample a local best-fit-plane RMS roughness before smoothing;
2. native GIANTS smoothing;
3. sample roughness after;
4. if `roughnessBefore - roughnessAfter > epsilon`, consider physical recovery successful;
5. reduce RE logical rut/shear history in a circle.

The code intentionally ignores the sign of center-height movement.

That rule is invalid for recovering a persistent wheel rut.

### Counterexample

Suppose the local cross-section is:

```
0      0
 \____/
  -0.15 m
```

Native smoothing may produce:

```
-0.04      -0.04
    \____/
     -0.12
```

RMS roughness decreases, so v22 reports an improvement.

But the actual terrain has not returned toward its pre-rut/reference surface. Some surrounding soil was merely lowered.

If this continues, the area approaches a broad low basin:
- low roughness;
- large absolute elevation error;
- no remaining gradient for smoothing.

That is the observed "worked at first, then stopped doing anything" failure mode.

## Logical/physical divergence

v22 reduces `SpatialHistory.rutDepthM` whenever roughness improves.

The log shows cumulative logical history recovery advancing strongly even though center movement is overwhelmingly downward.

This can create:

```
logical history says rut recovered
          !=
heightfield still contains broad depression
```

That divergence is especially dangerous because future terrain behavior can then reason from a rut state that no longer describes actual geometry.

## Why simply increasing smoothing strength is not the fix

Increasing:
- smooth amount;
- strength;
- frequency;
- number of passes;

would make the operation more aggressive but would not solve the missing target.

A smoother has no semantic knowledge of:
- pre-rut elevation;
- expected local field plane;
- working depth;
- displaced soil volume;
- whether a low sample is a rut or natural terrain.

A stronger blind smoother can erase more legitimate topography while still failing to reconstruct the intended surface.

## Required redesign: recovery as constrained soil redistribution

Cultivation recovery should be modeled as a **targeted redistribution/leveling operation**, not merely repeated GIANTS smoothing.

Recommended architecture:

```
worked implement footprint
        |
        v
RecoverySurfaceEstimator
        |
        +-- local/reference surface
        +-- current terrain samples
        +-- persistent rut history
        +-- operation depth/capability
        |
        v
RecoveryMassRedistribution
        |
        +-- low regions eligible for fill
        +-- high/berm regions eligible as source
        +-- per-pass working-depth limit
        +-- volume-conservation budget
        |
        v
TerrainWriter
        |
        +-- controlled RAISE for deficits
        +-- controlled LOWER for excess/high spots
        +-- optional final light SMOOTH
        |
        v
geometry verification
        |
        v
SpatialHistory recovery only for physically restored depth
```

## Reference surface: do not blindly restore one frozen "original height"

A permanent exact original-height target is also insufficient:
- legitimate tillage/terrain work can alter the field;
- mass transport changes local material distribution;
- natural slopes must be retained;
- external terrain operations may intentionally reshape ground.

Prefer a robust reference surface.

Candidate hierarchy:

1. **persisted pre-deformation local reference** where trustworthy;
2. robust plane/low-order surface fitted to surrounding non-rutted boundary samples;
3. neighboring recovered/undisturbed history cells;
4. conservative fallback from current local topography.

Persisted pre-deformation height can act as a safety/reference constraint, not necessarily an absolute target.

## Recovery operation semantics

Different operations can have different capacities.

For a cultivator:
- redistribute within a working depth;
- progressively fill wheel depressions;
- progressively reduce berm/high spots;
- do not reconstruct arbitrary deep landscape changes;
- multiple passes can converge.

For deeper tillage:
- larger vertical correction budget;
- stronger history reset.

For roller/reconsolidation:
- separate operation, potentially lowering loose peaks rather than filling deep wheel ruts.

The system should therefore consume operation capability rather than one generic smoothing primitive.

## Geometry verification

Replace "roughness improved" as the history-recovery trigger.

Track at minimum:
- target/reference elevation at the cell/patch;
- center/current elevation error;
- low-quantile deficit;
- high-quantile excess;
- roughness as a secondary shape metric.

Only reduce logical `rutDepthM` by the physically observed amount that moved toward the recovery target.

If the center moves downward while the target deficit remains:
- that is **not rut recovery**;
- do not reduce rut history merely because roughness fell.

## Relation to VMT audit

The recent Visual Mud Tracks audit highlighted:
- terrain writes should have explicit lifecycle semantics;
- original/pre-deformation state can be useful as a safety/reference;
- physical/logical state must not silently diverge.

This runtime session independently validates that lesson.

However the proposed redesign should not copy VMT's direct target-height writer or treat exact original height as universal truth.

RE can do better by combining:
- its SpatialHistory;
- actual displacement/mass-transport model;
- robust local surface estimation;
- operation-specific working-depth limits.

## Secondary observations

### Writer health
No writer rejection/failed-job pattern explains the symptom.

### Repeat pass detection
Repeat passes work: by end of session, 7,576 of 8,421 physical work-area calls are repeats.

### Recovery suppression of new ruts
Combination-wide rut suppression is active heavily during cultivation and is not the main failure.

### Old build
This session predates `feat/assimilation-tracks-vmt`:
- it does not contain LoadedContactRegistry;
- it does not contain the new loaded-wheel recovery guard;
- therefore the reported failure cannot be caused by that new guard.

## Recommended priority

Classify as **core TerrainRecovery correctness issue**.

Before further expanding absorbed capabilities, redesign recovery geometry if the current tracks/VMT runtime test does not reveal a more urgent regression.

Do not attempt to fix this with a simple constant increase.

## Next engineering step

Build a **RecoverySurfaceEstimator + recovery geometry probe** first, before changing terrain writes.

The next diagnostic/prototype should:
1. sample current patch + annulus/boundary;
2. estimate robust reference plane;
3. measure deficit/excess volume;
4. compare current native smoothing result against target-error reduction;
5. log how much each pass actually restores toward reference.

Once that estimator is validated on:
- a deep wheel rut;
- a broad rut;
- a slope;
- natural uneven terrain;
- berms;

implement bounded volume redistribution.

This preserves the project's rule:
**measure the phenomenon first, then give the writer a physical target.**
