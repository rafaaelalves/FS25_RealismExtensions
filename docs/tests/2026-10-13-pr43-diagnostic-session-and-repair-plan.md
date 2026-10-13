# 2026-10-13: PR #43 diagnostic session — what changed, what did not, and the repair proposal

## Build provenance
- **Old playable experimental zip**: RE `3e3554a43d1c3c6b3305d609a799d8ffb48a7ca4`. This has the experimental plastic yield, persistent rut writer and R1/R7 recovery.
- **Observed diagnostic zip**: RE **`43/merge@878e2be8e64c7ecaf89af0c580f8bd6310bca922`**, GitHub Actions `38239804963`, loaded 2026-10-12 22:54:57 local. This is PR #43 merge-ref testing artifact, NOT a merged branch/main. RC still `main@ad7461fb7777691f6f64e2327753417c95b6177b`.
- PR #43 adds **only** `RecoveryTargetOutcome.lua`, bounded trace counters for up to 12 TARGET samples and 18 rut samples, logging in Core, config flags, module loading and tests. No formula for `TerrainResponseModel`, no `SHALLOW_DISC` capability changes, no TerrainWriter actuation change, no R1 controller behavior changes, no physics fix.
- Separate PR #42 characterizes defective surface reference using a *pure* 16-ring-sample estimator harness. Separate PR #40 is spatial performance broadphase. Neither belongs to the installed PR #43 diagnostic zip.

## New session, primary evidence
- Uploads `log(20261013-024326).txt` (11,397 lines), `ModMixer(20261013-024326).log` (142 lines).
- RE restored **12,503** persisted history cells, then successfully saved **22,329** cells at 23:40:55 and **23,052** at 23:42:41. Game saved successfully at 23:40:58 and 23:42:45. These are persistent entries, not an exact count of distinct excavated holes.
- Every single one of ~547 periodic windows reported `TerrainRecovery calls=0, worked=0, TARGET applied=0`, so no `TerrainTargetOutcome` or `TerrainTargetSample` was emitted. This **does not** demonstrate a broken diagnostic R1 callback: the original R1 hook runs on cultivator/plow work-area, and the session did not emit those callback events.
- New writer debug did emit **nine** `TerrainRutSample` records, 3 Avatar, 3 Fiat, 3 S780. At 22:59:58 Avatar: x=240.98 z=299.98, wet=0.799, slip=0.000, Mud sink=0.313m, transfer=0.653, plasticYield=0.782, load=28,809N, pressure=250,000Pa, oldHistory=0.002m, `newModel=0.150m`, `acceptedDelta=0.0024m`. This sample proves 15cm model target can be reached without longitudinal slip because transient Mud sink is used as a vertical plastic input. It does **not** mean the native heightmap moved 15cm in that single callback, since `geometryProbe=0` in general rut-writer telemetry.
- End: `brushesAccepted=20,070`; owners `MR_Avatar_12_25_SD=12,554`, `180-90_DT=7,113`, `S780=403`. Roots `180-90_DT=19,667`. Actors `AI_FIELD=12,736`, `PLAYER=7,334`. The source of many accepted rut writes is Avatar, not exclusively S780, and mostly field traffic with workers, but the exact cause of vehicle immobilization and planting success is NOT inferable from this aggregate.
- End surface `FIELD=13,950`, `FIELD_FIRM=3,296`, `FIELD_SOFT=2,777`, `MUD=13`, `DIRT_WET=34`; wetness is local context, no uniform assumption.
- End `TerrainPlasticYield supported=206,469 yielded=21,309`. `instantSink` observed max=.360m; `maxPersistent=.180m` is a historical max, not actual verified change in heightmap.
- End `submittedJobs=5,587`, `failedJobs=0`; job-success alone does not prove terrain geometry correctness; historical sidecar cells and accepted brush requests are not physical depth probes.
- New modulation of instrumentation is proven active: no TARGET lines because no recovery work; first three contact examples per writer may miss late extreme/saturated conditions. No collision explanation solely in ModMixer conflict scan.

