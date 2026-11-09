# Absolute MAIN height: avoid edge-triggered overshoot

Status: research prototype only, not a production actuator. Branch: `feat/terrain-native-transaction-v1-2026-10-23` (draft PR #64).

## Evidence versus hypothesis

Two in-game isolated `setTerrainHeightAtWorldPos` experiments requested 0.0015 m of lowering and immediately observed 0.003891 m instead, with exactly one of nine sampled MAIN vertices moved. The points were (348,388) and (344,387) on Estância São Carlos. This is consistent with a ~3.891 mm vertical height step, such as `255 / 65535` m on a 16-bit map whose `heightScale` is 255 m. The **map's actual heightScale and the engine's rounding policy remain independently unverified**. The FS25 official API describes an **absolute height** setter; it does not promise sub-quantum resolution. These observations do not address the separate finer wheel-displacement channel.

## Newly addressed risks

1. **Sub-step debt:** `TerrainQuantizedHeightBudget` requires a FULL funded quantum in both cumulative demand and verified remaining safe geometry budget. A request of 1.5 mm cannot request one 3.891 mm native step. Replaying an unchanged cumulative target cannot accumulate extra damage.
2. **Quantizer boundary:** `TerrainAbsoluteVertexCandidate` used `target=beforeY-quantumM`, a target exactly on the next quantization boundary. For a floor quantizer and a readback a few micrometers below the theoretical lattice, that may select two steps. The prototype now asks for `beforeY-0.75*quantumM`, an **interior-bin proposal** that produces one step under simulated floor and nearest-grid policies when the current height is on the lattice. The measured result must still be one full quantum. This is a **model-backed safety hypothesis**, not a guarantee for the native C++ setter.
3. **Cumulative accounting:** `Budget:settle` now debits the *measured* lowering from its ledger, not the nominal planned quantum. The old 0.5 mm default readback tolerance could mask systematic amplitude errors; the research budget now caps tolerance at 0.05 mm AND 2% of one quantum. Out-of-tolerance results quarantine subsequent writes.
4. **Tests:** mock engine floor quantization with negative floating offset reproduces the former two-quantum hazard; the new interior target measures one. Another mock uses a continuous/nonquantizing setter and must fail closed. A matrix tests three map quantum values, both floor and nearest policies, and small positive/negative floating readback jitter. Ledger tests reject 0.2 mm excess as a valid quantum and verify measured rather than planned accounting.

## Safety boundary

The prototype `TerrainAbsoluteHeightExperimentalBackend` still requires explicit research permission, disposable-save confirmation, a separately verified map quantum, queue exclusivity and a one-shot limit. The regular RE permanent-terrain path stays `SHADOW`; no code in this research changes the default native wheel path. No autorun, no permanent write, no migration to RE or RC main.

Before considering any runtime integration, obtain map-specific `heightScale` provenance or independent safe calibration, prove one-step height change and no collateral through readback, then demonstrate persistence on a verified disposable clone by saving and loading a distinct mission. Even that would not establish wheel collider/fine displacement synchronization or physical recovery. Do not repeat plow/sow/harvest cycles as a substitute for these isolated gates.

## Sources

- GIANTS FS25 Lua documentation, `setTerrainHeightAtWorldPos` and `getTerrainHeightAtWorldPos`.
- GIANTS Engine terrain editor documentation (16-bit heightmap) and FS25 mapping documentation on `heightScale` as a map-specific `TerrainTransformGroup` attribute.
- The two uploaded 03-Nov runtime logs recorded in this branch's preceding research notes.
