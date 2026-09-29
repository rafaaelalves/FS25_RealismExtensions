# TerrainDeformation precedent matrix

Updated: 2026-09-29

Purpose: make implementation decisions auditable before calibration. A precedent is evidence about useful inputs, lifecycle, failure modes or architecture; it is not an instruction to copy another mod wholesale.

| Concern | Existing precedent | RE implementation | Why / remaining risk |
|---|---|---|---|
| Terrain write lifecycle | GIANTS TerrainDeformation users create one object, add multiple deformation areas/brushes, execute asynchronously and delete after completion. | TerrainWriter batches brushes by compatible depth, queues bounded jobs and deletes the deformation object from the completion callback. | Aligned with native lifecycle. Remaining optimization target is brush coalescing/job packing, not bypassing the queue. |
| Player/AI/implement coverage | True AI Tracks 2.2 processes wheels individually and includes implement wheels. | One wheeled-vehicle specialization covers player, AI-controlled vehicles and wheeled implements through the same path. | Avoids a separate AI-only physics path. Must still determine whether True AI Tracks visual/native track responsibility is separable from its ground writes. |
| Discovery/update cost | True AI Tracks 2.2.0.1 fixed an older units bug that made its intended 150 ms vehicle scan execute every frame. | No mission-wide vehicle rediscovery scan; specialization is attached during type setup and each object processes its own wheels. | Architectural advantage, but per-wheel sampling and writer volume still require profiling. |
| Wheel slip input | FS25 exposes wheel-shape slip; MR/RC also provide normalized/cached specialist slip state. | RE consumes RC normalized state and uses cheap wheel/body activity gates before requesting full context. | Prefer specialist normalized state where ownership exists; avoid recomputing parallel slip physics. |
| Static sinkage | Bekker/Wong family separates pressure-sinkage from tangential shear. Mud already owns actual local sink/resistance in the target stack. | Footprint/load/wetness produce a bounded geometric capacity; authoritative Mud sink can raise the lower bound. | RE must not become a second traction/resistance solver. |
| Shear mobilization | Janosi-Hanamoto-type models make shear response a saturating function of shear displacement. | RE keeps accumulated longitudinal/lateral displacement and a bounded exponential-style mobilization term. | Coefficients are gameplay/model parameters until calibrated against available FS state. |
| Slip-induced sinkage | Terramechanics literature reports additional sinkage associated with slip displacement; it is not identical to fast shear-stress saturation. | Experimental v2 branch keeps a slower slip-excavation history that can raise geometric rut capacity under sustained wheelspin. | Direction is physically justified; magnitude and saturation require runtime calibration. |
| Stationary wheelspin | Real wheel-soil models derive relative slip from wheel peripheral motion vs body motion. | Body speed may be zero while wheel surface speed keeps the activity gate open; runtime v3 confirmed this path in-game. | Validated structurally. Visual depth progression still needs v2 runtime test. |
| Spatial memory | Terrain height persists independently of RE's Lua runtime history. | SpatialHistory stores cell-level rut/shear/pass state; persistence contract branch adds deterministic versioned snapshots. | Savegame integration must prevent an existing persisted rut from being treated as virgin soil after reload. |
| Path coverage | Wheel/soil contact is continuous, while game updates are discrete. | RE interpolates between last/current contact position with spacing derived from footprint dimensions and a hard sample cap. | Needs runtime aliasing tests at high speed; do not simply raise sample frequency. |
| Writer pressure | Native TerrainDeformation is job/queue based. | RE uses brush/job/frame budgets and depth bucketing. | Runtime v3 had zero failed jobs; next target is reducing redundant overlapping brushes before changing budgets. |

## Rules derived from the comparison

1. Consume authoritative specialist state; do not reproduce its expensive physics merely to obtain the same scalar.
2. Separate state estimation from geometric consequence.
3. Treat pressure sinkage, shear mobilization and slip-induced sinkage as related but distinct terms.
4. Prefer object/specialization lifecycle over global rediscovery scans.
5. Batch native terrain work and optimize overlap before lowering physical sampling quality.
6. Persist only stable domain state; runtime bookkeeping is disposable.
7. Every imported idea needs a stated owner and a reason it remains necessary in the target stack.
8. Any coefficient inspired by literature but not calibrated to the game's units/state must be labelled as a model parameter, not an empirical soil constant.
