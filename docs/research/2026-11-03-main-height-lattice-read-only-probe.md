# 03 November 2026 — MAIN terrain height lattice observation, no writes

## Objective

The user prioritizes **exact authorized lowering amplitude**: requested 1.5 mm must not silently become 3.891 mm (or 7.78 mm). Visual wheel clipping is lower priority unless it reveals a causal physical mismatch. Two isolated absolute setter attempts returned `centerDeltaM=-0.003891` for `requestedM=0.00150` with exactly one of nine MAIN vertices changed. These match the **hypothesis** of a 16-bit DEM and `heightScale=255m` -> `255/65535 = 0.00389105m`, but no underlying source map's `TerrainTransformGroup heightScale` has been independently authenticated yet.

## Public API and map evidence

GIANTS FS25 LuaDocs document `getTerrainHeightmapUnitSize(terrain)` as **horizontal** main heightmap unit size; it cannot measure the vertical quantum: https://gdn.giants-software.com/documentation_scripting_fs25.php?category=28&function=812&version=engine

`getTerrainHeightAtWorldPos(terrain,x,0,z)` is the read-only height API: https://gdn.giants-software.com/documentation_scripting_fs25.php?category=28&function=811&version=engine

Modding references describe `heightScale` inside `TerrainTransformGroup` in the map's `.i3d` and 16-bit grayscale DEM values from 0 to 65535:
- https://alfamods.no/modding/fs25-maps/4-kilometre-1-unit-map-setup/
- https://forum.giants-software.com/viewtopic.php?p=1656370

The 255m scale is a common default, **not a verified property** of Estância São Carlos, nor proof that engine setters round toward nearest. An observed ~3.891mm change alone is not enough to grant production authority.

## New diagnostic implementation

`scripts/terrain/TerrainMainHeightLatticeProbe.lua` (read-only) is loaded in `modDesc.xml` before `TerrainControlledWriteTrial`.

After marking a patch with `reGeoMark`, the command

```
reTerrainTrial lattice
```

samples only a bounded **9×9** grid (81 samples) of main-height vertices using the actual runtime journal's `unitM` and `getHeight`. It does not invoke native terrain setters, the deformation queue, the wheel updater, or any stateful writer. It tests the conditional 16-bit lattice hypotheses with `heightScale` values 64, 127.5, 128, 255, 256, 512, 1024; use

```
reTerrainTrial lattice 300
```

to test an **explicit map-file heightScale** of 300, if known. This does not set the map's scale.

The comparator uses **relative height differences** to avoid assuming a zero Y offset and checks finite samples, bounded residual error (min of 50µm and 2% of one quantum), at least 6 distinct levels, at least 8 steps of vertical span, and at least 2 **adjacent observed levels** to reject harmonics such as half-quanta that merely divide all observed heights. It reports `ONE_LATTICE_CANDIDATE`, `AMBIGUOUS_LATTICE_CANDIDATES`, `INSUFFICIENT_OR_ALIASED_EVIDENCE`, or `NO_LATTICE_CANDIDATE`. All statuses have `authorizesNativeWrite=false`.

Passing a lattice hypothesis **does not certify** actual `heightScale`, the internal quantizer, contact surface, fine tire track geometry, engine write behavior, persistence, or recovery ownership. A flat patch may produce an inconclusive result; do not treat this as an error. The command is not automatic and costs only 81 native reads on demand.

## Verification and remaining gates

`tests/terrain_main_height_lattice_probe_harness.lua` covers noisy 255m 16-bit data, false half-step alias, flat area, sparse even steps, nondefault 300m explicit candidate, 512m candidate, nonfinite inputs, and a mocked runtime where any write throws. The workflow runs `luac`, all harnesses, and validates `modDesc.xml`.

Remaining mandatory gates before enabling any permanent MAIN writes:
1. Independently establish the loaded map's heightScale/DEM encoding or an equivalent verified observation of its actual quantizer, without trusting two test points.
2. Confirm whether a one-step interior target changes exactly one sampled vertex by one measured step in a **disposable copy**, with no neighboring changes. Recognize that even perfect readback does not imply future behavior across maps.
3. Confirm save/reload persistence on a genuine disposable clone, with witness written and independently reloaded, and only then consider a narrowly scoped production design with an irreversible post-write quarantine on any out-of-budget change.
4. Native wheel-displacement grid is separate from MAIN; there is still no proven write API for fine wheel ruts. Do not infer it from lattice matches.

PR #64 remains draft; RE and RC main branches unchanged. No build should be distributed on a docs-only change.