## Precise problem split and candidate solutions (NOT yet implemented)

### P0A. Repair does not converge after first tillage pass
Observed previously: `SHALLOW_DISC` sequence improves once, repeated passes leave continuous ruts and target actuator no-op rate near 70%. Current native TARGET uses center + a 16-point annulus to fit a plane; tests in PR #42 show parallel/wide ruts contaminate ring and natural curvature gives false positives.
**Candidate architecture:**
1. Construct a **stable, explicitly causal reference** for a damaged swath using geolocated rut-history masking and multi-radius reference candidates. Validate natural slopes/curvature, adjacent parallel tracks and berms. Avoid assuming one 1.2m annulus is untouched soil.
2. Controller measures *fixed target pre/post* with actual heightmap samples and distinguishes TARGET not moved vs target reference drift vs actual progress, using PR #43 outcomes. Do not blindly increase TARGET intensity or reenable additive RAISE: older R4 generated giant artificial mounds.
3. A surface finish pass can improve shallow local roughness, but capacity for a specific cultivator must remain grounded; severe deep rut may need an appropriate tool or mechanical grading. Only retire history debt after confirmed physical change. Do not guarantee all 18cm excavations vanish with one 8cm shallow disc pass.
4. Add offline regression: repeated passes on 12–18cm long parallel ruts, naturally curved sloped field, already mechanically worked field, interactions of same-writer histories; image-probe acceptance in game on a duplicate save. Define success by measured physical profile and restored seedbed workability, not rate of accepted brushes.

### P0B. Newly generated sink can overwhelm the field
Observed currently: Avatar can be assigned a 15cm rut target at 0 slip, with Mud instantSink=.313m, soil wetness=.799. A wet soil may sink under static load, so **zero slip is NOT justification to suppress ruts**.
**Candidate architecture:**
1. Audit source of RC `sinkDepthM` (effective wheel-radius reduction) against existing native heightmap depression under same wheel coordinates; test for double representation/feedback. Correlate snapshots and geolocation.
2. Replace unconditional reliance on transient sink magnitude as direct lower bound of permanent rut with a pressure/bearing/soil-state/plastic work-informed incremental model and an independent geometric limit that cannot be bypassed by sink alone. Preserve static loading plastification and severe-wet losses when physically warranted, distinguish stiffness from plasticity.
3. Check oversampling/AI contact distribution, coalescing, clipping and soil-condition field ownership with Mud/MR/SoilCompaction. Avoid across-the-board seeder immunity.
4. Verify first dry and damp pass realistic and field traffic under saturation causes credible degradation rather than unbounded re-excavation.

### P1. Safe gameplay / regression protocol
- Freeze original user save/sidecar and keep a clean older backup; disabling RE TerrainDeformation *stops future writes only* and cannot retroactively restore old heightfield. A separate opt-in restoration tool, if ever implemented, needs baseline geometry or independently validated controlled regrading, not deleting the history XML alone.
- Treat field **harvest→cultivate→seed** as a release-blocking vertical test: same strip, same implement, 2–3 repeated passes, defined weather, before/after physical profile, no artificial mounds, realistic inability under extreme saturation but playable recovery under ordinary conditions.
- **Next technical gate**: gather one R1 session in PR #43 diagnostic build in a copied save (without sacrificing main) *only if a test can specifically activate R1*. Current session validates rut contact instrumentation but cannot adjudicate native TARGET no-ops. No need for more broad, uncontrolled log loops to justify candidate algorithm implementation.
- Do not call PR #43 an R1 fix, and do not tell user another build fixed ruts. Any next build should have explicitly listed behavioral changes and controlled A/B comparison with the old zip.

## Status
Engineering diagnosis and acceptance targets documented. No corrective physics patch on PR #43. No merge into main. User clarity: **the change so far is observability, not behavior**.
