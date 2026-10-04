# Assimilation plan — Persistent Tracks, Visual Mud Tracks and True AI Tracks

Updated: 2026-10-04
Status: implementation-ready
Branch: `feat/assimilation-tracks-vmt`

## Implementation status — 2026-10-04

**Pre-runtime implementation checkpoint: CLOSED / READY FOR IN-GAME VALIDATION.**

This does **not** mean the three external capabilities are already retired. It means the implementation that can be justified without runtime evidence has been reviewed, refactored and covered by automated harnesses. Features whose correctness depends on actual game behavior remain intentionally gated.

### Terrain safety / VMT-derived lessons

- **LoadedContactRegistry v2:** contacts are indexed into every grid cell touched by their own footprint. Query cost is local; no global maximum contact radius can permanently inflate lookup cost.
- Contact radii are sanity-bounded before indexing.
- Stationary loaded contacts remain authoritative through a low-cadence (~1 s) refresh only for wheels already known to be loaded.
- That refresh updates contact position/load and the wheel path anchor, then exits before TerrainResponse: **a parked wheel is not allowed to deepen a rut merely because its safety contact was refreshed.**
- TerrainRecovery SMOOTH operations defer when overlapping recent loaded contacts.
- A blocked recovery point does not consume its stamp and can be retried after the wheel moves.
- Mud sink ↔ persistent rut remains telemetry-only. No private Mud radius/CTIS state is modified.

### Native TireTrack boundary

- **NativeTireTrackAdapter v2** is mission-instance scoped rather than a global TireTrackSystem class owner.
- Probe-only addTrackPoint takes an allocation-light fast path: no argument/result tables are created when there are no capture observers.
- Signature sampling is bounded; counters remain cheap after the sampling budget is exhausted.
- Capture observers are isolated by pcall.
- Pointer drift is counted as a state transition rather than once per diagnostics window.
- Uninstall restores the exact pre-install lookup shape: inherited methods return to inheritance instead of being frozen as direct instance methods.
- Adapter installation is required when **either** probe or capture is enabled; capture no longer accidentally depends on the probe toggle.

### Normalized visual-track domain

- **VisualTrackJournal v2** is a normalizer/simplifier, not the long-term persistence store.
- Native trackId is treated as transient. Reuse creates a new RE logical track identity and closes the old generation.
- Large spatial gaps/teleports close the current fragment instead of creating a long false track segment.
- onTerrain=false contact is excluded from world-persistent history; terrain re-entry starts a new fragment.
- Attribute thresholds are per semantic field. Ground depth no longer shares a generic epsilon with RGB/dirt.
- Endpoints, cuts, geometric curvature, direction changes and visual/material transitions remain preservation boundaries.
- Closed fragments are emitted incrementally to sinks.

### Spatial storage

- **VisualTrackChunkStore** consumes finalized fragments directly.
- Runtime no longer follows journal -> full snapshot -> full chunk rebuild.
- In capture mode, the journal emits a closed fragment to the chunk store, which copies it once into spatial ownership; the journal then releases its historical point copy.
- Chunks retain stable logicalTrackId / fragment sequence metadata rather than depending on array indices.
- Nearby lookup remains direct grid addressing rather than whole-history scanning/sorting.

### Gated runtime

- VisualTrackCapture=false remains the default.
- With capture disabled, only the bounded native probe runs.
- After the game confirms the official 2/15/1 native contract in the real target stack, capture can be enabled without changing hook ownership.
- Current automated head is green after the architecture review/refactor.

### Intentionally NOT implemented before runtime proof

1. AI visual tire-track policy.
   - GIANTS documentation proves vanilla TireTracks owns distance/segment-quality limits and AI specializations add the not-getIsAIActive suppression.
   - We still will not implement a blanket return-true; the final hook must remove only the AI suppression without bypassing other owners in the actual specialization chain.
2. Native replay/render of restored persistent tracks.
3. Savegame sidecar for visual tracks.
4. Visual aging/weather/tillage invalidation.
5. Multiplayer spatial replication / late join.

