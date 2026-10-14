# PTO field smoke — Fendt 512 Vario + Krone VariPack V 190 XC Plus (2026-10-13)

**Scope:** V1.5/V1.6 source- and log-backed PTO audit. **No physics/code patch, no merge to main.**
Uploaded evidence: `log(20261014-002901).txt` (4752 lines, 456073 bytes) and `ModMixer(20261014-002901).log` (141 lines, 23935 bytes). Despite the files being named Oct 14, the FS25 runtime messages are from **Oct 13 2026**. The main log includes **two sequential game sessions**, with a soft restart at 10:55:25; the baler console probes are all from the **second** session.

## Runtime identity and ownership

- FS25 1.24.0.0, build b41780 / 83220; singleplayer `g_server` and `g_client` exist on local host, **not a remote multiplayer authorization test**.
- RE `feat/pto-v1-6-drive-evidence@cad0c62d496f27155d0e738876b84b38dc1aa597`; CI run `38393575680`. `TerrainDeformation=disabled`.
- RC `main@ad7461fb7777691f6f64e2327753417c95b6177b`; MR `0.26.10.08`; RMS `0.11.0.0`.
- `MR+RE PTO ACTIVE` and `RMS+RE PTO ACTIVE`; `DynamicPTO=-` in RC detection (though the Dynamic PTO archive is present in the game mod scan and emits nonfatal duplicate translation warnings).
- ModMixer's 2026-06-01 scanner reports its baseline 26 suspected conflicts, with no new baler-specific PTO hook claim; farm boot watchdog reports HEALTHY.

## Exact RE PTO inspection observations

Root: `512 Vario (Enfardam 10)`. Tool: `MR VariPack V 190 XC Plus (Enfardam 10)`, `MoreRealistic/data/overriding/vehicles/krone/varipackV190XC.xml`.

| Runtime time | PTO mode | Engine RPM | RE physical ratio | MR PTO RPM | MR RPM/nominal | MR baler calculated kW | Active MR load kW | Connected | RE engaged |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| 11:01:55.778 | 540E | 1926.00 | 3.17777778 | 606.08 | 1.12238 | 46.8705 | 46.8705 | yes | yes |
| 11:02:31.196 | 540E | 800.00 | 3.17777778 | 251.75 | 0.46620 | 14.0929 | 14.0929 | yes | yes |
| 11:02:36.332 | 540E | 800.00 | 3.17777778 | 0 (stopped) | 1 (MR reset sentinel) | 14.0206 (last/smoothed cache) | **0** | yes (still coupled) | **no** |

All three `ROOT` reports: `required=540`, `nominalFamily=540`, `gearCompatibility=COMPATIBLE`, `known=1 unknown=0`, `conflict=false`, `driveEvidence=NATIVE_PTO_INPUT`, `attached=1 nativeInputs=1 profiles=0 unlinkedPower=0`; `inputPto=1 connectedInput=1`. `ai=false`, `handTargetRPM=0`. This independently validates the native shaft-input classifier, matching 540 gearbox family, engagement transition, and load zeroing on shutdown.

**The physical and MR speeds agree on this specific tool** because `requiredPtoRpm=540` equals RC's canonical 540 denominator: `1926/3.17777778=606.08`, `800/3.17777778=251.75`. Do not generalize to the Berthoud 500 RPM case where MR normalizes its ratio.

The 1926-rpm/540E snapshot corresponds to about **12.24% above** the implement's nominal 540 shaft RPM and the 800-rpm snapshot to about **53.38% below**. These are kinematic observations, not evidence of damage, cutoff, or automatic capacity penalties. `turnedOn=true` at low idle is plausible without material feed and does not prove that productive baling at 252 RPM is possible.

### What the actual MR profile means

Pinned MR source `quadural/MoreRealistic_FS25@b38d5667e073505255cd7ce170ab568616a91221`:
`MoreRealistic/data/overriding/vehicles/krone/varipackV190XC.xml` declares
`<mrBaler idlePower="14" powerIncreaseWithFeedingKilosPerSecond="4" powerIncreaseWithBaleMass="17" maxTonsPerHour="60" unfinishedBaleThreshold="0.95" densityFactor="1.1" nettingDuration="5" />`, while setting `vehicle.powerConsumer#ptoRpm=540` and `maxPickupLitersPerSecond=300`.

Thus 14.0929 kW at idle is near the MR **14 kW no-material drive consumption**; 46.8705 kW is 32.87 kW above idle, compatible with **feed throughput and/or accumulated bale mass** in `MR_Baler.lua`. The log lacks fill-level, bale mass, feed rate, tons/hr, and actual travel speed at the sample times; it does **not** prove that the kW reduction was caused by PTO RPM or that MR's calculated speed limit had been applied during a dense windrow.

### Important MR torque conversion at low shaft RPM (source-derived)

