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


# Release 1.7.0.0 architecture delta

The drivetrain recommendation is unchanged. The release mainly contributes lessons about **configuration architecture** and confirms that a clean AUTO advisor should be easier to tune than the external monolith.

## Do not make policy branches re-interpret raw triggers

The release now exposes physical policy toggles in UI, which makes duplicated decision logic visible.

Examples:
- binary braking reason checks `brakeEngage`, Smart target does not;
- binary implement reason checks `engageOnImplementLower`, Smart target does not.

A clean advisor should first construct a canonical trigger state:

```
triggers.brakeAssist = cfg.brakeEngage
    and modeAllowsBrake
    and brake01 > threshold
    and speedInsideRange

triggers.implementWork = cfg.engageOnImplementLower
    and work.active
    and work.draftConfidence > ...
```

Then all decision modes consume those canonical triggers.

Do not let Manual/Auto/Smart each partially re-implement configuration semantics.

## Configuration needs an authority model

Separate settings into two families.

### Local presentation
Examples:
- HUD style;
- HUD position;
- icon size;
- show store photo;
- local debug visualization.

Properties:
- profile-local;
- no network replication required;
- safe to change immediately.

### Authoritative simulation
Examples:
- automatic engagement policy;
- thresholds;
- road-speed limits;
- prediction gain;
- lock policy.

Properties:
- owned by server/save/admin policy;
- synchronized read-only to clients when UI needs to display them;
- mutations go through an authorized server command;
- validated on the authoritative side.

A disabled client control is **not** an authority boundary.

## Setting descriptor design

The reused `ZCSettingsMenu` pattern is worth learning from, but UI description should not be the only metadata.

A stronger shared RE settings primitive would define:

```
{
  id,
  type,
  default,
  values/min/max,
  scope,
  persistence,
  replication,
  applyMode,
  getEffective,
  validate,
  apply
}
```

where `applyMode` distinguishes:
- `LIVE`: value can be consumed on the next update;
- `REBIND`: capability/actuator registration must be recomputed;
- `RELOAD`: cannot safely change until vehicle/mission reload.

This directly prevents the 1.7 `manualTirePressure` problem, where a structural capability is presented as a normal live toggle.

## Capability identity must be synchronized before state

The pressure subsystem demonstrates a general networking rule.

Bad shape:

```
client derives hasCapability locally
server sends pressureLevel
client interprets pressureLevel according to its own capability guess
```

Preferred:

```
server capability descriptor
        |
        +--> client read-only capability view
        |
server effective state
        |
        +--> client presentation
```

For future RE/RC providers, synchronize enough capability metadata that clients do not have to infer hardware ownership from local config.

## Per-vehicle tuning requires a server command API

The existing terminal's direct mutation is convenient in single-player/listen-server but does not generalize to dedicated multiplayer.

A reusable tuning path should be:

```
UI request
   -> authorized server command
   -> validate range/capability
   -> mutate authoritative vehicle state
   -> dirty/snapshot group
   -> clients render accepted value
```

The same command pattern should handle telemetry reset.

## Shared settings adapter: useful, but centralize once in our code

The exact settings helper is reused unchanged across the audited 4x4 and HSS packages.

That is evidence that this abstraction is real rather than accidental.

If RE needs a native General Settings integration:
- implement one shared adapter in RE infrastructure;
- let capabilities register descriptors;
- never let every capability independently clone/hook the native page;
- version-gate/capability-check native GUI identifiers;
- support unregister/mission lifecycle explicitly.

Do not reproduce the external author's file/style; retain the architectural separation.

## HUD lesson

The new icon HUD demonstrates a good low-cost pattern:
- reusable image layers;
- state expressed through tint/visibility;
- lazy/cached resource creation;
- data read from the feature state rather than embedded in image variants.

If RE builds richer physical-system HUDs, prefer this kind of semantic layer composition over many pre-rendered state images.

Add explicit resource teardown and a shared UI asset/cache owner.

## Updated implementation priority

The original priority remains:

1. improve RMS AUTO/lock policy upstream;
2. expose normalized RMS topology/effective driven-wheel state where real consumers need it;
3. build/test a pure demand policy harness;
4. avoid a standalone RE drivetrain writer.

The 1.7 review adds:

5. if a generic settings layer is needed, build it once with scope/authority/apply metadata;
6. if per-vehicle tuning exists, make it server-authoritative from the start;
7. keep drivetrain policy settings separate from pressure/CTIS capability settings.
