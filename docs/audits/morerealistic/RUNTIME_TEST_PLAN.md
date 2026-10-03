# MoreRealistic focused runtime test plan

All tests are deferred until the game machine is available.

Use the project's evidence ladder. Static findings are not runtime proof.

## T1 — rolling-resistance wetness endpoint continuity

Hypothesis:
driven-wheel RR differs discontinuously at exactly 0/1 wetness because `isDrivenWheel` is omitted at the endpoint branches.

Hold constant:
- vehicle;
- wheel configuration;
- load;
- ground type/subtype;
- speed.

Sample:
- 0.0000;
- 0.0001;
- 0.01;
- 0.99;
- 0.9999;
- 1.0000.

Record:
- pressureFx;
- raw dry/wet factor;
- isDriven;
- final rrFx;
- RR force.

Acceptance:
endpoint values converge to neighboring values after a fix.

## T2 — hydrostatic flag path

Goal:
prove whether `VehicleMotor.mrUpdate` sees hydrostatic identity.

Use a known converted hydrostatic vehicle.

Record:
- vehicle.mrTransmissionIsHydrostatic;
- motor.mrTransmissionIsHydrostatic;
- branch entry;
- clutch-slipping timer/ratio behavior.

## T3 — hydrostatic engine-brake initialization

Record immediately after load:
- XML explicit `mrEngineBrakingFx` presence;
- vehicle hydrostatic flag;
- motor `mrEngineBrakingPowerFx`.

Compare a hydrostatic vehicle with no explicit override against ordinary transmission.

## T4 — PTO turn-on peak

Use a tool with a known/high `turnOnPeakPowerMultiplier`.

A/B:
- exact MR;
- isolated fixed condition in test build/harness.

Record:
- turnOnPeakPowerTimer;
- ignoreTurnOnPeak;
- returned virtual multiplier;
- engine rpm/load during engagement.

## T5 — timestep/cadence sensitivity

Goal:
measure actual time constants, not frame counts.

Compare stable scenarios at different effective render/physics cadences.

Observe:
- mrDynamicFrictionScale;
- mrLastRrFx;
- mrLastTireLoadS/S2;
- fuel smoothing;
- CVT target smoothing;
- PTO power decay after shutoff.

Do not infer a problem from FPS alone; log number of relevant function calls per real second.

## T6 — global-vs-converted wheel behavior

Compare:
- MR-converted tractor;
- unconverted mod tractor;
- trailer;
- lightweight wheeled equipment.

Record:
- wheel mass before/after MR;
- rotation damping;
- MR friction coeff;
- RR;
- force-point position;
- drag/downforce;
- mass/CoM.

Purpose:
prove exact reach of GLOBAL ENGINE behavior.

## T7 — random damping reproducibility

Reload the same save/vehicle multiple times.

Record per wheel:
- XML/base rotation damping;
- MR final rotation damping.

Check:
- repeatability;
- server/client values in MP if later relevant;
- whether differences are physically observable.

## T8 — WorkArea stationary ownership

Scenarios:
- ordinary cultivator;
- power harrow configured to process while still;
- combine work area requiring ground contact;
- implement with `mrNoGroundDisplacementWhenLowered`.

Record:
- WorkArea active result;
- component ground speed;
- GIANTS displacement allowed;
- RE active-combination suppression;
- resulting terrain writers.

Acceptance:
no wheel-rut/work-area oscillation and no loss of legitimate stationary operation.

## T9 — player / GIANTS AI / Courseplay / AutoDrive parity

Same tractor+implement+field, same target speed.

Record:
- control-path owner;
- throttle/brake commands;
- gear;
- PTO demand;
- wheel slip;
- RR;
- task speed;
- engine load.

AutoDrive is expected to use MR global wheel physics but previous/base central wheel control. Quantify the behavioral difference rather than assuming parity.

## T10 — VCA/hand-throttle interoperability

Reproduce the current upstream hand-throttle complaint if VCA is in the target stack.

Determine which owner writes:
- requested engine rpm;
- accelerator intent;
- CVT/hydro target;
- PTO rpm floor.

Only then decide whether RC needs a controller adapter.

## T11 — moisture ownership matrix

Future combined test:
- vanilla global wetness;
- MR seasonal/night floor;
- Mud local wetness;
- MoistureSystem local moisture.

At four spatial points, record every source and the value actually consumed by:
- MR friction;
- MR RR;
- Mud;
- SoilCompaction/RMS through RC.

Acceptance:
one explicit provenance chain; no accidental double damp/wetness amplification.

## T12 — custom-map surface classification

Use known custom terrain layers/material names.

Compare MR `groundType/subType` against visual/semantic surface.

Identify whether exact sound-material name matching misclassifies surfaces.

## T13 — mass/CoM contributors

Use:
- partially/full loaded high trailer;
- tension-belt cargo;
- dynamic-mounted object;
- wheel ballast/additional wheels.

Record:
- contributor mass+CoM;
- combined target CoM;
- actual physical CoM over time;
- total mass.

Specifically exercise DynamicMountAttacher because the exact source marks it untested.

## T14 — yield/process ordering

For any newly adopted crop/yield mod:
- hold crop and machine constant;
- capture liters entering MR throughput accounting;
- capture final liters after foreign modifier;
- capture MR power/speed model.

Any mismatch should be solved by dataflow/order composition, as with MRSoilHarvest.

## T15 — teardown/persistence

Exact 0.26.08.03:
- verify whether `mrVehicleMorePower` survives map teardown due command-name mismatch.

Also verify:
- saved vehicle filenames remain genuine;
- MR can be disabled/re-enabled without orphaning converted base vehicles.
