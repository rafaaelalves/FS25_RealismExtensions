# 2026-10-25 20:08:59 — Main-height step quantization and amplitude quarantine confirmed

## Source and runtime identity

Evidence: user-provided `log(20261025-200859).txt` (2,541 lines) and `ModMixer(20261025-200859).log` (142 lines). Verified real in-game RE build **`feat/terrain-native-transaction-v1-2026-10-23@4d9fbec85e101733707cf4e9714dd0395d62d9d5`**, Actions run **40226720436**. RC production **`main@546806b78...`**, FS25 1.25.0.0, map **Estância São Carlos v1.4.0.0**.

At entry `native journal ready; restored=937 rejected=0` and 1,501 historical cells restored; `TerrainDeformation=ENABLED`, `causal=true`. No in-game save completed, no recovery work, no PERIOD_CHANGED maintenance event.

## Operational verdict

At 17:06:11 (`TerrainHealth`), 101 native jobs completed, 4 actual lowering-positive jobs, 97 no-change. At 17:07:12 and **still unchanged** at 17:08:13, 129 jobs / 10 lowered / 119 no-effect. Thus **119/129 = 92.248%** of RE native submissions produced *no measured lowering on journal-sampled 1m main vertices*. 10/129 = 7.752% produced lower movement; **8/10 = 80%** of positive events crossed the >request+2mm amplification threshold. 0.1323 m is SUM of **each lowering-positive job's MAX vertex lowering**, not the depth of one rut. Paired requested sum for those same positive events is 0.0196 m. The sample cannot assert that the fine 0.125m physical displacement channel was motionless.

At **17:06:28.136**, the new protection correctly emitted:

`TerrainNativeQuarantine | x=443.14 z=177.94 request=0.0017m observed=0.0584m reason=EXCESS_NATIVE_LOWERING`

After the quarantine, native completed job counters remained exactly 129/129 at 17:07:12 and 17:08:13, providing strong evidence the **session latch prevented further RE native LOWER submissions**. The first 58.4mm sampled main-vertex event still occurred; this safety latch does NOT prevent first anomalous movement, does not guarantee no third-party terrain changes and is not a fix to native actuator amplitude.

No significant RE Lua exception, no journal pending at summaries. Native guard CAP encountered 71 samples; these are not 71 separate holes. Freezing was not active (`frozen=false, air=-1.96°C`), so freeze gating did not cause low effect in this test. Midgame RC bridges active; ModMixer warnings are common pre-existing chains, not direct attribution of a particular native height delta. Separate CBI6800CT duplicate registration errors and manualAttach `delete(nil)` at unload are unrelated.

## Direct precision comparison — strong empirical evidence of discrete main-height steps

The six bounded `TerrainNativeDelta` diagnostics printed **six-decimal beforeY and afterY**, at six distinct native 1m grid locations. Their deltas are, in meters, exactly within log decimal rounding of integer multiples of `q = 255/65535 m ≈ 0.00389105058m`:

| (x,z) vertex | RE request | beforeY | afterY | Measured difference | q-steps |
|---|---:|---:|---:|---:|---:|
| 270:309 | 2.4mm | 147.910507 | 147.902725 | 7.782mm | 2 |
| 242:294 | 3.0mm | 145.871597 | 145.859924 | 11.673mm | 3 |
| 439:189 | 1.7mm | 143.280151 | 143.272369 | 7.782mm | 2 |
| 442:182 | 1.7mm | 143.038910 | 143.027237 | 11.673mm | 3 |
| 442:181 | 1.7mm | 143.000000 | 142.980545 | 19.455mm | 5 |
| 443:179 | 1.7mm | 142.961090 | 142.957199 | 3.891mm | 1 |

Every error vs `n*q` is **below 0.3 micrometre**, consistent with the six-decimal print precision. `58.4mm` quarantine ~= 15q. The final aggregate 0.1323m ~= 34q, further consistent with this pattern. This is **strong empirical confirmation of a 3.891mm effective quantization in these main-height API deltas**. However, direct source confirmation of Estância São Carlos's terrain `heightScale`, storage bit depth and whether C++ conversion/rounding also contributes remains open; no one should present a guessed map-file XML line as sourced. Prior request to obtain the map's `heightScale` is **not necessary to establish this observed step** and should not be repeated automatically.

**Two orthogonal defects**:

1. **Micro-deformation dead zone**: 1.7–3mm requested is below a 3.891mm output step; most operations are no-op in sampled main channel. Tiny visible tracks may come from FS25's separate native fine deformation and not indicate genuine RE-caused *persistent 1m main-geometry* relief.
2. **Amplitude attribution / burst**: e.g., 1.7mm RE native request correlates with a 15-step (58.4mm) main-grid change in the same callback window. Quantization alone CANNOT explain why 15 steps moved. Neither immediate pre-submit resampling nor single-RE-job exclusivity rules out another simultaneous GIANTS/third-party edit during the async callback. Do not assert RE alone dug 58.4mm.

## Decisions / follow-up

- **Do not repeat an undirected wet-ground driving test**. Latest user reported no visually large ruts and uncertainty about defects in small ruts. Explain plainly: absence of giant ruts in this session is consistent with quarantine, and small RE main-height adjustments are mostly no-ops; user's observed small tire impressions need not be defective.
- Keep PR #64 draft, production RE terrain disabled, existing verified causal recovery and NPC maintenance logic unchanged, legacy generation guards intact. No new build for this report.
- Further RE work must explicitly separate the **GIANTS FS25 0.125m fine physically colliding displacement channel** from the **1m main heightmap** sampled by `getTerrainHeightAtWorldPos`. Dense sampling of this same API at 0.125m is **not** a proven accessor for fine persistent displacement.
- Choose a deterministic, bounded write **actuator** for physical main geometry, potentially studying target-based, one-native-quantum commands with immutable baseline and exact after-read tests, or a genuinely supported API for native fine rut geometry. Do **not** simply boost sub-quantum requested inputs: evidence shows it would be risky. Also do not implement "automatic undo" of a large event with unverified RAISE/TARGET commands (prior history showed giant overshoot).
- Needed future test, **only after a code change implements a falsifiable A/B protocol**: disposable save, control with RE LOWER disabled while native FS25 tracks/other mods continue vs isolated RE native job at same marked coordinates, recording main and genuine fine channels if accessible. Prefer automated/instrumented and short, not an entire farming year.
- Current result proves native quarantining and strongly supports vertical quantization; it **does not** prove eventual rut recovery, season maintenance, MP/saves, or correct native displacement output.
