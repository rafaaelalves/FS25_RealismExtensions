# PTO milestones, release gates, auxiliary hydraulics, and baler ownership (2026-10-13)

**Status:** source-backed checkpoint; **no `main` merge authorized**. Scope PTO only. This note follows the gameplay evidence at `docs/research/2026-10-13-pto-field-validation-berthoud-horsch.md`, and the exact Dynamic PTO archive audit stored in RC.

## Independent ownership: Horsch Avatar

### Real-world energy path

HORSCH's manufacturer brochure for **Avatar 8–12 SD**, technical table on page 14 (PDF page index 7), specifies for **12 SD** a hydraulic fan requiring **35–45 L/min** of oil, one depressurized return line (max 5 bar), and tractor hydraulic remote controls. This supports an engine-powered tractor hydraulic pump -> oil pressure/flow -> seeder hydraulic fan motor, rather than requiring a rear mechanical PTO shaft for fan operation. It does **not** prove that the in-game Avatar 12.25 SD duplicates every optional hardware variant or provide specific pressure/efficiency or precise fan mechanical kW.
https://cdn.horsch.com/celum/36966_original.pdf

### How MR actually simulates it

Exact MR source from `quadural/MoreRealistic_FS25@b38d5667e073505255cd7ce170ab568616a91221`:
- `MoreRealistic/data/overriding/vehicles/horsch/avatar1225.xml` declares `ptoRpm=340` and max 22 kW, with inline comment about the pneumatic seed/fertilizer turbine and electric distribution. Runtime has loaded min **20 kW**.
- `MR_PowerConsumer.lua:562+`: if `getDoConsumePtoPower()` is active, select the dedicated model or compute `minPower + consumingLoad*(max-min)`, store `mrLastNeededPtoPower`; `mrGetConsumedPtoTorque` converts power to the effective engine/drivetrain torque channel. Its legacy function/API names say 'PTO', but this code does **not** implement hydraulic pressure, oil flow, a hydraulic motor simulation, or prove mechanical shaft coupling.
- Actual `rePTOInspect` logs: Horsch OFF `mrLoadKW=0`; ON `mrLoadKW=20`, `inputPto=0`, `connectedInput=0`, `driveEvidence=POWER_CONSUMER_NO_INPUT`, RE `engaged=false`. MR's generic `activePto=true` when ON is **not** an evidenced cardan.
- RC `PTOState.getSnapshot` creates a scoped gearbox ratio bridge only when RE `requiredShaftRpm` is nonzero. Horsch has `requiredShaftRpm=nil`: **RC does not apply a physical PTO-gear correction to its MR generic-power path**. RE `PTOPhysics`' standalone GIANTS adapter explicitly skips installation when MoreRealistic is loaded. This is a qualified statement about this exact MR+RC+RE stack, not every non-MR setup.
- The Horsch drawbar/soil traction/draft work remains a separate demand on tractor power, independently of these auxiliary 20–22 kW.

## Berthoud's MR canonical speed is not shaft speed

The RE physical selected ratios were 2.3 (1000) and 4 (540) with engine ~2083.43 rpm. On this machine, `requiredShaftRpm=500` is the **raw MR/GIANTS consumer demand**, not an identified nominal gearbox. RC `PTOState.lua` adapts the MR normalized 540 channel using `effectiveRatio = physicalRatio * 500/540`, so MR `mrPtoCurrentRPM` reads 978.31 or 562.53; the approximated physical shaft speeds are instead ~905.84 or ~520.86. This is an exact source-contract mapping, **not** an engine-rpm timing mismatch. Both states consumed 12 kW; modeled torque varied inversely. No generic 'speed up spraying' rule follows from these observations.

## Baler audit: MR already simulates capacity and power

Pinned exact source `MoreRealistic/scripts/MR_Baler.lua`:
- Loads **only for MR-marked balers**: `mrBalerMaxTonsPerHour`, `mrBalerIdlePower`, `mrBalerPowerIncreaseWithFeedingKilosPerSecond`, mass of bale, optional per-stroke power and fixed `mrBalerStrokesPerMinute`.
- `Baler.mrGetActiveConsumedPtoPower`: tracks sampled liters per second, converts to tonnes/hour from fill type density, computes feeding/bale/idle/stroke kW, and updates `mrBalerSpeedLimit` from actual input versus rated throughput. `MR_Vehicle.lua` and `MR_VehicleMotor.lua` use this speed limit. Thus existing MR balers **already force slower travel** under excessive windrow material through a genuine throughput model; avoid an additional arbitrary RE speed limiter.
- The hardcoded nominal tons/hour and strokes/minute do **not** obviously scale with RE-selected real PTO shaft speed. Investigate this *specific* missing coupling only after runtime baler evidence, including engine low-RPM performance already modeled by MR.
- MR `mrBalerSpeedLimit` is clamped with a minimum of 5 km/h: this is a pre-existing approximation, not a perfect real intake/backlog solver. Check gameplay results before declaring a deficiency.

