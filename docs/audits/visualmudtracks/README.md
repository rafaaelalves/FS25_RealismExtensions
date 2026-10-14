# Visual Mud Tracks selective-absorption assessment

Updated: 2026-10-04

Exact package inspected:
- mod: `FS25_VisualMudTracks`
- version declared by package: `1.4.0.27`
- author: Sherman
- ZIP SHA-256: `4796d1f529fe6e0b7e324e91822d09858252f7f1e946a9a5c45f91168516470d`
- 29 Lua files
- ~33,411 Lua lines / ~1.18 MB Lua source
- multiplayer declared: true

Purpose: evaluate Visual Mud Tracks primarily as a source of **selective functional absorption and engineering lessons**, not as another target-stack dependency and not as a monolithic replacement for RE/Mud/Soil specialists.

## Safety / provenance triage

The uploaded archive was inspected statically without executing its Lua.

Package types:
- Lua/XML;
- DDS/I3D/shapes assets;
- OGG audio.

No executable/DLL/batch/PowerShell payload, nested executable loader, shell/process execution, HTTP/download client or dynamic eval/load payload was found.

The code writes only through normal GIANTS save/XML/file APIs and terrain APIs.

Public mod listings show the same Visual Mud Tracks lineage by Sherman/Sherman200, including 1.3.x and 1.4.x builds. The exact `1.4.0.27` package was not found in the indexed public sources checked, so exact distribution provenance is not independently verified.

Static safety result: **no suspicious behavior found**. This is not a malware guarantee, but there is no static reason to stop analysis.

## Licensing boundary

The inspected ZIP contains no LICENSE/NOTICE and the Lua source contains no explicit reuse license.

Therefore:
- do not copy source into RE;
- treat VMT as behavioral/architectural research;
- functional reimplementation must be clean-room unless the author grants reuse rights.

## Executive decision

**DO NOT ABSORB VMT AS A WHOLE.**
**DO SELECTIVELY ABSORB SEVERAL ENGINEERING PATTERNS.**

VMT has grown into a second realism platform:
- persistent real heightmap ruts;
- wheel sink / terrain handoff;
- tire pressure/CTIS;
- mud/particle/washable visuals;
- soil compaction;
- root/structure damage;
- crop destruction;
- tillage recovery;
- biological recovery;
- RWSM integration;
- persistence/migration;
- multiplayer chunk synchronization.

That breadth is exactly why adding it to the target stack or cloning it wholesale is undesirable. It duplicates domains already deliberately owned by:
- MudSystemPhysics;
- SoilCompaction / other agronomy specialists;
- RC provider/composition;
- RE TerrainDeformation.

The useful result is narrower: VMT contains several mature answers to runtime/lifecycle problems RE is likely to encounter.

## Architecture quality

VMT is operationally mature but structurally accreted.

Examples from the exact package:
- `VisualMudTracks:updateTerrainRuts` is redefined six times across modules;
- `saveTerrainRuts` / `loadTerrainRuts` are each redefined five times;
- compaction/crop methods are repeatedly wrapped/replaced within the same source line;
- multiple compatibility/persistence generations remain in the package.

This is useful evidence of hard-earned bug fixing, but not a design to reproduce.

RE should extract invariants and failure cases, then implement them behind its existing modular boundaries.

## Where RE is already stronger

### 1. Physical response model

RE separates:
- authoritative wheel/contact state from RC;
- footprint/contact area;
- ground pressure;
- wetness/deformability response;
- cumulative shear;
- slip-driven excavation;
- instantaneous Mud sink;
- persistent plastic sink transfer;
- persistent rut history.

VMT contains many strong heuristics, but its main rut depth logic remains heavily calibrated with fixed factors, tiers, pass multipliers and absolute limits.

RE's `TerrainResponseModel` is the better long-term owner because it explicitly models cumulative physical exposure and keeps the inputs/ownership separated.

### 2. Soil mass transport

VMT lowers terrain but has no equivalent of RE's explicit displaced-volume accounting and lateral berm model.

RE already distinguishes:
- displaced source volume;
- transported surface volume;
- retained compaction/sub-surface rearrangement;
- left/right berm placement;
- callback-observed terrain volume.

Therefore VMT should not replace RE's core deformation writer/model.

### 3. Terrain write API

VMT centrally calls `setTerrainHeightAtWorldPos` for point writes and then builds substantial lifecycle/synchronization protection around that choice.

RE uses the GIANTS `TerrainDeformation` API/queue, callbacks and displaced-volume result.

