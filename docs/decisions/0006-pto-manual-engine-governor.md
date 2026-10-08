# ADR 0006 — PTO manual engine governor with causal load

Date: 2026-10-07
Status: runtime-validated on experimental PTO line; selective main-based RE/RC build smoke pending

## Context

The native RE PTO implementation already owns:
- operator-selected 540 / 540E / 1000 / 1000E state;
- persistent hand throttle;
- capability/profile resolution;
- mismatch/HUD/network/savegame state.

RC composes that state into MoreRealistic (MR) and RMS without replacing their
specialist domains.

Runtime causality telemetry proved that MR already provides the important
physical chain:

`PTO consumer demand -> engine torque/power -> motor load -> fuel`.

MR also already tracks actual PTO under-speed:
- `mrPtoCurrentRpm`;
- `mrPtoCurrentRpmRatio`;
- ratio-aware PTO torque/power;
- low-RPM draft consequences for some soil tools;
- explicit wood-crusher feed cutoff below a PTO-speed threshold.

Therefore RE/RC must not add generic synthetic PTO load, fuel, slow-work or
stall multipliers.

The remaining problem is engine-speed ownership. GIANTS and MR normally treat
an active PTO consumer as an engine-RPM request. That makes the RE hand
throttle largely redundant in ordinary PTO work.

## Source findings

### GIANTS standalone path

GIANTS `VehicleMotor.getRequiredMotorRpmRange()` derives a minimum engine RPM
from `PowerConsumer.getMaxPtoRpm(vehicle) * ptoMotorRpmRatio`.

GIANTS `VehicleMotor.update()` also independently uses
`PowerConsumer.getMaxPtoRpm()` to clamp displayed/equalized motor RPM.

Therefore a standalone RE implementation must neutralize both automatic paths
for player/manual PTO operation.

### MoreRealistic path

MR `WheelsUtil.updateWheelsPhysics()`:
- keeps real `neededPtoTorque`;
- asks `getRequiredMotorRpmRange()` for the PTO engine-speed target;
- stores `mrLastMinRotForPTO` / `mrLastMinRotForPTOidle`;
- feeds those targets into fixed, CVT and hydrostatic transmission control.

MR hydrostatic vehicles can additionally define PTO-specific transmission
engine-RPM targets:
- `mrTransmissionPtoModeMaxEngineRotWanted`;
- `mrTransmissionPtoModeMinEngineRotWanted`;
- `mrTransmissionPtoModeIsHydrostaticAutomotive`.

These are engine-management policy, not physical PTO load.

MR `VehicleMotor.update()` explicitly avoids the GIANTS PTO display-RPM
clamp and uses non-clamped physical motor RPM, so RC does not need to suppress
GIANTS `PowerConsumer.getMaxPtoRpm()` inside the MR motor update.

### Dynamic PTO reference

Dynamic PTO suppresses `PowerConsumer.getMaxPtoRpm()` globally for managed
vehicles and then applies its own hand-throttle RPM state. That proves the
general ownership concept, but RE/RC should use narrower scoped composition.

Dynamic PTO also contains broad work-speed/grunt/overload effects. Those are
not copied because MR already owns causal PTO load and several under-speed
consequences.

## Decision

### Player / non-AI manual PTO

When native RE PTO state is valid, a PTO consumer is attached, there is no
requirement conflict, and the vehicle is not AI-controlled:

1. selected PTO ratio still scopes into the specialist drivetrain;
2. the PTO consumer's physical torque remains intact;
3. automatic PTO engine-RPM requests are suppressed;
4. RE hand throttle is the only PTO-specific engine-RPM floor;
5. accelerator/transmission/load may still raise or pull down engine RPM
   naturally;
6. actual shaft speed derives from physical engine RPM and selected ratio;
7. MR keeps all of its torque, power, fuel and under-speed consequence model.

### AI

AI keeps GIANTS/MR automatic PTO RPM management. A worker must remain
autonomous and must not require player hand-throttle input.