### Dynamic PTO's alternative behavior

Source ZIP `FS25_DynamicPTO_FFM (2).zip` (SHA-256 `e79a4cadca224ec83ba982ab4d507a1e244fef64e93f87011dc383946f7be20a`, declares 1.1.3.0):
- `PTODetector.getBalerPickupLoad` divides pickup liters buffered over 1 sec by `spec_baler.maxPickupLitersPerSecond`; adds a heuristic speeding factor beyond 8 km/h when `loadPct > 0.35`.
- `PTODynamics.update` reduces visual/animation work speed under overload, adds **synthetic** motor 'grunt' load, and if `overload >= 1.0` continuously for **1600 ms**, calls `vehicle:stopMotor()` and `object:setIsTurnedOn(false)`.
- The scripted stall is **not explicitly gated by physical torque available at current engine RPM versus actual baler torque demand**. It is an understandable gameplay design choice but not a proven mechanical stall model. Combined with MR's already modeled capacity/load and RMS wear, the same overload may be punished more than once. RC's Dynamic PTO + RMS bridge mitigates only part of the load duplication.
- Do **not** copy a flat threshold or a universal PTO output multiplier into RE. Prefer an evidence-backed rpm-to-throughput relation and owner-safe RMS degradation only if missing.

### Sprayers are different

Applying fertilizer once per field does not justify boosting crop-treatment passes or liters delivered by choosing 1000 PTO. Correct regulated-sprayer behavior may target constant volume/area via increased pump output and pressure regulation. The only useful new effect would be evidence of **inadequate** pump flow at too-low actual shaft RPM, where target application rate may fail and slower ground speed could compensate. Do not implement anything before establishing the exact in-game pump drive and GIANTS/MR application behavior.

## Three stages — status and merge decision

| Stage | Scope | Status as of 2026-10-13 |
| --- | --- | --- |
| **1 / V1.5** | Conservative PTO profile/gear family, basic hand throttle+AI, HUD, diagnostics | CI green; Horsch and Berthoud test cases passed real-save smoke; **baler smoke + multiplayer authorization verification remain**. Parent **PR #39**, draft, targets `main`. |
| **2 / V1.6** | True/unknown mechanical input vs nonphysical power, operator messaging, context-aware warnings, MP hardening | Initial classification and neutral HUD hint implemented; Horsch/Berthoud logs validate classification; `PWR?` visual confirmation pending; context-aware alerts and MP hardening not implemented. Child **PR #45**, draft, targets branch `feat/pto-v1-5-observability`. |
| **3 / V2** | Actual implement operating response and material throughput | **No RE physics code implemented**; MR baler already does mass throughput, feed load, speed governor and plunger strokes. Audit the missing RPM coupling before code. |

**Merge policy:** Do not merge either draft PR to `main` simply because its CI is green. For this PTO stack a minimal *targeted* in-game baler smoke under actual crop input (one on/off plus representative slow vs fast PTO gear, output/feed, current MR modeled kW and RE engagement) is appropriate; avoid retesting the Horsch/Berthoud data already captured. Verify/resolve server permissions for client PTO commands, and review chipper-specific previously reported engine-governor behavior before declaring all PTO-driven implement classes stable. A dedicated MP validation is required before advertising multiplayer readiness. If appropriate, land independently proved read-only HUD/inspection commits through a separate small PR, but never silently promote the full feature set.

As of this document, **`main` remains intentionally unchanged**. Keep using the verified experimental V1.6 ZIP `cad0c62d` (or its exactly same functional branch with CI) for PTO investigations; use RE and Dynamic PTO only as mutually exclusive PTO controller owners.

## 2026-10-13 — Baler V1.5 smoke evidence received and reviewed

Complete field audit: [Krone VariPack/Fendt 512 540E validation](2026-10-13-pto-krone-varipack-runtime-smoke.md). User's attached `log(20261014-002901).txt` has RE `cad0c62d`, RC `ad7461fb`, 540E nominal-family 540 and native connected shaft, with 46.87 kW at ~606 shaft RPM, 14.09 kW at ~252 shaft RPM and 0 active kW when OFF. **Basic engagement + MR load smoke PASS** on this machine. MR's exact VariPack profile has idlePower=14 kW, so the off-peak reduction is more consistent with feed/mass change than a proven RPM-dependent productivity curve; no actual material/throughput metric appears in the log.

**Stage 1 is not yet release-complete:** client→server PTO command authorization and multiplayer behavior remain unverified, and coverage of other connected implement/tractor classes is still limited. No `main` merge. The gear-vs-throughput comparison is a separate V2 workstream; a 540E-only high/low engine RPM sample is not a distinct 540-vs-1000 test. Fixes or enhancements must be targeted and tested, not synthetic load stacked onto MR.
