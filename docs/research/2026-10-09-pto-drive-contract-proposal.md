# PTO drive contract V1.6 — design proposal (NOT IMPLEMENTED)

Date: 2026-10-09. Status: **proposal for discussion**, not accepted runtime design.
Scope: **PTO only**, `feat/pto-v1-5-observability` / PR #39 draft; no terrain work and no MR/RMS ownership changes.

## Why this is needed

User inspected an actual visible PTO/cardanic drive on each of the trailed sprayers tested, including Hardi AEON 5200, Berthoud Vantage 4300, and newer John Deere R-series. Treat that in-game observation as real, **not as proof that all model variants are necessarily PTO-only**.

Reported native/MR `powerConsumer.ptoRpm` samples in logs:
- Hardi AEON 5200 and Berthoud Vantage 4300: **500** (MR source overrides, 7.5 and 12 kW).
- John Deere R732i PowrSpray: **340** (source value in log).
- John Deere R975i PowrSpray: **400** (source value in log).

RE currently treats these figures as **exact shaft gearbox families**, thus flags 540 and 1000 as incompatible by equality. The 500→540 mappings added in PR #39 were based on MR source identity plus reasonable mechanical interpretation, **not verified OEM factory configuration for the exact in-game variant**. They must remain draft, not merged as universally verified.

GIANTS documentation explicitly uses `PowerConsumer.ptoRpm` for **power/torque and required engine RPM calculations** (PowerConsumer and VehicleMotor), which does **not inherently encode the nominal 540/1000 gear selector**.
- FS22 legacy engine/source API: https://gdn.giants-software.com/documentation_scripting_fs22.php?category=48&class=533&version=script
- FS25 VehicleMotor: https://gdn.giants-software.com/documentation_scripting_fs25.php?category=91&class=896&version=script

OEM examples show configuration-dependent drive differences, not evidence of a unique PTO family:
- AEON manufacturer's product guide, pump 464/464H at 540 and 464H at 1000; possible hydraulic drive for 540 pump: https://www.homburg-holland.com/wp-content/uploads/2024/02/898855_EN_AEON_Product-guide_08-2023_OK.pdf
- Berthoud Vantage equipment spec has Omega pump and optional hydraulic pump drive: https://www.berthoud.uk/wp-content/uploads/2023/06/BERTHOUD_VANTAGE-_EN_24P_BD.pdf

## Proposed independent fields (do not collapse into one number)

