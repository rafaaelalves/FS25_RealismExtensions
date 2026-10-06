# Realistic Brakes — physics and ownership audit

Updated: 2026-10-06  
Exact baseline: 1.3.0.0

## Capability split

The source should be reasoned about as four subsystems, not one "brakes" owner:

```text
ParkingBrake
BrakeThermalFade
EngineExhaustBrake
TrailerAirSpringBrake
```

They interact in the HUD and some hooks, but they have different physical owners and different value in the target stack.

---

## 1. Parking brake

### Current physical implementation

RB combines several mechanisms:

1. `getBrakeForce()` changes effective brake force;
2. `WheelsUtil.updateWheelsPhysics` can force:
   - acceleration = 0;
   - currentSpeed = 0;
   - doHandbrake = true;
3. `getSmoothedAcceleratorAndBrakePedals` can force brake input;
4. manual-clutch path can call `vehicle:brake(1)` and later restore the previous pedal.

This was evolved through real bug reports and contains defensive comments, but from an ownership standpoint it is a multi-layer actuator.

### Holding-capacity algorithm

RB periodically measures:
- total mass;
- pitch-derived slope.

Then estimates:
```text
massRatio = mass / 12 t
maxSlope = 6 deg / max(massRatio, 0.25)
```

Modifiers:
- gear engaged: x1.6;
- RDS spring brake active: x6;
- hysteresis on the hold/exceeded transition.

If threshold is exceeded, normal parking force is reduced to a small residual so gravity can roll the machine.

### Main issue

Mass and slope should determine **required holding force**, not define a binary
change in available brake capability.

A stronger model:

```text
parking actuator capacity
   -> brake torque per applicable wheel/axle
   -> wheel physics
   -> tire/ground friction
   -> hold or roll emerges
```

Slope/mass remain excellent diagnostics:
```text
requiredHoldForce = m*g*sin(theta)
```
but should not be the switch that changes the hardware's brake force.

### Target-stack ownership

Potential owners:
- Realistic Brakes;
- RMS optional parking brake;
- Enhanced Vehicle parking brake;
- GIANTS baseline.

Do not run several physical parking owners simultaneously.

If RB remains external, target stack needs one of:
- RB configuration/API to disable only parking behavior;
- RMS configuration to relinquish parking ownership;
- explicit RC arbitration.

The exact current RB source forcibly neutralizes Enhanced Vehicle's private parking state, so "EV present" does not mean EV is the final owner.

---

## 2. Engine / exhaust / Jake-style brake

### Current RB model

RB controls engine braking through `VehicleMotor` fields:
- `lowBrakeForceScale`;
- `lowBrakeForceSpeedLimit`.

Base factor differs between manual vs CVT-ish classification.

An RPM/speed-derived gear factor increases/decreases the effect.

Exhaust-brake levels use multipliers:
- level 1: x4.0;
- level 2: x6.5;
- level 3: x9.5.

Application is gated by:
- truck capability heuristic;
- throttle near zero;
- speed >= configured minimum;
- sufficient RPM fraction.

Automatic transmissions may be downshifted with `motor:setGear()` to raise RPM.

### MR conflict

This is the clearest ownership conflict in the whole mod.

MoreRealistic already owns:
- motor torque/speed behavior;
- clutch/gear state;
- engine braking;
- wheel-level translation of engine brake;
- automatic transmission decisions.

Therefore RB's engine-brake subsystem cannot simply be stacked on MR.

### Recommended stack rule

If RB is adopted before any assimilation:
- disable RB engine/exhaust brake if an upstream/module switch can be added; or
- create a narrow exact-version integration that turns the RB player selector into **demand only** and lets MR translate it physically.

Conceptual:
```text
RB/RE retarder intent
  mode
  level
      |
      v
MR engine-brake owner
```

Do not keep RB's direct `lowBrakeForceScale` write and then multiply MR again.

### Automatic downshift

Gear selection must remain with the drivetrain owner.

A retarder can expose:
```text
preferredRpmRange
retardationDemand
```
but MR should decide whether/when to downshift.

The current per-update one-gear downshift is a useful gameplay idea but not a suitable cross-owner actuator.

---

## 3. Brake thermal / fade / permanent damage

### Current model

One vehicle-level temperature:
```text
brakeTempC
```

Heat input:
```text
heatRate =
    base
    * brakePedal
    * speedFactor
    * massFactor
    * classHeatFactor
    * userFadeScale
```

Cooling:
```text
T_new = T_ambient + (T_old - T_ambient) * exp(-coolCoef * dt)
```

Fade:
- piecewise temperature curve;
- minimum temporary factor around 15%.

Permanent damage:
- sustained temperature >= burn threshold;
- repeated damage steps;
- ceiling can drop to 25% effectiveness.

Repair:
- a significant drop in generic vehicle `damageAmount` resets brake damage.

### What is good

The cooling integrator is excellent for a game model:
- FPS invariant;
- supports sparse updates;
- ambient-relative.

