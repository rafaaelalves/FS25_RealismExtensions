# Current development handoff

Updated: 2026-10-02

## Read this first

Canonical active branch for TerrainRecovery work: `feat/terrain-recovery`.

Do **not** create a branch for every experimental version. Historical v11-v22 branches remain as old snapshots, but new iterations continue on the canonical feature branch. Commits, CI artifacts and this handoff preserve milestones.

Development/test policy: `docs/DEVELOPMENT_PROCESS.md`.
TerraFarm architecture audit: `docs/audits/terrafarm/README.md`.

## Architecture ownership

Target dataflow remains:

`MR/Mud -> RealismCompatibility normalized state -> RealismExtensions persistent geometry/history`

- MR owns base vehicle/wheel dynamics and traction.
- Mud owns local wetness, instantaneous sink, resistance/stuck and related wheel-ground state.
- RC normalizes/reuses specialist state and coordinates overlaps.
- RE consumes that state to create persistent terrain geometry/history.
- RE must not become a second Mud traction/sink solver.

## TerrainDeformation state before current recovery test

Validated/important:
- distance/cadence-based rut progression removed the simple low-speed sample-count bias;
- Mud instantaneous sink is plasticized before becoming persistent RE geometry;
- TerrainWriter LOWER/RAISE/SMOOTH paths execute through GIANTS TerrainDeformation;
- v13 proved `DensityMapHeightUtil.smoothAroundLine` was physically ineffective for this use;
- TerrainDeformation smoothing physically changes the heightfield;
- recovery must be evaluated by local roughness/relief, not center-height sign alone;
- SoilMassTransport remains disabled during current recovery isolation;
- crawler/native track modeling is still incomplete and remains a separate blocker.

## v21 runtime findings (2026-10-02)

Two runtime logs showed a repeated destructive pattern.

Representative later run:
- v21 recovery active;
- thousands of smoothing operations executed and most measured callbacks reduced local roughness;
- `activeCultivatorRutSkips` proved the new root-combination suppression path was active;
- nevertheless `MR_Koralin_9-840` remained the dominant RE LOWER writer under root `Steiger_785_Quadtrac`.

This initially looked like an incomplete root/implement suppression leak.

Source review of current GIANTS `Cultivator.lua` identified the deeper semantic bug:
- `processCultivatorArea` returns `realArea, area`;
- `realArea` is agricultural terrain state that actually changed;
- `area` is processed area;
- repeated passes over already-cultivated ground can therefore produce `realArea=0, area>0`;
- GIANTS sets `spec.isWorking` from physical movement/work state separately.

v21 incorrectly used `realArea > 0` to:
1. mark the tractor/implement combination as active for rut suppression; and
2. invoke recovery.

Therefore a repeated pass could become:
`SMOOTH OFF + RE LOWER ON`.

This matches the observed user report that additional passes could make a repaired area worse.

## v22 correction

v22 is now the current code on `feat/terrain-recovery`.

Behavior:
- before the vanilla call, an enabled moving cultivator marks its root combination active so same-frame wheel sampling cannot reopen persistent ruts;
- after vanilla processing, GIANTS `spec.isWorking` is used as physical work evidence;
- recovery uses processed `area`, not changed `realArea`;
- repeated physical passes continue smoothing even if the agricultural density-map state no longer changes;
- active combination suppression remains refreshed during those passes.

Regression harness explicitly covers:
- first pass: `realArea>0, area>0`;
- repeated pass: `realArea=0, area>0, isWorking=true`;
- inactive/no-area path.

CI passed before runtime testing.

## New telemetry discipline added after v22

The next build records:
- cumulative physical/changed/repeated work-area calls;
- cumulative changed/processed/repeated area units;
- pre-super active marks;
- five-second `TerrainWindow` causal summaries:
  - physical work;
  - changed work;
  - repeated work;
  - processed/repeated area;
  - smoothing enqueue/callbacks;
  - roughness improved/worsened;
  - rut writes blocked;
  - recently-cultivated skips;
  - accepted rut writes;