RE should keep that ownership. VMT is valuable mainly for the invariants surrounding terrain mutation.

### 4. Specialist ownership

VMT can fall back to its own:
- wetness;
- compaction;
- soil biology;
- tire pressure;
- sink/grip behavior.

RE intentionally avoids becoming another monolithic soil/traction simulation.

The current stack already has better ownership separation through Mud/Soil/RC.

## High-value pattern A — monotonic rut writes

`VMTTerrainPipeline.writeLowerOnly()` establishes a strong invariant:

**rut creation may lower terrain, but must never raise an already deeper terrain sample.**

This protects against:
- overlapping samples;
- interpolation differences;
- stale saved target depths;
- external terrain updates exposing a deeper current sample.

This is a very good invariant for RE.

### RE opportunity

Before submitting or reconciling a rut/deformation target, explicitly distinguish:
- deformation/deepening writes: monotonic downward;
- recovery/tillage/mass-transport writes: may raise under controlled ownership.

RE's brush-based writer currently reasons in additive deltas. A target/invariant layer could prevent accidental "healing" when stale history or async callbacks race with later geometry.

## High-value pattern B — never raise terrain under a loaded wheel

VMT's central writer scans current wheel contacts and blocks upward writes inside a guard radius around loaded wheels.

Reason: even an upward write beside the exact contact point can lift the interpolated terrain surface and kick the vehicle upward.

Recovery is retried after the wheel moves.

This is a highly practical runtime lesson.

### RE opportunity

TerrainRecovery and mass-transport raise jobs should gain a **loaded-wheel exclusion/protection query**.

This is especially relevant to:
- smoothing under/near a machine;
- tillage recovery while the tool/tractor still overlaps the area;
- berm raises near a neighboring wheel;
- async TerrainDeformation completion after a vehicle moved into the area.

Do not copy VMT's global fleet scan literally; RE should use the normalized current-contact/active-vehicle information it already owns and cache it per frame.

## High-value pattern C — hand off temporary wheel sink to permanent terrain

VMT explicitly tracks:
- total physical wheel sink;
- sink represented by a persistent terrain rut;
- residual sink still represented through temporary wheel-radius reduction.

Conceptually:

`totalSink = terrainRepresentedSink + radiusSink`

As real terrain lowers beneath the wheel, VMT reduces the temporary radius component instead of applying both at full magnitude.

This avoids a visual/physical jump and avoids double-counting the same sink.

This is one of the strongest lessons in the mod.

### Relationship to RE/Mud

RE already recognizes the ownership distinction:
- Mud owns instantaneous mobility/sink;
- RE owns persistent plastic heightfield geometry.

But RE currently transfers a fraction of observed Mud sink into persistent rut geometry without a formal feedback contract that says how much of the current wheel depression is now represented by the terrain itself.

A future RC/Mud/RE contract could expose or coordinate:
- instantaneous sink requested by Mud;
- persistent terrain depression currently under that wheel;
- remaining temporary sink component.

This must be designed carefully so RE does not become the owner of Mud's radius solver.

## High-value pattern D — stable contact anchoring

VMT contains several fixes for terrain samples jumping around the wheel:
- use true ground contact when available;
- only fall back to tire-track/repr nodes;
- compensate legacy visual-node forward offset;
- derive rut cross-axis from actual wheel rolling direction;
- preserve a stable contact anchor during strong low-speed slip;
- teleport/large displacement protection;
- sample intermediate points based partly on terrain resolution.

These are practical improvements for continuous ruts.

### RE opportunity

RE should compare its current wheel-context stamping against these failure modes:
- mirrored/steered wheel node orientation;
- tire-track node ahead of actual patch;
- wheelspin at nearly zero vehicle speed;
- low-FPS large travel between samples;
- teleport/reset.

The lesson is not VMT's exact constants; it is to make footprint placement explicitly contact-anchored and distance-continuous.

## High-value pattern E — terrain change observation and targeted reassertion

VMT learned that terrain/density/moisture updates from other systems can rebuild terrain representation around existing ruts.

Its later architecture includes:
- a shared terrain/density callback broker;
- recently touched rut holds;
- targeted checks near active/player areas;
- lower-only reassertion;
- no whole-map scan.

This is relevant even if RE uses `TerrainDeformation`, because external terrain/density owners can still affect runtime geometry/state.

### RE opportunity

Add a terrain-change observer layer only if runtime evidence shows RE geometry being lost or raised by:
- weather/moisture integrations;
- tillage/detail updates;
- other terrain writers.

