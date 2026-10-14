# TerraFarm audit — official machines addon and extensibility pattern

Updated: 2026-10-02

Sources audited:
- `scfmod/FS25_TerraFarm` commit `b50e677cdef062d605ab188f8982ae1faa2789e7`
- `scfmod/FS25_TerraFarmMachines` commit `bc2f65223879f6ee447554ea4590e826771918a4`

## 1. Why the addon matters

The official machines addon demonstrates how TerraFarm scales support beyond the core mod without hard-coding every third-party vehicle in Lua.

A registry XML maps external vehicle XML paths to small machine-configuration XML files.

Typical configuration only supplies the semantic delta TerraFarm needs:
- machine type;
- supported operation modes;
- work-area reference node;
- width;
- offset;
- optional raycast/contact tuning.

Examples observed:
- a ripper config declares type `ripper`, modes `LOWER FLATTEN SMOOTH PAINT`, reference node, width and vertical offset;
- a compactor declares type `compactor`, `FLATTEN SMOOTH PAINT`, work-area node/width/offset;
- a grader/leveler can rely on existing GIANTS leveler geometry and supply only an offset;
- discharge equipment may need only machine type and output work-area geometry.

## 2. Architectural lesson: generic core + declarative correction layer

This is a strong pattern for RE/RC.

Future RE support should distinguish:
1. **generic inference** from GIANTS/MR/RC structures;
2. **semantic family defaults**;
3. **small declarative equipment overrides** only when inference is insufficient.

Candidate RE external-profile uses:
- `TerrainRecoveryProfile` overrides;
- `TerrainWorkFootprint` reference/offset corrections;
- `ContactFootprint`/crawler grouping corrections;
- implement-wheel role/order metadata;
- unusual work-area geometry;
- known compatibility exclusions.

The core should not become:
```text
if machine == X ...
elseif machine == Y ...
elseif machine == Z ...
```

## 3. Profile precedence proposal for RE

A future independent RE registry could resolve:

```text
engine/native inference
    -> specialization/tool-family defaults
    -> mod/equipment declarative profile
    -> runtime sanity validation
```

Explicit profile data should refine missing/incorrect inference, not replace reliable engine state unnecessarily.

## 4. Runtime validation requirement

External metadata must be treated as a hint/configuration, not unquestioned truth.

At load/runtime validate:
- vehicle XML identity exists;
- referenced nodes/work areas resolve;
- width/length/radius values are finite/plausible;
- crawler/contact groups do not double-own constituent wheels;
- profile family is compatible with detected specializations;
- errors fail closed with clear diagnostics.

## 5. Version drift

Exact vehicle XML paths are practical but can become stale when third-party mods restructure files.

Useful tooling precedent from TerraFarm:
- verify configuration entries;
- report missing external vehicle files;
- reload configuration registry in single-player development.

RE should consider equivalent developer commands/tests for profile packs:
- list resolved profiles;
- verify target vehicle paths;
- show rejected/stale profiles;
- dump inferred vs configured geometry.

## 6. What not to copy literally

Because TerraFarm's repository licensing is restrictive for derivative distribution, RE should not vendor or adapt the TerraFarm addon/config files.

The lesson is architectural:
- external declarative registry;
- minimal per-equipment metadata;
- generic core;
- verification tooling.

RE should define its own independent schema and implementation.

## 7. Compatibility-pack opportunity

This architecture would allow a separate optional package such as a future:
`FS25_RealismExtensionsProfiles`

It could contain only data/configuration for equipment known to need corrections, while RE core remains useful without it.

That package could also be maintained independently from the main physics release cadence.

Do not require such a pack for vanilla/native equipment that can be inferred correctly.