- `RutWriters` now prints cumulative counts plus per-window deltas.

Reason: cumulative writer counts made it impossible to tell whether a write happened during transport or during active cultivation. Windowed attribution should expose that immediately.


## Testable refactor checkpoint — 2026-10-02

Runtime-test checkpoint: `d696024642cf7e0798a0ff1730456433ceae787a`.

GitHub Actions run: `37053455198`.
Artifact: `FS25_RealismExtensions-d696024642cf7e0798a0ff1730456433ceae787a`.

This checkpoint preserves the v22 physical behavior while refactoring the surrounding architecture/observability:

- added `TerrainWorkContext` as the single owner of combination root, vehicle labels, speed, cultivator pre/post work semantics and work-area geometry;
- TerrainRecovery consumes that shared context, including the `realArea=0, area>0` repeated-pass case;
- TerrainDeformation writer attribution uses the same root/label semantics;
- removed abandoned v18-v20 Construction/native-recovery writer paths from `TerrainWriter`;
- made terrain job ordering deterministic (`LOWER -> SMOOTH -> RAISE`);
- added `TerrainTelemetry` for causal windows and per-window writer attribution instead of calculating it ad hoc in Core;
- diagnostics use an explicit development profile with configurable window cadence;
- added CI build identity stamping (branch/commit/run/time) and ZIP identity verification;
- TerrainRecovery temporary state now has an explicit per-map lifecycle reset;
- added/expanded harnesses for work context, causal telemetry, Core diagnostics and recovery lifecycle;
- CI parses every Lua source before running harnesses.

All harnesses and packaging checks passed on run `37053455198`.

The connection interruption after this checkpoint occurred during a read-only broad source audit. No uncommitted implementation was lost. The broad audit was not completed; specifically, no WorkFootprint extraction or further physics changes were made after this checkpoint.

For the next runtime test, use the artifact above and verify the startup `BuildIdentity` reports exactly this commit before interpreting the log.

## Next runtime test

Do not tune smoothing strength/radius before this test.

Use the build from current `feat/terrain-recovery`.

Preferred scenario:
1. use a known manually repaired/smooth strip as a destructive-regression sentinel;
2. lower/activate the cultivator and make one pass;
3. make a second pass over the same path;
4. make a third pass if safe/useful;
5. include a visibly rutted region in the same session;
6. preserve the full log.

Acceptance:
- repeated passes report `repeat > 0`;
- `processedArea` continues growing when `changedArea` stops;
- active rut-block counts continue growing during repeated work;
- Koralin/root writer **window deltas** should remain zero or explainable while physical cultivation is active;
- manually repaired ground must not be newly excavated by RE;
- rutted ground should show nonzero smoothing callbacks and net roughness improvement.

If destructive LOWER writes still occur in the same five-second windows as physical/repeated cultivation, attribution is now sufficient to investigate the remaining path directly.

## TerraFarm audit findings relevant now

Source: `scfmod/FS25_TerraFarm` commit `b50e677cdef062d605ab188f8982ae1faa2789e7`.

Useful architecture:
- Machine specialization owns activation/state/cadence;
- MachineWorkArea owns spatial nodes and direct terrain-contact state;
- Landscaping operation classes own TerrainDeformation mode/execution;
- common input/output layer owns brush construction, constraints and async callbacks;
- machine input operations are cadence-controlled (50 ms);
- wide work areas are represented by multiple nodes across width;
- smooth input uses TerrainDeformation smoothing with 0.05 height-change amount; default machine input state uses radius 2 m, strength 0.25, hardness 0.2;
- async success callbacks own downstream consequences.

RE lesson: split future recovery architecture into WorkDetector / WorkFootprint / TerrainOperation / HistoryReconciliation rather than letting Cultivator semantics leak into generic terrain writing.

Important: TerraFarm values are precedents/configuration, not empirical constants and not automatically correct for agricultural recovery.

## v22 runtime validation — successful mechanism test (2026-10-02)

