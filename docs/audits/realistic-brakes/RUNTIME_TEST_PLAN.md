# Realistic Brakes 1.3 — runtime test plan

Status: static source audit complete; runtime pending.

Purpose:
- decide whether RB can safely join the target stack;
- validate static findings;
- separate useful capability from ownership conflicts;
- provide comparison evidence for any future assimilation.

## A. Baseline / provenance

### RB-T01 — clean baseline
Vanilla-compatible truck with RB only.

Capture:
- exact RB build/version;
- parking state;
- exhaust mode/level;
- brake temperature/fade;
- trailer air state.

Expected:
- no script errors;
- exact package provenance recorded.

### RB-T02 — second save same process
Save A -> menu -> Save B.

Expected:
- no duplicate hooks/commands;
- HUD/settings work once;
- no stale per-vehicle state.

## B. Parking brake

### RB-T03 — slope/mass hold boundary
Same truck at several:
- loads;
- slopes;
- gear/neutral states.

Measure actual roll/hold around source classifier threshold.

Goal:
- characterize discontinuity;
- compare computed threshold to physical outcome.

### RB-T04 — parking brake while moving
Apply at low/medium/high speed.

Measure:
- deceleration;
- wheel slip;
- brake temperature;
- final hold.

Expected source behavior:
- moving parking brake contributes full thermal pedal demand while hold is not exceeded.

### RB-T05 — manual clutch vehicle
Test park on/off with clutch released/pressed.

Verify direct brake-pedal restoration does not erase another braking owner.

## C. MR conflict

### RB-T06 — MR engine brake baseline
MR only:
- coast in fixed gear/RPM/speed;
- record deceleration, RPM, gear.

### RB-T07 — MR + RB engine brake
Repeat with RB:
- exhaust off;
- levels 1/2/3;
- auto downshift.

Inspect:
- lowBrakeForceScale;
- gear decisions;
- oscillation/double braking;
- load/engine response.

Exit gate:
RB engine-brake physical owner is not accepted into target stack until this overlap is resolved.

### RB-T08 — automatic downshift accumulation
Long downhill with RPM below RB target.

Count:
- downshift requests;
- actual gears skipped;
- cadence.

Verify whether repeated per-frame one-step requests exceed intended max-downshift concept.

## D. RMS / Enhanced Vehicle parking ownership

### RB-T09 — RB + RMS
Matrix:
- RMS parking enabled/disabled if configurable;
- RB parking on/off.

Observe:
- which state holds vehicle;
- auto release;
- AI release;
- duplicate brake demand.

### RB-T10 — RB + Enhanced Vehicle
Toggle each parking control.

Confirm:
- RB forces EV private parking state off;
- EV other functions remain stable;
- no state flicker/network fight.

### RB-T11 — RB + RMS + EV
Most important ownership matrix.

Expected:
- identify actual final parking owner;
- no path where RMS steps aside for EV while RB disables EV and nobody safely owns final hold;
- no double-force path.

## E. Thermal / fade

### RB-T12 — controlled downhill energy profile
Same vehicle/load/slope:
- service brake only;
- engine brake only;
- mixed.

Record temperature vs:
- speed;
- pedal;
- deceleration;
- elapsed time.

Goal:
test whether pedal-proxy heat matches qualitative mechanical work.

### RB-T13 — FPS/cadence invariance
Same braking scenario at several FPS limits.

Expected:
- cooling nearly invariant due exact exponential;
- heating should remain close if update dt is correct.

### RB-T14 — AI thermal parity
Same descent:
- PLAYER;
- GIANTS AI;
- Courseplay;
- AutoDrive.

Determine whether brakeTempC actually rises under AI as comments suggest.

This specifically tests the source ambiguity around axisForward.

### RB-T15 — fade physical effect
Heat from cold through fade zones.

Measure:
- stopping distance;
- brake force/effectiveness;
- temperature.

Then cool:
- temporary fade recovers;
- permanent damage ceiling does not.

### RB-T16 — repair semantics with RMS
Create RB permanent brake damage, then:
- vanilla repair;
- RMS service/repair actions;
- unrelated generic damage changes.

Determine what actually resets RB damage.

## F. Trailer hose semantics

### RB-T17 — both hoses connected
RDS truck + air-brake trailer.

Record truck/trailer pressure after connection.

Expected current source:
instant equalization.

### RB-T18 — supply only disconnected
Keep service/control line connected, disconnect red supply.

Expected physically:
- trailer spring brake applies.

### RB-T19 — service only disconnected
Keep red supply connected, disconnect yellow service.

Source prediction:
RB currently applies spring brake anyway.

Physical target:
- spring release should remain while supply pressure is healthy;
- service braking command should be unavailable/degraded.

