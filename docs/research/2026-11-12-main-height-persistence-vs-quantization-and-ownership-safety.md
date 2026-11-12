# 12-Nov-2026 — precision and save/reload are distinct; safeguard physically owned terrain

## What the real data means

The user worried that save/reload changed the elevation after a one-step height test. It did not: **the formatting differed**.

* Before absolute q-step: `152.50973510742188 m`.
* Immediately afterward: `152.50584411621094 m`.
* After game save, exit and reload, independently read with `reGeoVertex 348 387`: `152.505844116 m` (nine decimals). All displayed decimals match the immediate postwrite value. This validates physical MAIN height persistence for exactly one vertex and this map. No new physical recovery on that point was observed.
* Requested q = `255/65535 m = 0.0038910505836576 m`, observed lowering = `0.0038909912109375 m`; difference = `0.0000000593727201 m`, ~59 nanometers, caused plausibly by finite representation/height quantization. This is a WRITE-VS-REQUEST discrepancy of ~0.000059 millimeters, **NOT a SAVE/RELOAD discrepancy**.
* A requested 1.5 mm is below the single representable MAIN height quantum observed in Estância São Carlos; it cannot promise an exactly 1.5mm lowered MAIN vertex. The experimental planner holds sub-step depth as debt and permits full-q lowering only when the actual cumulative demand funds it. Do not turn a 1.5mm request into an automatic 3.891mm overshoot. Native tire ruts have a DIFFERENT fine terrain representation and need separate research.

## Actual coding defect exposed by source review

`TerrainGeometryJournal` **persisted readback provenance** but trusted its physical ownership much too loosely:

1. `importSnapshot` accepted a saved owner as RE-owned if the current native MAIN height was within **5mm** of the saved height. One q-sized external change of **3.891mm** fits within that 5mm band and could therefore be laundered into a current, supposedly authorized RE-owned rut.
2. `exportSnapshot` accepted up to **2mm** of native drift and wrote the new height as `observedHeightM` while leaving `owned=true`. The legitimate-looking next load could falsely restore authority to recover a vertex changed by another mod/player.
3. `getRecoverablePoint`, `getLoweringBudget`, and `begin` similarly tolerated up to **2mm** of unexplained runtime movement before revoking provenance. This was too weak for the user's requirement that RE never confuse unverified terrain changes with its own physical edits.

These were **potential ownership/recovery hazards**, not evidence that another mod actually changed x=348,z=387 in the supplied session.

## Implemented on terrain PR #64, still experimental

* `TerrainGeometryJournal.OWNED_HEIGHT_DRIFT_M = 0.00001m` (10µm). Only differences **below this threshold** may maintain *ownership* of persisted or currently observed MAIN heights. This is deliberately stricter than unrelated generic journal/readback tolerances.
* On import: keep up to 5mm-different samples for **untrusted diagnosis**, but set `owned=false` whenever original `owned=true` and real MAIN height differs >10µm; increment `reloadOwnershipDriftDowngraded`. Do NOT raise/lower any native terrain during import.
* On export: revoke `owned` and increment `preSaveOwnershipDriftDowngraded` whenever the current live MAIN height differs >10µm, **before writing any snapshot**; retain existing 2mm diagnostic-only retention band and reject larger mismatch.
* On live geometry-budget request and causal recovery authorization: check that owner still matches <=10µm. On divergence revoke ownership, preventing automatic recovery, and tally `runtimeOwnershipDriftDowngraded`. `begin` applies the same owner invalidation policy.
* Core save and load logs now show ownership-revocation counts separately from total restored or unknown cells.
* Regression harness: 5µm jitter retains a v2 owner; 20µm and 1 × ~3.891mm drift retain readable metadata but **revoke recovery authority**; an external 20µm change during gameplay blocks recovery; a 20µm change at save cannot be laundered into next-session ownership. No actual native setter calls or change of world height from these sidecar tests.

**Safety contract:** Lack of ownership means RE must NOT automatically grade/repair that vertex. It does not mean the geometry or visual rut disappears, nor does it mean the mod changed the user's terrain. Extremely strict 10µm checks may conservatively revoke valid ownership if native runtime noise ever exceeds that tolerance; revisit only based on trusted runtime measurements, never widen until q-sized external changes can become owned.

## Remaining release work

- Safely connect confirmed broad-MAIN cumulative target demand to the proven q-sized native setter, including repeated passes and several neighboring vertices. Check both per-vertex spending and per-footprint effects; avoid summed narrow tire tracks regrading a whole 1m cell. Still `SHADOW` by default.
- Test actual physical recovery via independently owned native geometry under tillage (no repair of untrusted edits). Never grant recovery authority to isolated research calibration points.
- Investigate true fine 0.125m wheel-displacement read/replay path separately from the `TireTrackSystem` visual event stream. Do not present a visual-track archive as physical rut persistence.
- Only then consider lifting a 10–12cm safety cap; one q-step does not prove continuous deep digging is safe.
- PR #64 still draft/divergent from RE main, and RC updates remain independent; do not merge without review.

Official FS25 public source confirming a *separate* higher-resolution native wheel displacement representation: https://www.farming-simulator.com/newsArticle.php?campaignIndex=22&country=za&lang=en&news_id=569 . The exact Estância São Carlos map's I3D `heightScale` remains indirectly inferred from the grid/lattice, not read from the shipped map file.