### Unattended non-AI PTO

The manual model remains active after the player leaves the vehicle.

A persistent RE hand-throttle target continues to govern the engine. ROAD
releases that target, allowing an unattended PTO implement to remain
under-speed or stop performing according to specialist physics.

## Implementation boundary

### RE standalone

`PTOPhysics`:
- returns the engine's ordinary RPM range instead of the implement PTO request
  for manual-owned PTO state;
- scopes `PowerConsumer.getMaxPtoRpm()` to zero only while GIANTS
  `VehicleMotor.update()` handles that same root vehicle;
- restores every global function immediately;
- preserves automatic behavior for AI.

### RC + MR

`MRPTO`:
- keeps `neededPtoTorque` untouched;
- scopes MR `getRequiredMotorRpmRange()` to zero only inside MR-owned
  player/manual calls;
- neutralizes MR hydrostatic PTO-mode targets to the normal road targets only
  for the same synchronous scope;
- strips MR's recognizable PTO-only `mrMinEcoRot + 10` idle floor when it
  reaches `controlVehicle`;
- applies the RE hand throttle after removing that automatic PTO floor;
- restores all methods/fields immediately;
- leaves AI paths unchanged.

## Non-goals

This decision does not:
- add a PTO fuel multiplier;
- synthesize extra motor load;
- multiply generic implement work speed;
- generically turn implements off below a threshold;
- change MR PTO torque/power equations;
- change RMS wear/damage ownership;
- change AI PTO behavior;
- permanently mutate MR/GIANTS motor fields.

## Validation gates

A final runtime PASS requires:

1. player, PTO active, hand throttle ROAD:
   - engine no longer jumps to implement nominal RPM solely because PTO is on;
   - MR `mrMinPtoRpm` no longer reports the nominal PTO engine target;
   - PTO torque remains non-zero;
   - shaft RPM follows actual engine RPM / selected ratio.

2. player hand throttle:
   - +100/-100 RPM target controls the minimum engine RPM;
   - load can still pull actual RPM below the target physically.

3. AI:
   - worker continues to obtain automatic useful PTO RPM.

4. unattended non-AI:
   - configured hand throttle persists and powers the implement after exit.

5. RMS:
   - native ratio-capacity bridge remains active;
   - engagement/wear/damage stays owned by RMS.

6. save/load:
   - mode and hand throttle persist without XML-schema errors.

After runtime PASS, detailed PTO causality logging returns to SUMMARY level.


## Attachment classification refinement

A generic `spec_powerConsumer` is not evidence that an implement is connected
to the tractor through a mechanical PTO shaft.

Non-PTO tools can expose generic power-consumer state for draft, hydraulic,
electrical or other simulation purposes and can also have connection hoses or
electrical cables. Those connections must remain independent of PTO
classification.

Native PTO implement detection therefore fails closed and accepts only:
- an evidence-backed implement PTO profile;
- a real input PowerTakeOff exposed by GIANTS;
- an explicit positive `powerConsumer.ptoRpm`.

An input PTO with no known RPM is retained as a real but unknown PTO
requirement. A generic PowerConsumer, hoses/cables, TurnOnVehicle state, plow
specialization, etc. are not sufficient by themselves.

This is intentionally stricter than broad heuristic detection. A real mod PTO
implement that exposes none of the contracts above should receive a profile
rather than causing every generic powered implement to be guessed as PTO.

## Consolidation checkpoint — 2026-10-08

The previous experimental PTO line completed targeted in-game tests for non-PTO cultivator classification and actual 540-RPM PTO consumption, while harnesses covered player/AI/unattended control and mechanical bridges. The selective main-based branches (RE PR #33 and RC PR #16) now pass their CI harness/build gates. The last outstanding acceptance gate is a short **combined in-game smoke on the two clean artifacts**; this ADR is not final-release accepted until that passes. Never merge the experimental terrain history as part of PTO integration.
