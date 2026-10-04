# Assimilation plan — Persistent Tracks, Visual Mud Tracks and True AI Tracks

Updated: 2026-10-04
Status: implementation-ready
Branch: `feat/assimilation-tracks-vmt`

## Implementation status — 2026-10-04

Implemented on `feat/assimilation-tracks-vmt`:

- **Phase 1A complete:** spatial `LoadedContactRegistry` records recent grounded/loaded wheel contacts without a mission-wide fleet scan.
- **Phase 1B complete for TerrainRecovery:** SMOOTH recovery brushes defer when they overlap a recent loaded contact; blocked points do not consume their recovery stamp and can retry after the wheel moves.
- **Phase 1C instrumentation complete:** runtime diagnostics expose observed Mud sink, rut-history overlap proxy and residual sink proxy. No Mud/radius ownership was changed.
- **Phase 2A implemented:** `NativeTireTrackAdapter` owns a guarded observation boundary for `createTrack`, `addTrackPoint`, and `cutTrack`.
- **Phase 2B implemented:** the adapter records only call counts, argument counts and type signatures; it does not persist raw GIANTS payloads.
- Official FS25 TireTracks source now documents the native contract: `createTrack(width, atlasIndex)`, 15-argument `addTrackPoint`, and `cutTrack(trackId)`. This allows a clean normalized domain without copying Persistent Tracks' raw-call journal.
- **Phase 2C deliberately NOT enabled yet:** AI visual-track policy remains pending runtime proof that RE fully replaces True AI Tracks physical AI/implement behavior and an exact ownership plan for the AI specialization overwrite chain.
- **Phase 3A implemented, capture gated OFF:** `VisualTrackJournal` normalizes native point semantics and never stores raw GIANTS call arrays as its domain model.
- **Phase 3B implemented:** clean-room adaptive simplification preserves endpoints/cuts, geometric deviations, direction changes, attribute transitions and a bounded maximum spacing.
- **Phase 3C core store implemented:** `VisualTrackChunkStore` splits closed fragments into direct-addressed spatial chunks and duplicates one boundary point for continuity; nearby queries use grid-key lookup rather than whole-history scan/sort.
- **Gated runtime wiring implemented:** `VisualTrackRuntime` can attach the normalized journal as an adapter observer, but `VisualTrackCapture=false` remains the default until the in-game probe confirms the exact runtime contract.
- Savegame persistence, native replay/rendering, semantic aging/invalidation and multiplayer replication remain intentionally unimplemented.

Automated harnesses cover:
- contact spatial movement / TTL / exclusion / cleanup;
- recovery deferral without stamp loss;
- TerrainDeformation contact registration and delete cleanup;
- TireTrack adapter native-first call ordering;
- observer failure isolation;
- signature probing;
- pointer-drift detection;
- non-destructive uninstall when another mod takes hook ownership.

This is the intended stopping point before the first in-game probe. The normalized journal/chunk architecture is ready, but the runtime capture toggle stays off until the probe confirms the official 2/15/1 call contract in the user's actual stack. AI visual policy, replay and persistence remain evidence-gated.

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
