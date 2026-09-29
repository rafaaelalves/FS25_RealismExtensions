# Architecture

## Boundary between RC and Extensions

The desired dependency direction is:

```text
specialist mods
      |
      v
RealismCompatibility adapters / normalized provider
      |
      v
RealismExtensions StateContract
      |
      +--> TerrainDeformation
      +--> CropInteraction
      +--> SurfaceEffects
      +--> future presentation/diagnostics consumers
```

Feature modules should not import or patch specialist internals merely because those internals are available.

## StateContract

`scripts/api/StateContract.lua` is the consumer-side boundary.

A future provider should expose wheel context approximately like:

```lua
{
    grounded = true,
    worldX = 0,
    worldY = 0,
    worldZ = 0,

    longitudinalSlip = 0,
    lateralSlip = 0,

    localWetness = 0,
    sinkDepth = 0,

    structuralRadius = 0,
    tireWidth = 0,
    wheelLoad = nil,

    surface = nil,
    frozen = false,

    isAIControlled = false,
    isImplementWheel = false
}
```

This is illustrative, not yet the frozen schema. Fields must be added only after source/runtime evidence defines their semantics and units.

## Module rules

Each gameplay module must:
1. declare the phenomenon it owns;
2. list the states it consumes;
3. avoid writing state owned by another module/mod;
4. be independently disableable;
5. fail closed when required state is unavailable;
6. expose diagnostics/telemetry adequate to validate runtime behavior;
7. keep per-frame/global scans bounded and justified.

## Performance rules

Prefer:
- event/registration-driven vehicle discovery;
- cached wheel contexts;
- spatial/temporal throttling;
- deformation thresholds and budgets;
- change-driven updates.

Avoid:
- scanning every vehicle every frame;
- rewriting unchanged physics state;
- unbounded terrain brush operations;
- multiple modules querying the same specialist internals independently.

## Compatibility philosophy

Absorb another mod only when doing so clearly reduces duplicate ownership/hooks, improves state quality, improves performance/maintenance, or enables a coherent phenomenon impossible to compose externally.

A smaller dependency graph is not itself sufficient reason to rewrite a mature specialist.
