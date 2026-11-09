# Persistent Tracks functional-absorption assessment

Updated: 2026-10-04

Exact package inspected:
- mod: `FS25_PersistentTracks`
- version: `1.0.0.0`
- author: iwatkot
- ZIP SHA-256: `89c10e01e1c1bb2d4a5de2c32c19a4fd60145f263020c3378e7149d6553be0fc`
- Lua SHA-256: `504cfe651bf2203c41160a2c72cbe5d839db09fb5f224034b9a289d6275b9694`
- package: 3 files, one 3,693-line Lua source
- multiplayer declared: false

Purpose: evaluate Persistent Tracks primarily as a **functional-absorption candidate**, not as another permanent stack dependency.

## Safety / provenance triage

The uploaded package was treated as untrusted and inspected statically without executing its Lua.

Archive contents:
- `modDesc.xml`;
- `icon_PersistentTracks.dds`;
- `scripts/PersistentTracks.lua`.

No executable/DLL/batch/PowerShell payload, nested archive, encrypted member, path traversal, shell execution, process launch, network/HTTP/download API or dynamic Lua eval/load payload was found.

The Lua writes only through GIANTS save/XML APIs to the active savegame or modSettings paths.

The package metadata matches the Persistent Tracks 1.0.0.0 release published on GIANTS ModHub (same name/author/declared filename/approximate size). Exact byte identity with the CDN artifact was not independently proven.

**Static safety conclusion:** no suspicious behavior found. This is not a cryptographic/malware guarantee, but nothing in the inspected package gives a reason to stop the code analysis.

## Licensing / absorption boundary

The ZIP contains no LICENSE file and the source has no explicit license header. The inspected official listing also does not grant a source-code reuse license.

Therefore:
- do **not** copy this implementation into RE;
- do not treat ModHub publication as permission to derive/relicense its source;
- functional behavior and architectural lessons can inform an independent RE design;
- if exact source reuse is desired later, obtain explicit permission/license from the author.

Recommendation below means **functional reimplementation**, not source-code import.

## Executive result

Recommendation: **CANDIDATE_ABSORB — HIGH VALUE, REIMPLEMENT IN RE, DO NOT ADD TO TARGET STACK YET.**

The capability is genuinely useful and is not already covered by current RE.

Current RE persists **physical terrain memory**:
- rut depth;
- longitudinal/lateral shear history;
- slip excavation;
- deformation exposure;
- pass count;
- sampled geometry validation.

That state is intentionally grid/cell based. It cannot reconstruct the exact native visual tire-track polyline because it does not contain:
- continuous track direction;
- native tire-track width;
- atlas/tread identity;
- native point payload;
- cut/discontinuity sequence.

Persistent Tracks fills that separate presentation-history domain.

However its implementation has several limitations that make direct dependency less attractive than implementing the capability inside RE:
- single-player only;
- record/replay is tightly coupled to private/internal GIANTS TireTrackSystem call shape;
- retained history uses heavyweight per-call Lua tables;
- load decode/simplification is synchronous even though native restoration is frame-budgeted;
- streaming candidate refresh scans/sorts all chunks rather than querying nearby grid cells;
- persisted tracks have no explicit age, surface lifecycle or relationship to RE terrain recovery;
- hook ownership is direct metatable replacement with no later integrity/reassert contract.

## What the mod actually does

Persistent Tracks does **not** draw a new tire-track system.

It observes the native `mission.tireTrackSystem` by replacing methods on its metatable:
- `createTrack`;
- `addTrackPoint`;
- `cutTrack`.

It calls the original method first, then records serializable arguments and returned logical track IDs.

Persistence is therefore a **native-event journal + replay system**.

That is the central useful idea.

## Recording model

### Track creation
For each native track it records:
- logical track ID;
- native create arguments, principally width and atlas/tread index.

It additionally scans loaded vehicle `spec_tireTracks.tireTrackNodes` before saving so width/atlas metadata can be corrected from live vehicle state.

This is a good fallback because it preserves vehicle-specific visual identity rather than inventing generic tire marks.

