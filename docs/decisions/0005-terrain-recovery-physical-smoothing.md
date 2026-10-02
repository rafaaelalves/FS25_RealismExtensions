# 0005 — Terrain recovery uses physical TerrainDeformation smoothing

Status: accepted for runtime validation

## Context

TerrainRecovery v12/v13 called DensityMapHeightUtil.smoothAroundLine after cultivator work.
Runtime probes proved the function executed without errors but did not change the terrain
heightfield used by RealismExtensions rut geometry: v13 observed zero changed samples.

FS25 TerraFarm provides a stronger precedent for physical terrain smoothing:
TerrainDeformation.new(...), setAdditiveHeightChangeAmount(...),
enableSmoothingMode(), then soft terrain brushes and asynchronous apply/callback.

RealismExtensions already uses TerrainDeformation for rut lowering and mass-transport
raising, so using the same API family removes a split between deformation and repair.

## Decision

TerrainRecovery v14:

- stops using DensityMapHeightUtil.smoothAroundLine for RE rut repair;
- submits SMOOTH jobs through TerrainWriter using TerrainDeformation smoothing mode;
- samples the exact RE history cell at the smoothing brush center before/after;
- changes SpatialHistory only after the asynchronous terrain callback reports a real
  upward height delta at that remembered rut;
- never treats local smoothing that lowers a ridge as rut healing;
- selects a bounded, depth-first, spatially separated subset of damaged cells in the
  cultivator work area instead of smoothing healthy terrain blindly;
- keeps recovery progressive across passes rather than resetting a rut in one pass.

TerrainResponseModel also clamps plasticized Mud sink to the surface-specific absolute
slip-rut cap so instantaneous sink cannot bypass RE geometry limits.

## Consequences

The existing RC -> state -> response -> history -> writer architecture remains valid.
Only the recovery execution path is replaced.

Automatic world maintenance will reuse the same smoothing jobs later. It should operate
only over sparse remembered damage, with ownership-aware policy and fixed work budgets,
rather than scanning the full terrain heightmap.

Player-owned farmland remains primarily the player's maintenance responsibility.
NPC-owned and public/unowned areas may recover on shorter maintenance timescales so
traffic damage does not persist unrealistically for in-game years.
