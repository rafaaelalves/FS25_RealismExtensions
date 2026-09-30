# Current development handoff

Updated: 2026-09-30

This file is the first place to read when continuing RealismExtensions in a new chat/session.

## Current state

- TerrainDeformation v6 is integrated into `main` via PR #24.
- The v6 runtime test validated the current wheel-based baseline, but **TerrainDeformation is not complete** against the agreed project scope.
- Production defaults remain safe: `TerrainDeformation=false`, verbose diagnostics off.
- PR #22 and historical PR #23 are superseded by the canonical implementation now in `main`.

## What the v6 test actually proved

- FIELD_SOFT, FIELD and FIELD_FIRM produced geometry.
- DIRT_COMPACTED and HARD were blocked under ordinary conditions.
- DIRT_WET required wetness/slip.
- 37,986 brushes accepted, 36,798 submitted, 5,056 native jobs, 0 failed jobs.
- GIANTS callbacks reported 244.519 m3 displaced volume.
- stationary wheelspin remained active.
- 12,483 terrain-history cells restored after reload without geometry-mismatch rejection.
- RC state reuse worked in the captured session.

This proves the basic wheel/rut writer pipeline. It does **not** close the full TerrainDeformation roadmap.

## Blocking scope still open before TerrainDeformation can be called complete

1. **Low-speed / sampling invariance**
   - Current deformation history advances per 250 ms sample.
   - At low travel speed, the same 0.20 m history cell can be processed repeatedly, creating an artificial low-speed excavation bias.
   - Redesign accumulation so ordinary rolling response is distance/contact-work based, while stationary wheelspin remains driven by true relative wheel/soil displacement.
   - Cross-check against FarmKit's audited speed-aware terrain response and Mud's terramechanics split between compaction, bulldozing and slip excavation.

2. **Dual / twin tire validation**
   - RC exposes MR total support width where available, but RE has no dedicated runtime proof that duals reduce effective rutting appropriately.
   - Add diagnostics/tests for support width, per-wheel load, tire pressure, contact area and resulting ground pressure on single vs dual configurations.
   - Do not assume that wider support alone is sufficient: pressure-driven footprint behavior and upstream pressure/load ownership must be verified.

3. **Crawler / track support**
   - `FootprintModel` intentionally fails closed for `isCrawler=true`.
   - Implement the previously planned grouped `TrackSupportGroup` model rather than pretending a track is one very wide tire.
   - Use actual crawler belt width/support length plus roller/bogie/load distribution where available.
   - Existing SoilCompaction source already demonstrates useful GIANTS crawler discovery via `spec_crawlers`, `crawler.trackWidth` and linked physics wheels.

4. **True AI Tracks absorption parity**
   - The user was explicitly asked to test RE with True AI Tracks disabled so RE could be isolated.
   - True AI Tracks exact source has two separable responsibilities:
     - enabling native AI/implement tire-track permission;
     - forcing AI/attached-implement WheelPhysics displacement.
   - Validate RE physical terrain deformation for player, GIANTS AI, Courseplay and wheeled implements with True AI Tracks disabled.
   - Decide separately whether its native visual tire-track permission must be reproduced or retained as a complementary feature.
   - Do not retire True AI Tracks until parity is demonstrated.

5. **External-source crosswalk**
   - RE exists to recover disabled FarmKit capabilities and selectively absorb/improve audited mods with cleaner ownership and lower duplicate work.
   - Before declaring any capability complete, explicitly cross-reference the implementation against the retained exact-source audits / source packages.
   - Relevant current terrain references include FarmKit, True AI Tracks, MudSystemPhysics, SoilCompaction, Reifenverschleiss and RC/MR normalized state.
   - Audits are design inputs, not historical notes.

## Current implementation concern: low-speed digging

The current `TerrainResponseModel` combines load/wetness/slip into capacity, but `TerrainDeformationEngine` calls that response on a fixed 250 ms cadence and commits rut progress per sample. At low speed, multiple samples can land in the same spatial-history cell; each one advances rut depth. This can make slow travel dig more per metre even when slip does not justify it.

That behavior is not accepted as final. Low gear itself should not be a magic anti-rut modifier, but controlled low-speed driving with low slip must not be punished simply because it spends more update samples over the same ground.

## Ownership remains

- MR: drivetrain, wheel dynamics, base traction/slip.
- MudSystemPhysics: physical wetness, sink/resistance/stuck behavior, tire pressure/load and ground/freeze state.
- RC: composition/arbitration and normalized authoritative state.
- RE TerrainDeformation: geometric consequence only.

RE should reuse owner outputs rather than duplicate their solvers. Where an audited specialist already computes a useful authoritative intermediate, prefer exposing/reusing it through RC over deriving a parallel approximation.

## Completion gate

TerrainDeformation is complete only when:
- wheel response is not spuriously dependent on update cadence/low travel speed;
- dual/twin behavior is validated;
- crawler/track support is implemented;
- player + GIANTS AI + Courseplay + wheeled implement behavior is validated without True AI Tracks;
- the external-source capability crosswalk has no unreviewed terrain-relevant gaps;
- CI/runtime stability and persistence remain healthy after those changes.

Until then, treat the current main implementation as a validated **baseline**, not a finished module.
