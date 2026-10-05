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


### Runtime gate — v28R3 closed-loop monotonic recovery

R2 runtime (build `8f1e6605ca5343fb7826c4aa317eb081364422f1`) proved the missing actuator:
- additive RAISE does move the FS25 terrain under machine work;
- recovery no longer lowered terrain (`lowered=0`, `loweringViolations=0`);
- but treating `setAdditiveHeightChangeAmount` as metres was invalid.
- observed runtime amplification was extreme: requested command telemetry peaked at ~0.027 while a recovery center callback observed up to 1.0389 m upward delta.
- R2 also selected centers ~0.30 m apart with 0.70 m diameter brushes, guaranteeing spatial overlap and cumulative mounds.
- user visually confirmed recovery overshot the original surface and created large hills.

R3 control contract:
1. Work-area callbacks schedule causal RE-owned intent only; they do not calculate/apply a raise.
2. Exactly one recovery raise may be in flight globally.
3. Immediately before each command, re-measure the current local boundary plane and center deficit.
4. Command units are opaque actuator units. Start conservatively with an assumed command->world gain and learn the observed gain from `deltaY / command`.
5. Desired physical correction is bounded (12 mm nominal and <=60% of remaining deficit per pulse).
6. RAISE remains monotonic; any negative delta is a hard violation/stop.
7. Only useful verified upward motion consumes SpatialHistory debt.
8. Positive center residual above the fitted plane is explicit overshoot telemetry.
9. Recovery centers are spaced at >=~brush diameter (0.30 m radius, spacing factor 2.10) instead of deliberately overlapping.
10. Recovery RAISE uses the direct TerraFarm-style machine deformation path, one brush/job.
11. TerrainDeformation objects are deleted directly in the completion callback; the R2 delayed-delete path produced one nil-handle delete error.

Primary telemetry:
`TerrainRecovery v28R3`
and
`TerrainRecoveryFill`.

Green runtime target:
- `loweringViolations=0`;
- `overshoot=0` (or only millimetric, <=4 mm);
- `maxOvershoot<=0.004m`;
- `gainSamples>0` and gain converges;
- `raiseMaxDelta` becomes centimetric rather than decimetric/metre-scale;
- `machineSmoothJobs=0`;
- repaired rut centers stop within the local-plane tolerance without surrounding-field depression or new mounds.


### Runtime gate — v29R4 signed recovery controller

R3 runtime (build `945c54b57f0bd2b461ae74227b7524949a7b21b5`) preserved the field but became ineffective on deep ruts:
- build identity was correct;
- serial execution was healthy (`timeouts=0`);
- no recovery RAISE lowered terrain (`loweringViolations=0`);
- however 4,242 applied fill callbacks produced 4,119 center no-ops;
- the linear gain controller collapsed to its minimum gain and stayed pinned at `commandMax=0.002500`;
- only 123/4,242 callbacks visibly raised the sampled center.
This falsifies the R3 assumption that the actuator can be modeled as a smooth linear gain. Runtime behavior is closer to a dead-zone/quantized actuator.

User also clarified an important architectural distinction:
- native SMOOTH is bad as a repeated deep-hole filler because it can lower the surrounding field;
- that does not make SMOOTH useless;
- positive causal peaks/berms are the opposite geometry, where redistribution/smoothing is the appropriate tool.

R4 state machine:
- signed residual < -4 mm: RAISE only;
- signed residual within +/-4 mm: converged;
- signed residual > +4 mm: SMOOTH only when that peak is explicitly authorized.
For this build, positive-peak authorization is deliberately narrow: the exact recovery sequence must have created the overshoot. A stale rut marker alone is not permission to smooth a player-created mound. General tire/soil berm repair should later gain its own SpatialHistory ownership field (for example `bermHeightM`) when SoilMassTransport creates the berm.

R4 RAISE controller:
- remove the failed linear gain estimator;
- start at opaque command 0.005;
- on physical no-op, multiply command by 1.70 up to 0.040;
- remember the discovered working command globally for new causal patches;
- after an overly large physical response, back command down to 65%;
- desired physical step remains ~12.5 mm / <=50% of current deficit / <=remaining rut debt;
- one structural command remains globally in flight at a time;
- deferred queue processing stops after accepting that command, preventing pointless churn while awaiting its callback.

