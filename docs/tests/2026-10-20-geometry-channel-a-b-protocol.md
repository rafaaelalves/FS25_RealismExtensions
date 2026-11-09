# R1 field recovery — minimal dual-channel falsification protocol

**Date:** 2026-10-20 (Brazil). **Issue:** [#59](https://github.com/rafaaelalves/FS25_RealismExtensions/issues/59). **Target:** existing RE branch `perf/terrain-r1-reference-rejection-backoff-2026-10-18@bfcf744c`, RC executable `main@546806b7` v0.2.0.9, FS25 1.25.0.0, Estância São Carlos. This branch is a **read-only geometry probe** and contains no recovery tuning.

## What is already known, versus NOT proven

1. The user's physical recovery acceptance failed. In October 20 logs, many native TARGET callbacks succeeded yet 75–89% of *measured centers* did not move and only 2–3% of *logical patch-cell examinations* reconciled. This did not produce perceptible field repair.
2. The game's `getTerrainHeightmapUnitSize` reports **1.0m** for the main heightmap. GDN explicitly defines this as the **main** terrain-heightmap unit; `getTerrainHeightAtWorldPos` samples terrain height. The GIANTS engine interview reports ground-deformation/physics detail of 0.125m but **does not expose a verified Lua sample/write contract for individual fine-displacement vertices**.
3. **`reGeoSnap` samples the SAME main height API at 1.0m and at 0.125m intervals**. The latter gives denser interpolated/returned values; it is **NOT a direct independent sample of the fine displacement channel**, regardless of output shape. Label this correctly in every report.
4. Native `Plow:processPlowArea` and `Cultivator:processCultivatorArea` update density-map field state and invoke `FSDensityMapUtil.eraseTireTrack`. This may be a track/field-state effect, not proven restoration of RE's heightmap or every fine-displacement component.

Official evidence:
- [Main terrain heightmap unit](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=28&function=812&version=engine)
- [Main terrain height lookup](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=28&function=811&version=engine)
- [GIANTS terrain-deformation engine interview](https://www.farming-simulator.com/newsArticle.php?news_id=569&lang=en)
- [FS25 Cultivator](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=652&version=engine)
- [FS25 Plow](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=379&version=engine) (if exact class link differs, use search for `Plow.processPlowArea` in GDN).

## Read-only instrument and direct commands

The experimental branch registers commands on **server-side map load**:
- `reGeoMark`: stand on one **specific** hole; mark its world coordinates (on foot). Alternative `reGeoMark 390.40 312.20`. **Do not re-mark after the first snapshot**: that resets previous state.
- `reGeoSnap before`: record 25 values spaced 1m in a 4×4m square and 289 samples every 0.125m in a 2×2m square, **both through the main height API**; log original `SpatialHistory.rutDepthM` and candidate `preDeformHeightM` at center, corner-residual metrics, absolute unit and world coords.
- `reGeoSnap after`: same exact world positions, log observed change in m, min/max and number of samples changed by at least 2mm. Preserve baseline inside this one map session. 2mm threshold is a **diagnostic noise cutoff**, not a target acceptance tolerance.
- Commands are intentionally **read-only** (no `TerrainDeformation`, no `FSDensityMapUtil` writes, no wheel shape changes, no save modification). Normal currently enabled RE terrain gameplay remains active while farming.
- Map unload unregisters commands/clears probe state; do not compare two different savegame loads using the in-memory previous snapshot.

### Short protocol — single cloned save

**No 30-minute farm session.** Use a **copy of the user's save**, same map and a short visibly rutted site. Keep one known hole inside the probe's 2×2m box.

**Control 0: stationary/no operation.** Mark+snap `before`, do not drive on the marked patch, snap `still`; expect 0 meaningful changes. If >=2mm changes occur without work, sampling or terrain state is not stationary — fix confounders before proceeding.

**Control 1: known base-height positive control (separate disposable patch or reset clone).** Perform one small **user-authorized TerraFarm leveling** operation that obviously changes the heightmap. Snap before and after. If the main API does not respond here, our sensor path is unreliable. This landscaping action may be destructive: NEVER use production save or the test rut as the TerraFarm control.

**Test A: new RE-authored rut.** On the reset cloned save, mark a previously smooth but deformable wheel lane; snap `before`. Drive with consistent tractor/harvester load until the fine surface visibly ruts and normal RE rut brushes are logged; stop moving away from the marked patch. Snap `rutted`, take same-camera screenshot and note whether stationary wheel/contact physically sits lower. Repeat after a save+reload only once in a separate baseline, not in an in-memory comparison. This classifies which observations accompany a known fresh RE-deformation command.

**Test B: existing damaged rut under field work (priority).** Reset cloned save to the pre-pass condition; mark the **known visible damaged hole**; snap `before`, take a fixed-camera screenshot. Use *one defined appropriate implement* (e.g., same SHALLOW_DISC as current test) across exactly that patch once with fixed direction/speed, no TerraFarm. Snap `pass1` once the implement clears, take screenshot; optionally one more `pass2` at the same depth/angle if first is inconclusive. Capture corresponding `TerrainEligibility`, `TerrainReferenceV2`, `TerrainRecoveryTarget`, `REGeoProbe` lines. Stop; no prolonged blind repetition.

**Control 2: native versus RE recovery (only if Test B ambiguous).** On two identical copies of the same pre-pass save, compare the same plow pass using A) RE deformation enabled but `TerrainRecovery=false` in one *separate, explicitly marked* diagnostic build, versus B) RE recovery on in the other, preserving all other mods/settings. These must be separate fresh starts, not a hot toggle with deferred jobs in flight. Same camera and world coordinate, difference of difference:
`(after-before)_REon - (after-before)_REoff`.

