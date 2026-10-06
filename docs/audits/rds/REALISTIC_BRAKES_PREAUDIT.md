# Realistic Brakes 1.3 ownership gate — exact-source closure

Updated: 2026-10-06
Status: **EXACT SOURCE AUDIT COMPLETE**

The original purpose of this file was to block RDS trailer-air work until the
current Realistic Brakes source could be inspected.

That gate is now closed with the user-supplied exact archive:

- mod: FS25_RealisticBrakes
- version: 1.3.0.0
- author: NegroATR / GN Realism
- SHA-256: c6cec8b89fb7bf409ee55f2a2421b989ff7392da0f5c5dedf65bc5d76912aa05
- no public GitHub repository found
- no LICENSE file found in the supplied ZIP

Full audit:
../realistic-brakes/README.md

## Questions answered

### Final brake actuator

Main parking behavior is spread across:
- getBrakeForce;
- WheelsUtil.updateWheelsPhysics;
- getSmoothedAcceleratorAndBrakePedals;
- direct vehicle:brake(1) in manual-clutch cases.

Trailer spring brakes use a better physical path:
- setCustomBrakeForce;
- forced brake pedal;
- normal wheel physics.

RB does not directly rewrite tire friction for the trailer spring-brake path.

### Parking-brake physics

The main parking model does **not** use one fixed hardware actuator torque and
let gravity determine the result.

It classifies whether the brake "holds" from:
- mass;
- slope;
- fixed reference mass/slope;
- gear multiplier;
- RDS spring-brake multiplier.

If the threshold is exceeded, RB deliberately reduces residual brake force so
the vehicle may roll.

Future RE/RB integration should prefer actual brake actuator capacity and let
vehicle/ground physics determine hold vs roll.

### Engine/Jake brake

Exact source confirms a direct MR conflict.

RB writes:
- motor.lowBrakeForceScale;
- motor.lowBrakeForceSpeedLimit;
- motor:setGear() for automatic downshift.

MR already owns engine-brake/drivetrain behavior.

Therefore the target stack must not run both physical algorithms independently.

### Brake thermal/fade

RB owns:
- one brakeTempC per motorized vehicle;
- server-side heating/cooling;
- exact exponential ambient cooling;
- one fade curve;
- persistent brake damage after sustained overtemperature.

Heating is based on pedal, speed, mass and vehicle-class factors rather than
actual dissipated brake work.

Fade/parking physical effects are bypassed for AI.

Generic base vehicle repair resets RB brake damage.

### Trailer reservoir

RB owns one persisted trailer pressure scalar in bar.

With RDS connected it immediately equalizes truck and trailer pressures using
relative volume proxies:
- truck: 12 * wheel count;
- trailer: 8 * wheel count.

This is conservation-inspired and useful as a reference, but:
- transfer is instantaneous;
- no tractor-protection cutoff;
- no trailer service-brake air consumption;
- no trailer leak;
- no separate spring/service reservoirs or priority behavior;
- trailer pressure has no dedicated MP stream.

### RDS API use

RB uses the public RDS methods:
- rdsGetAirPressure();
- server-side rdsSetAirPressure(bar).

This is cleaner than private spec access.

The future RE API should improve it further by exposing owner-managed
conservation-aware transfer rather than arbitrary absolute setPressure.

### Trailer spring actuator

RB applies custom brake force to all trailer wheels.

The torque proxy uses:
- assumed mu = 1;
- total trailer mass / wheel count;
- maximum wheel radius.

This allows ordinary wheel/ground physics to decide drag/skid, which is a good
direction, but actuator capacity should not depend on assumed surface friction.

### Hose topology

RB reads GIANTS ConnectionHoses state directly.

This means manualAttach and Interactive Control can compose indirectly by
changing the native hose state; RB does not need their private APIs.

Important exact-source defect:
RB applies spring-brake lock if **either** compatible air hose is disconnected.
Supply/emergency and service/control lines must be modeled separately.

### AI/controllers

Main RB controller resolver includes:
- GIANTS AI;
- Courseplay;
- Follow Me.

AutoDrive is explicitly not covered.

Main brake physics is largely bypassed under AI.

Trailer-air path uses only getIsAIActive(), so its controller policy is even
narrower.

This confirms the RDS/RE rule:
different interaction policy is acceptable; silently removing physical safety
state by controller type is not.

### Enhanced Vehicle

RB directly neutralizes Enhanced Vehicle parking state using EV private tables
and event surface.

This makes RB the intended parking owner on RB-managed vehicles rather than a
passive coexistence layer.

RMS parking ownership therefore needs explicit arbitration before RB is added
to the target stack.

### HUD/audio

RB owns another independent HUD/settings/calibration surface.

Per-vehicle audio is cleaned on delete.

Trailer supply disconnect reuses native air-release sound, which is a useful
presentation pattern.

The project should still prefer shared RE HUD slots and one semantic sound owner.

## New native-AIR result

FS25 Attachable itself exposes:
- vehicle.attachable.airConsumer#usage;
- getAttachbleAirConsumerUsage().

The attacher chain aggregates these usages into towing-vehicle air demand.

Therefore the RDS Native AIR P0 probe must include **trailer/implement AIR
metadata**, not only the truck Motorized AIR consumer.

This metadata may be valuable as capability/demand evidence even if the vanilla
continuous-consumption algorithm is replaced.

## P4 status after exact source

"Obtain/audit Realistic Brakes source" is now **CLOSED**.

Trailer implementation is still intentionally deferred because design decisions
remain:
1. storage backend;
2. supply vs service-line state;
3. finite transfer;
4. tractor protection;
5. service-demand model;
6. leakage;
7. trailer MP state;
8. wheel-group actuator topology;
9. controller policy;
10. whether RB remains external owner during migration.

See:
- ../realistic-brakes/TRAILER_AIR_AND_RDS.md
- PNEUMATIC_MODEL.md
- NATIVE_AIR_BACKEND.md
- FUTURE_IMPLEMENTATION_BLUEPRINT.md
