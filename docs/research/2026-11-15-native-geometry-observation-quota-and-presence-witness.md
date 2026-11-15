# 15-Nov-2026 — bounded MAIN geometry observations and missing-sidecar presence witness

## Scope and verification

Continuation of draft [PR #64](https://github.com/rafaaelalves/FS25_RealismExtensions/pull/64). Code and harness at `2941e4d7cbdc84e6745f8f38645d4c021afbe61d` passed [the entire GitHub Actions workflow](https://github.com/rafaaelalves/FS25_RealismExtensions/actions/runs/43715032823). All independent GIANTS height readbacks are **mocked** in the new tests. RE/RC `main` remain unchanged, `TerrainPermanentActuator="SHADOW"`, `runtime.absoluteHeightBudget=nil` under the default profile. No automatic physical actuator was enabled.

## 1. Bound observation provenance, not only recovery fences

Earlier the journal v5 had `maxRecoveryFences=50000`, but `observations` could grow without bound. This created an O(n) save/load and unbounded RAM lifetime, and uncontrolled observation insertions would bypass the meaning of the fenced quota.

- `TerrainGeometryJournal.new` now has `maxObservations=50000` by default (research configurable); `observationCount` tracks **actual preserved MAIN vertex records**, not the scanned/probed footprint. No record is deleted/evicted just to make room.
- `Journal:begin` preflights **all previously unobserved vertices in its sampled native footprint**, reserving enough slots BEFORE any setter is queued. It accounts for `observationCount + reservedObservationSlots + newFootprintSlots`. Independently queued, disjoint native jobs cannot overcommit the same capacity. A saturated attempt returns `GEOMETRY_OBSERVATION_CAPACITY`, without initiating a writer job. Existing footprint vertices do not need a new reservation. The capacity of the native sampled region is deliberately conservative: it may reserve neighbors that never end up moving, including the 3x3 candidate envelope.
- `Journal:complete` and `Journal:finishRecovery` release the operation's reservation in all synchronous success/failure/readback cases. Only native vertices that **actually move** and lack an old observation increase `observationCount`. A fully closed RE-owned rut retires its observation and reduces this count, but **preserves the separate recovery-epoch fence**.
- The importer refuses `#snapshot.cells > maxObservations` **before publishing any partial state** and quarantines; export refuses an over-cap journal. Export cross-checks the actual number of existing observation entries against its tracked count, quarantining a hidden mismatch rather than repairing the bookkeeping by silently dropping provenance.
- `TerrainAbsoluteRecoveryCandidate` no longer writes `journal.observations` from outside the journal. It delegates unsafe physical-setter outcomes to `Journal:invalidateRecoveryCandidate`, which explicitly revokes affected ownership/fences and creates a diagnostic deny marker only within quota. If physical geometry may have changed and the quota is exhausted, it quarantines the entire research journal rather than dropping another old marker or pretending the anomalous vertex is owned.
- The server save diagnostic includes `observedQuota=used/max`, `reserved` and `fences=used/max`. This is a research safety ceiling, not a complete production long-farm storage policy. Import/export still require a full in-memory snapshot and v5 XML; spatial partitioning or compact tombstone storage is future work.

`tests/terrain_geometry_observation_quota_harness.lua` checks parallel disjoint pending jobs, capacity refusals, successful/aborted job release, partial re-use of known vertices, 3x3 recovery reservations, full recovery with retained tombstone, over-cap import quarantine, research failed-setter diagnostic insertion at cap, and uncounted direct map mutation quarantine. Existing `terrain_absolute_recovery_candidate_harness.lua` additionally checks actual dictionary cardinality equals the tracked count after isolated native callback simulations.

## 2. Missing whole file detection across the two XML sidecars

V5 manifest integrity catches a truncated **present** `realismExtensionsGeometryJournal.xml`. It cannot by itself distinguish a deleted **entire file** from a genuinely new career. Some save ordering/crash sequences therefore remained ambiguous.

- Added optional `#geometryJournalExpected` boolean to existing mechanical `realismExtensionsTerrain.xml`, without increasing its historical format version 2. Core writes it as true whenever `TerrainGeometryJournal` is enabled, a geometry journal is present, or the loaded career already had a true witness. Default direct/old callers without this option remain false. This mechanical sidecar is saved first, before the geometry sidecar.
- `TerrainPersistence.load` returns this old-or-new presence witness as its optional third return value, even if the mechanical memory import later fails a native geometry consistency check. Core stores the witness for the map lifecycle.
- Both **early** (`loadMap`) and **deferred** (`update`) geometry loading paths forward that witness into `Persistence.loadGeometryJournal`. If the expected companion is absent, `Journal:quarantine("GEOMETRY_SIDECAR_MISSING_WITH_HISTORY_WITNESS")` blocks new RE MAIN writes and forbids overwriting the journal automatically.
- Old history sidecars with no witness remain backward-compatible. A genuinely new career with no geometry XML and no prior witness may initialize a fresh observation-only journal, since mere absence does not prove deletion. This ambiguity cannot be completely eliminated without an external authoritative identity/generation handshake.
- `tests/terrain_persistence_harness.lua` checks a new true witness, reload propagation, subsequent companion XML loss and automatic quarantine, refusal to overwrite provenance, and normal handling of an old false/no witness.

## Still NOT proven or solved

1. Neither XML file is part of an atomic GIANTS terrain-heightmap save transaction. The witness is a conservative **presence check only**, not a common generation number, checksum of height values or write-ahead log.
2. The default 50k observation/50k recovery-fence quotas bound memory growth but intentionally **refuse** additional native RE work on large saves rather than discarding historical deny markers. Production scaling needs spatial partitioning, a durable seekable index or compact old-epoch deny ledger with explicit migration tests.
3. Only a single **DOWNWARD** MAIN quantum persisted across an actual tested save/reload (11–12 Nov). **UPWARD** single-q recovery, actual tillage restitution, collision, native fine 0.125m wheel-displacement physics and multiplayer remain unproven. All recent tests use fake MAIN native heights.
4. Do not merge draft PR #64, activate the absolute MAIN writer, publish gameplay readiness or repeat an entire plow/sow/harvest test cycle without real isolated physical evidence.

## Next

Investigate a production-safe generation handshake between native save and sidecar (without claiming atomicity), then independently validate one isolated upward q-step in a disposable cloned save with strict 3x3 sampled and physical post-load checks. Partitioning only matters if automatic native MAIN terrain writing becomes physically justified.
