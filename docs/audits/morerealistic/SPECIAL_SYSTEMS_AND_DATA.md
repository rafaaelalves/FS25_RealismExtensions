# MoreRealistic special systems and data audit

## Purpose

This document covers the parts of MR that are neither the core wheel/drivetrain model nor simple converted-vehicle tuning: WoodCrusher, conveyor loaders, override catalog, default crop/fill rebalance, Precision Farming filename bridges and data/lifecycle edge cases.

## WoodCrusher

MR's WoodCrusher is effectively a subsystem replacement:
- buffers converted wood volume;
- adds power demand proportional to processed material;
- limits feed/crush behavior with available machine state;
- adds traction behavior for split shapes;
- attempts to recover split-volume lost by cutting;
- streams additional working state.

### Material-conservation defect

`mrWaitingFillLevel` is reduced before `addFillUnitFillLevel` is called, and the function's applied delta is ignored.

If the fill unit is capacity-limited, requested material that was not accepted is no longer present in the waiting queue.

Recommended fix:
1. calculate requested delivery;
2. call the owner FillUnit API;
3. subtract only the actual applied amount from `mrWaitingFillLevel`.

This is conceptually important for RE too: **requested physical/material change is not realization**. Use the callback/return value as authority.

## ConveyorLoaderVehicle adapter

Loader vehicles without a native PowerConsumer get instance methods for:
- PTO rpm;
- consumed PTO torque;
- fill-unit free capacity.

This is a pragmatic capability adapter rather than a generic specialization.

The free-capacity override deliberately uses `defaultCapacity - fillLevel` to prevent a GIANTS conveyor feedback issue where capacity/fill could rise indefinitely when discharge speed is too low.

Compatibility lesson:
- some MR behaviors are per-instance method replacement rather than class/global hooks;
- detection/provider code should inspect capability/instance state, not only global function pointers.

## Override catalog

Exact 0.26.08.03 database:
- 221 vehicle entries;
- 220 unique source filenames;
- one duplicate: `data/vehicles/grimme/evo290/evo290.xml`;
- duplicate maps to the same MR target and is therefore benign catalogue noise.

MR's replacement database is central to its calibration strategy. It allows base/DLC equipment to retain normal store/save identity while running an MR XML internally.

### Persistence strength

MR serializes genuine filenames rather than its private override XML path. This makes disabling/re-enabling the mod more resilient than a naive replacement catalog.

### Store mutation risk

Store combination lookups rewrite fields of the caller-supplied `combinationData` table in place. The impact depends on GIANTS caller reuse and remains a design-risk watchpoint.

## Precision Farming filename translation

MR directly replaces three PF linkage functions so MR-overridden base vehicles still resolve sensor/manure/sprayer metadata.

This solves a real cross-mod identity problem but creates a fragile direct ownership surface.

If PF changes its function shape or another mod owns the same functions, RC is the appropriate place for an explicit versioned bridge.

## Default fill-type rebalance

MR changes selected base-game fill types only while GIANTS is loading default types.

This is a good scope boundary: arbitrary mod fill types are not globally rewritten by name later.

Changed domains include:
- crop bulk densities;
- seed/fertilizer/diesel densities;
- selected price values.

Physical consequence:
density affects mass, which then propagates into MR CoM, wheel load, traction/RR and implement dynamics.

Therefore economy/data mods can have physics consequences under MR even if they never touch WheelPhysics.

## Default fruit-type rebalance

MR changes selected vanilla yields and attaches per-fruit processing factors:
- `mrCapacityFx`;
- `mrThreshingFx`;
- `mrChopperFx`.

These feed MR combine throughput/power logic.

This creates a general integration class:
**agronomic output modifiers must be aligned with MR physical-throughput accounting**.

MRSoilHarvest is one proven example, but future disease/weather/yield systems should be checked for the same semantic ordering problem.

## Data-loader robustness

The tire friction/RR loader mutates global GIANTS tire-type tables incrementally.

On unknown tire/surface names or a missing value it breaks out of part of the current load loop rather than constructing a complete candidate table and committing atomically.

Current shipped data is internally consistent, so this is not a present failure. It is a version-drift risk.

Safer future pattern:
- parse and validate complete data into private temporary structures;
- only replace global owner tables after full validation succeeds.

## Ballast mapping typo

`MR_WheelVisualPart.lua` defines:
`commonKey = "data/shared/wheels/weights/"`

but checks the CNH path using:
`commonKey .. "/cnh/weight001.i3d"`.

The resulting double slash prevents the normal path from matching the intended 0.6 t special case.

Runtime significance depends on whether this exact asset/configuration is used in the current catalog.

## Duplicate helper-symbol pattern

MR sometimes installs a wrapper, then later redefines the same `mr...` helper symbol and installs a second wrapper.

Examples:
- two `WheelPhysics.mrUpdateBase` layers;
- two `FillUnit.mrLoadFillUnitFromXML` layers;
- two `Baler.mrSetIsUnloadingBale` layers.

The previously installed closure remains in the chain, so this is not automatic behavior loss.

However, compatibility/introspection systems that compare the current global helper pointer against an installed layer can report "pointer drift" even when the chain is healthy.

Recommendation:
use unique helper names per layer in future MR versions or make diagnostics chain-aware.