Those are **post-runtime implementation phases**, not missing cleanup for this checkpoint.

### Automated coverage after review

Harnesses now cover:
- cell-covered contact spatial indexing;
- radius sanity bounds;
- contact movement / expiry / owner exclusion;
- low-cadence stationary loaded-contact refresh;
- proof that contact refresh performs zero rut writes;
- recovery deferral without stamp loss;
- native TireTrack adapter native-first ordering;
- probe fast path;
- bounded signature sampling;
- observer failure isolation;
- pointer drift transition detection;
- non-destructive instance uninstall;
- native-track-id reuse;
- teleport/gap fragmentation;
- terrain/non-terrain lifecycle split;
- per-attribute visual preservation;
- incremental finalized-fragment sink;
- direct chunk indexing;
- streamed runtime with no second retained copy of closed history.

**Decision:** this branch is ready for the runtime protocol. Do not implement post-runtime phases merely to make the feature look “complete”; their designs should be informed by the evidence the protocol is intended to collect.
---

## Goal

Assimilate only capabilities that materially improve RealismExtensions, while preserving existing specialist ownership and avoiding source-copy reimplementation.

This plan is deliberately stricter than "copy the good ideas".

A capability enters RE only if:
1. it solves a real gap or a reproduced failure;
2. it fits an existing or clearly justified owner boundary;
3. its inputs/outputs can be normalized and tested;
4. it is at least as maintainable as the system it replaces;
5. it does not create a second owner for Mud/MR/RMS/Soil/CTIS/agronomy;
6. it has an exit gate proving the external dependency can be retired without regression.

No third-party source is copied. The inspected packages do not provide a reusable source license.

---

# Decision matrix

| Source | Capability/lesson | Decision | Reason |
|---|---|---|---|
| Persistent Tracks | native TireTrack observation | ACCEPT | preserves GIANTS visual identity and avoids custom renderer |
| Persistent Tracks | adaptive point simplification | ACCEPT, redesign | good scaling idea; use normalized geometry/error criteria |
| Persistent Tracks | spatial chunk streaming | ACCEPT, redesign | needed for large persistent visual history |
| Persistent Tracks | current-session vs restored duplicate avoidance | ACCEPT | strong lifecycle invariant |
| Persistent Tracks | raw GIANTS call journal as persistent domain model | REJECT | too coupled to private call shape |
| Persistent Tracks | SP-only architecture | REJECT | RE is multiplayer-capable |
| Persistent Tracks | million-point table-heavy retention | REJECT | memory/import cost not bounded enough |
| Visual Mud Tracks | monotonic rut deepening | ACCEPT AS INVARIANT | RE additive negative rut writer already satisfies it; test/document rather than duplicate logic |
| Visual Mud Tracks | protect loaded wheels from upward terrain writes | ACCEPT | fixes a real physical/lifecycle risk in recovery/smoothing |
| Visual Mud Tracks | temporary sink -> permanent terrain representation handoff | ACCEPT FOR OBSERVABILITY/RESEARCH | important ownership issue, but unsafe to alter Mud radius semantics without runtime proof/provider contract |
| Visual Mud Tracks | stable contact anchoring / teleport / low-speed wheelspin cases | ACCEPT AS TEST MATRIX | practical runtime edge cases |
| Visual Mud Tracks | targeted terrain reassertion | DEFER | only build after reproduced external geometry loss |
| Visual Mud Tracks | chunked interest replication | ACCEPT AS FUTURE SHARED INFRA | useful for visual tracks and future client-visible spatial state |
| Visual Mud Tracks | direct point-height writer | REJECT | RE keeps GIANTS TerrainDeformation writer/callback/volume ownership |
| Visual Mud Tracks | CTIS/tire pressure owner | REJECT | MudSystemPhysics already owns target-stack pressure |
| Visual Mud Tracks | standalone agronomy/biology/compaction | REJECT | duplicates specialist ownership and is heuristic |
| Visual Mud Tracks | mud/particle owner | REJECT | Mud already owns |
| True AI Tracks | physical AI deformation path | REPLACE | current RE physical model is richer and controller-neutral |
| True AI Tracks | AI-only 1.2 deformation scale | REJECT | controller identity must not change soil law |
| True AI Tracks | mission-wide AI fleet scan | REJECT | RE specialization ownership is cleaner and cheaper |
| True AI Tracks | AI native visual tire-track permission | ACCEPT | genuine visual gap, belongs in native TireTrack adapter |
| True AI Tracks | crawler/NEXAT special patches | REJECT AS PATTERN | solve by generalized contact type, not model-specific patches |

