# Realistic 4x4 Traction System runtime test plan

Purpose: compare useful decision behavior against RMS and collect data for a better AUTO/lock policy. The external 4x4 mod is not intended to coexist permanently with RMS as a physical owner.

## Safety

Do not calibrate with both RMS drivetrain topology control and the external 4x4 physical writer active unless the session explicitly studies the conflict.

Prefer separate saves/sessions.

## A. Sensor characterization

On one conventional tractor record:
- primary/rear slip;
- front slip;
- wheel loads;
- local surface/wetness;
- draft;
- speed;
- steering;
- brake;
- motor load;
- grade.

Compare:
- 4x4 mod's private/fallback values;
- RC normalized values;
- RMS topology state.

Goal: quantify how much better the target-stack inputs are.

## B. Slip filter response

Repeat the same short traction-loss event at:
- 30 FPS;
- 60 FPS;
- high FPS if practical.

The shipped fixed-weight filter should show different real-time response.

Use results to choose dt-normalized time constants.

## C. Current RMS AUTO vs 4x4 decision

Same tractor/surface:
1. launch on dry field;
2. launch on wet/soft field;
3. heavy draft;
4. light lowered implement;
5. headland turn;
6. road acceleration;
7. one primary wheel loses grip;
8. steep climb;
9. heavy combination descent.

Log both *decision reasons*, not just whether 4WD was on.

Question:
Which cases improve materially over current RMS AUTO?

## D. Brake contradiction

With shipped 4x4 config `brakeEngage=false`:
- Smart mode;
- start disengaged;
- brake above threshold while >3 km/h.

Confirm whether target engagement rises as static source predicts.

## E. Topology coverage

External 4x4 only, RMS drivetrain owner OFF for this controlled test.

Try:
- conventional center differential;
- unusual four-wheel steering;
- articulated tractor;
- four-track vehicle;
- two-track excluded vehicle;
- multi-root/multi-axle machine if available.

Compare detected front/rear sets against actual geometry.

This is primarily evidence for why RMS topology should remain owner.

## F. Differential rebuild cost

Profile:
- Smart engagement ramp;
- diff-lock ramp;
- repeated partial target changes.

Count/measure graph rebuild frequency and updateMotorProperties cost.

This is not needed for target implementation but validates the ownership/performance conclusion.

## G. Traction reserve model

For a heavy draft case compare:
- source estimated demand;
- actual draft force;
- actual primary axle load;
- actual local effective grip;
- whether the primary axle is close to traction saturation.

This provides calibration points for a normalized demand equation.

## H. Descent

Controlled hill with:
- light implement;
- heavy trailer/implement;
- dry/high grip;
- wet/lower grip.

Measure required brake force vs primary axle capacity.

Use it to replace the fixed grade/mass heuristic.

## I. Lock semantics

Test open axle with one wheel:
- unloaded;
- low-grip;
- high-slip.

Observe whether a left/right asymmetry metric predicts lock need better than average axle slip.

## J. MP authority

On dedicated server:
- controlling client toggles;
- same-farm non-controller attempts toggle;
- other-farm client attempts;
- pressure/CTIS event paths if testing the external mod.

Future target integration must authorize control at server boundary.

## K. Cross-mod comparison

After the decision research, restore normal stack:
- RMS owns drivetrain;
- Mud owns CTIS;
- MR/RC composed.

The target outcome is not "external 4x4 works with everything".

It is:
> RMS AUTO/lock decisions gain the best useful semantics without adding another physics writer.

## Evidence needed before implementation

- logs of normalized wheel/axle load + slip + grip;
- RMS current AUTO reason/state;
- draft/motor load;
- hill grade;
- steering/brake state;
- comparative trigger timing.

A subjective "engages earlier" is not sufficient.
