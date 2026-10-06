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


# Release 1.7.0.0 additional runtime plan

The original A-K decision/drivetrain tests remain valid. Add the following for the new settings/HUD layer and the coverage gaps found during this review.

## L. Settings authority matrix

Test:
1. single-player;
2. listen server + client;
3. dedicated server + client.

Deliberately give server and client different profile settings for:
- road speed limit;
- brake engagement;
- implement-lowered engagement;
- prediction strength;
- manual tire pressure.

Record:
- value shown in each Settings menu;
- value used by server decision logs;
- whether client input is locally blocked before sending;
- whether server accepts/rejects the request;
- resulting HUD state.

Goal:
prove which values are authoritative and where local config leaks into behavior/presentation.

Target architecture must have one authoritative simulation config.

## M. Live toggle of manual tire pressure

On a generic tractor without built-in CTIS:

### Case 1
- start mission with `manualTirePressure=true`;
- confirm pressure actions/HUD exist;
- turn it OFF in the new menu;
- re-register action events if practical;
- test pressure keys without reloading vehicle.

### Case 2
- start with it false;
- turn it ON at runtime;
- check whether the current vehicle gains the feature.

Expected from static source:
- existing `spec.hasCtis/ctisMode` remains unchanged until vehicle capability is rebuilt/reloaded.

This test determines whether the UI should become:
- explicit reload-required; or
- backed by a real live rebind implementation.

## N. Server/client pressure capability mismatch

Dedicated server.

Run both mismatches:

### Server OFF / client ON
Check:
- client pressure actions;
- pressure HUD;
- client visual/radius response;
- server effective wheel radius/pressure behavior;
- event/broadcast traffic.

### Server ON / client OFF
Check:
- server pressure simulation;
- client pressure actions/HUD;
- client tire visual/radius response.

Goal:
characterize the consequence of not synchronizing `hasCtis/ctisMode`.

A future implementation must make capability identity authoritative.

## O. Smart-mode settings correctness

With Smart mode, independently disable:
- `brakeEngage`;
- `engageOnImplementLower`.

Then trigger:
- braking above 3 km/h;
- lowered implement on field with otherwise low traction demand.

Static source predicts:
- brake can still drive Smart target;
- lowered implement can still contribute `smartImplementLevel`.

Log:
- canonical sensor state;
- configured setting;
- target level;
- reason;
- engage level.

This validates 4WD-06 and 4WD-32 as user-visible settings defects.

## P. Dedicated-server terminal tuning

On a dedicated client:
- open the 4x4 terminal;
- change slip-engage threshold;
- change slip-disengage threshold;
- change terrain strength;
- repeat a controlled traction event.

Compare:
- client terminal value;
- server debug/log value;
- actual trigger threshold.

Then press telemetry reset and compare:
- client terminal;
- server persisted telemetry after save/reload.

Static expectation:
- tuning/reset is local-only and does not mutate server authority.

## Q. Manual-event authoritative safety

Use an instrumented test client or temporary debug harness to send requests that normal UI would prevent:
- engage rear/front lock above lock speed;
- engage front lock while 4WD is not effectively engaged;
- close/lock center above lock speed;
- same-farm non-controller request.

Record server:
- acceptance/rejection;
- immediate physical state;
- next automatic safety update;
- center-lock persistence.

Do not use this test to justify an RC hotfix. Its purpose is to define the validation contract any future RMS/advisor API must enforce.

## R. Settings-menu lifecycle across missions/mod sets

Within one game process:
- load save A with the mod;
- return to menu;
- load save B with the mod;
- if practical, load a save/mod set without it and then back again.

Check:
- duplicate section headers;
- duplicate option rows;
- stale callbacks/menu objects;
- whether old registry entries persist;
- focus/navigation integrity.

The shared registry pattern is promising, but needs explicit lifecycle proof before reuse.

## S. HUD asset/cache lifecycle

Use icon HUD and cycle through many vehicle models so multiple shop-photo overlays are cached.

Then:
- change save;
- reload mission;
- change HUD style;
- disable/show photo repeatedly.

Observe:
- memory/resource growth if measurable;
- stale/missing store images;
- duplicate overlay creation;
- whether map unload frees handles automatically.

Target RE UI infrastructure should pair cache ownership with teardown even if the engine later proves forgiving.

## T. RMS coexistence claim

Controlled comparison only; do not treat dual ownership as target architecture.

With current RMS:
- log differential graph/topology before both mods initialize;
- after RMS mode changes;
- after external 4x4 engage/lock ramps;
- after vehicle reset/workshop.

Look for:
- which owner writes last;
- graph restoration/rebuild churn;
- stale topology assumptions;
- effective driven-wheel state disagreement.

The success criterion is **not** "no crash".

The question is:
> is there a stable ownership/composition contract?

Static evidence predicts no explicit contract; therefore the preferred final design remains RMS ownership plus improved AUTO semantics.

## Updated evidence needed before implementation

In addition to the original evidence:
- authoritative server settings snapshot;
- client-visible settings snapshot;
- capability identity (`hasCtis/ctisMode`) on server and client;
- accepted/rejected manual request logs;
- per-vehicle tuning value on both sides;
- HUD resource/lifecycle observations.

These results should inform shared configuration/network architecture even if no 4x4 feature is absorbed into RE.