R4 peak cleanup:
- recovery-created positive overshoot may use one bounded native SMOOTH pulse at a time;
- re-measure signed residual after every pulse;
- never continue SMOOTH after crossing below the reference plane;
- no pre-existing positive mound is altered merely because stale rut history exists.

Primary runtime telemetry:
`TerrainRecovery v29R4`
and
`TerrainRecoveryFill`.

Green runtime target:
- no-op ratio falls sharply after initial command discovery;
- `escalations>0` early, then command estimate stabilizes;
- `effectiveMin/effectiveMax` identify the real FS25 actuation band;
- causal deep-rut center deficit materially decreases on each pass;
- `loweringViolations=0`;
- any quantized overshoot is small and followed by `peakSmooth` cleanup;
- no broad field depression returns.


### Runtime gate — v30R5 bounded target-plane recovery

R4 runtime (build `1778293966ac509380e2caec297cf30db778bff9`) closed the visible rut but falsified additive RAISE as a precision actuator:
- SoilMassTransport is disabled in the current development config, so the observed large mounds are not the lateral-berm model;
- useful additive recovery pulses remained coarse/quantized;
- observed recovery center raises reached ~0.224 m and later ~0.840 m in a single callback;
- total center raise greatly exceeded measured deficit reduction;
- R4 peak SMOOTH barely moved those mounds (example ~0.7245 m -> ~0.7206 m after many smooth jobs) and completed zero peak repairs.

External precedent re-check:
- TerraFarm issue #97 ("Machine modes update") explicitly reworked RAISE/LOWER to internally use flatten deformation mode when a landscaping target area exists;
- current TerraFarm Flatten/Slope uses `setHeightTarget(...)` + `enableSetDeformationMode()` with `heightChangeAmount=0.75`;
- therefore the amount is treated as actuator intensity/rate, while the target geometry bounds the destination;
- our R1 instead used only ~0.04 and incorrectly treated the amount as a maximum physical step, which is consistent with its near-no-op runtime.

R5 hypothesis:
1. Keep causal authorization from SpatialHistory.
2. Fit the current local boundary plane (now using a 16-sample ring).
3. If the initial center is already above the plane, do not touch it; stale rut debt is not permission to flatten player terrain.
4. If the causal center is below the plane, submit a localized TARGET brush to that fitted plane.
5. Use TerraFarm-like target actuator intensity 0.75 (up to 1.0 only after verified no-op).
6. Serialize globally and re-measure after every target callback.
7. Keep logical rut debt until physical convergence; clear it only once |signed residual| <= 4 mm.
8. If a target pulse crosses slightly above the plane, the same causal target sequence may correct it back down. No additive RAISE and no native SMOOTH are used in this runtime experiment.
9. Any worsening of absolute residual stops the sequence instead of trying to overpower the terrain.

Primary runtime telemetry:
`TerrainRecovery v30R5`
and
`TerrainRecoveryTarget`.

Green runtime target:
- recovery `raiseJobs=0` and `smoothJobs=0`;
- `targetJobs>0`, `targetApplied>0`;
- `residualReduce` grows and `maxAbsAfter << maxAbsBefore`;
- both `targetRaised` and (only if correcting a small sign-crossing) `targetLowered` are bounded by the fitted target plane;
- `targetMaxDelta` is proportional to actual rut/peak error, never the 0.2-0.8 m additive jumps seen in R4 unless the measured error itself is that large;
- fresh ruts converge without leaving a replacement mound or broad depression.

Important test hygiene:
- use fresh ruts generated after loading R5;
- do not use old R4 mountains as the primary gate because their causal rut debt may already have been cleared and R5 intentionally refuses to infer ownership from geometry alone.


## R5 runtime gate — concept proven, efficiency/refactor gate opened

Runtime build: `988f97421f80ebb4c034205433c7d91f592293da` (workflow 37224032054, green).

Observed result:
- user visual gate: PASS. Repeated cultivator passes can remove the RE ruts without producing the R4 replacement mountains;
- TARGET is isolated correctly: final runtime had `raiseJobs=0`, `smoothJobs=0`, `targetJobs=4120`;
- no target timeout/rejection/backlog failure: `timeouts=0`, `rejected=0`, `deferredDropped=0`, final writer queue 0;
- geometric direction is healthy overall: `residualReduce=28.8858m` vs `residualWorsen=0.2961m`, with only 39 worsening callbacks;
- the largest observed TARGET center delta was ~0.1012m, far below the 0.2-0.84m additive R4 jumps.

