# PTO V1.5 / V1.6 — shaftless auxiliary power and evidence-driven next stage

Date: 2026-10-12
Status: verified source semantics + planned architecture, not an independent physics implementation.
Baseline: RE PTO V1 main `2534cec`, active V1.5 draft PR #39 and RC `ad7461f`.

## What the Oct 12 gameplay log proves

The user installed V1.5 merge build `041ca9bfd72901c2dcbc89842d3c94e1a0ee0b7f` on the Fiat 180-90 DT / Horsch Avatar 12.25 SD save. The HUD no longer falsely flags 540/1000 as incompatible. RE native PTO bootstrap and RC `MR+RE PTO` / `RMS+RE PTO` integrations are active.

RC end-of-session counters: `effectiveRatioScopes=0`, `mrPtoRpmRatioScopes=0`, `motorizedUpdateScopes=0`, `startGearRatioScopes=0`. These support *absence of RE PTO mechanical-ratio substitution during this session*. They do **not** measure or disprove MR PowerConsumer power consumption. No `rePTOInspect` snapshot was captured. RE log emitted a missing-character warning for `≈` around an estimated `370` readout; V1.5 now uses ASCII `~` for the kinematic estimate.

## Source evidence: MR auxiliary demands may use a PTO-named engine accounting path

Exact MoreRealistic source `quadural/MoreRealistic_FS25@b38d5667e073505255cd7ce170ab568616a91221`:
- `MoreRealistic/data/overriding/vehicles/horsch/avatar1225.xml`: `vehicle.powerConsumer#ptoRpm=340`, `neededMaxPtoPower=22`. Inline note describes the pneumatic seed/fertilizer fan and electric distribution. Neither value identifies a 340-rpm physical PTO gearbox. The exact in-game attachment input-count has not yet been sampled; user's observation is no visible cardan.
- `MoreRealistic/scripts/MR_PowerConsumer.lua`: `mrUpdatePtoPower` uses `getDoConsumePtoPower()` and `getConsumingLoad()` to compute `mrLastNeededPtoPower` and `mrGetConsumedPtoTorque` converts this power demand to engine/drivetrain-model PTO torque. Generic consumers get a min+load*(max-min) model; active demand is not necessarily the 22 kW maximum. MR/FS25 names this channel PTO even for indirect auxiliary power. The routine is gated by active consumption and must not be assumed to have run from XML alone.
- `MR_WheelsUtil.lua` / MR motor remain owners of engine/drivetrain power. RE should neither remove nor duplicate these kW/torque demands.

Separately, the Horsch's ground-tool drag and MR mass/rolling resistance plus Mud/wet-soil traction explain why a relatively small tractor can struggle. Do not translate PTO UI warnings into motor/soil diagnoses.

## Ownership model

| Owner | Contract |
| --- | --- |
| GIANTS/native | implements' on/off, attachment input/output, existing PowerConsumer API, work semantics |
| MR | actual engine RPM, engine torque/power, scalar auxiliary or shaft-driven demand through modeled PowerConsumer and draft |
| RMS | mechanical PTO wear/failures only when applicable |
| RE | evidence-based physical PTO gear selection, operator/AI interlock, truthful UI, read-only diagnostic classification |
| RC | narrow state/ratio translation to MR/RMS for evidence-backed mechanical drive; no auxiliary-power shadow accounting |
| Dynamic PTO | alternative PTO owner if explicitly selected after exact-source review; not simultaneously with RE |

The display may show `540` even without a connected shaft: this is the *tractor-selected physical gearbox*. Future UI must differentiate gearbox **available/selected**, connected mechanical input, and operating/engaged state, without hiding an actual tractor control. Consider a neutral idle/disconnected indicator after an in-game observation; avoid false certainty if native input declarations are incomplete.

## V1.5 changes made after log analysis

- HUD replaces unsupported `≈` glyph with `~` for *estimated* engine/ratio-derived PTO speed; not a shaft sensor.
- Read-only inspector now logs every attached tool's `mrLastNeededPtoPower` (`mrLoadKW`), modeled `getConsumedPtoTorque` (`mrTorqueKNm` when MR is active), declared min/max kW, and native PTO input presence. This includes a seeder with **no** physical shaft.
- The inspector harness uses a Horsch-style non-mechanical consumer, with nonzero modeled MR load, preserving distinction between `hasPtoConsumer=false` and `mrLoadKW>0`. No new physics, power penalties or engine hooks.

## Proposed V1.6 capability/consumption report (not implemented)

Independent fields with provenance:
- `mechanicalDrive`: `CONNECTED | DECLARED_UNCONNECTED | UNKNOWN`, as observed from native input structures and linkage. Do not mistake missing API data for absence of a cardan.
- `nominalGearFamilyRpm`: resolved only from exact model/variant evidence; `nil` for load-only values like 340/400/500.
- `powerConsumerRpm`: original raw MR/GIANTS demand. Preserve and expose but never reinterpret as physical nominal gear.
- `auxiliaryPowerModelKW`: optional read-only snapshot of MR current and declared min/max power, with `source=MR_POWER_CONSUMER`, no implied mechanical transmission.
- `engagement`: native implement on/off and PTO active paths as separate observations; don't collapse mere turn-on into proof of coupled shaft.
- `evidence`: `NATIVE_LINK | EXACT_OEM_VARIANT | MOD_DECLARATION | PLAYER_VISUAL | UNKNOWN`, maintaining limitations of each source.

Do not replace the existing `requiredShaftRpm` public API with a breaking rename. Introduce typed optional diagnostics first; integrate only after harness and runtime evidence.

## Immediate acceptance criteria

A single Fiat/Horsch `rePTOInspect` capture with the implement **off and then actively sowing**, without changing PTO gearbox, will test whether `getDoConsumePtoPower` and MR `mrLastNeededPtoPower` transition. Comparing to a disconnected state can separate `hasPtoConsumer=false` from `MR auxiliaryPower>0`. Include `inputPto`, `mrLoadKW`, `mrTorqueKNm`, `powerMaxKW`, `engineRPM` and `engaged` from log. If the actual load is missing, inspect MR PowerConsumer/TurnOnVehicle before changing models.

Then classify implement-specific gaps: baler PTO-driven feed/stroke speed vs existing MR stroke *load*, woodchipper feed cutoff already in MR, mowers/conveyors and any real hydraulic/electric accessory behavior. A category hook should be proposed only for a measured missing output semantic; no global work-speed multiplier, synthetic engine-load multiplier, always-stall or false generator penalty.

Dynamic PTO 1.1.3.1 public claims were recorded in RC `docs/audits/2026-10-12-dynamic-pto-1.1.3.1-preliminary.md` as **non-source-verified**. Do not switch production PTO owners on release notes alone.
