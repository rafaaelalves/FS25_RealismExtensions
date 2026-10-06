# Realistic Brakes — integration and assimilation opportunities

Updated: 2026-10-06
Status: exact-source static integration pass.

## Guiding rule

Do not treat Realistic Brakes as one compatibility target.

Decide independently for:
- PARKING;
- BRAKE_THERMAL;
- ENGINE_RETARDER;
- TRAILER_PNEUMATIC.

A bridge is justified only where two owners genuinely need composition.

## MoreRealistic

### Conflict: engine/exhaust/Jake brake

HIGH / exact-source.

RB writes the same motor/gear domain MR already owns:
- lowBrakeForceScale;
- lowBrakeForceSpeedLimit;
- gear selection/downshift.

Do not let both algorithms run independently.

Preferred options, in order:
1. upstream RB module-disable for engine brake when MR is present;
2. public RB retarder-demand API consumed by MR;
3. exact-version RC adapter that suppresses RB physical writes and translates only selector/level into MR;
4. if no clean boundary exists, do not enable that RB capability in the MR target stack.

Do not build a second engine-braking solver in RE.

### Parking/brake actuator

MR owns wheel/control behavior deeply.

RB parking/spring demand should be translated at one final brake boundary, not through getBrakeForce, wheel physics and pedal forcing independently.

Future concept:

    BrakeDemand -> MR/GIANTS actuator adapter

### AutoDrive

MR has an AutoDrive fallback path.

Runtime test must prove that RB parking/spring effects and any future RE forced spring demand remain physically effective under AutoDrive.

## RMS

### Parking brake conflict

RMS already has optional parking-brake ownership.

RB also owns parking brake and forcibly neutralizes Enhanced Vehicle's parking state.

Before running both:
- choose one parking owner; or
- make one explicitly provide demand/state only.

No current RC bridge exists.

### Brake condition/service opportunity

RB persistent brake damage is currently repaired by generic vanilla damage repair.

RMS is a better conceptual owner for:
- brake component condition;
- stress/overheat history;
- service/replacement transaction.

If brake thermal/fade is kept in RB or later assimilated:
- expose brake condition to RMS/service; or
- add an RMS brake subsystem if upstream architecture supports it.

Avoid another independent workshop.

### Thermal

RMS owns engine/transmission thermal, not service-brake thermal.

Brake thermal is therefore not inherently a duplicate domain.

It can remain a distinct capability if service/condition ownership is explicit.

## Enhanced Vehicle

RB directly disables EV parking state through private fields.

This is brittle but intentional.

Potential improved contract:

    parking capability owner arbitration

Instead of private vData[13] mutation:
- EV exposes ownership/state API; or
- RB/RMS/RE negotiate through RC.

Until then, exact-version/source-shape guarding is appropriate if RC ever touches this overlap.

## MudSystemPhysics

No direct bridge should be created.

Correct physical chain:

    brake torque
      -> wheel lock/slip
      -> Mud/MR ground response

Do not have RB/RE spring brake modify friction, sink or stuck state.

Mud decides ground consequence.

Authoritative wheel loads from Mud/RC could improve spring-brake actuator diagnostics and load-distribution calibration without making Mud a brake owner.

## Reifenverschleiss

No direct RB->Reifen mutation is needed.

A real locked/sliding wheel naturally feeds slip wear and force wear through the existing wheel state.

This is preferable to an explicit "spring brake adds tire wear" bridge.

Cross-test:
- high spring/parking brake drag on asphalt;
- low grip/mud;
- loaded trailer.

Verify wear is not double-counted and follows actual slip.

## Native PTO / EngineRpmDemand

No direct PTO/brake ownership conflict.

Potential future shared infrastructure:
- compressor fast-idle may create an EngineRpmDemand;
- PTO hand throttle already creates one.

If compressor fast-idle is implemented:
- one aggregator;
- one MR adapter;
- reason/source telemetry;
- motor-phase gating.

Do not reset PTO hand throttle simply because brake/start/air state changes.

## RDS / future RE pneumatics

Exact RB source closes the trailer-air gate conceptually.

Useful to preserve:
- ConnectionHoses as connector state;
- persisted trailer reservoir;
- conservative pressure-equalization concept;
- spring-release threshold as profile evidence;
- native air-release sound reuse;
- actual wheel brake force.

Improve:
- distinguish supply/service line;
- finite transfer flow;
- tractor protection;
- trailer service demand;
- leakage;
- spring/service priority;
- wheel-group topology;
- server-synced trailer reservoir;
- conserved amount API.

See TRAILER_AIR_AND_RDS.md.

## GIANTS native AIR

Exact cross-source result:

FS25 already provides:
- motorized AIR fill consumer;
- compressor refill state;
- lastAirUsage;
- native compressor sounds;
- attachable airConsumer#usage;
- attacher aggregation of attached air consumers.

This significantly strengthens the P0 native-AIR probe.

Potential design:

    native XML AIR metadata
      -> capability / relative chamber demand evidence
      -> RE physical policy
      -> native or RE storage backend

Do not assume native AIR fill units map directly to bar/L without runtime characterization.

## soundExpansionMP

Previous exact audit showed it observes/synchronizes native AIR doRefill for compressor audio.

If RB/RDS/RE pneumatics uses native AIR:
- preserve doRefill semantics;
- avoid a second compressor sound loop.

