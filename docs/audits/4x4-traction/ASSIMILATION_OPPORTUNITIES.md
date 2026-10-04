# Realistic 4x4 Traction System assimilation design

## Goal

Improve automatic drivetrain decision quality without adding another physical drivetrain writer.

The useful abstraction is not "4x4 mod".

It is:

**How much additional driveline assistance is justified by current/predicted traction demand?**

## Ownership

### RMS
Remains physical owner of:
- live differential topology;
- 2WD / 4WD effective state;
- differential locks;
- drivetrain wind-up/mechanical consequence;
- parking-brake/mechanical state.

### MR
Remains baseline motor/drivetrain/wheel dynamics owner where applicable.

### Mud
Remains tire pressure / CTIS / local sink and physical ground-state owner.

### RC
Normalizes the final cross-mod state and can carry an adapter if an external advisor must feed RMS.

### RE
Should own a reusable drivetrain-demand advisor only if it has a clean public consumer and is useful beyond one compatibility bridge.

Preferred first choice is to improve RMS upstream.

## Proposed normalized input contract

```
speedKph
movingDirection
steeringCurvature / steer01
brake01
throttle01

drivetrain.currentMode
drivetrain.effectiveDrivenWheels
drivetrain.primaryAxleWheels
drivetrain.engageableAxleWheels
drivetrain.diffLockRequested/engaged
drivetrain.windup01

wheel[].grounded
wheel[].longitudinalSlip
wheel[].lateralSlip
wheel[].loadN
wheel[].effectiveGrip / friction state
wheel[].surfaceCompliance

environment.localPhysicalWetness
environment.surfaceClass

work.draftForceN
work.drawbarLoadN
work.active

motor.dynamicLoad01
motor.availableTractivePower

terrain.gradeCurrent
terrain.gradeAhead
```

Every field should have provenance/confidence.

Do not reach directly into private Soil Draft or MR tables in the policy model.

## State estimator

### Slip

Compute primary-driven slip from the *effective* RMS topology.

Use:
- load-weighted mean;
- worst loaded wheel;
- unloaded-wheel classification.

Filter with asymmetric **time constants**:
- fast rise;
- slower fall;
- separate lock signal.

```
alpha = 1 - exp(-dt / tau)
```

Launch/brake invalidation remains valuable.

### Traction reserve

Estimate:

```
F_required =
    F_draft
  + F_grade
  + F_rolling
  + F_acceleration(optional)
```

Primary axle capacity:

```
F_capacity =
    sum(loadN_primary * effectiveMu)
```

Then:

```
assistDemand = saturate((F_required / F_capacity - reserveStart) / range)
```

This naturally asks for front-axle assistance when the primary axle is approaching its available traction.

Do not use a fixed rear-load percentage when actual loads exist.

### Descent / braking

Compute braking traction reserve separately.

Inputs:
- negative grade;
- gross combination mass;
- speed;
- brake request;
- primary axle normal load/grip.

Request additional driven/braked axle support when rear-only braking capacity approaches the required force.

This replaces fixed "grade > 6% + heavy child" logic.

## Predictive grade

If terrain anticipation is desired:
- sample several points along vehicle/path heading;
- reject terrain spikes/outliers;
- smooth grade profile;
- compute near-future longitudinal force requirement.

For AI/path controllers, sample along planned curvature rather than only straight root-node forward.

Terrain anticipation should predict **force**, not directly command 4WD.

## Decision output

Keep policy separate from actuator.

Suggested output:

```
{
  axleAssistDemand01,
  rearLockDemand01,
  frontLockDemand01,
  reasonMask,
  primaryReason,
  confidence01,
  minHoldMs,
  releaseReason,
  emergencyRelease
}
```

RMS can map this to its supported discrete/continuous behavior.

## Reason model

Retain explainability but allow multiple simultaneous reasons:
- SLIP;
- DRAFT;
- GRADE;
- BRAKING;
- LOW_TRACTION_RESERVE;
- WHEEL_UNLOAD;
- MANUAL;
- HOLD;
- STEERING_RELEASE;
- SPEED_RELEASE;
- WINDUP_RELEASE.

A primary reason is chosen for HUD, but reasonMask preserves causality.

## Engagement hysteresis

Preserve:
- separate engage/release thresholds;
- minimum hold;
- manual override timeout;
- speed release;
- steering release.

Improve:
- all filters/timeouts expressed in elapsed time;
- hold depends on trigger class if needed;
- no hidden Smart-only bypasses.

## Differential-lock demand

Do not lock merely because average slip is high.

Prefer signals that indicate open-differential loss:
- same-axle wheel speed/slip asymmetry;
- one wheel unloaded/spinning;
- available torque failing to reach the loaded wheel;
- high tractive demand.

Release/avoid lock under:
- steering curvature;
- speed;
- braking safety condition;
- high grip + wind-up risk.

Use RMS surface/wind-up semantics rather than inventing a second model.

## Actuator interface

The advisor never calls:
- `removeAllDifferentials`;
- `addDifferential`;
- `updateDifferential`;
- wheel radius;
- tire visual hooks.

RMS owns those consequences.

Ideal RMS API:

```
getDrivetrainState(vehicle)
submitAutoDriveDemand(vehicle, demandState)
```

or RMS embeds the advisor logic itself.

A topology revision remains useful for Reifen/MR/RC consumers.

## CTIS lesson

Do not absorb CTIS code.

Only carry these design lessons back to the pressure owner:
- manual vs onboard automatic systems are distinct capabilities;
- pressure changes have real transition time;
- field/road target should depend on load/hardware;
- drivetrain mode should not itself be pressure ownership.

## Implementation priority

1. propose/patch RMS AUTO semantics using the demand model;
2. expose RMS normalized topology/wheel sets;
3. add harnesses for the pure decision model;
4. only create a standalone RE advisor if RMS cannot host it cleanly and another consumer justifies the abstraction.

This avoids creating an RE feature whose only job is to override an external specialist.