### Point events
Native `addTrackPoint` payloads are recorded with:
- logical track ID;
- monotonically increasing replay sequence;
- all serializable point arguments except the duplicated track ID.

Supported persisted argument types:
- number;
- boolean;
- string;
- vec3-like table.

Unknown future argument types fail open by making that call non-persistable rather than invoking dynamic code.

### Cut events
`cutTrack` is also journaled with sequence ordering, preserving discontinuities between native track fragments.

## Point simplification

This is one of the strongest transferable ideas.

The mod does not blindly store every native point. Configurable spacing modes use an online anchor/pending-point algorithm.

A point is retained when one of these conditions is important:
- enough distance from the last anchor;
- sudden direction change;
- significant change in selected native point attributes;
- a long link/gap boundary;
- a cut or end-of-track requires the pending endpoint.

This preserves corners and state transitions better than simple every-Nth-point decimation.

Settings roughly correspond to:
- every point;
- 0.35 m;
- 0.60 m;
- 1.00 m;
- 1.50 m.

### RE lesson

Keep the *principle*, improve the model.

RE should implement its own adaptive simplifier based on:
- distance;
- curvature/error;
- visual-attribute boundaries;
- surface boundary;
- lifecycle/age boundary;
- physical deformation significance when linked to a rut.

A normalized error/curvature criterion would be preferable to only fixed angular thresholds.

## Save format

The mod stores a separate per-career XML sidecar.

It has:
- versioned format;
- legacy-file migration;
- compact row encoding;
- 64 calls per XML string chunk;
- nine-significant-digit numeric encoding;
- percent escaping for strings.

It intentionally avoids a global modSettings history backup by default so one career's tire history cannot migrate into another.

This is a good provenance rule.

### Performance weakness

The compact representation improves disk/XML node overhead, and a background preparation pass pre-encodes rows with a small frame budget.

But restoration is **not end-to-end asynchronous**:
- XML loading is synchronous;
- every compact row is decoded synchronously;
- the full history can then be simplified synchronously;
- restored IDs/data are normalized synchronously;
- only spatial-index construction and native replay are strongly frame-budgeted.

With the exposed maximum of one million retained points, this can still produce a significant restore/save/memory spike.

RE should not advertise a large retention count without budgeting decode/import as well as rendering.

## Spatial streaming

After load, history is converted into a spatial chunk index.

Current parameters:
- 64 m chunk size;
- 128–320 m camera-centered restore distance;
- refresh every 250 ms;
- refresh skipped until focus moves 16 m;
- native point/render budget derived from GIANTS tire-track segment capacity;
- reserve kept for live/native tracks;
- maximum 96 restored points / 128 native ops / about 0.75 ms per frame;
- spatial-index build budget about 0.75 ms per frame.

When a logical track crosses a chunk boundary, the previous point is duplicated into the new fragment when close enough, preserving visual continuity.

This is a good pattern.

### Important streaming trick

Current-session points enter the persistence index as **not immediately stream-eligible**.

That avoids creating a second restored copy on top of the native track that GIANTS is already rendering.

After a chunk becomes distant, those live fragments become eligible. If the player later returns after native recycling, the persisted representation can be recreated.

This is a particularly useful architectural idea.

### RE improvement

The current refresh still loops over **every spatial chunk**, computes distance, collects candidates and sorts them by distance whenever a refresh occurs.

A RE implementation should exploit the fact that chunks already have integer grid coordinates:
- derive the finite chunk-coordinate rectangle/radius around the focus;
- look up only those chunk keys;
- optionally maintain a nearest-ring traversal.

That changes selection from whole-history `O(C log C)` work to work proportional to the nearby streaming window.

## Native capacity ownership

The mod reads GIANTS tire-track segment capacity and intentionally reserves a portion for live/native tracks rather than filling the whole native buffer with restored history.

This is good ownership.

Persistent history and currently rendered native segments are correctly treated as different resources.

RE should retain this concept and expose:
- logical retained points;
- rendered/restored points;
- native segment headroom;
- load/unload counts;
- frame cost.

## Hook architecture

