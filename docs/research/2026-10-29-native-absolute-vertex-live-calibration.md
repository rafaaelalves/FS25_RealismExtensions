# 2026-10-29 — GIANTS live test: direct absolute-height setter is vertex-local, but quantized

## Provenance

User supplied `log(20261029-233058).txt` and `ModMixer(20261029-233058).log`; FS25 1.25.0.0, Estância São Carlos 1.4.0.0, RE code commit `877e673800351268278b2e10b78cd0380cef43da` from GitHub Actions `40970500215`. RC main stayed `546806b78cc0c5d0481361b814b6964d3d709f43`. Test at 2026-10-29 20:28–20:30 local.

The native queue/direct probes were installed and intact; no queued RE/GIANTS terrain deformation job was reported. The absolute setter bypasses `TerrainWriter` and `TerrainDeformation:apply`, so `WRITER_NEAR=0` is expected and must not be used as independent proof of no foreign terrain activity.

## One direct GIANTS setter — actual results

The user executed precisely the requested commands in order:

```
reTerrainTrial probe
reTerrainTrial status
reGeoMark
reGeoSnap beforeAbsolute
reTerrainTrial absoluteCheck
reTerrainTrial absolute
reTerrainTrial status
reGeoSnap afterAbsolute
```

- Mark position (on foot): x=344.049 z=388.354; snapped tested native height vertex **x=344 z=388**. MAIN heightmap unit=**1.000m**.
- `CHECK READY`: clean journal, 9 readable vertices. Before center **152.525299m**; requested **1.5mm** lowering, absolute target **152.523799m**.
- 20:30:03.749 `setTerrainHeightAtWorldPos` returned **nil** without throwing (normal void-like binding), immediate readback **center delta -0.003891m (3.891mm)**, **1 of 9** native main-grid vertices changed, no measured rise. Center after **~152.521408m**.
- 20:30:09.500 `absoluteUsed=true`, no pending trial or callbacks, quarantined by calibration for this session; no further RE writes.
- 20:30:14.673 delayed visual survey sampled using the same **main-height API**: coarse 1m-spaced grid changed 1/25 >=2mm (max -2.3mm), and denser INTERPOLATED 0.125m sample grid changed 48/289 >=2mm (max -3.7mm). Different amplitudes reflect **different sample coordinates relative to the snapped exact vertex**. They do not establish separate fine-mesh deformation and do not contradict -3.891mm at the exact native vertex.
- 20:30:34.082 `quit savegame` (no save action seen in the tail). Save/reload persistence, collision regeneration and MP replication remain UNTESTED.

The result is a breakthrough in **localization**: unlike the additive brush, a direct absolute setter changed only the intended main-grid vertex in the nine-point measured footprint. The result is **NOT 1.5mm accurate**: it moved one step of 3.891mm, 2.59x requested. Use a debt threshold >= a verified native step instead of pretending that substep physical excavation is possible.

## Resolution hypothesis now strongly corroborated, still map-specific

One main heightmap step `255/65535m = 0.00389105058366m` matches this `0.003891m` measured native delta. Earlier additive experiment yielded `~0.007782m` at a native vertex, matching TWO such steps. This is compatible with a conventional 16-bit heightmap with a **heightScale of 255m**; that heightScale is an external map attribute, not verified from these logs or a public API. Even if this specific loaded map uses it, DO NOT hardcode this quantum globally: different `heightScale` and terrain assets can change it.

A *quantization-aware permanent actuator* must:
1. Maintain continuous, bounded logical demand per 0.20m source, aggregate overlapping sources to a **maximum new vertex height demand**, not sum of depths.
2. Issue at most **one proven native quantum** per vertex per write, only when cumulative net demand >= that quantum, with local journal locks, 3x3 collateral readback, queue/MP/foreign actor guards and no no-op retry loops.
3. Reconcile the **same original cumulative target**, not re-add it every onUpdate frame or re-observation. Commit `committedM` only after physically measured one-step lowering. A target fall must require a separately proven recovery epoch.
4. Verify the setter's quantization, collision/ground contact, saving/reloading, lifetime ownership and tillage recovery before enabling automatic native writes.
5. Protect narrow/fine tire tread geometry and Mud/MR physics from the 1m coarse main-heightmap; this experiment is not proof that isolated 1m vertices make visually realistic ruts.

## Implemented after reviewing this test

- `TerrainQuantizedHeightBudget.requestTarget(key,cumulativeDepthM,remainingBudgetM)` is a new pure *cumulative* contract. It stores `demandTargetM` and `committedM`, does NOT add a repeated target, and releases a new one-step plan only when demand minus measured commits >= one step. This contract cannot be mixed with additive `request()` for the same vertex.
- `TerrainQuantizedHeightBudget.retireTarget(key,verifiedRecovery)` requires explicit externally verified native-recovery authority, no pending job, and never infers repair merely from a model target decreasing.
- `TerrainAbsoluteVertexCandidate:applyOne(...,"CUMULATIVE")` routes to that contract, still obeying 3x3 journal/one-step readback/quarantine guards.
- `TerrainAbsoluteHeightExperimentalBackend` now uses cumulative contract, but is still explicit opt-in single-shot research code and **not wired to live wheel contacts**.
- New mock coverage repeats a 10mm cumulative target **500 times in the budget test / 50 times in candidate test** and confirms exactly two 3.891mm steps, 2.218mm remaining unspent, no multiplication of rut damage.

The code-level remedy eliminates a potential repeat-frame over-dig bug. It cannot assert physical save/load safety; the automatic `SHADOW` actuator remains OFF. RC and RE main untouched; no production release or PR merge.

## Separate errors

The GIANTS shutdown stack `FS25_manualAttach/.../DetectionHandler.lua:65 delete(nil)` is unrelated to the terrain operation. A legacy `FS25_CBI6800CT` specialization duplicate and outdated `FS25_MeadowTrails` are also outside this isolated test. ModMixer high/hook findings remain independent hypotheses requiring their own audits; they are not evidence of terrain modification in this session.

## Next validation gate

**No repeated tillage cycle.** Later, when the verified-quantum/setter route is safe to expose, a *different dedicated disposable-save test* must check main collision and restart persistence (which requires deliberately saving a THROWAWAY copy, never the real farm). Neither success nor any error of this first test decides persistence. Do not request that test until its one-shot harness, readback preconditions and reproduction steps are ready.