Tested artifact identified itself as:
- branch: `feat/terrain-recovery`
- commit: `94a10476e45b8fc4ebf14f7a25e6cd7440c92509`
- run: `37063152919`

That commit is only one documentation commit ahead of the d696 code checkpoint; the runtime implementation is the same tested recovery/refactor code.

User observation: terrain recovery finally behaved correctly and visibly converged instead of becoming progressively worse. More than 2–3 passes were required on the damaged test area, but the result was considered satisfactory.

Runtime evidence from the main work session before soft restart:
- final cumulative physical work calls: 2759;
- changed first-state calls: 1098;
- repeated physical work calls: 1661;
- recovery brushes/callbacks: 9504/9504;
- roughness outcomes: 6796 improved, 571 worsened, 2137 neutral;
- cumulative measured improvement: 4.8308 m vs 0.1885 m worsening;
- recovered history: 917 cells / 0.649 m;
- active cultivator rut skips: 20068;
- no failed TerrainDeformation jobs;
- late stable work windows repeatedly showed `rutAccepted=0` and Koralin/root writer window delta `(+0)` while recovery continued.

This validates the v22 mechanism-level correction:
- repeated work (`realArea=0, area>0`) continues recovery;
- root-combination persistent rut suppression remains active during physical work;
- machine-style SMOOTH now produces useful convergence rather than the previous destructive/no-op behavior.

Remaining calibration issue:
- severe historical terrain required substantially more than 2–3 passes.
- Do not immediately increase strength. First establish a baseline pass-count vs initial roughness/rut-depth relationship and preserve the now-working monotonic convergence.
- Some 5-second mixed transition windows still show accepted Koralin writes while work also occurred in the same window. Because the window can include both active and lifted/post-work portions, this is not yet proof of an in-work suppression leak. If further refinement is needed, add event-state attribution to accepted writes rather than infer from coarse window overlap.

Status: TerrainRecovery mechanism is **runtime validated; calibration/stabilization pending**.

## TerraFarm deep audit status

The TerraFarm audit has been expanded beyond the initial smoothing precedent. Canonical entry:
`docs/audits/terrafarm/README.md`.

Focused supplements now cover:
- machine lifecycle/configuration and work detection;
- TerrainDeformation operation/constraint/callback/material pipeline;
- persistence, multiplayer, path/polygon areas and map resources;
- RC/RE integration opportunities and compatibility tiers;
- integration risk/decision matrix;
- official TerraFarm Machines addon extensibility pattern.

Important current conclusions:
- prefer event/state observation over patching TerraFarm internals;
- lazy physical SpatialHistory reconciliation is the preferred generic compatibility mechanism;
- if ownership-aware integration is needed, an event-driven machine adapter is preferable to another `Vehicle.load` hook;
- large future RE heightfield edits may need coalesced GIANTS AI `setAreaDirty` updates;
- external declarative profile packs are a strong precedent for future RecoveryProfile/ContactFootprint equipment corrections;
- keep implementation clean-room/independent; do not vendor/adapt TerraFarm source.

No TerraFarm runtime bridge has been implemented yet.

## Canonical next-phase terrain plan

The detailed implementation sequence now lives in:
`docs/project/TERRAIN_EVOLUTION_PLAN.md`.

It explicitly preserves the following future work so it is not lost across chats:

- TerrainPassTracker and pass-based recovery dose;
- RecoveryPassSummary and direct `rutAcceptedWhileActive == 0` invariant;
- slope-aware roughness, roughness distributions and target/convergence roughness;
- severity-adaptive recovery;
- TerrainWorkFootprint and TerrainRecoveryProfile;
- tool-family differences (cultivator/disc/subsoiler/plow/roller), later moisture/direction response;
- ContactFootprint abstraction for single, dual/twin, wide/flotation and implement wheels;
- first-class native GIANTS crawler/track footprints from `spec_crawlers.crawlers`;
- PLAYER / GIANTS_AI / COURSEPLAY parity;
- True AI Tracks / `FS25_aiTracks` ownership audit and retire/coexist/bridge decision;
- recovery independent of direct player action:
  - natural relaxation;
  - NPC/other-farmer field work;
  - public/municipal maintenance;
  - sparse world-recovery scheduler;
  - ownership/maintenance zones;
  - persisted elapsed-time handling;
  - arbitration so background recovery does not race active machine work;