The implementation replaces methods directly on the tire-track system metatable and stores their previous function values.

Positive:
- captures all native producers using the same TireTrackSystem;
- does not require per-vehicle instrumentation;
- naturally preserves modded vehicle tire width/tread output.

Weaknesses:
- direct replacement rather than an explicit composable/integrity-managed adapter;
- `_trackHooksInstalled` only remembers that installation once succeeded;
- no pointer integrity check/reassert if another mod later replaces those methods;
- no explicit teardown/restoration;
- source is coupled to native method signatures, including compatibility logic for 14/15-argument point shapes.

### RE direction

The native boundary is still the right observation point, but isolate it:

`NativeTireTrackAdapter -> TrackJournal -> Simplifier -> ChunkStore -> TrackStreamer`

Only the adapter should know GIANTS call signatures.

The persistent domain model must not be "whatever arguments the engine happened to pass".

## Data model weakness

The persisted model knows:
- track ID;
- width/atlas create data;
- opaque native point payload;
- event ordering.

It does **not** explicitly know:
- vehicle/wheel identity;
- time/age;
- surface category/material;
- weather when created;
- physical rut association;
- whether an agricultural operation later erased the physical trace;
- ownership/farm semantics.

For a standalone visual-retention mod that is understandable.

For RE it is not enough.

## Why RE can do materially better

RE already has authoritative normalized wheel/terrain context through RC:
- physical local wetness;
- wheel load;
- support width;
- tire pressure;
- slip;
- applied sink;
- ground profile;
- physical terrain history and recovery.

A native persistent-track feature can therefore link a visual mark to actual terrain lifecycle instead of keeping it until FIFO retention happens to remove it.

Examples:
- cultivation/recovery can invalidate or attenuate field tire marks in the affected area;
- rain/weather can age suitable surface marks;
- persistent physical rut can retain a corresponding visual mark longer;
- asphalt/yard marks can remain visual-only without inventing physical deformation;
- freeze/thaw or surface category can choose different persistence rules.

Persistent Tracks does none of this.

## Relationship to TerrainDeformation

Do **not** merge visual tire-track state into `SpatialHistory` cells.

The domains have different geometry:
- terrain history is a raster/grid physical-memory problem;
- tire tracks are oriented polylines with width/tread presentation metadata.

Instead share infrastructure:
- savegame identity;
- spatial chunk coordinates;
- lifecycle invalidation events;
- diagnostics/performance budgeting;
- terrain-operation notifications.

Suggested relationship:

```
Wheel / GIANTS TireTrackSystem
        |
NativeTireTrackAdapter
        |
VisualTrackJournal -----------+
        |                     |
adaptive simplifier           | physical correlation
        |                     v
VisualTrackChunkStore <-> Terrain SpatialHistory / Recovery
        |
client TrackStreamer
        |
GIANTS TireTrackSystem renderer
```

## Multiplayer gap

The external mod explicitly declares multiplayer unsupported.

This is the largest feature gap for RE.

RE is multiplayer-capable and should not absorb this feature as an SP-only subsystem.

Recommended authority:
- server owns persistent logical journal / aging / invalidation;
- native live tire-track rendering may remain client-local as GIANTS already does;
- clients receive only nearby persisted visual chunks;
- chunk snapshots + incremental deltas use sequence/revision IDs;
- late join requests the current nearby chunk set;
- settings that affect retention are server/savegame policy, while local draw distance can be client preference.

A runtime investigation is needed to determine which native TireTrackSystem operations are local-only versus naturally network-visible.

## Memory model

The external mod can retain up to one million point calls, each represented in memory as nested Lua tables plus encoded strings.

That is flexible but not an attractive RE storage model.

Prefer:
- chunk-owned compact numeric arrays/records;
- interned track metadata;
- avoid one table per scalar/point where possible;
- keep encoded disk representation separate from hot in-memory representation;
- unload historical chunk payloads from memory if large-retention modes are eventually supported.

Do not equate native render budget with logical-history memory budget.

## Persistence format recommendation