The runtime also exposed the next bottleneck: efficiency, not correctness.
- 4,120 TARGET callbacks produced 2,818 exact-center no-ops (~68.4%);
- 1,255 callbacks raised the sampled center and 47 lowered it;
- 1,006 structural sequences stalled;
- 666 completions were initial-positive/stale-debt skips rather than physical TARGET convergence;
- 29,544 structural schedule requests collapsed into only 4,120 physical TARGET jobs, with 24,339 deferred coalesces.

Primary architectural mismatch:
- one R5 TARGET brush physically modifies a ~0.40m-radius patch;
- logical reconciliation still clears only the exact 0.20m SpatialHistory cell at the selected center;
- neighboring causal cells may already be physically repaired by the same brush but retain logical rut debt and are selected again on later passes;
- this is the leading explanation for the user's "works, but needs many passes" result and for the high no-op/initial-positive counts.

Preferred next refactor before gameplay tuning:
1. Add patch-level verified reconciliation: enumerate causal SpatialHistory cells inside the applied TARGET footprint, sample their post-operation terrain height against the same fitted target plane, and clear only cells physically within tolerance. Do not blindly erase a circle.
2. Retire dormant SpatialHistory cells when rut/shear/exposure state is fully recovered. The R5 session loaded 49,567 cells and ended around 49,150 against the current 50,000-cell cap, so stale zero-debt cells are a real large-field scalability risk.
3. Reuse the preflight RecoverySurfaceEstimator probe in TerrainWriter rather than immediately sampling the same 16-point ring again. Current TARGET flow does at least preflight + writer-before + writer-after probing; passing the verified preProbe into the writer can remove one full ring per TARGET without changing physics.
4. Replace the writer's front-of-array `table.remove(queue, 1)` with a head-index/ring queue before enabling higher TARGET throughput or SoilMassTransport.
5. Clean telemetry semantics: TARGET `heightChangeAmount` is an actuator intensity, not meters. Current generic writer counters therefore emit misleading values such as `requestedDepth=3495.188` / `maxRequested=1.000`. Split additive-depth metrics from TARGET-intensity metrics.
6. Mark performance timing as inclusive where appropriate: direct TerrainDeformation callbacks run inside writer flush, so callback time is nested inside flush and should not be double-counted.

Performance interpretation from the ~620s runtime:
- vehicle update: avg ~0.045ms, max ~2.149ms;
- recovery work-area logic: avg ~0.439ms, max ~0.916ms;
- writer flush when non-empty: avg ~0.628ms, max ~2.652ms;
- callback: avg ~0.056ms, max ~1.999ms (nested in direct apply/flush);
- measured non-double-counted RE terrain CPU is roughly ~1.14% of one CPU core averaged across the session. This is healthy and does not justify a rewrite.

Calibration should follow the refactor, not precede it:
- do not simply increase TARGET amount (already reaches 1.0);
- investigate hit-rate/coverage after patch reconciliation;
- R3's old `targetSpacingFactor=2.10` was chosen to prevent additive RAISE overlap. With bounded TARGET this anti-overlap constraint may now be obsolete, but spacing/radius should be tuned only after neighboring history cells are physically verified and reconciled;
- if throughput still limits large fields after no-op debt is removed, consider a small bounded set of non-overlapping independent TARGET patches per frame rather than the current single global structural in-flight slot.


## R6 consolidation refactor — patch ownership, lifecycle and throughput hygiene

R6 intentionally preserves the R5 physical contract. No recovery tuning constants, target-plane semantics or ownership rules were loosened to obtain speed.

Implementation invariants:
1. TARGET remains the only structural actuator in the current runtime path.
2. One globally serialized structural TARGET remains in flight; concurrency tuning is deferred until waste is removed and runtime proves a need.
3. The preflight local-plane probe is passed into TerrainWriter and reused as the callback's before-geometry, eliminating one duplicate 17-sample ring per TARGET.
4. A successful/near-converged TARGET reconciles the full physical brush patch, but only per-cell after verification:
   - enumerate only SpatialHistory cells with causal rut debt inside the TARGET radius;
   - sample each cell's current terrain Y;
   - compare against the exact same fitted target plane;
   - clear that cell's logical debt only when |residual| <= structuralToleranceM;
   - retain every cell still physically outside tolerance.