If needed, reassert only persisted cells whose geometry no longer matches the RE-owned rut target, with a strict nearby/budgeted queue.

Do not proactively build a global height-hold system without a reproduced failure.

## High-value pattern F — chunked persistence and multiplayer interest

VMT's later networking does not send the entire persistent state to every player.

It builds chunk indices and supports:
- client interest position/radius;
- nearby chunk snapshot queues;
- incremental live terrain updates;
- join batching;
- server authority;
- recenter/reset requests.

This is stronger than RE's current terrain-history persistence model in one specific area: **RE persists server state but does not yet have a general chunked metadata synchronization layer for future client consumers.**

The actual heightmap may already be handled by GIANTS, so RE should not duplicate terrain geometry networking unnecessarily.

However, this pattern will be useful for:
- Persistent Visual Tracks;
- client terrain-history/debug visualization;
- future local surface state;
- any visual consequence not automatically synchronized by the engine.

A generic RE spatial-interest transport could serve more than one feature.

## High-value pattern G — event-driven caches / workload

VMT has evolved away from repeated full scans:
- short mass/payload caches;
- signatures/dirty markers;
- vehicle registry revisions;
- LOD by player distance;
- sleeping soil cells;
- cursor/budget based biological recovery;
- density/terrain callbacks instead of blanket scanning.

Some implementation is complex, but the direction is correct.

RE already uses explicit budgets and performance telemetry; this audit reinforces that:
- expensive vehicle/load topology should be event/signature cached;
- long-lived spatial state needs sleeping/chunk strategies;
- maintenance work should be cursor-based rather than periodic full sweeps.

## VMT terrain persistence — lessons, not model replacement

VMT stores:
- original terrain height;
- applied rut depth / target height;
- profile kind/load/pass state;
- chunked persisted rut data;
- migration/validation metadata.

It also verifies saved files after writing and contains compatibility/migration paths for older formats.

Strong lesson:
- a "save succeeded" API return is not enough; validate critical sidecars and keep format/version/provenance explicit.

RE already validates restored geometry against actual loaded terrain samples, which is a stronger safety property than blindly replaying persisted memory.

### What not to copy

VMT often treats the captured original height as the restoration target.

RE should not generally promise exact "return to original height":
- soil was displaced/compacted;
- repeated passes can change local mass distribution;
- tillage is not a perfect undo;
- RE now models recovery and mass transport.

Original/pre-deformation samples may still be useful as:
- corruption bounds;
- restore safety ceilings;
- migration validation;
- optional landscape-reset semantics.

## Tire pressure / CTIS

VMT has a substantial tire-pressure system:
- per-wheel and per-vehicle state;
- gradual inflation/deflation;
- sounds;
- persistence;
- UI/HUD;
- pressure-dependent sink/grip;
- recommended pressure based on soil/load/width;
- multiplayer event.

However, **do not absorb this from VMT now**.

MudSystemPhysics already has an overlapping, actively owned TirePressureSystem in the target stack, including per-wheel pressure, persistence, sounds, visual pressure and grip/sink composition.

Adding an RE CTIS owner today would create another three-way ownership problem.

Useful VMT ideas can be compared against Mud later if a real missing capability is identified.

### Authority issue worth not copying

The inspected VMT tire-pressure event accepts a client-supplied vehicle/pressure and applies it server-side without checking that the connection controls or owns that vehicle.

That is the same category of trust-boundary issue found in some RMS events.

Any future RE input event must validate requester/vehicle authority.

## Standalone compaction / root / crop model

VMT's internal agronomic model is broad:
- surface/subsoil compaction;
- structure damage;
- root health;
- plough pan;
- roller reconsolidation;
- crop growth sensitivity;
- repeated-pass diminishing returns;
- tillage-class effects;
- biological recovery.

It is impressive in breadth but is predominantly a calibrated heuristic model.

Examples include hard-coded percentage targets and hand-tuned formulas for:
- root damage;
- structural damage;
- pass factors;
- tillage effects;
- daily recovery.

When RWSM is available, VMT itself deliberately disables/delegates parts of its standalone biology and treats RWSM as soil authority.

That is the correct ownership lesson.

### RE decision

Do not absorb VMT's standalone agronomic/compaction model into TerrainDeformation.

Current direction remains:
- physical rut/deformation: RE;
- persistent agronomic compaction: external specialist;
- crop/root interaction: future dedicated capability only if justified.

VMT is a useful research reference for future `CropInteraction`, especially:
- young-crop sensitivity;
- care-tire reduction;
- repeated wheel-pass semantics;
- slip + steering/scrub damage;
- operation-aware grass protection.