Pinned `MoreRealistic/scripts/MR_PowerConsumer.lua:526-559` declares:
```lua
if self.rootVehicle ~= nil and self.rootVehicle.getMotor ~= nil then
    rpm = math.max(0.85, self.mrPtoCurrentRpmRatio)*rpm
end
return neededPtoPower / (rpm*0.10472), spec.virtualPowerMultiplicator * turnOnPeakPowerMultiplier
```
At the 800-engine-RPM observation, the logged shaft-ratio is `251.748/540 = 0.4662`, but MR's conversion clamps the RPM factor to 0.85, using `540*0.85 = 459 RPM` as the denominator. This **exactly explains** `mrTorqueKNm=14.0929/(459*0.10472)=0.293196`. On this raw torque at the RE-calculated 251.748 physical RPM, the `torque*actualRPM*0.10472` product is ~**7.73 kW**, below the `mrLoadKW=14.09` nominal modeled demand. This is **not independent proof of actual engine power** because the second return value includes a virtual multiplier; it is evidence that the raw torque no longer corresponds to the full requested power at extremely low PTO RPM. At ~606 RPM (>540), the conversion is *not* clamped: `0.738477*606.084*0.10472=46.8705` kW.

Consequence: beware treating `mrLoadKW` as actual shaft power when the shaft is far below nominal. This clamp may be a deliberate bounded-torque safeguard; do **not** delete or circumvent MR's clamp without torque-stall and safety analysis. It reinforces why staged V2 must analyze low-RPM torque/throughput, not stack a flat RE 'grunt load' or forcibly stall vehicles.

The `powerMinKW=30 powerMaxKW=30` in the inspector reflects the GIANTS powerConsumer configuration. For an MR-specific `mrIsMrBaler` implementation, `MR_PowerConsumer.mrUpdatePtoPower` uses `Baler.mrGetActiveConsumedPtoPower` instead of that constant generic 30 kW. A real active **46.87 kW** is therefore expected, not a power accounting error. After shutdown `mrBalerPowerKW=14.0206` is a **stale or smoothed MR field**, while the operative demand `mrLoadKW=0`, `consumePower=false`, `mrTorqueKNm=0` verifies zero consumption. Do not mistake cached `mrBalerPowerKW` for live load.

Importantly, the upstream MR XML itself comments that `maxPickupLitersPerSecond=300` "doesn't seem to be useful except for visual fillEffect". This is a **distinct variable** from MR's true `mrBalerMaxTonsPerHour=60` throughput model. Dynamic PTO's synthetic baler pickup-loading based on `maxPickupLitersPerSecond` is therefore not obviously equivalent to MR's tons-per-hour capacity, and stacking two penalties would require an owner-safe conceptual proof first.

## Errors unrelated to proof of RE PTO failure

- `Error (physics): Wheel shape not found for getContactPoint` on `vario500_axle_component2` wheel indices 153–154 and `vario500_main_component1` indices 155–156 at 10:57:04, immediately after Fendt 512 spawn. Requires separate chassis/wheels stack investigation if it recurs or influences gameplay; no proven causal link to RE PTO from this log.
- Twice on shutdown, `Script error: 'delete': Argument 1 ... Actual: Nil`, call stack `FS25_manualAttach/src/core/DetectionHandler.lua:65` / `VehicleAttachmentHandler.lua:116`. Existing mod lifecycle issue; not traceable to RE PTO.
- `FS25_CBI6800CT.WoodGrinder`: 8 duplicate vehicle specializations per game boot (repeated after soft restart); unrelated to the Krone. Translation duplication warnings from installed, **inactive** Dynamic PTO and some other mods.
- `RealismCompat [MRMud] Integrity pointer drift ... widthRadius=false` in both loads. It is a warning requiring telemetry to determine actual compatibility; do not collapse it into a PTO failure.
- `ModMixer` June 2026 static scan's severity categories are reports, not live reproduction of breakage; 0 active veto, one cutter hook reorder, farm boot HEALTHY.

## Release-gate disposition

- **V1.5 baler smoke: basic state/kinematics/load/stop PASS** for this precise Fendt/Krone/540E scenario. The extra physics test "vary RPM *with identical windrow feed* and measure throughput/speed limitation" remains **UNTESTED** and is stage V2 design evidence, **not** proof of failed V1.5 core PTO.
- **V1.6 classifier/HUD:** `driveEvidence=NATIVE_PTO_INPUT` correct and stable; no image evidence for other hints/warnings, and no new context-aware alert code.
- **MP safety gate still open:** `PTOStateEvent:run(connection)` receives client-to-server requests and invokes `vehicle:setPowerTakeOffState` after validity/engagement checks, but does **not explicitly verify that the incoming connection can control this vehicle or belongs to its farm**. Dedicated server tests remain unperformed. Do not assert an exploit without actual control/permission modeling; review real GIANTS authorized-control APIs before shipping.
- No automatic `540E vs 540/1000` comparison occurred; do not mark differential gear behaviour as tested just because three inspections are present.
- **Main must not be merged yet** under established release criteria: parent PR #39, child PR #45 remain draft. No RE gameplay code is changed based only on these three point-in-time snapshots. All Horsch/Berthoud test gains remain valid and need not be repeated.

Next engineering work should be authorization hardening of RE PTOStateEvent with a server-observable, GIANTS-compatible ownership/permission contract, plus precise tests. Separately, design an optional baler throughput-versus-real-shaft-RPM study with MR as sole throughput owner, using `mrBalerLastTonsPerHour`, `mrBalerSpeedLimit`, `mrBalerLastNeededPower`, speed, and material feed at the same test points if new measurements are ever needed. The idle-power test has already been completed; avoid repeating it.