5. SpatialHistory v5 has explicit retirement. A cell is removed from the live LRU once rut/shear/slip-excavation/exposure debt is physically zero. `passCount` alone is metadata, not ownership, and cannot keep/create a tombstone.
6. Snapshot import/export ignores dormant/pass-count-only cells so stale bookkeeping cannot consume the 50k live-history budget.
7. TerrainWriter v13 replaces front-array `table.remove(queue,1)` with head/tail/count dequeue. Ordinary pops are O(1); queue compaction happens only when job-budget leftovers must be placed ahead of callback-enqueued work.
8. TARGET actuator amount is now reported as dimensionless intensity, not metres. Generic additive-depth counters exclude TARGET.
9. Performance telemetry explicitly labels `flushInclusive` and `callbackNested` to prevent double-counting direct TerrainDeformation callback time.

New R6 diagnostics:
- `patch=examined/converged`
- `retained=`
- `sampleFail=`
- `patchDepth=`
- `patchMaxResidual=`
- `preProbeReuse=`
- `retired=`
- `targetIntensity=count/sum/max`
- writer queue size comes from `getQueueSize()`.

Expected runtime improvement versus R5:
- substantially fewer stale/no-op TARGETs on later passes;
- one TARGET can retire several neighboring causal cells that it physically repaired;
- `initialPositiveSkip` should fall because already repaired neighboring debt is removed immediately;
- live history count should fall as ground is recovered instead of remaining pinned near 50,000;
- CPU should remain in the same or lower range despite patch verification because one 16-point before-probe is removed per TARGET and stale future TARGETs are avoided.

R6 is a consolidation checkpoint. Do not tune radius/spacing/parallelism until its runtime log confirms patch reconciliation is reducing no-op work without altering the R5 visual result.


## R7 tillage-capability layer — implementation checkpoint

While the R6 patch-reconciliation build is being runtime-tested separately, development has started on tool-specific recovery capability.

Research conclusion:
- do not use one scalar `recoveryPower`;
- separate surface regrade, surface finish and deep compaction relief;
- implement identity should come from GIANTS specialization semantics, not display/config names.

Implemented architecture:
- new `TillageRecoveryProfiles.lua`;
- CULTIVATOR preserves the R6 TARGET constants exactly;
- distinct SHALLOW_DISC, POWER_HARROW, SUBSOILER, PLOW and PLOW_PACKER profiles;
- Cultivator resolution uses `isSubsoiler`, `isPowerHarrow` and `useDeepMode`;
- Plow is first-class through `processPlowArea`;
- PlowPacker is resolved before generic Plow/Cultivator;
- profile parameters are captured when a causal work-area pass authorizes recovery and survive deferred retries/convergence;
- R6 causal ownership, patch verification, target-plane tolerance, loaded-contact safety and global closed-loop serialization are unchanged;
- `surfaceFinish01` and `deepCompactionRelief01` are semantic future-facing capabilities and do not yet create extra terrain operations.

New runtime line:
`TerrainRecoveryTools | profile=workAreas/intentPoints/scheduled/applied ...`

Research/design document:
`docs/research/tillage-recovery-capability-study.md`.

Important validation rule:
the R7 profile values beyond CULTIVATOR are initial evidence-informed gameplay mappings, not claimed measured physical coefficients. Validate class detection and qualitative ordering before fine tuning.


## R6 runtime gate — PASS (build 977cfaef, 2026-10-04)

User visual result: PASS. The bounded target-plane recovery still removes the causal ruts without reintroducing R4-style mounds or R1/H2 depressions.

