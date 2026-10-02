# 0005 — Terrain recovery uses physical TerrainDeformation smoothing

Status: accepted mechanism; current policy under runtime validation
Updated: 2026-10-02

## Context

v12/v13 called `DensityMapHeightUtil.smoothAroundLine` after cultivator work. Runtime probes proved the function executed without errors but did not change the heightfield used by RE: v13 observed zero physically changed samples.

TerraFarm and GIANTS TerrainDeformation usage provide a stronger precedent for physical smoothing:
`TerrainDeformation.new(...)`, additive height-change amount, smoothing mode, soft brushes, asynchronous apply/callback.

RE already uses TerrainDeformation for persistent terrain writes, so recovery should use the same physical API family.

## Decision

Recovery uses TerrainDeformation SMOOTH jobs and treats the callback plus physical before/after geometry as authoritative.

History reconciliation occurs only from verified reduction in local physical roughness. Absolute center-height direction is not sufficient: valid smoothing can lower a ridge or raise a depression.

The writer owns TerrainDeformation lifecycle; recovery policy owns where/when/how strongly to request smoothing and how verified physical improvement reconciles SpatialHistory.

## Runtime refinement

v14 proved physical smoothing executes but exposed the inadequacy of center-height-only success metrics.

v21 adopted machine-style smoothing across the cultivator work footprint and root-combination rut suppression. Runtime showed most measured smoothing callbacks could improve roughness, but destructive LOWER writes could still appear.

v22 identified and corrects a semantic activation bug:
- GIANTS Cultivator `realArea` is changed agricultural state, not physical work;
- `area` is processed area;
- repeated passes can have `realArea=0, area>0`;
- recovery/suppression must therefore not depend on `realArea>0`.

v22 uses physical work state + processed area so repeated passes remain recovery operations.

## TerraFarm precedent clarification

TerraFarm input smooth currently uses:
- smoothing height-change amount 0.05;
- default input radius 2 m;
- default input strength 0.25;
- default input hardness 0.2;
- multiple active work-area nodes across machine width;
- asynchronous TerrainDeformation callback.

RE currently uses its own calibrated policy values. TerraFarm constants are implementation precedents, not empirical agricultural constants. Do not claim exact TerraFarm parity unless the values and lifecycle actually match.

## Consequences

- API success is not physical-success evidence.
- changed agricultural area is not physical-work evidence.
- every recovery experiment needs physical + causal telemetry.
- repeated passes are a first-class regression scenario.
- future refactoring should separate work detection, work footprint, terrain operation and history reconciliation.
- automatic world maintenance, if added later, should reuse the physical operation layer without pretending to be an agricultural work detector.
