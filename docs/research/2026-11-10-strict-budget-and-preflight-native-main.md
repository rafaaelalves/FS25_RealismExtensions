# 10 Nov 2026 — strict MAIN write amplitude and submission drift gates

## Coordination after repository cleanup

Actual GitHub states observed 10 Nov 2026:

- RE `main` `c71df33309f30643fa07d2bdbb04390d14cc95fb` (documentation/archive cleanup merged). Draft terrain PR #64 remains on `feat/terrain-native-transaction-v1-2026-10-23`, now targeting `main`, with a divergent history and GitHub `mergeable=false`. Do **not** force-merge or discard either history while this experiment is under review.
- RC `main` `6a0305b2a21c9deffe5218f88d5e9d5cf4f688fe`; draft PR #55 `feat/stack-rms-beta1-mud140-2026-11-09` is the active RMS/Mud cross-mod risk branch. No RC code changes were needed for these isolated RE numerical guarantees.
- The most recent supplied live logs predate the present RE source patch. Hence this research is **CI-validated only** and not FS25-runtime-validated.

## New defect found

`TerrainQuantizedHeightBudget:settle` compared actual height readback to `plan.stepM` with a 50 µm tolerance, appropriately checking if the native quantizer moved roughly ONE step, but then wrongly reused the SAME 50 µm tolerance when comparing measured lowering to the REMAINING AUTHORIZED DEPTH `item.debtM`.

Example: `q=255/65535 m ≈ 3.89105 mm`, a q-sized cumulative target, measured `q+0.020 mm` -> readback could previously be marked `verified=true`, even though the user authorized only `q` removal. In hundreds of transactions this could certify incremental over-digging. **Readback similarity and spending authority must be different predicates.**

### Fix implemented

`TerrainQuantizedHeightBudget.VERSION=3`:
- Keep the bounded map-specific readback comparator `abs(observedStep-q) <= toleranceM` for quantum recognition, but **strictly reject** `observedLowering > debtM+tinyFloatingPointSlack`.
- New slack: `max(1e-9m,abs(debtM)*1e-7)`, deliberately *not* 50 µm. This is a numerical comparison allowance, not excavation permission. On a typical 3.891 mm quantum the allowance is 1 nm.
- On overshoot: return `OBSERVED_LOWERING_EXCEEDS_DEBT`, quarantine the budget, do not advance committed physical depth or debt in the model; do not automatically raise back a real terrain edit.
- Applies to both cumulative TARGET and INCREMENTAL research contracts.

`TerrainGeometryJournal:validateBeforeSubmit(token,maxAllowedDriftM)`:
- Previously accepted up to 2 mm of new MAIN geometry between `begin` and submit. That generic default remains for other callers.
- Allows an explicit **smaller** just-in-time drift limit, never a looser one.
- `TerrainAbsoluteVertexCandidate` now requests a strict min(`budget.toleranceM`, **10µm**) limit over its entire 3×3 vertex footprint immediately before using the absolute native setter.
- If any competing writer moves terrain by 0.1 mm inside this window, there is **no RE setter call**; the candidate aborts and permanently quarantines this isolated research budget for the mission. Future attempts must obtain a new verified epoch, not silently retry against shifted ground.
- Important remaining race: no Lua-level preflight can globally lock unrelated third-party C++/Lua writers between the final read and physical setter. This is a defensive fail-closed gate, NOT absolute C++ isolation.

## Tests and evidence

- `tests/terrain_quantized_height_budget_harness.lua`: rejects 10–20 µm excess with full q demand despite passing 50 µm step-matching threshold; verifies budget quarantine and unchanged debt. A 20 µm shortfall, however, is credited by its actual measured amount. Runs on both contract types.
- `tests/terrain_absolute_vertex_candidate_harness.lua`: synthetic setter returning q+20µm quarantines and revokes affected vertex provenance; in matrix of floor/nearest quantizers and different q, positive readback biases are intentionally **rejected**, not counted as successful within authorized depth.
- Additional runtime-like simulated foreign 0.1 mm edit after `journal.begin` but before submit is detected in 3×3 validation and refuses native setter with 0 calls; budget quarantined and no source ownership invented.
- GitHub workflow runs full Lua syntax/test/XML checks. Confirm latest green code commit from CI before presenting as validated (not a gameplay test).

## Hard release gates preserved

1. Establish genuine Estância São Carlos map `heightScale` and native MAIN quantum. `255/65535` is observed/hypothesized, NOT map-source-certified, and must not be used as a default release parameter.
2. In one **verified disposable clone**, demonstrate exactly one authorized native height step at the center, zero forbidden neighbor movement, and an identical readback after an actual save and distinct-mission reload. Do not experiment on a normal game save.
3. **Thin tire rut geometry remains separate from 1m MAIN**. Native `displacementScale` and `TireTrackSystem` visual `groundDepth` are not fine physical height readbacks. Do not declare fine physical persistence/replay or tillage recovery based on visual archive data.
4. The geometry journal may revoke ownership on suspicious edits, but recovery must only affect proven RE-owned physical geometry after separately verified persistence. No automatic MAIN writes, no forced wheel displacement scale, no MP rollout.
5. Maintain draft PR #64, `SHADOW/OBSERVE_ONLY`, no changes to RE/RC `main` or PR #55. Do not generate a user-facing new test build unless the tested code and exact next in-game question justify it.

External reference: GIANTS FS25 Engine LUADOC `getTerrainHeightAtWorldPos` and `getTerrainHeightmapUnitSize` (main grid horizontal unit): https://gdn.giants-software.com/documentation_scripting_fs25.php?category=28&function=811&version=engine ; https://gdn.giants-software.com/documentation_scripting_fs25.php?category=28&function=812&version=engine .