RB's trailer supply-disconnect reuse of native air-release sample fits this philosophy.

## Courseplay / Follow Me / AutoDrive

RB source contains hard-earned controller workarounds.

Positive:
- explicit Courseplay;
- explicit Follow Me;
- 250 ms cache.

Gap:
- AutoDrive absent;
- trailer-air uses narrower AI detection.

RE should create one normalized ControllerContext instead of each module rediscovering controller state.

Conceptual values:
- PLAYER;
- GIANTS_AI;
- COURSEPLAY;
- AUTODRIVE;
- FOLLOW_ME;
- OTHER.

Interaction policy consumes ControllerContext. Physics does not disappear by controller kind.

## 4x4 / active suspension design lessons

Reuse the already-audited pattern:

    sensors/state -> pure demand/decision -> one actuator adapter

For brakes:

    Pneumatic/Thermal/Parking state
      -> BrakeDemandModel
      -> BrakeActuatorAdapter
      -> MR/GIANTS final owner

This is the clearest architectural improvement over RB's current multi-hook parking implementation.

## TerraFarm/profile lesson

Use declarative profiles for:
- brake family;
- parking actuator;
- retarder/exhaust capability;
- thermal capacity/cooling;
- spring/service axle groups;
- pneumatic volumes/thresholds.

Resolution:
- native explicit metadata;
- semantic family;
- curated exact override;
- conservative fallback.

Do not create an ever-growing vehicle filename catalog in logic.

## FarmKit / shared HUD / audio

RB has its own HUD and sound surface.

Do not clone it during assimilation.

Future shared presentation:
- PARKING status;
- RETARDER mode;
- BRAKE_TEMP / fade;
- PNEUMATIC warning.

Prefer native/in-cab dashboard values when safe.

Sound:
- engine/retarder owner should control its own physical sample;
- compressor/release should reuse native/soundExpansion where possible;
- avoid duplicate global+3D loops.

## Compatibility architecture opportunity — BrakeContext

If a concrete RE consumer appears, RC could expose a normalized read-only BrakeContext containing:
- parking requested/effective/owner;
- service effectiveness/temperature/condition/owner;
- retarder requested/level/effective/owner;
- pneumatic supply/low-air/spring demand/owner;
- provenance.

Do not add this provider merely because RB exposes data.

Add it when shared HUD, AI policy, or another RE module actually consumes it.

Mutation remains a separate action/demand contract.

## Possible future RB improvements worth proposing upstream

1. independent module toggles for parking, engine brake, fade and trailer air;
2. secure client events;
3. server-authoritative simulation settings;
4. normalized public brake-state API;
5. controller resolver including AutoDrive and shared by trailer path;
6. engine-brake API/disable for MR coexistence;
7. parking owner arbitration with RMS/EV;
8. trailer supply vs service-line distinction;
9. trailer pressure network stream;
10. finite supply flow + protection valve;
11. use native attachable air-consumer metadata;
12. brake service hook/API instead of generic damage reset;
13. rate-limited/owner-delegated automatic downshift.

These could make "keep RB external" substantially cleaner than absorbing it.

## Assimilation decision matrix

### PARKING
- value: medium-high;
- conflict: high;
- recommendation: EVALUATE / integrate first.

### BRAKE_THERMAL_FADE
- value: high;
- conflict: low-medium;
- algorithm improvement potential: high;
- recommendation: strong future audit/absorption candidate, not current priority.

### ENGINE_RETARDER
- value: high in isolation;
- MR conflict: very high;
- recommendation: MR-owned; use demand integration or disable RB physical owner.

### TRAILER_PNEUMATIC
- value: high for RDS/RE air roadmap;
- current algorithm completeness: medium-low;
- integration value: very high;
- recommendation: use as source/reference and optional external owner; future RE pneumatic roadmap already captures improvements.

No whole-mod assimilation decision is justified yet.


## Exact MR wrapper-order result

Exact MR and RB both wrap `WheelsUtil.updateWheelsPhysics`.

MR's normal path consumes the call and does not invoke the previous function;
it invokes super primarily for explicit fallback modes.

Therefore RB's wheel-physics parking hook is not safely composable by load
order alone.

At the same time MR calls the global smoothed-pedal helper, and RB wraps that
helper too, so part of RB parking can remain active even if its wheel-physics
hook is skipped.

This creates a dangerous half-composed state.

If RB is tested in the MR stack:
- log hook identity/order;
- prove which RB layers actually run;
- do not "fix" ordering by simply forcing RB last;
- move toward a single explicit BrakeDemand integration.

The load-order problem is architectural evidence for an adapter/API, not a
reason to choose a preferred accidental wrapper order.


## Restore-ownership rule

Exact source adds another reason not to compose RB with MR/RMS by accidental
load order.

RB keeps long-lived baseline snapshots for:
- motor low-brake fields;
- trailer `customBrakeForce`.

It later restores those snapshots when its temporary ownership ends.

A later external owner can therefore be overwritten even if RB only restores
once.

Any future integration should prefer:
```text
current authoritative baseline
+ active normalized demands
-> one composed final actuator
```
instead of:
```text
capture baseline
mutate shared field for a while
restore captured baseline
```

If RB remains external, an upstream capability API/module-disable path is safer
than RC trying to continually repair stale restores.
