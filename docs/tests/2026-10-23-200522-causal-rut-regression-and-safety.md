# Runtime 2026-10-23 20:05:22 — causal tillage partial recovery, severe rut failure and safety patch

**Evidence:** exact player uploads `log(20261023-200522).txt` (~2,539 lines) and `ModMixer(20261023-200522).log`. Real test, current São Carlos savegame2; the owner reported shallow/new ruts appeared to repair but deep inherited ruts remained, and tractor eventually stuck between newly deepened ruts while attempting subsoiler repair. These observations are **acceptance FAIL** despite positive native recovery callbacks.

## Session/build

- FS25 1.25.0.0, map Estância São Carlos 1.4.0.0; savegame2; RE `64/merge@fa492d77973d953da5f132463ff43223834d4db1`, Actions **40004057554**; RC `main@546806b78cc0c5d0481361b814b6964d3d709f43` (previous build, no new icon).
- `TerrainMode | journalRequested=true causalRequested=true legacyTARGET=false`; native geometry journal becomes available at 16:55:50 with `unit=1m`. Sidecar **rejected** `GEOMETRY_JOURNAL_FORMAT_OR_UNIT_MISMATCH`. **30,189** legacy mechanical history cells load separately; these do **not** contain verified original native vertex heights.
- There are no observed TerraFrame/native writer submission failures from RE. External `FS25_manualAttach/src/core/DetectionHandler.lua:65` calls engine `delete(nil)` on exit. Eight duplicated WoodGrinder specializations from `FS25_CBI6800CT` on boot. Neither error is a demonstrated cause of this rut behavior.
- ModMixer June 1 scan-based conflict database is stale; live hook-chain observations are not evidence that a particular interface/contract mod caused rut failure.

## Runtime causal measurements

| At | journalJobs | lowered vertex events | writer no-effect | RE recovery candidates | native callbacks | improved | unchanged |
|---|---:|---:|---:|---:|---:|---:|---:|
| 16:56:51 | 72 | 61 | 26 | 0 | 0 | 0 | 0 |
| 16:57:51 | 586 | 223 | 368 | 11 | 11 | 9 | 2 |
| 17:00:51 | 950 | 272 | 564 | 138 | 138 | 112 | 26 |
| 17:03:51 | 1,276 | 298 | 644 | **358** | **358** | **256** | **102** |

`improved` here means **positive callback change at the target towards stored original**, not physically restored deep rut or per-unique-vertex completion. `lowered` counts main-grid vertex-change events, NOT distinct holes. `noEffect` counts whole jobs with no measured main heightmap movement.

**Telemetry defect corrected:** previous `TerrainHealth wheelAccepted=0` was **false negative**, not proof of no accepted rut writes: `TerrainDeformationEngine.diagCount` drops all counters when `diagnostics.verbose=false`, while journal writer callback counters are unconditional. The new code retains a low-cost whitelist of core acceptance/guard counters with verbose off.

**Missing proof in the log:** physical mean/max regained meters, number of fully restored vertices, which implement profile produced which native jobs, how many old points lacked baseline, whether the tractor's severe hole was made by RE's coarse/native path vs Mud's transitory sink/fine visual channels or earlier saves. There is no clear `saved native geometry journal ...` confirmation in the supplied period; `quit savegame` alone is insufficient to assert geometry sidecar persistence.

## Code findings and targeted follow-up (new branch commits)

1. Legacy deep rut remains irrecoverable automatically unless the journal has trusted pre-RE original; normal cultivation/subsoiler MUST NOT infer original from old `SpatialHistory`.
2. Native rut generation had no reliable *physical* ceiling independent of 0.20m logical history. Added `TerrainGeometryJournal:getLoweringBudget`: cap new RE native confirmed main-heightmap lowering to **0.10m** and refuse new lowering in an **existing >0.12m local concavity** (opposing 1m height samples cancel planar slope). Known externally edited vertex fails closed. This is a temporary release-safety envelope; **not** a fix or a measurement of the separate fine displacement channel, and it does not prevent Mud sink. No global terrain leveling or landscape edits.
3. The old causal candidate check required the **exact 1m native vertex centre** strictly inside the (potentially <1m) GIANTS physical work area. Subsoiler or narrow tillage strips could never touch a native centre. Modified to admit a vertex whose supporting main-grid footprint comes within **45cm of an actual GIANTS worked strip**; regressions ensure farther vertices remain excluded. This change is an explicitly bounded representation approximation, not permission to grade the entire field.
4. `SUBSOILER.surfaceRegrade01=0.35` vs `PLOW.surfaceRegrade01=0.90`: deep ripping is primarily compaction relief, not final visible seedbed leveling. The subsoiler test is an important recovery *coverage* indicator, not reason to make it an aggressive ground-planarizer.
5. Reorganized health log to preserve `wheelAccepted, wheelConfirmed, guardBlocked, cap, oldHollow, untrusted`, actual **sum/max native meters gained**, **physicallyClosed**, legacy missing baseline counts (these are repeated work-area visits, not unique world cells), and candidate tool origin `PLOW/SUBSOILER/CULTIVATOR/OTHER`. Research 5-second logs remain opt-in.
6. No changes to production RE main, RC, PTO, MR/Mud/Reifen. PR #64 remains draft, and the latest test has **not validated a release**. Do not claim the simulation test proves subsoiler correction in the real engine.

## Next in-game acceptance (ONLY on the newly built patch, small controllable area)

The current save is user-disposable, but deep legacy ruts won't auto-heal; avoid using them as a causal-recovery test. A short test on an undamaged, flat patch (or a *clone* of the pre-RE backup) should see: native `wheelAccepted>0`, `wheelConfirmed>0`, new rut <= safety envelope, `byTool` includes the worked implement, `gained>0` / `physicallyClosed>0` with visible decreasing trench on primary work. A separate old-damage remediation path would need explicit landscaping/opt-in legacy reset, not a silently guessed original.

If new tracks still become impassable or restoration insufficient despite positive measured `gained`, acceptance remains FAIL. Investigate fine/native deformation ownership and true physical recovery capacity rather than asking for dozens more passes.

**CI:** all Lua harnesses pass for these incremental changes; check the exact latest Actions run before authorizing a ZIP or publishing a build.
