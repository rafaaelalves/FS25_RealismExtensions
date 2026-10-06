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


# Release 1.0.0.0 assimilation delta

The release does not change the original ActiveSuspension recommendation. It adds two physically interesting but separable phenomena and several engineering lessons.

## Capability decomposition

Do not absorb "Hydraulic Suspension System" as one feature.

If pursued, decompose it into independently owned capabilities:

```
VehicleDynamics signals
        |
        +--> ActiveSuspension --------> wheel/suspension actuator
        |
        +--> LoaderRideControl -------> validated loader actuator
        |
        +--> CabIsolation ------------> local presentation adapter
```

UI/settings consume state from those capabilities; they do not own physical state.

### ActiveSuspension
Status: **CANDIDATE_ABSORB / REDESIGN**

Unchanged requirements:
- compose over MR/vanilla passive baseline;
- one final suspension write path;
- no suppression of another mod's dynamic spring/damping commands;
- conservative vehicle capability profiles;
- server authority.

### LoaderRideControl
Status: **CANDIDATE_ABSORB / REDESIGN**

Treat loader ride control as a separate actuator problem, not as an extension of front-axle suspension merely because both affect ride quality.

Inputs worth researching:
- vehicle/chassis vertical acceleration;
- loader-arm angle/velocity;
- tool/load mass if trustworthy;
- hydraulic/command state;
- vehicle speed;
- attachment topology.

Controller target:
- attenuate chassis-to-load and load-to-chassis oscillation without fighting deliberate operator arm movement.

Candidate architecture:

```
operator/base loader command
            |
       actuator baseline
            |
LoaderRideControl bounded transient correction
            |
      one final actuator write
```

Binding must expose explicit states:
- `detected`: compatible loader capability seems present;
- `bound`: a supported actuator was actually found and validated;
- `active`: controller currently applies a correction.

Only `bound` may suppress a fallback. Only `active` may be shown as physically active.

Do not rely on one `axisName contains "ARM"` heuristic as the production capability contract.

### CabIsolation
Status: **LEARN / POSSIBLE_RE**

The current feature is a camera-isolation effect, not a cab mechanical simulation.

Two valid future scopes are possible:

1. **Presentation-only isolation**
   - local client feature;
   - filtered chassis attitude;
   - bounded camera correction;
   - no gameplay/physics authority.

2. **Physical cab suspension**
   - actual cab mass/mount model if the vehicle exposes usable nodes/joints;
   - physical state may inform camera presentation.

Do not label scope 1 as full cab physics.

Any camera adapter needs:
- original-parent identity;
- install-once semantics;
- explicit teardown/restoration;
- composition policy with camera/head-motion mods.

## Shared signal layer: possible future contract, not an implementation requirement

The release again consumes similar vehicle-dynamics signals from different private sources:
- wheel contact force;
- slip;
- draft;
- speed derivative;
- suspension movement.

If ActiveSuspension and LoaderRideControl are both implemented, duplication may justify a small normalized signal provider.

Candidate outputs:
- longitudinal acceleration;
- vertical acceleration if trustworthy;
- pitch/roll rates;
- normalized wheel/axle load;
- suspension stroke and velocity;
- normalized draft/drawbar load;
- slip.

Ownership rule:
- RC may normalize cross-mod/provider state when the value comes from MR/other external systems;
- RE should not make RC a generic physics engine merely to avoid reading vanilla state twice.

Add this abstraction only after two or more real capabilities demonstrate the need.

## Engineering rules learned from this release

### 1. Capability detection != actuator binding != active control

Use three explicit phases/states.

This prevents UI lies, invalid fallback suppression and accidental resource ownership.

### 2. Separate baseline command from transient correction

Do not make a transient controller discover the baseline solely by undoing its previous write if a cleaner base state can be observed.

Represent:
- base/operator command;
- controller correction;
- final composed command.

### 3. Hooks and hierarchy mutations need ownership identity

For wrapped methods, movingTools, wheel visuals and camera parents:
- capture identity;
- install once;
- restore only if still owner;
- fail closed after rebuild;
- reset transient state on delete/detach/physics removal.

### 4. Network slow authority, reconstruct safe fast presentation

The HSS visual strategy is conceptually strong:
- server sends authoritative effective/slow state;
- client derives visual high-frequency motion.

Use this only when the local high-frequency component cannot influence authoritative gameplay.

### 5. Authoritative configuration must not be independently inferred on clients

Keep local-only:
- HUD placement/scale;
- optional visual intensity where it does not misrepresent physical state.

Synchronize or derive from authoritative state:
- selected physical system/profile;
- capability flags;
- physical limits/parameters needed for truthful UI;
- effective mode/state.

### 6. Prototype paths must be explicit

Alternative experimental actuator implementations should be:
- a named experimental strategy with diagnostics/tests, or
- removed.

Do not leave dormant physics paths that appear production-capable but are unreachable from supported configuration.

### 7. Keep physical-data confidence separate from tuning

For every capability/profile distinguish:
- sourced/verified hardware facts;
- inferred engine capability;
- controller tuning;
- gameplay approximation.

This lets later research improve fidelity without conflating evidence and calibration.

## RC impact after the 1.0.0.0 review

**No HSS-specific RC patch is recommended.**

If the external HSS remains installed beside MR, fixing its ownership behavior in RC would make RC responsible for repairing a third-party controller's private implementation.

That violates the intended RC boundary unless a broader, reusable cross-mod contract emerges.

The useful path remains:
1. learn from HSS;
2. establish a clean MR/vanilla suspension composition boundary;
3. clean-room implement the desired phenomenon in RE if it proves worthwhile;
4. keep external HSS out of that ownership path rather than patch-fighting it.

A future RC addition is justified only if it is a general compatibility primitive, for example a normalized passive-suspension baseline or shared external-provider signal contract used beyond HSS.
