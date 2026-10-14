# R1 corrective prototype: history-screened two-radius reference (13 Oct 2026)

## Purpose and context

User reports harvester ruts persist after the first shallow-disk pass and repeated passes plateau, making subsequent sowing extremely difficult. The gameplay acceptance requirement is not to erase damage regardless of weather; it is to provide mechanically plausible recovery when the soil and tool permit it. A separate more recent session with wet-to-saturated field under **hail** was productive despite a small tractor pulling a very large planter; this is not evidence to weaken bearing/traction. Hail and liquid rain may have different water/ice infiltration and temperature consequences, deferred to independent weather research.

Previous R1 logs: around 70% native TARGETs made no measurable central height change, and recovery uses a plane fitted to 16 points on a **single annulus**, which can include the adjacent harvester ruts. PR #42's pure estimator harness independently established the contamination; PR #43 added fixed-height and wheel-contact diagnostics. Neither was a corrective physics patch.

## Branch/review stack

Branch `fix/terrain-recovery-reference-v2-2026-10-13` created from PR #43's diagnostics branch `diag/terrain-target-outcome-2026-10-12`, not main. Intentionally leave PRs #40 (spatial-performance), #42 (research) and #43 (diagnostics) separate. New changes are only within R1's recovery measurement / callback classification, not the ground deformation response, wheel model, PTO or RC.

## Changes made

1. **RecoveryReferenceV2.lua** (pure/reference geometry):
   - Use **two rings**, inner at the selected tool profile's original probe radius (for SHALLOW_DISC 1.20m), outer at 1.70x radius (2.04m).
   - Query RE `SpatialHistory:getRecoveryCellsCircle` within 0.23m of each ring point; mask only cells whose model rut debt >= 0.008m. A flagged candidate is not accepted as proof of pre-rut baseline. Masking is conservative and may omit otherwise safe points.
   - Fit a reference plane only from clean ring samples; require >=7 clean points total and >=5 separately in each ring, multi-directional coverage, a stable robust fit and no more than 0.035m difference in the intercepts fitted to clean inner and outer rings. A naturally curved surface that produces conflicting intercepts is **not treated as a flat rut**.
   - No reference? No machine height TARGET for that point. No smoothing or raise fallback. Reject reasons `NO_CLEAN_REFERENCE`, `INSUFFICIENT_CROSS_RADIUS`, `UNBALANCED_REFERENCE`, `CURVED_OR_INCONSISTENT`, etc. counted for future decisions.
2. **TerrainWriter.lua**: sample the second annulus only in causal R1 recovery calls when the feature flag is true; normal rut writes and general wheel contact are unchanged. Recovery TARGET callback resamples with the same history-screened reference.
3. **TerrainRecovery.lua**: pass history to the writer; use new reference only when available and valid. For V2 callbacks, measure actual central height against the **fixed pre-command TARGET**, not a re-fitted post-callback reference; this avoids declaring a physical improvement a regression merely because outer terrain reference changed. Existing TARGET strength, timing, pulse caps and history reconciliation are unchanged.
4. **Config.lua**: new independently switchable `modules.TerrainRecoveryReferenceV2=true` for experimental A/B. Toggle false to fall back to precisely the legacy annular algorithm and callback decision on a backup save.
5. **Core.lua**: periodic `TerrainReferenceV2 accepted/rejected, max drift` and aggregated rejection reasons. No per-frame spam.
6. **modDesc.xml**: load new module before writer/recovery.

## Verified offline (do not call this a field pass)

- `recovery_reference_v2_harness.lua`: sloped surface no rut => 0, isolated 12cm rut => 12cm, two parallel 12cm ruts => ~11.91cm, reject naturally curved surface and reference with zero clean points.
- `recovery_reference_writer_integration_harness.lua`: actual Writer height samples on same two-rut scenario: old ~6.70cm, new ~11.91cm; curvature rejection; validates the call path and flag.
- `terrain_recovery_harness.lua`: mock callback with post-reference drift; physical move toward original TARGET must count as improvement rather than false worse; existing tillage/no-op/loaded wheel/capability tests preserved.
- All tests are **simulated heightmaps**, not a confirmation that FS25 native TARGET actually raises terrain. Previous 70% center no-ops remain an independent actuator concern.

## Tradeoffs, limitations and next decision

- This change can **improve the target reference** for long parallel ruts where enough undamaged surrounding heightmap exists. It is not designed to automatically grade an entire field containing no reliable baseline. In that case the safe result is rejection, which may temporarily leave visible ruts.
- Curvature check can refuse benign uneven fields. That is safer than reconstructing into unexpected mounds; field testing decides whether the 3.5cm guard is overly conservative, but it should not be widened just to raise acceptance counters.
- Additional heightmap samples (~33 vs old 17) and spatial history queries occur only when actual R1 recovery is scheduled; the engine's FPS effect is unverified. CI runtime is not gameplay profiling. Monitor `TerrainPerf recovery` and CPU budget on a duplicate save.
- RE-owned rut debt is an approximation of deformation generated. Masking damaged points does not provide the *true untouched geometry* when a large zone has been affected, or soil material has been redistributed by TerraFarm/user.
- **No change** to pressure/wetness calibration, hail interpretation, static loading behavior, slip/Mud transfer or long-term terrain consolidation. Do not infer that the earlier reported tractor immobilization was a bug solely in RE.

## In-game acceptance gate

1. Duplicate the save including `realismExtensionsTerrain.xml`, preserve both the recent deformed save and the pristine predecessor. Do not replace the user's main farming save.
2. Compare baseline RE `3e3554a` vs corrective build on **identical** copies, same affected harvester track, same shallow-disk machine; record *actual* before/after physical heights or screenshots and visual pass 1/2/3, plus target outcome counters. Note humidity map and tool profile.
3. A valid improvement must leave the lane closer to workable seedbed without introducing mounds, deleting nearby natural terrain or misleadingly clearing logical debt. The native 70% zero movement may still cap recovery; do not label V2 complete if it persists.
4. As second phase test a known undamaged sloping/curved segment: unchanged unless documented RE rut history justifies a target.
5. Finally, separately test sowing over freshly cultivated area and under genuinely wet hail conditions. Hard wet soils may remain temporarily unworkable; no guarantee any 8cm disk can fill an 18cm persistent rut.
6. No merge to main until practical A/B validation; if R1 still plateaus, investigate alternative native TARGET geometry and mechanical tool capability *as a separate corrective PR*, instead of blindly escalating amount or enabling additive RAISE (previously caused artificial mounds).

**Bottom line:** this is the first conservative **behavior-changing R1 prototype**, not a complete restoration solution and not a reason to recalibrate Mud based on one extreme-weather session.
