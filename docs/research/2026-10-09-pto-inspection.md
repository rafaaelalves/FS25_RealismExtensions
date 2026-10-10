# PTO live diagnosis — on-demand, read-only probe

Status: experimental diagnostic tooling (no PTO mechanical behavior changed).

Branch `feat/pto-on-demand-inspection` is based directly on RE `main`, separate from draft PR #39's provisional 500→540 sprayer assumptions and separate from terrain work. The existing `PTOHUD.lua`, `PTOControl.lua`, `PTOResolver.lua`, RC, MR and RMS are untouched.

## Why

A chipper now respects manual hand throttle but a baler still raises engine RPM; earlier a plow/cultivator appeared to use PTO; multiple trailed sprayers show native demand of 340/400/500 rather than 540/1000. Distinguish at runtime:
1. Whether RE reports an attached PTO consumer and conflict for the controlled tractor.
2. Whether the implement exposes a real `inputPowerTakeOffs` list and whether any input has a non-nil `connectedVehicle`.
3. The *raw* PowerConsumer `ptoRpm` versus the live getPtoRpm() (which may return zero when idle) and on/off state.
4. The motor speed/selected physical ratio/hand throttle and MR's last PTO rotational floors.

The command merely prints these values to the game log. It does **not** equate `ptoRpm` with tractor mechanical gear, infer real pump nominal RPM, change throttle, change selected ratio, turn on a tool, edit MR data, or require telemetry polling.

## Usage when convenient

With the tractor controlled, open the game console and type:

`rePTOInspect`

The command emits `[RealismExtensions] PTO INSPECT | ROOT ...`, `MOTOR ...` and `TOOL[1] ...` log lines. Compare before and after activating ONE implement (e.g. baler, then chipper). No need to repeat old save/load tests, change mods, or switch on per-frame telemetry.

Relevant fields:
- `hasConsumer`, `engaged`, `required`, `selected`, `gear`: snapshot of RE state (may be stale until attachment refresh).
- `rawConsumerRPM`: numeric field used by GIANTS/MR power demand, **not guaranteed nominal gearbox family**.
- `liveConsumerRPM`: `getPtoRpm()`, typically 0 when not running.
- `inputPto`, `connectedInput`: physical input declarations and observed non-nil connected vehicle; some game implementations may bind via another runtime path.
- `powerKW`: raw declared max/needed PTO power.
- `nominalFamily`, `gearCompatibility`, `known`, `unknown`: RE's **inferred/evidenced physical gearbox family** and tri-state conclusion, independent of raw load RPM. `UNKNOWN` does not prove mechanical mismatch.
- `mrPtoCurrentRPM`, `mrPtoRpmRatio`: MR's per-tool calculated kinematic speed and speed ratio; these are read-only internal values, not a sensor. Values may be stale or absent if MR is not installed or the tool is inactive.
- `forcePtoRpm`: MR's per-implement explicit engine governor request flag (if present); do not confuse it with the tractor's physical PTO gear.
- `mrBalerPowerKW`: MR's last modelled baler power consumption, if present, for comparing transient compressor loads to tractor response. No new load is added by the inspector.
- `mrMinPtoRot` and `mrMinPtoIdleRot`: **radians per second**, NOT RPM; do not compare to engine RPM without converting. Values are the last reported MR state, not an independent RPM control proof.
- `maxPtoDemand`: aggregate `PowerConsumer.getMaxPtoRpm` result; it can differ from static raw XML and is for *active* consumers.

If a baler shows `hasConsumer=false` with a nonzero live consumer rpm, suspect RE consumer discovery. If `hasConsumer=true`, manual player, zero hand RPM yet engine rises, inspect RC/MR's remaining governor path. This is a differential hypothesis; the snapshot alone may not prove cause.

The harness exercises both off/on, physical vs generic consumers, nil safety, cycle defense, read-only outputs and console installation. CI builds test ZIP with no changes to physics.

## Follow-up

Use the source-level evidence plus this single on-demand sample to decide if a small bridge correction is needed. Resolve classification generically; do not add an unsupported mapping for every 340/400/500 sprayer.
