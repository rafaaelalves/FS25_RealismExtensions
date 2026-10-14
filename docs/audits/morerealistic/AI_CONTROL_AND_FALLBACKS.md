# MoreRealistic AI, control and fallback audit

## Global motor/control reach

Second-pass source review corrected an earlier audit assumption.

MR globally overwrites:
- `VehicleMotor.new`;
- direction change;
- gear shifting;
- min/max ratio;
- motor update;
- speed limit;
- start-in-gear;
- target-gear application;
- gear-group operations;
- clutch/torque helpers;
- motor-run checks;
- `WheelsUtil.updateWheelsPhysics`.

The converted `vehicle.MR` flag enriches calibration/metadata, but does not define the boundary of MR motor participation.

This means an unconverted mod tractor can still run through substantial MR motor/control logic.

## AutoDrive hybrid fallback

`WheelsUtil.mrUpdateWheelsPhysics` detects active AutoDrive and calls the previous/base central control function instead.

The reason is documented in source: AutoDrive can issue pulsating acceleration/brake commands that MR considered dangerous for heavy vehicles.

Important nuance:
- MR central wheel-control is bypassed;
- global MR WheelPhysics/friction/RR/mass changes remain installed;
- VehicleMotor global wrappers can still exist downstream/upstream.

This is a hybrid state, not "MR off".

## CVTaddon hybrid fallback

When a CVTaddon configuration exists and is not the MR-supported configuration value, MR likewise falls back from its central wheel-control function to the previous path.

Again, this does not remove all MR global physics.

## GIANTS AI

MR modifies AI behavior in multiple layers:
- central wheel-control interprets AI zero acceleration as desired braking/deceleration;
- `AIVehicleUtil.driveAlongCurvature` reduces target speed near the destination;
- `driveToPoint` limits speed during field-worker turns.

Thus AI parity should be tested as a first-class scenario, not assumed from player behavior.

## Courseplay

Courseplay commonly routes through GIANTS AI/controller surfaces but can own speed/path commands.

No source-level MR-specific Courseplay bridge was identified in the exact package.

Required future test:
same tractor/implement/field under PLAYER vs GIANTS_AI vs COURSEPLAY, comparing:
- control owner;
- target/actual speed;
- throttle/brake;
- gear;
- engine rpm/load;
- PTO demand;
- slip/RR.

## Control interoperability rule

Future RC controller integration should preserve ownership by layer:
- controller owns desired motion/work intent;
- MR owns baseline physical drivetrain response;
- damage/mechanical mods own failure constraints;
- Dynamic PTO/WorkMode owns their declared user-selected operation mode;
- RC translates state only when paths bypass each other.

Avoid making RC another controller.