Runtime evidence from `log(20261004-202419).txt`:
- correct build: `977cfaef51dbc80fe7e93a138e7bb77491a9f8e7`;
- TARGET isolated: 1,432 TARGET jobs/brushes, `raiseJobs=0`, `smoothJobs=0`;
- 922 exact-center no-ops (64.4%), down from R5's 2,818/4,120 (68.4%);
- 414 improved callbacks (28.9%), up from R5's 25.1%;
- 15 worsened callbacks (1.05%); residual reduction 12.1681 m vs worsening 0.1113 m;
- 324 stalled sequences (22.6% of TARGET applies), down proportionally from R5's 24.4%;
- 217 initial-positive stale-debt skips (15.2%), down from R5's 16.2%;
- patch reconciliation examined 6,702 causal cells and verified 768 as converged, recovering 4.3042 m of logical rut debt inside TARGET footprints;
- SpatialHistory retirement is active: 971 cells retired during the run; 971 history cells / 5.948 m of logical rut debt were reconciled overall;
- preflight probe reuse is complete: `preProbeReuse=1432` for `targetJobs=1432`;
- no target timeouts, no writer failed jobs, no rejected recovery brushes, queue returned to zero;
- performance remained healthy: vehicleUpdate avg 0.0343 ms / max 1.798 ms, recovery avg 0.4052 ms / max 0.830 ms, flushInclusive avg 0.4967 ms / max 1.249 ms, callbackNested avg 0.0558 ms / max 0.519 ms;
- versus R5, flush average dropped ~21% and flush max ~53%, recovery average ~8% and recovery max ~9%. Treat this as directional rather than a strict A/B benchmark because runtime activity differed.

Interpretation:
- R6 achieved its goal: reduce redundant work without changing the proven R5 physics;
- patch reconciliation is materially useful: more than one causal cell can be retired by a single physical TARGET footprint;
- history lifecycle no longer leaves every recovered cell resident forever, although active history can still remain near the 50k cap when new deformation is being created simultaneously;
- remaining no-op rate is still high enough that later throughput tuning can be useful, but it is now a gameplay/calibration issue rather than a structural correctness blocker.

Non-RE shutdown noise:
- the session ends with `delete(nil)` from `FS25_manualAttach/src/core/DetectionHandler.lua` via ManualAttach deleteMap. No RealismExtensions frame appears in that stack.

Decision: close the R6 consolidation/runtime gate as PASS and proceed with R7 tillage-specific recovery profiles. Do not reopen R6 architecture unless a later regression provides new evidence.


## R8 actor policy + territorial maintenance foundation

Trigger: R7 runtime showed that hired-worker navigation can generate persistent ruts outside the already-protected active tillage pass. The worker/root produced hundreds of accepted rut brushes per 5 s window while the recovery controller itself remained healthy.

Implemented:
- `TerrainActorPolicy.lua` classifies PLAYER / AI_FIELD / AI_GENERIC at the combination root;
- normal AI field work uses **exactly the same terrain physics as player driving**;
- persistent RE rut writes are suppressed only for explicit AI-navigation pathology:
  - GIANTS field-worker turn/corner-cut;
  - stationary AI wheelspin/stuck;
- wheel context, MR/Mud, loaded-contact tracking and visual tire tracks remain upstream and active;
- new `TerrainActors` telemetry exposes samples, accepted brushes/depth and suppressed-turn/spin counts;
- `TerrainMaintenancePolicy.lua` classifies territory fail-closed:
  - player farm → none;
  - other farm/human → none;
  - NPC field → neighbor;
  - public/non-buyable → municipal;
  - unowned buyable/unknown → none;
- passive neighbor/municipal terrain mutation is **not enabled yet**. Only classification exists.

Architecture rule:
- native GIANTS actor/farmland semantics belong in RE;
- if Courseplay/AutoDrive or another external AI system needs extra actor state, normalize it through RC/provider integration rather than hard-coding mod-specific behavior into terrain physics.

Validation rule:
- do not demand an exhaustive manual matrix. Use ordinary gameplay plus `TerrainActors` / existing recovery telemetry. Add directed tests only when runtime exposes a missing class or pathology.

Detailed design: `docs/research/terrain-ai-and-maintenance-policy-study.md`.


## R9 periodic neighbor/municipal terrain maintenance

The maintenance executor is now implemented as an **event-driven, amortized system**, not a per-frame world scanner.

Trigger model:
- subscribe to GIANTS `MessageType.PERIOD_CHANGED`;
- one period change ages only existing active SpatialHistory cells;
- fresh wheel interaction resets that cell's `maintenanceAgePeriods` to 0;
- age is persisted in the terrain sidecar so save/reload does not reset maintenance eligibility.

Why PERIOD_CHANGED:
- GIANTS itself uses PERIOD_CHANGED for persistent age progression (e.g. hand tools and persistent game systems);
- FieldManager's `FINISHED_GROWTH_PERIOD` was reviewed, but is intentionally not used as the primary maintenance trigger: it is tied to crop-growth update cadence and can run more often than the desired low-frequency land-maintenance abstraction;
- monthly/period maintenance gives stable bounded cost and matches the intended "neighbors/public service eventually maintain their land" gameplay layer.

