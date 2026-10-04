# Hydraulic Suspension runtime test plan

Baseline: exact external `1.6.9.0` package plus current target stack.

Purpose: learn the engine behavior and validate the phenomenon. This plan does not imply the external mod will remain installed.

## A. Baseline without HSS

Run with target MR/RC/Mud/RMS stack, HSS OFF.

For at least:
- one large tractor whose front suspension is visually modeled;
- one tractor with simple front wheel suspension;
- one independent-suspension candidate if available.

Record:
- static front suspension length;
- front wheel loads;
- spring/damping values/multipliers if diagnostic access allows;
- response over one bump;
- response after adding/removing front ballast;
- heavy rear implement weight transfer.

Goal: establish what vanilla + MR already owns.

## B. HSS ownership observation

HSS ON, same machines.

Verify:
- when MR calls suspension multipliers;
- whether HSS suppresses them as source predicts;
- effective front spring/damping after suppression;
- whether rear MR behavior remains different from front.

This test is diagnostic, not a target behavior.

## C. Load leveling

Change front/rear load in controlled steps.

Measure:
- ride-height error before leveling;
- settling time;
- overshoot;
- final suspension stroke;
- left/right load difference.

Compare current HSS load-ratio controller with the proposed ride-height closed loop.

## D. Mode transitions

AUTO -> WORK -> LOCKED -> MANUAL where supported.

Look for:
- ride-height jumps;
- wheel-shape rebuilds;
- spring/damping discontinuities;
- tire visual deformation discontinuity;
- MR state divergence.

## E. Bump / articulation

Test:
- one wheel over a rock;
- diagonal ditch;
- repeated rough road;
- low-speed crawl.

Separate:
- real physics movement;
- wheel visual movement;
- synthetic `positionY` movement.

Especially validate vehicles whose XML already has a physical axle component/joint.

## F. Power hop

Create a repeatable high-draft/slip case.

Record:
- front/rear slip;
- suspension stroke;
- vertical load;
- chassis pitch/vertical acceleration if available.

Question:
Does slip residual correlate reliably with actual vertical hop?

The result informs the clean RE detector.

## G. Braking/acceleration pitch

Repeat hard brake and launch.

Compare:
- `getLastSpeed` derivative;
- body acceleration if available;
- actual front suspension response.

## H. Multiplayer authority

On dedicated/server + client:
- owner changes mode;
- another player in same farm attempts to change the vehicle remotely if practical;
- different-farm client attempts request;
- manual height spam.

A future RE implementation must reject unauthorized transitions.

## I. Physics rebuild lifecycle

Trigger:
- vehicle reset;
- workshop/configuration change;
- leave/re-enter physics;
- load second save in same process.

Check suspension hook/visual ownership remains singular.

## Evidence wanted for clean implementation

- exact logs around MR suspension calls;
- wheel/suspension diagnostics before/after HSS;
- video/screenshots for ride-height and bump behavior;
- save/reload behavior;
- MP logs from both sides.

The most important output is the **MR composition contract**, not a subjective "feels softer".