This is a deliberate regression test for future RE model.

### RB-T20 — no RDS truck pressure owner
Trailer with hoses behind a tractor/truck lacking rdsGetAirPressure.

Characterize:
- disconnected-hose lock;
- connected state;
- pressure/HUD behavior.

## G. Trailer reservoir / conservation

### RB-T21 — empty trailer connection
High-pressure truck + empty trailer.

Record immediate pressure change.

Compare against source weighted-average formula.

### RB-T22 — different wheel counts
Same truck with trailers of different wheel counts.

Confirm proxy capacity changes equalization as expected.

### RB-T23 — finite fill observation
After instant equalization, measure refill curve through RDS compressor.

This provides a baseline to compare future finite-flow RE model.

### RB-T24 — disconnected pressure persistence
Charge trailer, disconnect, wait, save/reload.

Expected RB:
no modeled runtime leakage; saved pressure remains.

### RB-T25 — service-brake applications
Repeatedly apply/release trailer brakes while connected/disconnected as possible.

Expected source:
custom trailer reservoir itself does not lose pressure from service applications.

This validates missing service-demand coupling.

## H. Protection / low-air

### RB-T26 — truck reserve
Connect nearly empty large trailer to marginal-pressure truck.

Observe whether truck pressure can be pulled below a safe reserve.

Expected source:
no tractor-protection cutoff.

### RB-T27 — spring threshold
Sweep trailer pressure across ~4.14 bar.

Observe:
- apply;
- release;
- chatter/hysteresis.

### RB-T28 — wheel drag on different surfaces
Spring brake active:
- asphalt/high grip;
- gravel;
- mud/low grip;
- empty vs loaded trailer.

Expected:
wheel physics determines drag/skid; RB should not change friction directly.

## I. Trailer wheel/axle topology

### RB-T29 — semi load distribution
Loaded semi where tractor carries significant kingpin load.

Compare source torque proxy against measured wheel loads if available.

### RB-T30 — multi-axle trailer
Determine whether all wheels receive custom spring-brake force.

Expected source:
yes.

Future profile may differ.

## J. Native AIR metadata

### RB-T31 — attachable airConsumer inventory
Inspect representative trailers:
- presence/value of vehicle.attachable.airConsumer#usage;
- number of air hoses;
- native brake force;
- RB trailer specialization eligibility.

Goal:
determine whether native airConsumer metadata is useful capability/demand evidence for RE P0.

### RB-T32 — native towing AIR interaction
Measure towing vehicle native:
- AIR fill level;
- getAirConsumerUsage();
- lastAirUsage;
- doRefill
with/without trailer.

Repeat with MR + soundExpansion.

This closes the native-AIR backend decision with actual current stack evidence.

## K. Controllers

### RB-T33 — Courseplay
Trailer + main RB behavior during:
- start;
- stop;
- slope;
- low air.

### RB-T34 — Follow Me
Same.

### RB-T35 — AutoDrive
Same.

High priority because AutoDrive is not explicitly handled in exact RB source.

Verify whether:
- main RB thinks no AI job;
- trailer logic differs;
- parking/spring state blocks or bypasses unexpectedly.

## L. Multiplayer / authority

### RB-T36 — join in progress main state
Join with:
- hot brakes;
- permanent damage;
- parking on;
- exhaust level.

Expected:
full main initial state immediately.

### RB-T37 — join in progress trailer pressure
Join while connected trailer pressure differs or during any future finite-flow experiment.

Current RB has no explicit trailer-pressure stream.

Characterize visible/client state.

### RB-T38 — unauthorized park request
Client A sends/attempts park event targeting Client B vehicle.

Expected current source risk:
server lacks controller validation.

### RB-T39 — unauthorized exhaust request
Same for exhaust state/level.

### RB-T40 — mismatched local settings
Host/client intentionally use different:
- fadeScale;
- trailerAir;
- exhaustAuto/level.

Observe divergence.

## M. Performance

### RB-T41 — parked fleet
Many unattended vehicles on small slopes.

Measure with:
- parking exceeded;
- after 8-second wake window;
- RB disabled baseline.

Goal:
verify the historical forced-wake FPS issue is bounded in 1.3.

### RB-T42 — active fleet
Multiple moving RB vehicles + trailers.

Profile:
- RB onUpdate;
- wheel hooks;
- trailer air;
- HUD.

### RB-T43 — repeated connect/disconnect
Stress hose lifecycle and trailer custom-force restoration.

## N. Stack adoption exit gate

Before calling RB safe for the target stack:
- MR engine-brake overlap has a deliberate solution;
- RMS/EV parking ownership has a deliberate solution;
- AutoDrive/Courseplay/AI behavior is characterized;
- MP event authority is understood/fixed or accepted for local testing only;
- local physical settings divergence is addressed;
- trailer supply/service-line behavior is understood;
- no material performance regression in realistic fleet size.