---

# Ownership after assimilation

## Physical terrain

`TerrainDeformation` remains the sole RE physical-rut owner.

It consumes normalized RC state and owns:
- persistent rut geometry;
- shear/slip history;
- terrain-cell memory;
- recovery;
- optional soil-mass transport.

It does not become a wheel traction/sink/pressure model.

## Temporary sink

Mud remains owner of instantaneous wheel sink/mobility/radius consequence.

RE may measure how much persistent terrain depression overlaps that observed sink, but must not write Mud private radius state.

A future handoff requires an explicit provider/API contract or an upstream Mud mechanism.

## Visual tire tracks

A new RE presentation domain is introduced:

```
GIANTS TireTrackSystem
        |
NativeTireTrackAdapter
        |
        +--> AIVisualTrackPolicy
        +--> TrackProbe / diagnostics
        +--> future VisualTrackJournal
                    |
             adaptive simplifier
                    |
              spatial chunk store
                    |
             persistence/streaming
```

Physical terrain state and visual track state remain separate.

## Tire pressure / agronomy / particles

No ownership change:
- tire pressure: Mud;
- agronomic compaction: specialist;
- crop/root interaction: future dedicated capability only;
- mud/dirt particles: Mud.

---

# Implementation phases

## Phase 1 — terrain safety and observability

### 1A. Loaded-contact registry
Add an event-driven per-wheel contact registry.

It records only recent grounded, loaded contacts:
- x/z;
- effective footprint radius;
- wheel load;
- timestamp.

No mission-wide vehicle scan.

### 1B. Recovery raise protection
Before a recovery SMOOTH brush is enqueued, reject/defer the brush if its footprint overlaps a recent loaded-wheel contact.

Important:
- do not claim the recovery stamp when blocked;
- the next legitimate work-area update may retry after the wheel moves;
- no physical rut/deepening write is blocked.

Mass-transport RAISE protection is deferred until SoilMassTransport is enabled/runtime-calibrated, because dropping or indefinitely deferring berm volume would break accounting.

### 1C. Sink-handoff telemetry
Do not change physics yet.

Add diagnostics that compare:
- observed Mud sink;
- existing persistent rut-history depth;
- their overlap proxy;
- observed sink beyond existing persistent rut history.

This is explicitly a **history proxy**, not proof of actual geometric sink representation.

The runtime result decides whether a real Mud↔RE handoff API is justified.

### Exit gate
- no regression in existing recovery harness;
- loaded-contact guard harness passes;
- blocked smoothing does not consume the recovery stamp;
- runtime: tractor/implement smoothing no longer raises terrain under a loaded wheel;
- sink telemetry is plausible before any ownership change.

---

## Phase 2 — native TireTrack boundary

### 2A. Adapter lifecycle
Create a GIANTS-facing adapter that can observe:
- `createTrack`;
- `addTrackPoint`;
- `cutTrack`.

Requirements:
- call native/previous function first;
- never throw observer errors into GIANTS;
- track installed wrapper identities;
- detect pointer drift;
- uninstall only if RE still owns the pointer;
- no persistence in this phase.

### 2B. Probe
Collect:
- call counts;
- argument counts;
- type signatures;
- create/cut sequencing.

Do not permanently encode unknown raw GIANTS payload semantics.

### 2C. AI visual policy
Implement only after confirming the exact FS25 specialization chain at runtime.