Use a separate sidecar from physical terrain history, for example:
`realismExtensionsTracks.xml`.

Reasons:
- visual history can be much larger;
- it has different compatibility/version semantics;
- corruption/incompatibility must never prevent physical terrain history from loading;
- visual history can be discarded safely when adapters change.

Store normalized/versioned chunks rather than raw GIANTS function-call history.

Each chunk should include:
- chunk coordinates/revision;
- logical track fragments;
- width/tread metadata;
- normalized points/attributes;
- creation/last-touch game time;
- optional surface/lifecycle class;
- optional physical-history correlation key or flags.

## Persistence lifecycle improvement

External Persistent Tracks is effectively FIFO/history-limit based.

RE should support semantic expiration:
- explicit terrain recovery/tillage invalidation;
- weather/age attenuation where appropriate;
- bounded retention;
- versioned adapter migration;
- optionally different policy by surface class.

Visual persistence should describe a world state, not merely replay everything the player once drove over.

## Quality assessment

### Better than a naive RE implementation would be
- captures native tire-track output instead of guessing tread style;
- preserves width/atlas;
- records cut ordering;
- adaptive online point reduction;
- live-vs-restored duplicate avoidance;
- spatial chunking;
- native segment headroom;
- frame-budgeted index/render work;
- careful per-career save isolation.

### Inferior to the architecture RE should target
- SP only;
- monolithic 3.7k-line module;
- direct/internal call-record persistence;
- synchronous decode/simplification of very large histories;
- whole-chunk scan/sort around the camera;
- heavyweight retained Lua object model;
- no semantic aging/recovery;
- no physical/visual coherence with terrain deformation;
- no stable provider/adapter boundary.

## Implementation feasibility

**Technically feasible: HIGH.**

Nothing in the mod relies on a native DLL, shader injection or inaccessible external service.

The key capability is implemented entirely through normal FS25 Lua/GIANTS APIs:
- observe TireTrackSystem;
- serialize track metadata/points;
- spatially index;
- recreate native tracks nearby.

That means RE can implement an independent equivalent.

### Difficulty estimate

Core single-player prototype: **moderate**.

Production RE implementation with:
- save compatibility;
- performance at large histories;
- semantic recovery/aging;
- current-session coexistence;
- multiplayer;
- diagnostics and integration tests:

**moderate-to-high**, but still substantially more tractable than terrain deformation itself.

Most risk lies in lifecycle and scale, not mathematical complexity.

## Recommended staged implementation

### Phase 1 — native adapter + diagnostics
Observe native create/point/cut calls without persistence.
Document exact FS25 payload semantics and hook ownership.

### Phase 2 — normalized journal
Create RE-owned logical track/fragment/point structures.
Do not persist raw function argument arrays as the domain model.

### Phase 3 — adaptive simplification
Distance + curvature + attribute-boundary simplification with deterministic tests.

### Phase 4 — spatial chunk store / streamer
Grid-direct nearby lookup, GIANTS native-capacity reserve, strict frame budgets.

### Phase 5 — savegame persistence
Versioned visual sidecar, staged decode/import, bounded memory.

### Phase 6 — terrain lifecycle integration
Recovery/cultivation/weather/surface-aware invalidation or aging.

### Phase 7 — multiplayer
Server journal authority, nearby chunk snapshots/deltas, late join and per-client draw radius.

## Decision

Persistent tire-track visuals should be added to the capability catalog as:

**CANDIDATE_ABSORB — strong candidate.**

The external mod demonstrates that the native TireTrackSystem can be persisted and streamed without custom rendering assets.

That removes the main feasibility uncertainty.

The correct RE goal is not to reproduce Persistent Tracks 1:1. It is to build a **persistent visual track layer coherent with RE's already-persistent physical terrain layer**, while retaining the best proven ideas:
- observe native track output;
- adaptive simplification;
- spatial streaming;
- native-capacity headroom;
- duplicate avoidance;
- per-save persistence.

No implementation should begin by copying this source. The next useful engineering step is a small native TireTrackSystem probe inside RE to capture/document exact point payload semantics and determine client/server behavior.
