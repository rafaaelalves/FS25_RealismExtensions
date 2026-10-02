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


## Terrain interaction architecture — target shape

The validated terrain baseline is evolving toward explicit domain layers:

```text
normalized specialist state
        |
        v
TerrainWorkContext / ContactContext
        |
        +--> TerrainPassTracker
        |
        +--> TerrainWorkFootprint / ContactFootprint
        |
        v
Recovery / deformation policy
        |
        +--> TerrainRecoveryProfile
        +--> autonomous RecoveryAgent policy
        |
        v
TerrainOperation / TerrainWriter
        |
        v
physical callback / realization
        |
        v
SpatialHistory reconciliation
        |
        v
TerrainTelemetry / pass-event summaries
```

### TerrainPassTracker
Owns continuous physical work-pass identity and pass-level distance/time/speed bookkeeping. It must not own smoothing strength or terrain APIs.

### TerrainWorkFootprint
Owns spatial coverage of a soil-working operation. It should be reusable by cultivators, discs, subsoilers, rollers and other work-area-based tools.

### TerrainRecoveryProfile
Describes the physical recovery capability/finish target of a tool family. It should be based on specialization/operation semantics first, not hard-coded model names.

### ContactFootprint
Normalizes wheel/track contact geometry before persistent rut policy. Planned source classes include single tire, dual/twin, wide/flotation tire, implement wheel and native crawler.

Native GIANTS crawlers must be grouped from `spec_crawlers.crawlers`; constituent wheels must not also be processed as independent ordinary tires.

### RecoveryAgent
Autonomous recovery is a separate policy layer from player/AI vehicle control.

Candidate causes:
- PLAYER_WORK;
- NPC_FARM_WORK;
- NATURAL_RELAXATION;
- PUBLIC_MAINTENANCE;
- EXTERNAL_TERRAIN_EDIT.

RecoveryAgent decides eligibility/cadence/zone/profile. TerrainWriter remains the physical execution owner.

### Recovery arbitration
Only one recovery policy should own a physical region at a time.

Priority should prefer explicit active physical work over abstract/background recovery. A starting rule:

```text
active physical machine work
    > explicit external terrain edit reconciliation
    > scheduled NPC/public maintenance
    > natural relaxation
```

Background agents should defer or skip regions recently touched by an active player/vehicle operation rather than racing it.

### WorldRecoveryScheduler
Natural/NPC/public recovery must use a sparse bounded scheduler, not a map-wide per-frame scan.

Cost should scale with active damaged regions/candidates, not total map area.

Stable elapsed-time state may be persisted, but save/load recovery should compute bounded elapsed effects from timestamps rather than replaying missing frames.

### Ownership / zone classification
Autonomous recovery requires a spatial policy boundary such as:
- PLAYER_PROPERTY;
- PRIVATE_FIELD;
- NPC_FIELD;
- PUBLIC_MAINTAINED;
- NATURAL_UNMAINTAINED;
- EXCLUDED.

The exact source of ownership/zone data requires GIANTS/map research before implementation.

### Driver control is orthogonal
PLAYER / GIANTS_AI / COURSEPLAY identifies who controls a physically simulated vehicle. It must not be confused with NPC/world recovery where no physical vehicle may exist.

## Contact-system policy

Persistent terrain deformation must not assume every contact is a pneumatic tire.

Each ContactFootprint should expose at minimum:
- source type;
- contact center/frame;
- width;
- effective contact length;
- area;
- load;
- pressure;
- orientation.

This becomes the common input for persistent rut geometry/history.

## Recovery observability

Recovery must be explainable at three levels:
- short causal windows for debugging;
- physical pass summaries for active machines;
- background recovery event summaries for natural/NPC/public agents.

Every physical/history reconciliation should retain enough source identity to answer: **what changed this terrain, when, and why?**
