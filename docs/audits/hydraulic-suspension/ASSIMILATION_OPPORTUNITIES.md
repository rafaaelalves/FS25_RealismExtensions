# Hydraulic Suspension assimilation design

## Goal

If runtime and ownership research support it, implement a clean `ActiveSuspension` capability that models active/hydropneumatic front suspension **without replacing MoreRealistic's passive wheel-physics baseline**.

## Non-goals

Do not:
- port the external Lua;
- intercept and discard MR suspension commands;
- assign hydraulic suspension to every heavy tractor of an eligible brand;
- manufacture rigid-axle kinematics for unknown vehicles by default;
- make RE a generic tire/spring owner.

## Proposed ownership

### MoreRealistic / vanilla
Own:
- passive spring/damper baseline;
- general WheelPhysics;
- tire/contact dynamics.

### RE ActiveSuspension
May own, when explicitly supported:
- ride-height target;
- hydraulic/pneumatic actuator offset;
- system mode;
- active/semi-active damping correction;
- verified suspension-system capability;
- anti-dive/leveling policy.

### RC
May normalize the passive baseline / cross-mod state when direct composition with MR cannot be expressed through a stable public API.

RC should not become a second active-suspension controller.

## Composition contract

Preferred semantics:

```
passiveSpringBase
passiveDampingBase
       |
ActiveSuspension correction
       |
single final wheel actuator
```

The active controller should output normalized corrections, for example:
- rideHeightOffsetM;
- springFactor relative to baseline;
- compressionDampingFactor;
- reboundDampingFactor.

The final adapter composes them once.

Do not consume an MR call and simply refuse to forward it.

## Better controller

### State

Per controlled wheel/axle:
- suspension stroke;
- normalized stroke position;
- stroke velocity;
- vertical load;
- base spring/damping;
- actuator position;
- actuator velocity;
- ground-contact validity.

Per vehicle:
- speed;
- longitudinal acceleration;
- pitch/pitch-rate if available;
- roll/roll-rate;
- draft/drawbar force;
- working state.

### Auto-level

Control target should be suspension stroke/ride-height error.

Suggested controller:
1. load feed-forward estimates required actuator offset;
2. PI-like slow feedback removes steady ride-height error;
3. rate/travel limits model hydraulic hardware;
4. deadband prevents valve chatter;
5. integrator clamped to physical travel;
6. exact dt-normalized filtering.

This remains stable when passive spring baseline changes.

### Work mode

WORK is a policy, not a sensor.

Enter based on actual mechanical context such as:
- sustained draft;
- measured oscillation;
- loader/implement mode if a profile explicitly uses it.

Do not equate lowered implement with high suspension demand.

### Pitch control

Use real longitudinal acceleration when possible.

A semi-active damping correction can scale with:
- acceleration;
- pitch rate;
- current stroke margin.

Keep the correction bounded and decay it with a time constant.

### Power-hop detection

Build an oscillation detector from:
- front axle load/stroke residual;
- pitch/vertical response;
- slip residual.

Possible implementation:
- remove slow mean with EWMA;
- measure oscillatory energy in a tractor-relevant band;
- require persistence;
- expose confidence;
- use slip as corroboration.

This is more physically grounded than slip-only deviation.

## Vehicle capability profiles

Separate:

### Capability
- systemId;
- axleType;
- hasAutoLevel;
- hasManualHeight;
- canLock;
- lockSpeedRule;
- verified travel/range;
- source confidence.

### Tuning
- target stroke;
- actuator rate;
- damping maps;
- filter constants;
- work/pitch thresholds.

Unknown model behavior should fail closed.

An optional generic profile can exist for development/user opt-in, not as silent default fidelity.

## Physical adapter

Requirements:
- lifecycle-safe hook identity;
- one final suspension write owner;
- no repeated write fight;
- reinitialize safely after vehicle physics rebuild;
- server authority;
- fail closed if MR/private API shape changes.

Before implementing, inspect the exact MR suspension call path and determine whether a public or RC-normalized baseline can be exposed cleanly.

## Visual adapter

Prefer deriving visual movement from effective physical actuator state.

Only reparent wheel representation nodes if:
- native wheel visual API cannot represent the actuator;
- the vehicle is proven compatible.

If wrapping `getVisualInfo`:
- identity-check installation;
- observer/composition contract;
- safe teardown;
- do not hide later owners.

## Persistence

Persist only player/system state that must survive:
- mode;
- manual ride-height request;
- optional system settings version.

Do not persist transient controller/filter state unless runtime proves it is necessary.

Schema upgrades must merge user profiles instead of deleting the old file.

## Multiplayer

Server:
- validates input permission;
- runs physical controller;
- owns mode/manual state.

Client:
- sends request only;
- receives accepted effective state;
- renders.

Network dirty groups can separate:
- mode/request;
- slow effective ride height;
- left/right articulation if needed.

Do not send raw wheel physics every frame.

## Exit gates before implementation

1. exact MR spring/damping ownership path understood;
2. a clean baseline-composition API exists;
3. vanilla + MR baseline measured on at least one suspended and one non-suspended tractor;
4. wheel `positionY` actuator effect characterized;
5. reparenting not assumed necessary;
6. profile capability data selected conservatively.

If gate 2 fails, keep the phenomenon in research rather than implementing a write fight.