If physical 0.125m geometry has no documented/readable Lua sampling API, triangulate **main heights + controlled photographic surface shape + controlled vehicle contact**. Contact point values are physics proxies with suspension/load variability, never claim they directly reveal native 0.125m displacement data. If this evidence cannot discriminate the channels, state precisely that the distinction remains unproven and require a verified engine debugger/API, rather than fabricate one.

## Explicit decision table

| Observed after a positive control | Next engineering intervention |
| --- | --- |
| Known visual rut increases while main API hardly changes | Seek actual FS25 fine ground-deformation/tire-track owner; don't amplify 1m TARGET blindly |
| Main API changes but visible hole/physics don't | Suspect fine surface channel mismatch or deformation strength/area ineffective; inspect separate geometry and source |
| Main API and visible/physical rut both respond to new RE writes, but tillage TARGET seldom changes patch | Investigate radius/heightmap lattice coverage, surface reference and native callback; use tiny **cloned** patch actuator A/B |
| Main grid patch changes only under RE recovery and hole becomes shallower with same visual/contact vantage | Proceed with conservative tool-specific calibration and native-vertex provenance; positive causal evidence |
| No main/API movement even for obvious TerraFarm terrain edit | Sensor/coordinate/API probe inadequate; fix measurements before physics |
| Visible mark disappears with `eraseTireTrack`, but geometric depression/vehicle contact remains | Visual track removal is not actual structural repair; integrate correct structural channel |

**Acceptance (both channels if measurable):** on matched identical patch, physical surface hole visibly decreases under real agricultural operations and any measured depression drops beyond sensor noise; no mound, no removal of natural slope or TerraFarm cuts; verify save/reload once measured effect appears. Gameplay result takes priority over callback counts. Do not merge into main until verified.

### Known remaining research
- No publicly confirmed Lua binding to query individual fine 0.125m ground-displacement values.
- Main heightmap's 1m unit size does **not** imply a grid with origin at world integer coordinates; probe's 1m samples are world-position samples, not authenticated vertex addresses.
- Need test to decide whether recovery's 0.30–0.48m TARGET brushes miss base vertices or whether visible ground deform is largely separate.