But formulas should be independently derived/calibrated, not ported.

## Mud/particle/washable visuals

VMT contains mature:
- wheel mud accumulation;
- GIANTS Washable integration;
- mud/dust/snow particles;
- wet low-spot visuals;
- client distance tiers.

The target stack already gives wheel dirt/mud ownership to MudSystemPhysics.

Do not absorb these visuals unless a concrete Mud presentation gap is demonstrated.

The LOD/resource-management patterns remain useful for any future RE visual subsystem.

## Multiplayer assessment

Unlike Persistent Tracks, VMT is explicitly multiplayer/dedicated capable and has meaningful server/chunk architecture.

This is valuable reference material.

Positive:
- server-authoritative rut/soil writes;
- client interest chunks;
- batched join state;
- incremental nearby updates;
- terrain-mode/revision information.

Caution:
- the package still contains older full-sync paths plus newer chunked sync layers;
- function ownership is heavily wrapper-dependent;
- individual events must still be audited for requester authority.

Use the protocol concepts, not the implementation wholesale.

## Quality comparison

### VMT is ahead of current RE in
- maturity of runtime terrain edge cases;
- immediate sink-to-heightmap handoff;
- wheel-under-raise protection;
- lower-only/reassert terrain invariants;
- migration history;
- chunked multiplayer metadata synchronization;
- broad operational/tillage detection;
- extensive real-world failure workarounds.

### RE is ahead of VMT in
- modular ownership boundaries;
- normalized specialist-state provider;
- physical contact-area/ground-pressure model;
- explicit separation of instantaneous sink and persistent plastic deformation;
- cumulative shear/slip exposure model;
- soil mass/volume transport and berm accounting;
- use of GIANTS TerrainDeformation callbacks/volume;
- cleaner feature ownership with Mud/Soil/RMS/MR;
- maintainable architecture and testable submodels.

## Recommended actions

### Implement / research soon

1. **Rut monotonicity guard**
   - deepening must never raise a deeper current rut.

2. **Loaded-wheel raise exclusion**
   - recovery/berm/tillage upward writes defer near loaded wheel contacts.

3. **Sink representation contract**
   - investigate safe accounting between Mud instantaneous sink and RE terrain-represented depression.

4. **Contact-anchor / teleport / low-speed-slip tests**
   - add to TerrainDeformation runtime matrix.

5. **Terrain-change observer prototype only if needed**
   - reproduce external geometry loss first; then targeted reassert.

### Park as infrastructure design

6. **Generic spatial-interest/chunk transport**
   - likely shared by Persistent Visual Tracks and future client-visible terrain metadata.

7. **Persistence verification/migration discipline**
   - sidecar integrity markers and transactional/verified save improvements.

### Do not absorb now

8. VMT standalone soil/biology/compaction model.
9. VMT tire-pressure ownership.
10. VMT wheel mud/particle ownership.
11. VMT direct point-height writer as RE's primary terrain backend.
12. VMT monolithic/wrapper-layer architecture.

## Capability outcome

Visual Mud Tracks itself is **not** a `CANDIDATE_ABSORB` as a whole.

Its relevant capabilities classify as:

- persistent physical ruts: **already RE-owned; selectively improve from VMT lessons**;
- sink/terrain handoff: **RESEARCH / strong integration opportunity**;
- terrain lifecycle guards: **CANDIDATE_INTEGRATE into RE writer/recovery**;
- spatial MP state transport: **CANDIDATE_INFRASTRUCTURE**;
- tire pressure: **DO NOT DUPLICATE while Mud owns it**;
- standalone agronomic compaction/root biology: **DO NOT ABSORB into TerrainDeformation**;
- crop-wheel interaction: **EVALUATE for future CropInteraction**;
- mud/particle presentation: **DO NOT DUPLICATE without a demonstrated Mud gap**.

## Final assessment

Visual Mud Tracks is more valuable to RE as a **catalog of solved runtime problems** than as a feature package to absorb.

The strongest immediate lesson is not its rut-depth formula. RE's physical model is already more coherent there.

The strongest lesson is **representation/lifecycle correctness**:
- one sink must not be represented twice;
- rut writes should be monotonic;
- upward recovery must not lift loaded wheels;
- contact stamps need stable physical anchors;
- persistent terrain needs targeted reassertion/verification under external changes;
- large spatial state needs chunked, interest-driven synchronization.

Those ideas can materially improve RE without importing VMT's overlapping simulation domains or architectural debt.