Responsibility rules remain fail-closed:
- player-owned: no passive maintenance;
- another owned farm: no passive maintenance;
- NPC field: NEIGHBOR;
- public/non-buyable/no-farmland: MUNICIPAL;
- unowned buyable / unknown: none.

Eligibility:
- NEIGHBOR: causal RE rut debt aged at least 1 period;
- MUNICIPAL: causal RE rut debt aged at least 2 periods;
- municipal work additionally requires all sampled points in the patch to remain municipal and terrain paint to resolve to GRAVEL or DIRT;
- public MUD is deliberately not auto-maintained because without an explicit road mask it could be swamp/wetland rather than infrastructure;
- any ownership boundary crossing rejects the patch.

Performance design:
- no map scan;
- PERIOD_CHANGED scans only active SpatialHistory cells (bounded by the existing 50k history cap);
- classification is cached per farmland id during the monthly scan;
- eligible cells are spatially bucketed, selecting the oldest/deepest representative per bucket;
- queue is capped per period (256 NEIGHBOR + 128 MUNICIPAL patches);
- neighbor and municipal tasks are interleaved;
- one maintenance task at most is started per ordinary update and it yields whenever active recovery or TerrainWriter already owns work;
- loaded wheel contact defers a task rather than mutating terrain beneath a vehicle;
- TARGET uses the same current-local-plane safety model already proven by R5/R6 recovery;
- a task verifies and retires only physically converged SpatialHistory cells;
- unfinished debt survives into the next period.

Default gameplay semantics:
- neighbor radius 0.45 m, up to 3 TARGET pulses;
- municipal radius 0.30 m, up to 2 TARGET pulses;
- municipality intentionally acts more slowly and only on public dirt/gravel;
- the system never restores map-start height.

Expected memory/performance benefit:
- maintenance physically resolves and retires old RE debt outside player-owned land;
- therefore old NPC/public rut cells stop occupying the live SpatialHistory LRU and stop being persisted/reconsidered forever;
- normal per-frame cost is almost zero when the maintenance queue is empty;
- the only O(history) pass is PERIOD_CHANGED, not frame/update cadence.

New telemetry:
`TerrainMaintenance v1 | periods=... scanned=... eligible=neighbor/municipal buckets=... queued=... started=... target=... complete=... neighbor=... municipal=... stale=... blocked=... boundaryReject=... surfaceReject=... patch=examined/recovered depth=... pending=... inFlight=...`

This completes the originally planned neighbor/municipal responsibility loop. Runtime observation can now happen through normal gameplay; no exhaustive manual test matrix is required.


## Wheel/track support topology — coordinated RC/RE layer

Terrain v1 exposed a remaining contact-geometry gap:
- aggregate dual/triple width was treated as one solid strip;
- crawler footprints were rejected.

A paired contract upgrade is implemented on:
- RC: `feat/wheel-support-topology-v2`;
- RE: `feat/wheel-support-topology`.

RE now requires RC provider API / WheelContext v2.

Ownership:
- MR/Mud/Reifen own wheel force, traction, pressure, slip, sink and structural
  radius state;
- RC normalizes actual support topology;
- RE owns the missing persistent heightfield consequence;
- SoilCompaction remains untouched.

Round multi-support:
- total pressure-driven area is conserved;
- GIANTS WheelVisual offsets/widths are retained;
- each tyre writes its own lateral strip; gaps remain undeformed.

Crawler:
- no pneumatic pressure is assumed;
- MR `mrTrackFx` provides the effective support-length contract;
- average track area/pressure is computed once;
- long support is written through bounded longitudinal sub-patches whose
  exposure shares sum to one.

Do not add direct tyre-type rut multipliers. Upstream type effects should arrive
through normalized slip/sink/load state.

Known parked issue:
general solid/small-wheel vs pneumatic eligibility remains unresolved because
the current owner mods expose pressure/wear broadly and FS25 has no stable
semantic flag sufficient for a general classifier. Keep fail-closed; do not use
name/radius heuristics.

Detailed study: `docs/research/wheel-support-topology-study.md`.


## Wet-field playability calibration — 2026-10-04

