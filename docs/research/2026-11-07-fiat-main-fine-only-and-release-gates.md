# 07-Nov-2026 Fiat in Estância São Carlos — measured release blockers (FS25 1.25.1)

Sources provided by tester: `log(20261108-012138).txt` (5044 lines, includes two map loads) and `ModMixer(20261108-012138).log` (142 lines); screenshots of Fiat 180-90 DT and ModMixer Performance. The game process was FS25 `1.25.1.0` engine runtime `10.0.0 (50093)`.

## Observations, *not* proof of native digging

- Actual RE zip loaded: `branch=64/merge commit=93339e2b172c83243a38062a030f95539fe56420 run=41571884867` (Nov 3). **Older than** the experimental branch's strict budget, interior-bin setter and lattice observer development (Nov 3 after the cited CI). These fixes were not tested during this live session.
- RC zip: `branch=51/merge commit=b85bceff72462f2d58a516607694caac299703b7` (Nov 2). The game and most of its stack did update separately.
- `TerrainHealth` on the second load, six telemetry points: `wheelAccepted=0, wheelConfirmed=0, journalJobs=0, lowered=0, nativeActualMaxSum=0, nativeRequestedSum=0, nativeAmplified=0, queued=0`, native permanent actuator has no executed job. `TerrainAbsoluteShadow mode=NO_WRITE quantum=UNVERIFIED`. A visual tire clipping impression **cannot** be attributed to a fresh physical lowering from the RE permanent writer during this session.
- `TerrainAbsoluteShadow` at 22:20:53: `sources=3 vertices=1 samples=23 targetIncreases=5 duplicates=18 sourceGrowthSumM=0.019836 vertexDemandSumM=0.006708 multiSourceVertices=1 mainFootprintSamples=5 mainFineOnly=5 mainResearchCandidates=0 mainGeometryUnknown=0 maxMainCoverage=0.066`. The 19.836 mm is aggregate mechanical source growth, **not a proposed single 19.836 mm terrain vertex edit**; the coarse vertex's *model demand* is 6.708 mm, still UNWRITTEN. All five evaluated contact patches were narrower than justified for the 1m MAIN support.
- Native wheel observation passive samples=1369 distinct=8, `scaleMin=scaleMax=1`, `changes=0`; this is *not* sampling wheel physical height changes directly. Main native unit `unit=1`. No session `reTerrainTrial absolute`, `reGeoMark`, `lattice`, `contact` on this zip.
- The savegame restored 937 native journal cells, 0 rejected; this is a restoration of RE bookkeeping, **not** proof 937 physically owned or verified permanent grooves.
- The screenshot's near-tire soil/mesh overlap cannot distinguish suspension, normal tire sink, visual wheel-rut/texture overlays, another writer, saved legacy ground or geometry collision. Previous controlled comparisons also saw clipping with RE disabled. Do not label cause from screenshot alone.

## Stack compatibility changed independently of RE

- RC detects `MudSystemPhysics=1.4.0.0`, `MR=0.26.10.08`, `RMS=0.13.0.1`, `TireWear=1.2.2.70`, `RHarvest=1.6.4.1`.
- New Mud 1.4 is **UNSUPPORTED** by RC MRMud, MRMudDraft, MudRMS, MudSoil; MRRMS and RMSPTO also unsupported with RMS 0.13.0.1. `MR+Tire`, `MR+Soil`, `MR+RE PTO` are ACTIVE. A runtime UNSUPPORTED status means **not audited**, not necessarily broken; never bump the RC allowlist based on the version alone.
- Mud 1.4 published changes include terrain depressions/puddles in local-moisture mode, new settings path, hydration processing and performance implications. Tester also uses `FS25_RutFlow=1.2.5.2`, which renders water in tire tracks. The mod's own `[LocalPuddles]` telemetry showed `surfaces=0` twice in this session. They may overlap in visual responsibilities under wet weather, but no actual duplicated puddle surface is evidenced yet; examine actual mod sources before writing an RC bridge or claiming one must be removed.
- User's ModMixer Performance screenshot: frame ~15.0 ms (~67fps), measurable listener script load ~1.2ms/f (~7% of nominal 16.7ms 60fps frame budget), only 28/212 mods measurable. Top rows Reifenverschleiss 0.40ms/f, adjustTramLines 0.19ms/f, Mud 0.18ms/f, RMS 0.14ms/f. `PARK` is the control action, **not evidence the mods were already stopped**. It cannot measure VRAM/render/game engine GPU costs or all mods; this snapshot does not prove that physics overlaps are harmless nor a performance blocker. ModMixer boot confirmed healthy.
- Unrelated `FS25_CBI6800CT` duplicated specialization errors continue; do not attribute to terrain system.

## Reproduction in mock CI (not another request to tester)

Commit `5ecb6e1b` extends `tests/terrain_absolute_height_planner_harness.lua` with a regression that reproduces the log's 3 sources -> 1 vertex, five source increases totaling 19.836mm, only 6.708mm shared vertex model demand, and 6.6% coarse-cell support. Even with a *hypothetically verified* 255/65535m quantum, it confirms NO MAIN write authorization; repeating a source target 100 times cannot increase demand. Pure harness cannot certify actual FS25 physics.

## Real release gates and decision

The module is **not yet shippable as a permanent wheel-rut writer**; passing read-only tests and synthetic setter tests is not gameplay-level validation. Do not relabel SHADOW as a functional physical rut release. We should split the implementation:

1. **Thin tire tracks (primary path):** research a separate verified mechanism for the finer native wheel deformation channel or persistence/replay of *already generated native* ruts, without modifying MAIN at 1m for every ~0.2m track. GIANTS/native behavior and save semantics must be established before integration. Study alternatives such as `Soil Deformation Save` by RMark (published 26 Oct 2026), which describes recording native tracks and rebuilding after load; public description also notes coarser map restoration and MP-client limitations. This is a research lead, **not** evidence its method is compatible with RE or that its code should be copied.
2. **Broad true earthworks (optional MAIN path):** continue the bounded quantized absolute writer, but only for a contact/footprint that meets the MAIN coverage geometry gate. Map-specific vertical height quantum and a correct one-step setter response in FS25 1.25.1 must be verified without amplifying the authorized budget.
3. **Ownership and save semantics:** verify actual modified geometry in a confirmed disposable save after save/reload, with no duplicate dig on new session or change of map. Revoke ownership on any unexpected foreign edit; do not repair foreign deformations.
4. **Physical restitution:** tillage/mulching/maintenance must target the exact proven owned rut geometry, not virtual history or inferred offsets. No release of autonomous municipality/neighbors without backed geometry and successful restoration transaction.
5. **Compatibility and safety:** audit Mud 1.4 source, RMS 0.13.0.1 hooks, RutFlow overlap and FS25 1.25.1 engine behavior before declaring RC bridges supported. Keep multiplayer and third-party geometry edits fail-closed unless independently validated.
6. **Performance:** bounded per-frame work, sample budgets and save data caps. Avoid duplicate flooding visuals and active terrain writer hot loops; do not optimize from a single ModMixer screenshot alone.

Potential **early public preview** could be explicitly labeled `soil realism / instrumentation (nonwriting)` but must not claim to be the promised persistent-ruts terrain module. Avoid creating a cosmetic 'release' merely to mark the roadmap done.

No additional plow–sow–harvest loop is justified by these logs; only the eventual **one isolated copied-save native test** after code/source readiness can resolve the setter and persistence unknowns.

PR #64 stays draft, RE main and RC main untouched; no new downloadable build from docs/harness-only edits.
