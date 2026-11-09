# Historical terrain history tile broadphase — not active

**Archive:** 2026-11-09. Original unmerged [RE PR #40](https://github.com/rafaaelalves/FS25_RealismExtensions/pull/40) (2026-10-09): `perf/terrain-recovery-history-broadphase`, branch head `62ccb1386d`.

The original feature adds `tileCellSpan`, `occupiedTiles`, `hasOccupiedTileInCellBounds` and a short-circuit in `SpatialHistory:getRecoveryCandidatesParallelogram` to skip fine recovery search in regions with no live history. It updates tile counts on insert/remove/prune/reload and includes a dedicated regression harness. This commit series **diverged by three commits from the current active terrain PR #64** (its merge-base is `3e994a304`); the newer #64 `SpatialHistory.lua` does **not** implement this same tile occupancy mechanism. It is **not correct to call the exact code merged or superseded byte-for-byte**.

- `SpatialHistory.lua.txt`: complete original PR #40 source snapshot (treated as research text; **not loaded by FS25**).
- `terrain_history_broadphase_harness.lua.txt`: original isolated regression (archived, **not executed by CI**).
- [Historical on-field note](../../tests/2026-10-09-plastic-yield-harvester-and-history-broadphase.md) already preserved by archive PR #83.

**Disposition:** close old dependent PR #40 as deferred design research, *not* as implemented or performance-proven. Any future reintroduction must adapt this optimization to #64's newer history recovery/observer semantics, ensure pruning/reload/negative coordinates, and measure actual scan cost with the reworked geometry journal. No runtime RE change, new hook, release/build or gameplay claim.
