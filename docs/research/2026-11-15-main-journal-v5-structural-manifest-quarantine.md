# 15-Nov-2026 — MAIN geometry journal v5: structural save manifest, atomic RAM import, persistent denial after foreign edits

## Status and measured boundaries

This is a research-only development continuation on [PR #64](https://github.com/rafaaelalves/FS25_RealismExtensions/pull/64), with RE/RC main unchanged and `TerrainPermanentActuator="SHADOW"`. Code commit `fd8acf990d3205a71b533813fd4212a891cec80a` [passed the full Lua/source/XML GitHub Actions workflow](https://github.com/rafaaelalves/FS25_RealismExtensions/actions/runs/43671450310). The testing framework uses mocked MAIN native heights.

Physical evidence remains limited to the previously confirmed **one quantized MAIN downward height step (~3.891mm) surviving actual save/reload**, at one tested vertex on one map. No upward native q-step, precise agricultural rut restoration, wheel collision, fine 0.125m wheel displacement, MP or save atomicity is proven by this change.

## Safety gap found in v4

`TerrainGeometryJournal:importSnapshot` would import a subset of rows while silently skipping malformed or strongly foreign-edited native vertices. A partially saved XML could therefore look like a legitimate smaller ledger, *including fewer recovery tombstones*. Without a durable deny record, a later independent MAIN candidate could treat missing owned history as a fresh unencumbered location. The runtime did not globally quarantine a journal when an existing sidecar failed to load or belonged to another map.

Simply raising the fence cap or evicting old entries would only make loss of old-generation proof harder to notice, not correct.

## V5 implementation

1. `TerrainGeometryJournal.VERSION=5` adds a **structural manifest**: `cellCount`, `fenceCount`, `cellKeys`, `fenceKeys`. The latter two are sorted MAIN integer-vertex coordinate fingerprints; the portable hash is small and inexpensive, not cryptographic. It rejects truncation, duplication and substitution of coordinate keys at unchanged row count. Manifests are written/read in the same `realismExtensionsGeometryJournal.xml` sidecar. The native sampled heights and exact originalY still need independent ownership readback.
2. Import now builds both observations and recovery fences in **temporary RAM maps**, publishing neither until format, unit, manifest, capacity, unique keys and required native probes are accepted. Incompatible/corrupt **existing** XML calls `Journal:quarantine`, which revokes RE physical ownership, paid recovery authority and unconsumed proof capabilities, while blocking `begin`, `beginRecovery`, `getLoweringBudget` and `exportSnapshot`. Thus a later save cannot quietly overwrite the last recorded sidecar with empty or partially parsed state.
3. Even when a **legitimate third-party terrain edit** makes a saved vertex differ by more than 5mm, the V5 importer keeps its exact MAIN key as an explicitly `owned=false` deny marker. Older versions had skipped this cell entirely. Small foreign differences still lose ownership under the existing <=10µm trust threshold. Fences at the same key are independently downgraded when their old readback/ownership no longer matches.
4. Export no longer drops significantly edited observed vertices; it writes their measured native heights with RE ownership revoked. If GIANTS returns no finite native height, export refuses rather than replacing a previously valid sidecar with an incomplete one. Import/reload and export both keep the prior 50k experimental recovery-fence cap, with **no eviction**.
5. Existing V1/V2 geometry snapshots remain conservatively importable, V3/V4 fences remain physically inspectable if their independent readback is valid, but **V3/V4 cannot automatically gain V5 paid recovery authority**: they lack the new structural manifest. New V5 fences retain the distinct `trusted` and `accounted` bits established in V4. Missing sidecar on an otherwise new career is treated as absent rather than automatically corrupt, since filesystem absence alone cannot prove which scenario occurred.
6. `TerrainPersistence.loadGeometryJournal` quarantines on an existing unparseable XML, a map-ID mismatch, or a header/row iteration error. The load path catches such errors rather than propagating a Lua exception through the game. The server's startup and deferred-load paths emit a warning on quarantine, and the save path warns rather than overwriting an unsafe sidecar.

## Automated tests

- `terrain_geometry_manifest_v5_harness.lua` creates authentic-shape fake journal XML, loads it successfully, then deletes the recovery rows while leaving the v5 manifest. The importer quarantines, native `begin` and lowering are refused, and a later save does not overwrite the damaged file.
- At unchanged row count, substituting an existing coordinate for a different one also fails the key fingerprint. Missing manifest header fields likewise fail.
- A large external (60mm) height edit keeps its previous vertex as an **untrusted, blocking observation** through an additional save/reload, instead of losing it and implicitly freeing budget.
- A foreign map identity and a deliberately unparseable file fail closed; a genuine new career with no sidecar remains allowed to initialize an observation-only journal.
- Existing journal, spatial history, recovery accounting, v1/v2 migration, new wheel source, XML, and pure vertex-budget suites passed together under [Actions run 43671450310](https://github.com/rafaaelalves/FS25_RealismExtensions/actions/runs/43671450310).

## Important unresolved limitations

- **This is NOT a crash-atomic save.** GIANTS owns its own heightmap persistence and the RE XML sidecar remains an independent save; mismatched readbacks make the RE trust fail closed on reload but do not roll back physical geometry.
- **No cryptographic integrity:** coordinate fingerprints and row counts catch accidental omissions/duplicates/identity substitutions, not deliberate editing or all possible value corruption. The original numeric heights cannot be considered independently witnessed merely because a hash matches.
- **Missing whole file:** without an external authoritative save-generation handshake, a deleted sidecar cannot be distinguished from a brand-new save. A fully general durable writer must not grant old-recovery clearance purely from sidecar absence.
- **Potentially large XML:** records are bounded on the recovery-fence side (50k), but a production storage/partition policy for long-term terrain observation coverage is still unresolved. Zero eviction is the safety default; do not remove historical deny markers to improve memory.
- **Live acceptance not done:** no upward MAIN recovery, no repeated agricultural test, no fine wheel-heightfield restitution or collision, no multiplayer validation. Continue on disposable saves only when an exact, isolated physical test is justified. Do not merge or enable a production writer.

## Recommended next engineering

Assess observation cardinality and the journal's save-load lifecycle under large maps before selecting a compact on-disk spatial partition, while keeping old-generation deny markers. For the true geometry milestone, prepare exactly **one** verified, isolated upward-q experimental test on a cloned save with complete 3×3 readbacks and save/reload/collision checks; never replace it with another full plow/seed/harvest cycle.
