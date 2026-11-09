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


## T16 — RR stale when friction is unchanged

Use `CHAINS` on `GROUND_SOFT_TERRAIN`.

Hold all geometry/load constant and transition wetness:
- 0;
- 0.5;
- 1.

Record:
- tire friction coefficient;
- base `mrTireGroundRollingResistanceCoeff`;
- final `mrLastRrFx`;
- RR force.

Critical case:
friction remains 0.76 while expected base RR changes from 0.030 to 0.060.

Acceptance after a fix:
RR follows wetness even when friction coefficient does not change.

## T17 — PowerConsumer maxGroundDistance control flow

Use a converted header with `mrPowerConsumer#maxGroundDistance`, PTO rpm and nonzero maxForce.

Exercise:
- header at normal ground distance;
- header raised beyond threshold while still active/turned on.

Record:
- function branch;
- turnOnPeakPowerTimer;
- mrLastNeededPtoPower;
- mrPtoCurrentRpmRatio;
- engine/PTO load.

Question:
does raising the header intentionally suppress only draft force, or incorrectly freeze the entire PTO update for that frame?

## T18 — same-mass center-of-mass redistribution

Use a multi-compartment vehicle where positioned fill-unit CoMs differ.

Scenario:
- start with mass M in compartment A;
- transfer approximately the same mass to B while keeping total component mass within the ~20 kg setMass threshold.

Record:
- contributor CoM from FillUnit helper;
- component.mass / lastMass;
- mrWwantedCOM;
- physical getCenterOfMass.

Expected current-source failure:
helper position changes while target/physical CoM remains stale.

## T19 — positioned + unpositioned mass mix

Construct or find a vehicle/component combining:
- at least one positioned MR contributor;
- additional mass without explicit resolved CoM.

Compare:
- physical total mass;
- positioned mass sum;
- target CoM denominator/result.

Purpose:
measure whether target CoM is materially biased by mass omitted from the positioned denominator.

## T20 — WoodCrusher material conservation

Create a capacity-constrained woodchip destination.

Record per update:
- mrWaitingFillLevel before;
- requested volumeToDeliver;
- FillUnit applied delta;
- mrWaitingFillLevel after;
- fill unit free capacity.

Invariant:
`queue_before - queue_after == applied_delta`.

Current source is expected to violate the invariant when applied delta < requested delta.

## T21 — CNH wheel ballast mapping

Load the exact CNH shared wheel weight asset if reachable from a current configuration.

Record:
- filename;
- input mass;
- expected 0.6 t special-case mass;
- final WheelVisualPart mass.

This determines whether F-22 is only dead data or a visible current-stack defect.

## T22 — process-model first-sample warm-up

For Mower/Tedder/Windrower/ForageWagon:
1. turn on and collect a stable sample;
2. turn off for a long interval;
3. reactivate and immediately process material.

Record:
- previous timestamp;
- sampleTime;
- liters/area buffer;
- computed throughput/power.

If first sample is diluted by inactive time, classify severity and decide whether timestamps should reset on activation.

## T23 — unconverted vehicle global drivetrain reach

Choose a mod vehicle with no MR conversion/override.

Record whether it still executes:
- MR VehicleMotor wrappers;
- MR `WheelsUtil.mrUpdateWheelsPhysics`;
- MR direction/gear logic;
- MR friction/RR.

This is not expected to fail; it validates the corrected ownership model and provider semantics.