Runtime trigger:
- build `ec49d653dd2bbc0da98634096cc82a62a4d698ec` showed ordinary field work becoming persistently destructive well before an explicit MUD scenario;
- final sample: wetness 0.89, longitudinal slip 0.266, instantaneous Mud sink 0.080 m, plastic transfer 0.76, persistent sink 0.061 m, modeled rut 0.146 m;
- session totals were dominated by FIELD / FIELD_SOFT / FIELD_FIRM, not MUD;
- AI_FIELD accepted 38,070 persistent brushes / 72.838 m cumulative applied depth, making unattended worker use excessively destructive.

Interpretation:
Mud owns transient mobility difficulty (grip, resistance, sink). RE should not automatically make most of that temporary sink a permanent heightfield scar. The old global plasticity band (start 0.45 wetness, full at 0.90, up to 0.90 transfer with slip) made ordinary wet fieldwork behave too much like saturated mud.

Branch: `tune/wet-field-playability`.

SurfaceResponse v3 introduces persistent-geometry severity bands while leaving upstream MR/Mud mobility unchanged:
- FIELD_FIRM: plastic start 0.68, full 0.98, base max transfer 0.28, slip max 0.45; caps 35/75 mm static/slip;
- FIELD: start 0.62, full 0.98, base max 0.38, slip max 0.58; caps 50/100 mm;
- FIELD_SOFT: start 0.56, full 0.98, base max 0.48, slip max 0.68; caps 65/130 mm;
- explicit MUD keeps the previous severe response.

Design intent:
- wet conditions may still be difficult to traverse because Mud/MR remain physical mobility owners;
- ordinary wet field passes should create modest persistent damage rather than repeatedly undoing tillage;
- freshly cultivated/ploughed soil remains more vulnerable;
- true MUD/saturated conditions remain the exceptional rescue/adventure scenario.

Approximate transfer at wetness 0.75 / slip 0.266:
- FIELD_FIRM ~4%;
- FIELD ~11%;
- FIELD_SOFT ~21%;
- MUD ~56%.

Approximate transfer at the reported wetness 0.89:
- FIELD_FIRM ~22%;
- FIELD ~33%;
- FIELD_SOFT ~43%;
- MUD ~76%.

Validation split:
1. If the new build remains hard to drive but no longer destroys repaired terrain every pass, RE calibration is working; any remaining excessive traction/sink difficulty belongs to Mud/MR tuning.
2. If persistent ruts are still too frequent/deep, tune SurfaceResponse bands further before touching recovery strength.
3. Do not make recovery stronger to compensate for overproduction of new rut debt.

### Performance observations from the same session

RE terrain internal timing remains modest on average; callbacks are nested in flush and must not be double-counted. However VisualTrackCapture accumulated >223k points and >114k cuts, so tracks need a dedicated perf/memory audit.

Current stack hot-path observations:
- RC MRDynamicPTO wraps Motorized and WheelsUtil hot paths and reported tens of thousands of calls/scopes;
- FarmKitCompatibility reported >54k suppressed wheel-dust calls and >143k plowing-suspension scopes: ownership is correct, but suppression-after-dispatch still has runtime cost;
- FarmKit implement dust remains intentionally enabled; source defaults/tool multipliers and multi-second fade tails can create substantially more particles than the UI's top-level multiplier suggests;
- the uploaded ModMixer report does not serialize the live Performance-tab ms/frame ranking, so the user's observed Reifen > DynamicPTO ranking must be verified with ModMixer hook probe before making an optimization/absorption decision.

Next performance pass should:
- run ModMixer hook probe / peak capture during the same representative fieldwork;
- profile Reifen hot hooks, Dynamic PTO + RC composition, FarmKit implement dust, RE VisualTrackCapture separately;
- optimize ownership at registration/dispatch level where possible instead of paying thousands of suppressed calls;
- keep gameplay calibration and performance refactors on separate branches.


## Runtime acceptance checkpoint — berms/mounds (2026-10-04)

User validation after the current recovery line: visible mounds/berms are no longer a blocking problem and the delivered terrain result is now acceptable.

This is a **behavioral non-regression requirement, not an implementation freeze**:
- recovery/writer/mass-transport internals may still be redesigned or optimized;
- a replacement is acceptable only if it preserves or improves the current visible/functional berm result;
- do not reopen berm/mound recovery as an active problem without new runtime evidence of regression.

Performance work is now being pursued separately in RealismCompatibility/stack profiling so terrain recovery is not destabilized merely to chase frame time.