The separation:
```text
temporary thermal fade
+
persistent material damage ceiling
```
is also conceptually strong.

### What should improve

Heating should ideally be based on **mechanical energy dissipated by friction brakes**.

For each brake/wheel:
```text
P_i = abs(brakeTorque_i * wheelOmega_i)
E_i += P_i * dt
T_i += E_i / thermalCapacity_i
```

Benefits:
- actual speed/torque determine energy;
- engine/Jake braking does not heat service brakes;
- fade reducing friction can naturally alter later heat flow;
- axle/brake size can be profiled;
- trailer brakes can have their own temperature.

A simpler first version can still use one temperature per axle/vehicle but should derive heat from authoritative brake work rather than raw pedal.

### Condition/service

Do not tie brake lining replacement to generic `damageAmount` in the target stack.

Preferred:
- RMS mechanical/service extension if brake subsystem support becomes available;
- otherwise an explicit brake service transaction/provider.

RMS's separation of Condition / Stress / Service is the right conceptual precedent.

### Controller parity

Thermal state should not disappear under AI.

If an AI vehicle performs the same physical braking work, it should generate the same heat.

Only:
- manual control UI;
- retarder selector interaction
should differ by controller.

---

## 4. Trailer spring brake actuator

RB trailer logic is physically stronger than its truck parking classifier.

When spring brake should apply it:
- calculates a custom wheel brake-force/torque proxy;
- forces brake pedal;
- lets ordinary wheel-ground physics determine skid/drag.

This is directionally the architecture RE wants:
```text
pneumatic state -> forced BrakeDemand -> final wheel actuator
```

### What not to copy

The actuator target is:
```text
muAssumed * wheelLoadProxy * radius
```
with `mu=1`.

Brake hardware capacity should not depend on an assumed road friction coefficient.

Better:
- profile effective spring-chamber/brake torque by axle/wheel group;
- optionally derive from brake geometry/normal vehicle brake force;
- let MR/Mud/tire physics decide whether that torque locks/slides/drags the tire.

### Axle topology

RB applies to all trailer wheels.

Future contract must support:
- spring-brake axle groups;
- service-brake groups;
- different effective chamber/brake capacities.

MVP may use a global value but the public API should remain group-capable.

---

## 5. Wheel/tire/ground ownership

Realistic Brakes does **not** need its own friction model.

Target order:
```text
brake demand / actuator torque
        |
        v
MR / GIANTS wheel dynamics
        |
Mud + RC grip/sink/resistance
        |
Reifen wear consequence
```

This produces natural outcomes:
- wheel lock;
- slide;
- drag;
- tire wear;
- mud resistance.

Do not:
- modify tire friction because spring brake is active;
- zero speed;
- declare a vehicle immovable based on a threshold.

---

## 6. Vehicle capability profiles

Recommended evidence hierarchy if any RB capability is assimilated:

```text
native explicit metadata
 -> semantic family/profile
 -> curated exact vehicle override
 -> conservative fallback
```

Candidate brake profile:
```text
serviceBrakeFamily
parkingBrakeFamily
hasExhaustBrake
retarderFamily
thermalMass / coolingFamily
serviceBrakeAxleGroups
springBrakeAxleGroups
trailerAirCapability
```

Do not infer final physical truth from store-category strings alone.

---

## 7. Assimilation ranking by physical value

### Highest value to study/possibly absorb later
1. brake thermal/fade — unique phenomenon, can be made more physical;
2. trailer spring/air behavior — directly relevant to RE pneumatics.

### Keep external/integrate if possible
3. parking brake — useful, but owner arbitration is the hard part.

### Do not duplicate in MR stack
4. engine/Jake brake physical implementation.

This ranking is not a roadmap commitment.


## Final exact-source refinements

### Parking drag heat

Current thermal code treats parking brake as full thermal demand only while the
parking-hold classifier says it is still holding.

Once `parkHoldExceeded=true`, that forced thermal contribution disappears even
though the vehicle may be moving against residual parking brake force.

This is another case where an energy/work-based thermal model is cleaner:
```text
actual brake torque × wheel angular velocity
 -> dissipated power
 -> heat
```
No separate parking heuristic is required.

### Thermal family profiles

If this capability is ever assimilated, do not preserve one universal
temperature/fade curve merely with car/truck/tractor heat multipliers.

A profile should be able to describe:
- drum;
- dry disc;
- wet multi-disc;
- thermal mass;
- cooling;
- fade onset/curve;
- damage temperature/time;
- axle bias.

Unknown vehicles can use conservative semantic-family defaults.

### Integration-friendly external RB would benefit from module switches

The cleanest path to use RB externally beside the target stack may be upstream
capability toggles rather than an RE replacement:

```text
parking              -> RB / RMS / EV owner selected
service thermal/fade -> RB
engine retarder      -> MR
trailer pneumatic    -> RB or future RE
```

Current 1.3 does not expose enough independent physical switches for this
ownership matrix.

This is a strong candidate upstream request before building suppressive RC
patches.