Absorption is **not** required to pass this gate. A clean external integration is a valid outcome.


## O. Exact MR wrapper-order / partial-composition tests

### RB-T44 — hook identity and load order
Capture runtime identity/order for:
- WheelsUtil.updateWheelsPhysics;
- WheelsUtil.getSmoothedAcceleratorAndBrakePedals.

Test both practical mod load orders if controllable.

Expected:
- determine whether RB wheel-physics hook runs on MR normal path;
- determine whether RB smoothed-pedal hook still feeds MR;
- no assumption that "loads without error" means full RB behavior is active.

### RB-T45 — MR normal path vs AutoDrive fallback
Same parking scenario:
- player/manual MR path;
- AutoDrive active.

Record:
- RB callback counters;
- pedal demand;
- brake force;
- actual deceleration/hold.

Goal:
detect RB behavior disappearing/reappearing when MR chooses super fallback.

## P. Physical-model characterization

### RB-T46 — low-speed thermal floor
Same vehicle/load/pedal at approximately:
- 5 km/h;
- 15 km/h;
- 30 km/h;
- 40+ km/h.

Source predicts a flat speedFactor contribution below ~33 km/h.

This characterizes the gameplay proxy before comparing an energy-based model.

### RB-T47 — free-roll suppression of base brake force
Create a scenario where another owner/base path contributes nonzero brake force
while RB parking is released or hold-exceeded.

Measure before/after RB's PARK_SLIP_BRAKE_FACTOR path.

Goal:
prove whether RB reduces another owner's base braking to ~6%, not merely its
own parking force.

## Q. Developer diagnostics lesson

### RB-T48 — action-registration failure probe
Use a deliberately colliding key/action with a moving-tool vehicle and compare
RBDiagBrazo output against actual action-event registration.

Purpose:
validate the generic diagnostic concept for a future RE dev service, not to
adopt the RB implementation.

Exit:
document the minimum stable GIANTS surfaces needed for generic input/action
diagnostics.


## O. Final source-pass regressions

### RB-T44 — parking save-schema regression
Save two vehicles:
- parking ON;
- parking OFF.

Reload.

Expected after upstream/fix:
- each state survives independently;
- no XML path validation warning;
- old save without the key uses documented default.

Current exact-source prediction:
`parkBrakeOn` path is not registered in the save schema.

### RB-T45 — long inactive cooling
Heat brakes, then leave vehicle inactive for:
- 60 s;
- 299 s;
- 301 s;
- long sleep/time acceleration.

Compare against closed-form exponential cooling.

Expected current source:
- <300 s gap can reconcile from mission clock;
- >=300 s gap falls back to ordinary dt and can remain too hot.

### RB-T46 — hot save/reload cooling
Save a hot vehicle, advance meaningful game time / reload according to test
setup.

Expected current source:
- temperature persists;
- no persisted thermal timestamp applies elapsed cooling.

Future target:
bounded timestamp-based exact reconciliation.

### RB-T47 — dragged failed parking brake thermal
Put parking brake ON on a slope/load that exceeds the hold classifier and allow
the vehicle to roll/drag.

Compare temperature against:
- same motion with parking off;
- parking holding successfully.

Goal:
confirm whether `parkHoldExceeded` removes the intended parking thermal
contribution despite real brake drag.

### RB-T48 — full-stack input registration
With the normal large mod keymap:
- default B exhaust toggle;
- default N parking toggle;
- custom remaps.

Inspect:
- both action events register;
- callback counts;
- no silent collision;
- custom mappings survive.

If upstream changes defaults, preserve user customization rather than
overwriting it.

### RB-T49 — capability-disable matrix
If independent upstream/module switches are added, test:
- thermal ON / retarder OFF / parking OFF / trailer ON;
- MR remains sole engine-brake owner;
- RMS/EV remains sole parking owner;
- RB thermal/trailer continue normally.

This is a high-value adoption configuration for the target stack.


### RB-T50 — stale restore ownership

#### Motor baseline
1. let RB capture motor low-brake baseline;
2. while RB owns player retarder state, simulate/observe an MR/owner baseline
   change;
3. leave player control so RB performs its restore.

Expected safe target:
the newer authoritative owner state survives.

Current source risk:
RB restores the original captured snapshot.

#### Trailer custom brake force
1. apply RB trailer spring brake so it snapshots `customBrakeForce`;
2. alter the baseline through another legitimate owner;
3. release spring state.

Expected safe target:
new owner baseline survives.

Current source risk:
RB restores the stale pre-spring snapshot.
