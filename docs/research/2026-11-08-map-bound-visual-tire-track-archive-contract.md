# 08-Nov-2026 — bounded visual TireTrack archive; no native fine terrain writes

## Context and correct interpretation

The user wants the FS25 RE terrain module to **produce exactly the authorized lowering** and eventually retain and repair physical wheel ruts. The MAIN (coarse) heightmap readback and its ~3.891 mm candidate vertical quantum do NOT expose the GIANTS native finer wheel deformation grid. The standard GIANTS tire track specialization calls `spec.tireTrackSystem:addTrackPoint` with the `groundDepth` returned by `wheel.physics:getGroundAttributes()`. This is a **rendering/track observation** and cannot be certified as permanent deformable soil geometry or as post-load collision readback.

Official FS25 reference: https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=811&version=engine and WheelPhysics class https://github.com/umbraprior/FS25-Community-LUADOC/blob/main/docs/script/Wheels/WheelPhysics.md

The PR64 runtime already observes these visual calls via `NativeTireTrackAdapter`; `VisualTrackJournal` simplifies and segments paths, then `VisualTrackChunkStore` bounds spatial memory. None of the new work authorizes a terrain setter.

## Implemented in the experimental branch (03b23027 baseline → new commits)

### Last remaining runtime visual capture metadata leak

- `VisualTrackJournal.VERSION=4` introduces `maxTrackedNativeIds=8192` (configurable). On a **new distinct native ID** at capacity, recycle only the least-recently-used **inactive** track metadata when `retainClosedFragments=false`. An active fragment can never be evicted to admit another native ID. If all IDs are busy, fail closed and ignore the new ID rather than merging foreign points into an older trace.
- Retained-history mode does not evict old snapshots. It refuses expansion at capacity, including reuse of an ID where reuse would allocate a new generation. On refused reuse, remove the old live ID mapping so later points cannot attach to the previous generation.
- Track list indexes use swap-with-last on eviction; continuous churn remains bounded by the configured active-ID count. Counters: `nativeIdEvictions`, `nativeIdCapRefusals`; both appear through `VisualTrackRuntime.getDiagnostics` and existing periodic `VisualTrackCapture` log summary in `Core.lua`.
- `tests/visual_track_native_id_cap_harness.lua` exercises active-track overflow refusal, idle-only eviction, old-ID rejection, same-ID reuse without growth, 550+ IDs of churn and retained-mode refuse+orphan safety. The harness cannot prove native physical rutting.

### Visual archive format (no disk IO, no replay)

- `scripts/tracks/VisualTrackArchive.lua` exports **plain Lua data**, `version=1`, `channel=NATIVE_TIRE_TRACK_VISUAL_ONLY`, `authorizesTerrainWrites=false`, `authorizesPhysicalReplay=false`, and exact caller-supplied `mapId`, `terrainFingerprint`, `terrainSizeM`, `mainUnitM`.
- The *terrainFingerprint* is a **required trusted external input**, not yet derived from the live FS25 map; an arbitrary string does not authenticate the map! This is a schema and map-binding contract awaiting a genuine loader-side provenance mechanism, not a working persistence feature.
- Archive snapshots are independently deep-copied, with only known, finite, bounded point fields; each stored chunk key and coordinates must be consistent. Default maximum 8192 chunks, 40000 fragments, 160000 point references. Reject oversized, wrong-map, malformed, duplicated, non-terrain or physically-authoritative data. Imported data is held in a **new, detached** VisualTrackChunkStore only; no calls to `setTerrainHeightAtWorldPos`, `setWheelShapeTerrainDisplacement` or `TireTrackSystem:addTrackPoint`.
- `modDesc.xml` loads the archive validator before `VisualTrackRuntime`. `VisualTrackRuntime.exportVisualArchive(world)` produces the read-only serializable snapshot; `VisualTrackRuntime.inspectVisualArchive(snapshot,world)` returns a separate store and never attaches it to gameplay or XML.
- Tests `visual_track_archive_harness.lua` cover round-trip of cross-chunk boundaries, deep copy/nonaliasing, map mismatch, nonfinite point, tampered channel/authority/version, mismatched totals, duplicate chunk, invalid coordinates and native setter traps. Extended `visual_track_runtime_harness.lua` confirms export + isolated inspection with actual simulated adapter events.

## Verification and release gates

Automated Lua tests + source parsing + XML validations are green for code commit `ad71f87e` via https://github.com/rafaaelalves/FS25_RealismExtensions/actions/runs/42464764066 . This is **harness proof, NOT FS25 runtime proof**.

The remaining actual launch blockers are NOT solved by a visual archive:
1. The engine's native fine wheel rut geometry **has no verified readback/write/persistence API** in the reviewed public Lua docs. `TireTracks` point and `groundDepth` values are not independent physical geometry observations. Do not relabel a visual overlay as a persistent physical rut.
2. MAIN 1m coarse grid cannot be indiscriminately used for ~0.2–0.35m tire grooves. For broad MAIN changes, map-specific verified vertical quantum, exact one-step native setter behavior, no collateral damage and real save/reload on a **verified disposable clone** remain mandatory.
3. A real visual archive save format requires deriving a genuine map/terrain fingerprint from runtime, encoding/decoding to a bounded persisted file, replay controls **separately for the visual renderer** and validation of lifetime/MP behavior. These are **not implemented**.
4. Physical restitution must only alter PROVEN-owned geometry. Neither visual track point history nor arbitrary `terrain history cells` can grant recovery ownership.
5. Existing `SHADOW` and `OBSERVE_ONLY` gates stay in place; no automatic permanent height writes, no native wheel force scale, no merge to main. Repeated plow/sow/harvest testing does not validate the unanswered engine API and is not requested.

**Intent:** make subsequent persistence experiments auditable, bounded and map-specific while keeping the module honest about physical limitations. This is not a declaration of release readiness.
