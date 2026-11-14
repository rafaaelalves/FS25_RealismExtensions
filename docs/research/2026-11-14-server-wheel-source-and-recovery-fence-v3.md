# 14-Nov-2026 — isolated server wheel source and durable recovery-epoch fence (experimental, no native writer)

## Why this work follows 13-Nov MAIN recovery proof

On 11–12 Nov the one-quantum (~3.891 mm) **MAIN** height command was observed and persisted after a real Estância São Carlos save/reload. The **UPWARD** native quantized restitution, broad worked-area agricultural repair, collision and native 0.125m fine wheel geometry remain **unproven**. The 13–14 Nov code made one-use geometry-journal recovery receipts reconcile an existing cumulative physical budget, but the next fresh source was only a synthetic test input and the in-memory recovered-epoch fence disappeared on process restart.

This change implements the **next two research prerequisites**, preserving `TerrainPermanentActuator="SHADOW"`, no release, no routine user game test.

## 1. Actually wired server wheel context — NO native write

- New `scripts/terrain/TerrainFreshWheelSource.lua` is declared in `modDesc.xml`. `TerrainDeformationEngine.processSample` calls it **only in SHADOW and only when a separately trusted `runtime.absoluteHeightBudget` exists**. That budget is **not initialized** by production or this experimental profile; the ordinary game still performs no automatic RE MAIN excavation.
- The source reads the already-computed server-authoritative `vehicle/wheel`, ground context, footprint, travel orientation and `TerrainWheelPathContinuity` result. It independently invokes `TerrainMainFootprintGate`, rejecting narrow tire prints/under-sampled/teleported contacts. A `MAIN_RESEARCH_CANDIDATE` result is **not** a setter authorization.
- After a budget already carries a **journal-confirmed physically recovered** MAIN vertex, it builds an *independent post-recovery* `TerrainResponseModel.compute` history. It never feeds old `SpatialHistory` or shadow model rutDepth into the new source. Server wheel-object identity is assigned locally, sequence monotonic within session, 512-source bounded. It passes fresh model depth to `TerrainQuantizedHeightBudget.observeFreshDamage`, which requires the later measured travel and strictly new plastic demand. It returns only a research ticket / modeled target, **never** submits a `TerrainWriter` job or absolute height setter.
- No eligible physical recovered epoch/budget: immediate refusal, no new independent model allocation. Dedicated `tests/terrain_fresh_wheel_source_harness.lua` exercises actual `TerrainResponseModel` separately and deterministic source/model values for source-epoch and no-write regressions. In-game server/MP behavior is **not** tested by Lua harnesses.

## 2. Geometry journal v3 recovery tombstone after save/reload

- `TerrainGeometryJournal.VERSION=3` introduces `recoveryFences`. Only a **successful, safe, physically observed** `finishRecovery` center gain records a fence: native (x,z), immutable originalY, last actually observed MAIN height, partial/full completion, trusted state. A completely restored vertex may leave the ordinary `observations` map, but its **stale wheel target still needs a safety tombstone**.
- On a subsequent independently checked RE LOWER transaction, a still-owned valid fence advances its last observed physical height while preserving originalY. A generic raise, adjacent collateral, foreign drift or owner mismatch invalidates the fence. This **does not claim causality for unobserved external GIANTS edits**.
- The same geometry sidecar `realismExtensionsGeometryJournal.xml` now stores the fences under `recoveryFences.fence`. Import validates map identity (existing code), unit, vertex alignment, claimed ownership and **actual native readback within 10µm** before retaining trusted status. A foreign-edited or already quarantined tombstone stays serialized as **untrusted**, preventing silent re-entry. A missing/untrusted fence never authorizes repair.
- Prior **v1** journal geometry stays untrusted, prior **v2** geometry is still importable with the existing strict ownership readback, but it contains **no recovered-epoch proof**. Neither older sidecar justifies automatic post-recovery writes. No changes to the original separate mechanical `realismExtensionsTerrain.xml` format.
- `TerrainQuantizedHeightBudget.VERSION=7` provides `seedPersistedRecovery(journal,key)`, a **read-only**, versioned fence bootstrap into `recoveryEpochPending=true`. It reconstructs only the **actual remaining physical depth** (originalY - measured currentY), NEVER the older virtual target, and issues no ticket. A fake/changed marker quarantines the research budget. `TerrainFreshWheelSource` performs this bootstrap when a new process sees the first real server wheel context for a fenced vertex and intentionally returns without authorizing a new step. Subsequent real post-reload samples must establish a fresh baseline and positive new damage.

## Automated acceptance

- `terrain_recovery_epoch_persistence_harness.lua`: mock MAIN 2q rut → journal-confirmed partial restoration → XML save/reload → old demand blocked → full restoration and loss of owned rut entry → **tombstone remains** → reload still blocked → foreign 20µm edit untrusts/quarantines marker → invalid marker persists.
- Existing `terrain_geometry_journal_harness.lua` and `terrain_persistence_harness.lua` check v3 and conservative legacy v1/v2 migration.
- `terrain_fresh_wheel_source_harness.lua`: actual source object with synthetic server wheel path, independent model, budget fence, no setter; extended to cold-start from versioned persisted fence and require new wheel sample progression. Native heightmap behavior in these tests is mocked.

## Boundaries and engineering risks (NOT gameplay-approved)

1. **No automatic writer:** `absoluteHeightBudget` remains null in normal SHADOW. The source provides future controlled input; it does not grant release readiness.
2. **Physical actuator acceptance:** upward one-quantum MAIN restoration remains a MOCK result. A tiny real cloned-save roundtrip with 3×3/real collision/reload still needed; no long plow/sow/harvest loop requested now.
3. **Atomically persisted geometry:** geometry journal and GIANTS main height save timing are not guaranteed atomic. The v3 import fails closed on unmatched physical readback, not silently rolls world geometry backward. Crash-consistency/multiplayer validation remains.
4. **One-meter versus fine 0.125m:** neither width nor visual tire mark proves fine physical displacement is available to Lua for durable replay/repair. Normal narrow tires remain outside the MAIN native writer path.
5. **Performance/GC:** persisted tombstone cardinality, import cost, decay/administrative reset and dynamic slope/foreign maintenance cooperation need a bounded production policy. Never delete unknown markers merely to make stale models writable.
6. **Versioned source evidence:** in-memory wheel-object identity and monotonic clock are from the server observer, not cryptographic attestation; the editor can manipulate mods. Multiplayer authority and native geometry locks require independent verification.
7. **Legacy saves:** a v2 sidecar does not contain proof a previous repair happened. Keep automatic writer disabled unless a new, physically confirmed RE-authored rut/recovery lifecycle establishes provenance.

## Next focused step

After all Lua CI passes: inspect actual `setTerrainHeightAtWorldPos` upward operation semantics and prepare a *single safe, explicit* cloned-career research acceptance (one native q at one isolated owned vertex, all 3×3 neighbors, immediate readback, save/reload, collision), or defer it until fine wheel geometry API feasibility is resolved. Do not merge this draft or lift 10–12cm native safety caps.

Related: [13 Nov measured epoch handoff](2026-11-13-native-main-one-step-recovery-and-epoch-handoff.md), [14 Nov first v6 fence](2026-11-14-fresh-post-recovery-wheel-damage-epoch.md), [issue #63](https://github.com/rafaaelalves/FS25_RealismExtensions/issues/63).