- lazy SpatialHistory reconciliation after Construction/TerraFarm/external edits;
- SoilMassTransport redesign;
- underbody/high-centering research.

This plan is the canonical source for sequencing/dependencies; CURRENT_HANDOFF should record only the current implementation/runtime evidence.

## Separate unresolved TerrainDeformation blockers

Do not lose these while focusing on recovery:
- first-class native crawler/track footprint;
- avoid generic wheel-contact errors for crawler shapes;
- implement-wheel ordering relative to work operation;
- SoilMassTransport adaptive mass realization (latest enabled test had ~2x over-realization; currently disabled);
- player/GIANTS AI/Courseplay parity;
- event-triggered underbody/high-centering diagnostics;
- True AI Tracks external-mod integration/retirement decision;
- performance/persistence regression validation.

## Context-continuity rule

A new chat should read, in order:
1. `docs/project/CONTEXT.md`
2. `docs/project/CURRENT_HANDOFF.md`
3. `docs/DEVELOPMENT_PROCESS.md`
4. relevant decision/audit docs.

CURRENT_HANDOFF is expected to be updated after every meaningful runtime conclusion, not only at release boundaries.


## 2026-10-04 consolidation / current active state

Canonical active branch remains **`feat/terrain-recovery`**.

Repository organization:
- validated pre-recovery terrain foundation through the v10.2 profiler baseline is now merged into `main`;
- current recovery experiments, tracks/VMT assimilation and completed assimilation audits continue only on `feat/terrain-recovery`;
- do not create another branch for the next TireTrack bootstrap or recovery iteration;
- branch cleanup inventory: `docs/project/BRANCH_CLEANUP_2026-10-04.md`.

CI policy:
- docs-only / Markdown-only pushes no longer create a build artifact;
- mixed code + docs changes still run the full workflow.

### Tracks/VMT runtime result

First runtime test of the adapter checkpoint:
- `addTrackPoint=65622`;
- `cutTrack=3972`;
- `createTrack=0`;
- max args `0/15/1`;
- `observerErrors=0`;
- `drift=0`.

Interpretation:
- mission-instance adapter boundary is stable;
- point/cut contracts are proven;
- current `Core:loadMap()` installation is too late to observe existing track creation;
- `VisualTrackCapture` remains OFF.

Next tracks step is documented in:
`docs/research/native-tire-track-create-bootstrap.md`.

Preferred next experiment:
- install the mission-instance adapter from a lightweight `TireTracks:onPreLoad` bootstrap;
- first test remains probe-only;
- require runtime `createTrack>0` and `2/15/1` before enabling capture.

### Recovery runtime result

The new loaded-contact safety guard is over-broad in normal cultivation.

Observed final session:
- coverage candidates: 14,552;
- post-stamp contact queries: 13,678;
- blocked by loaded contact: 13,409;
- smoothing brushes enqueued: 269.

This means the current guard prevents a fair comparison of recovery geometry and must be redesigned.

Recovery is now explicitly split into:
1. safety/eligibility;
2. recovery intent/reference;
3. terrain operation.

The current preferred research sequence is:
1. deferred/eventual recovery for temporarily blocked patches;
2. measure actual wheel-channel depth/width instead of only roughness;
3. retest GIANTS native smoothing under fair coverage;
4. add history-guided target behavior only if native smoothing still leaves persistent rut relief;
5. explicit raise/lower redistribution only as a later proven need.

Design document:
`docs/research/terrain-recovery-design-study.md`.

Do **not** implement frozen original-height restoration.


### Recovery implementation checkpoint after over-blocking test

Implemented on the canonical `feat/terrain-recovery` line:

