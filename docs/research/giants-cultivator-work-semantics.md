# GIANTS Cultivator work semantics

Updated: 2026-10-02

Source basis: current FS25 Lua API mirror, `vehicles/specializations/Cultivator.lua`, audited at commit `9478ee9245f7f95fdff98a887ad3b2f713340f8a`.

## Important distinctions

`Cultivator.processCultivatorArea` produces both:
- `realArea`: area whose agricultural/density-map state actually changed;
- `area`: total processed work area.

They are not interchangeable.

A repeated pass over already-cultivated terrain may remain a real physical cultivator operation while producing little or zero `realArea`.

The specialization also owns `spec.isWorking` and work-area activation independently.

## Lifecycle observations

- `onStartWorkAreaProcessing` resets `spec.isWorking=false` and per-frame area statistics.
- individual work-area processing can set working state based on actual processing/movement;
- `onEndWorkAreaProcessing` uses `spec.isWorking` for cultivated-time behavior/effects;
- `getIsWorkAreaActive` can gate cultivator work based on activation timeout and lowered state.

## RE rule

Never infer "implement physically not working" from `realArea == 0`.

For recovery and temporary suppression of RE persistent wheel ruts:
- use work-area activation / physical work semantics;
- use processed `area` for repeated-pass eligibility;
- retain `realArea` only as evidence of agricultural state change.

## Regression scenarios

The following must remain distinct in harness/runtime telemetry:

1. first pass:
   `realArea > 0, area > 0, isWorking=true`

2. repeated pass:
   `realArea = 0, area > 0, isWorking=true`

3. inactive/lifted:
   `area = 0` and/or work area inactive

4. moving/transport with implement raised:
   wheel deformation may occur normally; cultivator recovery/suppression must not be inferred merely from attachment.

This distinction is now a project-level semantic contract, not a v22-specific workaround.