Desired semantic:
- remove only the AI suppression;
- preserve native TireTracks distance/quality/segment limits;
- do not enable tracks when the native TireTracks owner itself says no.

Until that chain is proven, keep the adapter/probe active but the policy mutation independently switchable.

### Exit gate
- player native tire tracks unchanged;
- AI native tracks enabled without bypassing native distance/quality limits;
- pointer integrity survives target stack load order;
- no True AI Tracks dependency needed for visual marks.

---

## Phase 3 — normalized persistent visual tracks

### 3A. VisualTrackJournal
Domain records must not be raw engine argument arrays.

Normalized model should contain:
- logical track identity;
- width/tread/atlas identity where proven;
- normalized spatial point data;
- cut/discontinuity sequence;
- creation/last-touch time;
- optional surface/lifecycle class.

### 3B. Adaptive simplification
Keep:
- first/end points;
- attribute transitions;
- discontinuities;
- points required by curvature/error tolerance;
- bounded maximum spacing.

Prefer geometric error over only fixed angle thresholds.

### 3C. Chunk store
Use direct grid-key lookup around the camera/client interest area.

Do not scan/sort every historical chunk each refresh.

### Exit gate
- deterministic harnesses;
- large synthetic history bounded in memory/time;
- identical simplified result independent of frame batching;
- native track identity is visually retained.

---

## Phase 4 — savegame persistence

Separate sidecar:
`realismExtensionsTracks.xml`

Do not merge into physical terrain history.

Requirements:
- format version;
- map/save identity;
- chunked normalized data;
- staged/budgeted import;
- retention limits;
- corruption-safe discard;
- independent failure from physical terrain history.

### Exit gate
- no long blocking decode for large history;
- save/load round trip;
- malformed/incompatible visual history fails closed;
- physical terrain history still loads if visual file is lost.

---

## Phase 5 — semantic lifecycle

Integrate visual tracks with world state:
- tillage/recovery invalidation;
- surface category;
- age/weather attenuation where evidence supports it;
- physical-rut correlation where useful.

Do not make every persistent physical rut require a visual mark or vice versa.

---

## Phase 6 — multiplayer spatial interest

Server owns persistent logical visual state.

Clients receive:
- nearby chunk snapshots;
- incremental deltas;
- revisions/sequence;
- late-join nearby state.

Client draw distance can remain local preference.

Before custom replication, verify which native TireTrack operations are already local/network-managed by GIANTS.

---

# Explicit non-goals

This assimilation does **not** authorize:
- copying Persistent Tracks/VMT/True AI Tracks Lua;
- replacing Mud sink/pressure;
- implementing VMT agronomy in TerrainDeformation;
- adding an AI-specific physical deformation multiplier;
- switching RE to direct `setTerrainHeightAtWorldPos`;
- building terrain reassertion before a reproduced need;
- adding model-specific crawler/NEXAT patches.

---

# Runtime matrix before dependency retirement

## True AI Tracks retirement
- player;
- GIANTS helper;
- helper + wheeled implement;
- nested implement;
- Courseplay;
- AutoDrive;
- player ↔ AI transition;
- dedicated server;
- native AI visual tracks;
- no duplicate physical rut path.

## Persistent Tracks retirement/avoidance
- player visual track journal;
- AI visual track journal;
- native tread/width identity;
- current-session duplicate avoidance;
- save/load;
- large history;
- MP late join/interest.

## VMT-derived terrain safety
- smoothing near loaded tractor wheel;
- smoothing near loaded implement wheel;
- wheel enters an already queued recovery area;
- low-speed wheelspin;
- teleport/reset;
- low FPS large wheel travel;
- tillage over persistent rut.

---

# Acceptance standard

A third-party capability is considered absorbed only when:

1. RE provides equal or better user-visible behavior;
2. ownership is simpler, not merely relocated;
3. the external calculation can be disabled/removed rather than overwritten after doing work;
4. tests cover the original mod's important edge cases;
5. runtime stack evidence confirms no dependency-specific regression.

Until then, the state is **TRANSITION**, not REPLACED.