A typed implement drive report:
- `connectionType`: `MECHANICAL_PTO | OTHER_DRIVE | UNKNOWN`. Prefer actual GIANTS `inputPowerTakeOffs` and relevant runtime linkage; a visual cardan observed by the user is strong manual evidence. *Never* infer purely from `ptoRpm > 0`; but do not deny a visible shaft simply because an OEM offers hydraulic variants.
- `ptoConsumerRpm`: raw numeric **load/governor demand** from the game/MR, e.g. 340/400/500. Preserve untouched for physics and diagnostics. Do not automatically call it shaft spline or rated gear.
- `nominalGearFamilyRpm`: `540 | 1000 | other explicitly supported | nil`, representing **operator gearbox family** only if validated for the *exact in-game configuration*. No guessed rounding to 540.
- `evidence`: provenance and confidence with `NATIVE_MECHANICAL_LINK`, `OEM_EXACT_VARIANT`, `OEM_FAMILY_ONLY`, `MOD_SOURCE`, `PLAYER_OBSERVATION`, `UNKNOWN`.
- `engagementState`: on/off/unknown; `source` from native implement (the HUD's `≈` estimate is kinematic, not a physical sensor).
- `neededPtoPowerKW`: original consumer value (optional), never synthesize fuel/torque penalties here.

Do **not** rename existing API fields without a backward-compatible migration; `requiredShaftRpm` is currently overloaded. Use a new explicit report for V1.6, then deprecate/alias carefully.

## State evaluation

Use a tri-state for gear compatibility:
- `COMPATIBLE`: nominal gearbox family is **evidenced**, installed mode belongs to that mechanical family. 540E and 540 share nominal family; likewise 1000 and 1000E.
- `INCOMPATIBLE`: nominal gearbox family is **evidenced**, selected mode is demonstrably from another family; explicit confirmed incompatible simultaneous shaft configurations may also be flagged.
- `UNKNOWN`: machine really has PTO, but source only gives governor/load RPM or the exact factory drive option is not verifiable. No red **mismatch** warning and no automatic gear change. Show that gear family is unverified rather than incorrectly displaying 340-vs-540 as mechanical failure.

Never turn on/off, block spraying, fake PTO mechanics, or override MR physics from a status icon. Return hard failures to engine/MR or a specific evidenced mechanical incompatibility implementation later.

Mixed 500 and 540 **load targets** are NOT necessarily conflicting physical gear families; future multiple-implement rules should compare independently known shaft families, not raw `ptoConsumerRpm` values.

## AI policy

- Confirmed nominal family + equipped tractor ratio: choose suitable non-economy mode before engagement; preserve operator preference and restore safely after PTO stops.
- Unknown family: keep operator gear, emit **one transition diagnostic** with raw demand and unknown gearbox family. Never invent a mapping from `340/400/500` to `540` or change an engaged shaft.
- Continue to let MR/GIANTS decide engine throttle and PTO power demand; RE supplies no independent engine governor during AI.

## Scope of simulation

**V1.6 (base):** accurate identification/observability, correct UI trinary status, MR/RMS compatibility, non-invasive AI behavior. This is useful without simulated hydraulic circuits.
**V2 optional:** evidence-backed implement response curves, e.g. low-speed feeding or pump pressure/flow only if source code demonstrates a gap not covered by MR and acceptance tests can show a measurable consequence. Prefer per-category modelling over a pile of brand exceptions; no global work-efficiency/fuel multipliers.
**Not a goal:** full internal CFD / hydraulic cylinder and hose pressure / separate microscopic pump model for every tool. Complexity requires an observable player benefit.

Owner matrix:
- GIANTS: native geometry, input/output linkage, equipment actions and turn-on prerequisites.
- MR: engine RPM, power/torque, transmission, PTO load; source numerical targets remain unmodified.
- RMS: wear/damage and failures.
- RE: gearbox selection, safe AI operator behavior, HUD and any demonstrated missing implement behavior.
- RC: narrow inter-mod bridges only; no shadow physics or general corrections to MR.

## Investigation and test matrix before any runtime patch

1. Audit base-game exact XML and game `PowerTakeOffs`, `PowerConsumer`, `TurnOnVehicle`, `Sprayer` contracts for the four sprayers, including variants. Determine whether a rendered cardan corresponds to actual `inputPowerTakeOffs` in the running object (not just a visual model).
2. Compare vanilla values to MR source overrides; record native `ptoRpm`, `getPtoRpm()`, power load, actual input list, current gear, engagement and turn-on result per equipment. Sample **on attachment and on state change**, not every frame.
3. Distinguish **UI warning** from **cannot turn on** from **turns on but does not spray** with optional event-scoped trace of GIANTS turn-on rejection and state (fill level, folding/booms, start motor, implement selected).
4. Test contract with fixed harness fixtures for 340, 400, 500, 540, 750, 900, 1000, 1300 (both physical input present/absent), OEM-confirmed 540/1000 cases and version-changed XML. No rounding. Unknown should not appear red.
5. Preserve existing regression tests for manual selector, 540E/1000E, AI interlock, persistence, RC/MR ratio and HUD observability. No terrain branches touched. One compact in-game smoke after static CI, not redundant older saved-game test cycles.

## PR #39 integration recommendation

Keep PR #39 **draft**, optionally split approved HUD/diagnostics into a safe PR and isolate PTO classification refactor into a later PR. Before merging #39, remove or validate the 500→540 **exact machine** assumptions against base game's concrete drive variant and replace simplistic exact-RPM mismatch. Source-driven profiles remain useful where they describe a *known gearbox family*, not merely a numerical `powerConsumer.ptoRpm`.

This is a plan document; do not interpret it as proof of the exact 540 vs 1000 configuration of each installed sprayer or as evidence the RE HUD warning physically blocks spraying.
