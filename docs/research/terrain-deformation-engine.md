# TerrainDeformation engine audit and runtime design

Updated: 2026-09-29

## Source evidence

### GIANTS official FS25 scripting docs

The FS25 PlaceableLeveling implementation shows the supported TerrainDeformation lifecycle:

1. create `TerrainDeformation.new(terrainRootNode)`;
2. add one or more deformation areas/brushes;
3. queue through `g_terrainDeformationQueue:queueJob(...)`;
4. receive completion callback;
5. delete deformation objects after completion, preferably on a later async task.

Source: https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=745&version=script

The FS25 rice-field implementation independently confirms multiple concurrent queued TerrainDeformation objects and callback-driven ownership.

Source: https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=756&version=engine

### FarmKit

FarmKit custom ruts currently:

- create one `TerrainDeformation` object per deformation tick;
- use additive deformation mode;
- set a negative additive height delta;
- add one soft-circle brush;
- attempt mission queue variants and fall back to direct apply;
- keep a per-wheel 500 ms gate;
- offset the brush behind the wheel;
- cap accumulated depth per wheel rather than per terrain location.

RE keeps the useful GIANTS brush path but changes ownership/scheduling:

- spatial history is ground-cell based rather than wheel based;
- multiple brushes with similar depth can share one deformation object/job;
- lifecycle deletion is explicit after callback;
- no crop destruction is bundled into rut writing;
- no AI multiplier exists in the physical model;
- no global mission vehicle scan is needed.

### True AI Tracks 2.2.0.1

True AI Tracks does not create custom TerrainDeformation brushes. Its AI-ground capability enables the native wheel displacement/tire-track path by overriding WheelPhysics displacement gates and periodically rediscovering AI/implement wheels.

Therefore RE TerrainDeformation and True AI Tracks overlap in final visible ground consequences but not through the exact same mechanism.

RE must not claim True AI Tracks replacement until runtime validation covers:

- GIANTS AI vehicles;
- attached wheeled implements;
- Courseplay-controlled vehicles;
- native tire tracks/displacement parity where desired;
- performance under large fleets.

## Engine architecture

### Vehicle-local specialization

`TerrainDeformationEngine` is injected into wheeled vehicle types.

This means each wheeled object owns its own update path. The engine does not iterate `g_currentMission.vehicles` to discover work.

Cheap activity gating occurs before StateContract access so parked vehicles stop paying provider/model cost after their initial contact sample.

### Sampling

Default sampling cadence: 100 ms per active wheel.

Path between previous/current wheel contact is subdivided according to footprint size, with an upper bound of 6 samples per wheel tick.

Stationary wheelspin still samples the current cell because wheel-surface speed can create shear without vehicle translation.

### Spatial history

History is quantized into 0.20 m cells.

Each cell stores response history such as:

- rut depth;
- longitudinal shear distance;
- lateral shear distance;
- pass count.

The cache is bounded. Large caches prune least-recently-touched cells in batches to avoid sorting the full history for every new cell after the limit.

Current limitation: history is session-memory only. The geometry itself persists in the terrain heightmap, but response memory is not yet persisted in savegame data. The module remains disabled by default until this mismatch is addressed or accepted for prototype testing.

### Brush writer

`TerrainWriter` owns all GIANTS TerrainDeformation calls.

Defaults:

- max 24 brushes consumed per frame;
- max 4 deformation jobs per frame;
- max 8 brushes per deformation object;
- max queue backlog 512 brushes;
- depth quantization 0.5 mm;
- minimum useful depth 0.4 mm.

Brushes are grouped by quantized depth because one additive TerrainDeformation object uses one additive height-change amount across its brushes.

### Lifecycle

Each queued deformation object owns a callback target that deletes the object after completion. When the GIANTS async task manager is available, deletion is deferred to the next async task, matching official GIANTS patterns.

### Server authority

Only server vehicle instances submit terrain deformation.

Clients consume replicated terrain state through the game rather than running their own additive writes.

## Deliberate exclusions

The first runtime engine does not:

- change friction, sink, wheel radius or engine load;
- destroy crops;
- alter field cultivation state;
- synthesize crawler footprints;
- automatically suppress True AI Tracks;
- persist spatial response history;
- enable itself by default.

## Runtime validation plan

First in-game prototype should be run with TerrainDeformation explicitly enabled and True AI Tracks disabled to avoid ambiguous visual ownership.

Validate in this order:

1. one player tractor, dry field, low slip;
2. same tractor, wet field;
3. stationary wheelspin;
4. hard lateral steering/scrub;
5. repeated passes over the same rut;
6. attached wheeled implement;
7. GIANTS AI worker;
8. Courseplay;
9. large fleet / parked vehicle performance;
10. save/reload behavior and terrain/history mismatch.

Only after these tests should RC consider disabling True AI Tracks when RE owns the capability.