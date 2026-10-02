# TerraFarm audit — TerrainDeformation pipeline and material accounting

Updated: 2026-10-02
Audited source: `scfmod/FS25_TerraFarm` commit `b50e677cdef062d605ab188f8982ae1faa2789e7`.

## 1. Operation class structure

### Source finding

TerraFarm splits terrain behavior into:
- `LandscapingBase`;
- common `LandscapingInput` / `LandscapingOutput`;
- operation subclasses such as Smooth, Flatten, Slope and Paint.

Common layers own:
- brush generation;
- modified-area bookkeeping;
- collision/outside-area constraints;
- async apply;
- success/failure cleanup;
- density/field/AI side effects;
- optional painting/material conversion.

Operation subclasses mainly configure TerrainDeformation mode/target.

### RE lesson

This strongly supports RE's planned separation:
- policy chooses *what* operation is desired;
- TerrainOperation/TerrainWriter owns *how* engine jobs execute;
- physical callback owns realized result;
- history reconciliation happens afterward.

## 2. Input brush construction

### Source finding

For active work-area nodes, input operations add one soft brush per active node.

Circle mode:
`addSoftCircleBrush(x, z, radius, hardness, strength, -1)`

Square mode:
`addSoftSquareBrush(x, z, radius*2, hardness, strength, -1)`

No deformation is submitted when no modified input area was produced.

### RE lesson

This is a direct precedent for a reusable node-based `TerrainWorkFootprint`, and for rejecting empty/no-op work before creating engine jobs.

## 3. Input Smooth

### Source finding

`LandscapingInputSmooth` uses:
- `TerrainDeformation.new(g_terrainNode)`
- additive height-change amount 0.05;
- `enableSmoothingMode()`.

Default MachineState input brush:
- radius 2 m;
- strength 0.25;
- hardness 0.2.

The common input path applies directly with `apply(false,...)`.

### RE caution

These values are gameplay configuration, not soil constants. RE's currently validated recovery policy must not be replaced simply to match TerraFarm.

The structural contract is more important than the constants:
- active spatial samples;
- explicit machine constraints;
- async completion;
- measured physical effect.

## 4. Output Smooth

### Source finding

Output Smooth also uses smoothing mode but height-change amount 0.75 and a separate output node/material-output path.

### RE lesson

There is no single universal “correct smoothing amount.” Operation intent matters.

Do not compare TerraFarm output Smooth numerically with agricultural recovery without considering that it participates in material deposition/output behavior.

## 5. Flatten and slope target operations

### Source finding

Input Flatten/Slope use set-deformation mode with explicit height targets/planes.

Input Flatten:
- can prohibit grading upward unless `allowGradingUp`;
- can require active terrain-contact nodes unless `forceNodes`.

Output Flatten/Slope:
- perform a precheck against target height;
- create the TerrainDeformation;
- call `apply(true, previewCallback)`;
- compare preview displacement against a radius-dependent threshold;
- only then call real `apply(false,...)`.

The preview thresholds are heuristic functions of radius, not generic engine constants.

### RE opportunity

For future:
- target-plane recovery;
- municipal grading;
- bounded road maintenance;
- mass-conserving deposition;

consider preview-first execution when the engine's preview metric correlates with the desired safety criterion.

Do not force preview semantics onto current SMOOTH merely because Flatten uses them.

## 6. Constraints differ by operation

### Source finding

Generic machine input/output paths typically set:
- outside-area angle constraints;
- blocked-area max displacement 0;
- dynamic-object collision mask 0;
- dynamic-object max displacement 0.

Input Flatten differs:
- blocked/dynamic max displacement are small but non-zero (0.01).

This confirms constraints are part of operation semantics, not incidental boilerplate.

### RE lesson

TerrainWriter should eventually use named operation profiles for constraints rather than one implicit/default constraint set.

Potential profiles:
- wheel rut LOWER;
- machine agricultural SMOOTH;
- target grading;
- mass deposition;
- municipal maintenance.

## 7. Success/failure lifecycle

### Source finding

On success:
- operation-specific material accounting runs;
- density/field cleanup is applied;
- modified areas are marked dirty for AI;
- optional paint deformation is applied.

On failure:
- deformation is cancelled;
- paint deformation is cancelled;
- terrain objects are deleted/cleaned.

### RE lesson

Keep “physical callback success” as the commit point for:
- SpatialHistory reconciliation;
- mass accounting;
- AI-navigation invalidation;
- secondary visual/density side effects.

Do not mutate logical history merely because a job was submitted.

## 8. Density/field side effects

### Source finding

After successful terrain deformation, TerraFarm can:
- remove field area;
- remove weeds;
- remove stones;
- clear density-map height;
- clear decoration;
- paint terrain;
- mark modified world bounds dirty in `g_currentMission.aiSystem`.

These are controlled by MachineState flags/modifiers.

### RE compatibility rule

RE TerrainRecovery should **not** automatically copy these side effects.

Agricultural recovery currently owns persistent heightfield geometry/history, not:
- weeds;
- stones;
- field ownership/state;
- crop/deco clearing.

For large future RE grading/municipal operations, however, AI-area invalidation is likely required. Current RE code has no `aiSystem:setAreaDirty` path, so this is a concrete future gap.

## 9. AI navigation dirtying

### Source finding

TerraFarm tracks exact modified brush regions, computes their world bounding boxes and calls:
`g_currentMission.aiSystem:setAreaDirty(minX, maxX, minZ, maxZ)`
after successful deformation.

### RE opportunity

Add an optional `TerrainModifiedRegion` result from TerrainWriter/operations.

Small wheel ruts may not justify frequent AI dirty updates. Larger operations such as:
- target-plane grading;
- municipal road repair;
- large autonomous maintenance;
- large berm/deposition work;

should coalesce modified regions and dirty AI navigation on a bounded cadence.

## 10. Material accounting from physical volume

### Source finding

Input operations use the TerrainDeformation callback's actual displaced volume:
- convert m³ to liters;
- apply a configurable input ratio;
- add material to fill units or route it through machine-specific behavior.

Output operations:
- request terrain output based on available liters;
- TerrainDeformation callback reports actual output volume;
- convert actual volume back to liters;
- only remove that realized amount from the fill unit.

Ripper/shovel/overflow paths have specialized material-routing behavior.

### RE lesson for SoilMassTransport

This is one of the strongest TerraFarm precedents for redesigning SoilMassTransport:
- **physical callback volume is authoritative**;
- material inventory changes after realization;
- requested amount is not assumed to equal achieved amount;
- excavation and deposition are separate operations.

RE's future mass ledger should follow that discipline even though its “material” is soil mass/history rather than a player fill unit.

## 11. Painting is a secondary deformation

### Source finding

Terrain paint uses a separate TerrainDeformation object and is applied after successful primary deformation.

### RE lesson

Keep cosmetic/surface-state follow-up separate from primary heightfield writes.

If RE later adds visual furrow/soil-surface painting, it should not be entangled with the physical height callback.