- blocked smoothing patches now enter a bounded deferred queue instead of relying on a future Cultivator callback;
- queue uses spatial coalescing, 200 ms retry, 5 s TTL, 2048-entry cap and 16 checks/update;
- deferred patches revalidate loaded contacts before writing;
- harness proves eventual completion after contact clears without another work-area callback;
- added pure `RecoverySurfaceEstimator` using a robust outer-boundary plane;
- estimator measures center deficit, valley depth, peak height, relief range, roughness and mean elevation;
- uniform field lowering is intentionally separated from rut-relief reduction;
- TerrainWriter now reports these metrics around recovery brushes.

No physical smoothing constants changed.

Current physical strategy remains GIANTS native SMOOTH until runtime determines whether fair coverage + deferred completion removes the surviving wheel channels.

Latest integrated recovery/measurement code is green in CI; the earlier tracks-only artifact remains the required build for the current createTrack test.


### Current recovery head — Strategy H1

After the v23 runtime proved deferred eventual completion, recovery selection moved from blind full-width coverage to SpatialHistory-guided intent.

Current rules:
- a cultivator work area alone is not permission to alter terrain;
- only RE-attributable rut debt creates recovery centers;
- nearby history cells are clustered and deepest debt is prioritized;
- GIANTS native SMOOTH remains the only physical actuator;
- deferred requests are revalidated against remaining rut debt before execution;
- no original-height target exists.

The previous full-width v23 runtime remains the evidence baseline:
- 3,284 deferred created / 3,176 applied;
- queue drained to zero;
- ~86% of measured brushes reduced local relief;
- full geometry probing was expensive at v23 brush volume.

Next runtime should use the latest green Strategy H1 artifact and compare intent/brush/performance counters against v23.


### Recovery H2 — causal-center convergence

The latest user-visible v23 test falsified full-width smoothing as a sufficient solution:
- many callbacks reported lower roughness/relief;
- the visible RE wheel channels remained;
- center geometry usually moved down rather than up;
- logical rut history was being reconciled too broadly from roughness improvement.

H2 fixes the model rather than tuning v23:
- history cells select exact causal centers;
- roughness/relief are telemetry only;
- center-deficit reduction is the physical recovery signal;
- logical history is reduced only at the exact causal cell;
- one cultivator authorization can continue bounded native-smooth pulses after the work-area callback moves on;
- physical center deficit, not remaining logical debt, owns convergence completion.

Automated H2 regression suite is green.

Runtime gate:
1. create **fresh ruts after loading the H2 build** on a clean patch;
2. cultivate the fresh ruts before manual landscaping;
3. inspect visible convergence and v25H2 center-deficit/convergence telemetry;
4. separately verify an unrelated/clean landscaped area is untouched;
5. use the same session to close VisualTrackCapture if create/accepted/finalized/chunk counters are healthy.

Important: old v23 ruts are not the best H2 reference because v23 could already have erased/understated their logical history without physically removing them.

If fresh H2-owned ruts still do not close, stop tuning native SMOOTH and implement Strategy R1 target-plane recovery.


### Runtime gate — v26R1 structural recovery

H2 runtime conclusion is now stable:
- causal rut selection works;
- native SMOOTH works well for finishing/shallow irregularity;
- native SMOOTH is not a sufficient deep-rut reconstruction actuator.

The next build uses hybrid R1:
- >3 cm causal center deficit: narrow target-plane structural repair;
- <=3 cm: H2 native SMOOTH finishing;
- every structural step capped by remaining RE rut ownership;
- current robust local boundary plane is the reference.

Green code commit:
`fd665a5c6f11b2976c1d3ed91db363ece4f524d5`

Runtime test must use fresh ruts generated after loading this build.

Primary telemetry:
`TerrainRecovery v26R1`
and
`TerrainRecoveryStructural`.

Success signal:
- targetJobs/targetBrushes > 0;
- targetRaised > 0;
- targetLowered near zero for causal hole centers;
- centerRaised and deficitReduce are centimeter-scale on deep ruts;
- maxAfter materially below maxBefore;
- ownershipExhausted does not dominate normal fresh-rut repair.

The tracks assimilation runtime gate is separately CLOSED/PASS.
