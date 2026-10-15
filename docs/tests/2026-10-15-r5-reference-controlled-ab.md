# 2026-10-15 — R5 reference A/B: regain a proven recovery behavior before expanding V3

**Status:** isolated test build. NO merge to main, NO proven gameplay recovery at the new code revision.

## Decision: stop combining independent unknowns
The Oct 4 R4 `RAISE` tests physically closed the rut but created 0.224–0.840 m jumps and mounds; TerraFarm's modern `Flatten/Slope` uses `setHeightTarget()` + `enableSetDeformationMode()`, with actuator amount 0.75 on slope. R5 `988f974` migrated to bounded `TARGET`; the player confirmed visible repair without destructive mounds, but complained that many passes were required. R6 improved debt reconciliation and scheduling while preserving R5 physics.

Oct 15 game log (`log(20261015-111537).txt`, RE `53/merge@fee104b9`) now shows an almost total V2 admission failure: 1,106 accepted vs 376,172 repeated rejected references, all `CURVED_OR_INCONSISTENT`. 864 native TARGETs were applied; 613 reported no measured center change; 217 moved toward/reached the target, 34 moved away. The hypothesis **V2 starvation is a major regression relative to demonstrated R5 behavior** deserves direct isolation before radically changing the reference model.

### TerraFarm and native API comparisons
- TerraFarm 1.6.5.0 archive `scripts/landscaping/LandscapingInputFlatten.lua`: `setAdditiveHeightChangeAmount(heightChangeAmount)`, `setHeightTarget`, `enableSetDeformationMode`; applies work-area brushes, not tiny pointwise isolated centers; slope operation defaults to `heightChangeAmount=0.75`.
- TerraFarm `LandscapingInputSmooth.lua` selects a distinct `enableSmoothingMode`; smooth is for finish, not a proof of crater filling.
- TerraFarm `LandscapingBase.lua` reads the heightmap unit; its `LandscapingUtils.addModifiedCircleArea` uses a square *area-bookkeeping fallback* for circles with radius <1.5 terrain units. This is NOT an actuator clamp nor proof that a 0.45 m circle cannot move native vertices.
- Native FS25 `getTerrainHeightmapUnitSize` supplies terrain vertex unit spacing; in the Oct 15 test, it was 1.000 m. At present we have only center-height samples, not full native vertex sampling. The proposed on-grid/off-grid radius experiment remains unproven and **must not be mixed into this A/B**.

### Build A/B contract
- Baseline/control: verified exact RE `53/merge@fee104b9` build with V2 enabled.
- Variant R5-REF: same code family `research/terrain-predeform-reference-v3-2026-10-15@fb3063b`, only `TerrainRecoveryReferenceV2=false` in `scripts/Config.lua`.
- Preserve `TARGET`, loaded-contact veto, center residual checks, causal RE rut-history authorization, brush size/strength/amount, plow vs shallow-disc semantics, global async serialization, active tillage suppression, terrain plastic-yield, PTO, and sidecar persistence.
- PR53 pre-deform snapshots stay observational; never assume a 0.2 m history-cell value identifies the untouched 1.0 m mesh vertex.
- This branch **does not** add cache, change `TARGET` brush radius, strengthen commands, switch to `RAISE`, or relax guards in production. No mass-transport mound generation.

### Short decisive field gate — clone, no prolonged failure
1. Clone one already-damaged but geometrically identifiable save, including `realismExtensionsTerrain.xml`; use a short lane with no active harvesting or unrelated rut writers. Do not overwrite the valuable save.
2. Record same before/after lane screenshot and, if possible, the same x/z geometry, with one or two identical `SHALLOW_DISC` passes on control and R5-REF. Save/run using distinct cloned slots.
3. Compare `TerrainReferenceV2 accepted/rejected`, `TerrainRecoveryTarget applied/noOp/improved/worsened/reached`, `TerrainTargetOutcome`, and observable ruts. R5 build intentionally emits no V2 evaluation counters; compare actual TARGET applications instead.
4. Failure gate: a new mound or off-lane degradation, >=5 cm unexpected upward point excursion, widespread lowering, or strong physical regression immediately rejects this build. The 5 cm threshold is a conservative test stop, not a promise of engine-level enforcement.
5. Success gate: more working TARGETs and *measured or convincingly visible* net reduction in a known rut with no material off-lane damage, while one/two passes improve versus V2. Merely more TARGET calls is not success.
6. If the target still does not move, isolate **actuator/mesh** next: controlled unchanged reference, radius 0.45 m vs >=1 m in a disposable patch, actual vertex before/after, one variable at a time.
7. Only if both estimators fail to establish a trustworthy original surface should V3 native-vertex, provenance and curvature-safe inference be considered as the main corrective path.

### Limits
The legacy R5 single annulus can be biased by parallel ruts and curved natural grades, so this is a **bounded experimental diagnosis, not a safe universal production fallback**. The TARGET target-plane safety prevents old R4 unbounded raises but does not guarantee an inaccurate plane cannot create a small mound. Keep V2 research and original ruts/terrain intact for comparison.

**Why this order:** get back a known working controller before increasing model complexity, make one falsifiable experiment, then address the next measured bottleneck rather than cycling models based only on aggregate counters.
