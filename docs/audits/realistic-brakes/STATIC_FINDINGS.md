# Realistic Brakes 1.3 — static findings

Exact baseline:
- `FS25_RealisticBrakes 1.3.0.0`
- SHA-256 `c6cec8b89fb7bf409ee55f2a2421b989ff7392da0f5c5dedf65bc5d76912aa05`

Labels:
- **CONFIRMED_STATIC**
- **DESIGN_RISK**
- **POSITIVE_PATTERN**
- **RUNTIME_PENDING**

## RB-01 — specialization scope is capability-broad, not vehicle-profiled
**CONFIRMED_STATIC / MEDIUM**

`realisticBrakes` is injected into every vehicle type with `motorized + wheels`.

This is acceptable for generic service-brake thermal state more than it was for RDS glow logic, but it is too broad for:
- exhaust/Jake brake;
- parking-brake architecture;
- vehicle-class thermal calibration.

The source later uses category/type/mass heuristics to classify truck/car/tractor.

Target rule if assimilated:
- generic service-brake capability may be broad;
- exhaust brake, retarder, parking architecture and thermal profile require explicit/evidence-backed capability profiles.

## RB-02 — engine/exhaust brake directly conflicts with MR's motor owner
**CONFIRMED_STATIC / HIGH**

RB caches and writes:
- `motor.lowBrakeForceScale`;
- `motor.lowBrakeForceSpeedLimit`.

It can also call `motor:setGear()` for automatic downshift.

MR already globally owns motor, clutch, gear and engine-braking behavior.

In the target stack, allowing both owners to write this domain is not acceptable without a deliberate adapter/feature-disable path.

## RB-03 — automatic downshift's "max gears" guard does not bound cumulative steps
**CONFIRMED_STATIC / MEDIUM**

The code calculates a one-step target and may execute it every update while RPM remains below target.

Although config exposes a maximum-downshift concept, repeated per-frame one-gear calls can accumulate beyond that number over several frames.

A future implementation should:
- compute a target gear once per decision;
- rate-limit shift requests;
- respect gearbox owner/API;
- avoid direct gear ownership when MR is active.

## RB-04 — parking brake is implemented across several owner layers
**CONFIRMED_STATIC / HIGH**

RB parking behavior reaches:
- `getBrakeForce`;
- `WheelsUtil.updateWheelsPhysics`;
- `WheelsUtil.getSmoothedAcceleratorAndBrakePedals`;
- direct `vehicle:brake(1)` in manual-clutch cases.

This makes coexistence/load order difficult and is exactly the architecture the RE demand/actuator split is intended to avoid.

## RB-05 — Enhanced Vehicle parking brake is forcibly neutralized
**CONFIRMED_STATIC / HIGH OWNERSHIP**

RB writes private EV fields:
- `vehicle.vData.want[13]`;
- `vehicle.vData.is[13]`;

and may send `FS25_EnhancedVehicle_Event`.

This is not passive coexistence: RB deliberately claims parking-brake ownership.

The integration is fragile to EV private-state changes.

## RB-06 — RMS + RB parking ownership is unresolved
**DESIGN_RISK / HIGH**

RMS also has optional parking-brake behavior and already contains Enhanced Vehicle arbitration.

RB does not expose a capability-level "parking brake off" mode in its current player settings.

Potential outcome:
- RMS steps aside because EV exists;
- RB disables EV;
- RB becomes de facto parking owner;
or, without EV:
- RMS and RB both apply parking state.

This must be runtime/ownership-resolved before RB joins the target stack.

## RB-07 — parking holding capability is a classifier, not an actuator model
**CONFIRMED_STATIC / PHYSICS HIGH**

RB estimates whether the parking brake can hold from:
- total mass;
- slope;
- fixed reference mass/slope;
- gear bonus;
- RDS spring-brake multiplier.

If the estimated threshold is exceeded, the mod switches to a greatly reduced residual brake factor so the vehicle can roll.

This is discontinuous and hides actuator capacity inside a slope/mass decision.

Better physical model:
- define available parking/spring brake torque by wheel/axle;
- apply it continuously;
- let gravity, driveline and tire-ground physics determine whether the vehicle holds or rolls.

## RB-08 — gear-engaged parking bonus is hard-coded
**DESIGN_RISK**

Parking hold slope receives a fixed multiplier when a gear is engaged.

The phenomenon can be real for some drivetrains, but magnitude and applicability belong to drivetrain/motor compression ownership, especially with MR.

Do not port this as one universal multiplier.

## RB-09 — RDS spring brake only multiplies parking-hold threshold
**CONFIRMED_STATIC / MODEL LIMIT**

For motorized vehicles, RDS spring-brake state increases RB's allowed parking slope through a fixed multiplier.

It does not introduce an explicit spring-chamber torque/axle model on the truck.

Future RE pneumatics should output physical brake demand, not an abstract "holds six times more slope" multiplier.

## RB-10 — AI is intentionally exempt from main RB brake physics
**CONFIRMED_STATIC / HIGH**

RB's main physical hooks return to the original path for detected AI work.

Consequences such as:
- RB parking brake;
- brake fade reduction;
- custom engine-brake path

are not applied the same way under AI.

This avoids controller deadlocks but makes physical rules controller-dependent.

Target rule: controller policy may skip interaction; physical safety/thermal/brake capability should not disappear.

## RB-11 — AI detection is incomplete/inconsistent
**CONFIRMED_STATIC / HIGH**

Main AI helper recognizes:
- GIANTS AI;
- Courseplay;
- Follow Me.

Source explicitly has no AutoDrive-specific check.

Trailer-air logic uses only `root:getIsAIActive()`, so it does not even reuse the richer main controller resolver.

This can produce different physical behavior between main RB and trailer RB for the same controller.

## RB-12 — MR AutoDrive fallback makes physical-hook placement critical
**CROSS-AUDIT DESIGN_RISK**

MR deliberately falls back from its central wheel-control path when AutoDrive is active.

Any future spring/parking brake adapter must be placed at a physical owner boundary that remains effective in that path.

Do not bind safety brakes only to player/controller command processing.

## RB-13 — brake heating is a pedal/speed/mass proxy, not dissipated brake work
**CONFIRMED_STATIC / PHYSICS MEDIUM-HIGH**

Heating uses approximately:
```text
gain ~ pedal * speedFactor * massFactor * vehicleClassFactor```

It does not integrate actual:
- brake torque;
- wheel angular speed;
- deceleration attributable to service brakes;
- axle/wheel heat distribution.

This is a useful gameplay model but not an energy-based brake thermal model.

Better future direction:
```text
brakePower = sum(brakeTorque_i * abs(wheelOmega_i))
heat += brakePower * dt / effectiveHeatCapacity
```
with cooling separately.

## RB-14 — brake thermal state is one scalar per vehicle
**CONFIRMED_STATIC / MODEL LIMIT**

All service brakes share one `brakeTempC` and one fade factor.

No axle/wheel differences exist.

This cannot model:
- front/rear bias;
- trailer vs tractor heat;
- individual hot drums/discs;
- one failed/dragging brake.

A future model can start global but should not freeze the contract around one scalar.

## RB-15 — exact exponential cooling is a strong positive pattern
**POSITIVE_PATTERN**

RB uses:
```text
T = ambient + (T - ambient) * exp(-k * dt)
```

This avoids timestep-dependent Euler cooling and is worth preserving conceptually.

It also reconciles elapsed mission-clock time when update cadence becomes sparse.

## RB-16 — thermal heating under AI is source-comment/implementation ambiguous
**DESIGN_RISK / RUNTIME_PENDING**

Comments state temperature can continue under AI while fade effects are bypassed.

But heating reads the player-style forward/brake axis and requires `getIsControlled()`.

The source itself notes AI/control-axis inconsistencies elsewhere.

Do not assume AI thermal parity until runtime evidence verifies actual pedal input during GIANTS AI / Courseplay / AutoDrive.

## RB-17 — permanent fade damage is coupled to generic vehicle repair
**CONFIRMED_STATIC / HIGH CROSS-OWNER**

RB resets its brake damage when `getDamageAmount()` drops sufficiently.

In the target stack:
- RMS deliberately replaces/resets vanilla generic damage semantics;
- unrelated base-game repair can therefore become "new brakes";
- brake service has no explicit subsystem transaction.

Future brake degradation should integrate with a mechanical/service owner or have its own explicit service contract.

## RB-18 — fade effect itself is bypassed for AI
**CONFIRMED_STATIC**

`getBrakeForce` returns the base/original value for AI before applying RB fade/parking behavior.

Thus a hot, damaged brake vehicle can brake differently solely because AI took over.

This is useful as a bug-avoidance reference, not a fidelity target.

## RB-19 — simulation-affecting settings are local per-user
**CONFIRMED_STATIC / MP HIGH**

Local `modSettings` includes:
- `fadeScale`;
- `trailerAir`;
- `exhaustAuto`;
- `exhaustLevel`.

These affect physical behavior, yet there is no server-authoritative settings sync.

Same architecture lesson as RDS:
- LocalPreferences;
- SimulationConfig;
- DevCalibration
must be separate.

## RB-20 — client park event lacks controller authorization
**CONFIRMED_STATIC / SECURITY**

`RBParkEvent` accepts a synchronized vehicle + requested state and applies it server-side without proving that the sender controls/owns the target vehicle.

## RB-21 — client exhaust-state event lacks controller authorization
**CONFIRMED_STATIC / SECURITY**

`RBStateEvent` similarly accepts vehicle, active state, level and forced-off state and rebroadcasts it without target-controller validation.

Server should validate sender, legal transition and authoritative settings.

## RB-22 — main vehicle state has useful full initial synchronization
**POSITIVE_PATTERN**

Initial stream includes:
- exhaust state/level/forced-off;
- brake temperature;
- parking hold state;
- permanent brake damage;
- parking state.

Temperature and damage are compactly quantized.

This is stronger than RDS's missing trailer-air initial stream.

## RB-23 — update sync is compact but one dirty group mixes semantic domains
**DESIGN_RISK / IMPROVEMENT**

One dirty flag carries temperature, hold-exceeded and brake damage.

A richer future system should separate domains such as:
- THERMAL;
- PARKING;
- PNEUMATIC;
- CONDITION.

This follows the RMS semantic-dirty-group precedent.

## RB-24 — bounded parking wake is a good correction to a real performance bug
**POSITIVE_PATTERN**

Source documents that repeatedly `raiseActive()`-ing unattended rollable vehicles forever caused large FPS losses.

Current code bounds forced wake/manual wheel update to 8 seconds.

General lesson:
- expensive wake/physics recovery needs a finite retry budget;
- persistent inactive-state correction should be event/scheduler-driven, not per-frame forever.

## RB-25 — manual wheel-physics invocation is still a brittle workaround
**DESIGN_RISK**

During the wake window RB can call `WheelsUtil.updateWheelsPhysics` manually.

With MR/other global owners this traverses the effective wrapper chain outside the ordinary game call site.

Keep as runtime-sensitive compatibility code; do not copy into RE unless absolutely necessary.

## RB-26 — vehicle-class thermal/exhaust inference is heuristic
**CONFIRMED_STATIC**

Classification uses store category/type strings, then mass fallback (<3.5 t => car, otherwise tractor).

This can misclassify unusual mod vehicles and makes exhaust-brake capability a category inference.

Use declarative/evidence-backed profiles if this capability is ever assimilated.

## RB-27 — trailer specialization uses actual ConnectionHoses state
**POSITIVE_PATTERN**

The trailer system reads GIANTS connection hose objects rather than integrating separately with manualAttach/Interactive Control.

This is a clean provider boundary:
- hose mods manipulate GIANTS connection state;
- RB consumes that state.

Future RE should keep this principle.

## RB-28 — trailer supply and service hose loss are conflated
**CONFIRMED_STATIC / PHYSICS HIGH**

If **any** air hose with a compatible target is disconnected, RB reports `SIN_MANGUERAS` and applies spring brake.

That means disconnecting only the yellow service/control line can apply the emergency spring brake.

Real air-brake semantics distinguish:
- supply/emergency line -> fills reservoirs / maintains spring release;
- service/control line -> carries service-brake command.

Future model must represent them separately.

## RB-29 — trailer pressure equalization is instantaneous
**CONFIRMED_STATIC / MODEL LIMIT**

When connected to RDS, truck and trailer pressures are set to a weighted average immediately.

Positive:
- attempts conservation rather than copying pressure.

Limit:
- zero line/valve restriction;
- no finite fill time except repeated compressor replenishment afterward.

Future transfer should have bounded flow/valve conductance.

## RB-30 — trailer equalization volume model is a rough wheel-count proxy
**CONFIRMED_STATIC / MODEL LIMIT**

Relative capacity uses:
- truck: `12 * wheelCount`;
- trailer: `8 * wheelCount`.

The constants are motivated by reservoir-to-chamber-volume requirements, but wheel count is not sufficient to determine actual chamber/reservoir volume.

Use profile/native metadata where available.

## RB-31 — trailer service braking does not consume modeled trailer air
**CONFIRMED_STATIC / PHYSICS HIGH**

The custom trailer reservoir changes through truck equalization, but normal trailer service-brake applications do not withdraw air from this reservoir.

This leaves the modeled tank disconnected from one of its main purposes.

GIANTS already exposes attachable `airConsumer#usage`; investigate this as native demand evidence/backend input.

## RB-32 — trailer model has no leakage
**CONFIRMED_STATIC**

Disconnected trailer pressure can persist indefinitely through ordinary runtime/save unless equalized later.

Future model needs controlled leakage/fault policy.

## RB-33 — no tractor-protection / towing-vehicle reserve valve
**CONFIRMED_STATIC / PHYSICS HIGH**

An empty trailer can immediately equalize downward with the truck.

No valve stops supply to preserve tractor pressure at a low-air threshold.

Future system should model a protection/supply cutoff policy before richer trailer air.

## RB-34 — no service-vs-spring priority valve behavior
**CONFIRMED_STATIC / MODEL LIMIT**

The source has one trailer pressure scalar and one release threshold.

Real trailer systems may prioritize spring release vs service availability.

Future circuit model should leave room for these semantics.

## RB-35 — trailer spring brake uses actual wheel brake-force path
**POSITIVE_PATTERN**

RB does not reduce friction or teleport/zero speed.

It raises custom wheel brake force and brake pedal, then lets wheel-ground physics determine whether the wheels skid/drag.

This is directionally correct and aligns with RE's planned BrakeDemand -> actuator architecture.

## RB-36 — trailer spring torque proxy is coupled to an assumed μ=1
**DESIGN_RISK**

The lock torque is estimated from:
```text
mu * mass*g/wheels * radius
```
with `mu=1`.

This makes actuator capacity depend on an assumed tire-ground friction coefficient.

A brake actuator should have a hardware force/torque limit independent of current surface; Mud/MR/tire physics then determine skid/drag.

## RB-37 — semi-trailer load distribution can overestimate spring torque
**CONFIRMED_STATIC**

The source itself notes that using trailer total mass per trailer wheel can overstate wheel load where part of a semi's mass is carried through the fifth wheel.

Future axle/wheel load input should come from authoritative physical load state if available.

## RB-38 — spring brake is applied uniformly to all trailer wheels
**CONFIRMED_STATIC / MODEL LIMIT**

No spring-chamber axle/wheel topology exists.

Future BrakeDemand contract should permit wheel groups.

## RB-39 — trailer pressure persists but lacks dedicated MP stream
**CONFIRMED_STATIC / MP HIGH**

`rbTrailerAir#presion` is saved server-side.

There is no custom initial/update stream for trailer pressure.

Client assumes connected trailer pressure equals synchronized RDS truck pressure.

That assumption only works because the current algorithm instant-equalizes.

A finite-flow future model requires authoritative trailer pressure replication.

## RB-40 — detached trailer falls back to vanilla parking, not modeled pressure
**CONFIRMED_STATIC / OWNERSHIP GAP**

When no attacher exists, `rbGetTrailerAirState` returns LIBRE because base Attachable deactivation is expected to hold it.

Thus custom persisted trailer pressure/spring state does not actually own detached-trailer braking.

A future physical pneumatic owner should define this state explicitly.

## RB-41 — trailer AI bypass coverage is narrower than main RB AI coverage
**CONFIRMED_STATIC**

Trailer path checks only `getIsAIActive()`.

Courseplay/Follow Me/AutoDrive may therefore see trailer spring physics while main RB physics has already bypassed itself.

## RB-42 — native air-release sound reuse is a good presentation pattern
**POSITIVE_PATTERN**

Disconnecting the supply hose reuses the towing vehicle's native `airRelease` sample.

Prefer semantic/native sound reuse over a duplicate compressor/release sound owner where possible.

## RB-43 — GIANTS native attachable AIR metadata is a major integration opportunity
**CROSS-SOURCE POSITIVE FINDING**

FS25 Attachable exposes:
- `vehicle.attachable.airConsumer#usage`;
- `getAttachbleAirConsumerUsage()`.

The attacher chain aggregates implement air consumption through `getAirConsumerUsage()`.

This means RE's future native-AIR study must include **trailer/implement air demand**, not only the towing vehicle's AIR reservoir.

It may provide better evidence than RB's wheel-count-only service-demand assumptions.

## RB-44 — per-frame thermal/engine work can be split by cadence
**DESIGN/OPTIMIZATION**

Server `onUpdate` advances engine brake, thermal state, parking diagnostics and compatibility work.

Not every subsystem needs frame cadence.

Future:
- player input/engine-brake responsiveness: active vehicle/frame;
- brake thermal: fixed 50–200 ms or actual energy event cadence;
- parking slope/mass: existing 250 ms/event;
- trailer air: fixed server cadence;
- HUD: draw/revision.

## RB-45 — debug/calibration tooling is valuable but globally persistent
**POSITIVE + LIFECYCLE RISK**

RB has extensive console calibration tooling, useful for development.

No matching `removeConsoleCommand` lifecycle was found.

This is acceptable for a mod-lifetime singleton but should not be copied as per-mission module registration without explicit teardown/idempotence.

## RB-46 — local settings save implementation learned from a real overwrite bug
**POSITIVE_PATTERN**

Settings/HUD calibration now write the complete config atomically instead of separate partial writers deleting each other's fields.

General lesson: one authoritative serializer per settings file.

## RB-47 — sound ownership is partially duplicated
**DESIGN_RISK**

Engine/exhaust brake can use both a vehicle 3D sample and a global 2D fallback.

Source comments document previous duplicate/loss problems.

In the target stack, sound ownership should follow the physical owner and avoid duplicate loops with MR/FarmKit/soundExpansion.

## RB-48 — absence of packaged license requires clean-room discipline
**PROVENANCE**

No LICENSE file was found in the exact archive.

Treat code/assets as audit evidence only unless explicit permission/license is established.

## Static conclusion

Realistic Brakes 1.3 contains several genuinely useful ideas, especially:
- trailer ConnectionHoses integration;
- amount-aware pressure equalization;
- wheel-physics spring-brake actuation;
- exponential cooling;
- bounded inactive-physics wake;
- initial state sync;
- extensive runtime calibration.

Its strongest target-stack conflicts are:
- MR engine-brake/gear ownership;
- RMS/EV parking-brake ownership;
- controller-dependent physics bypass;
- generic repair coupling;
- local physical settings;
- incomplete trailer pneumatic model.

The mod should be evaluated **by capability**, not adopted or rejected wholesale.


## Additional cross-source findings

### RB-49 — MR/RB wheel-physics composition is load-order dependent
**CONFIRMED_STATIC / HIGH**

Exact MR source also installs:
`WheelsUtil.updateWheelsPhysics = Utils.overwrittenFunction(...)`.

MR's ordinary physical path usually does **not** call its `superFunc`; it only
returns to the previous implementation for specific fallbacks such as active
AutoDrive/CVTAddon.

Therefore:

If RB wraps MR:
```text
RB -> MR
```
RB can modify arguments before MR runs.

If MR wraps RB:
```text
MR -> (RB only when MR chooses super fallback)
```
RB's `rbUpdateWheelsPhysics` parking path can be skipped during ordinary MR
control.

Meanwhile MR dynamically calls `WheelsUtil.getSmoothedAcceleratorAndBrakePedals`,
which RB also wraps, so another RB parking-control path may still execute.

Result: partially active RB parking semantics can vary by wrapper order.

This needs an explicit RC/upstream owner boundary before target-stack adoption.

### RB-50 — RB smoothed-pedal hook feeds directly into MR's control path
**CONFIRMED_STATIC / HIGH**

Exact MR uses the global `WheelsUtil.getSmoothedAcceleratorAndBrakePedals()`
inside its own drivetrain controller.

RB can force accelerator/brake values through that function for parking.

Therefore RB is not merely "after MR"; its parking demand can become an input
to MR itself.

This is potentially a useful integration point if formalized, but the current
global overwrite is an implicit contract.

Preferred:
- explicit normalized BrakeDemand input;
- MR consumes it deliberately;
- no hidden global function interception.

### RB-51 — low-speed thermal heating has a large flat speed floor
**CONFIRMED_STATIC / PHYSICS**

RB uses:
`speedFactor = max(speedKmh / 60, 0.55)`.

Above the minimum heating speed, all speeds below about 33 km/h therefore use
the same speed contribution.

At equal pedal/mass:
- 5 km/h;
- 15 km/h;
- 30 km/h

can produce essentially the same heating-rate speed factor.

This was intentionally added to fix under-heating of heavy slow vehicles, but
it is another reason to prefer actual dissipated brake work rather than a
speed proxy.

### RB-52 — parking "roll free" can suppress another owner's base brake force
**CONFIRMED_STATIC / HIGH OWNERSHIP**

For an unattended non-AI vehicle with parking released or classified as
exceeded, RB multiplies the `superFunc` brake force by
`PARK_SLIP_BRAKE_FACTOR=0.06`.

Because `superFunc` can already include base/other-owner brake force, this is
not only "removing RB parking". It can reduce another subsystem's effective
brake capability.

This strengthens the requirement for one final brake actuator/composition
boundary.

### RB-53 — RBDiagBrazo is a valuable generic developer-tool precedent
**POSITIVE_PATTERN / CROSS-PROJECT**

The package includes a diagnostics module unrelated to brake simulation.

It can explain hydraulic moving-tool failure by checking:
- selected control group;
- Easy Arm semantics;
- whether the action event actually registered;
- key-collision symptoms;
- last input time;
- move command;
- movement limits;
- getIsPowered();
- motor state;
- mod specializations present.

This is directly relevant to the recent native PTO input debugging experience.

RE opportunity:
build a generic dev-only `InputActionDiagnostics` / `VehicleControlDiagnostics`
service instead of embedding similar diagnostics independently in features.

Potential capabilities:
- input action registered/active/collision state;
- current action event ID/text;
- feature-specific callback counters;
- selected/controlled vehicle;
- power/interlock blockers;
- last transition/rejection reason.

Do not copy the unlicensed RB source; preserve the diagnostic idea.


## Final source-pass additions

### RB-54 — parking-brake save field is written/read but not registered in XML schema
**CONFIRMED_STATIC / PERSISTENCE HIGH**

The 1.3 source correctly changed parking persistence to typed
`getBool()/setBool()`, but the schema-registration paths declare only:
- `#brakeDamage`;
- `#brakeTempC`.

`saveToXMLFile()` also writes:
`#parkBrakeOn`,
and `onLoad()` reads it, yet neither `RealisticBrakes.initSpecialization()`
nor `RBRegister.injVehicleInit()` registers that BOOL path.

The source comments explicitly note that FS25 rejects unregistered save paths.

Therefore the parking-persistence repair is incomplete at the schema boundary.

Target/upstream fix:
- register `XMLValueType.BOOL ...#parkBrakeOn` in the one canonical schema
  registration path;
- add a save/reload harness/test so a comment-level fix cannot regress again.

### RB-55 — long inactive/sleep cooling intervals over 300 s are deliberately discarded
**CONFIRMED_STATIC / THERMAL LIFECYCLE**

Brake cooling tries to compensate for sparse vehicle updates by measuring
`g_currentMission.time`.

However the measured interval is used only when:
`0 < realDiffSec < 300`.

At 300 s or more the code falls back to the ordinary current-frame `dtSec`.

Consequences:
- a vehicle not updated for >5 minutes can retain much more heat than the
  exponential model implies;
- sleeping/time acceleration or long inactive periods are not reconciled;
- `brakeTempC` is persisted, but no timestamp is persisted to cool it across
  save/reload/offline elapsed time.

Positive lesson: exact exponential cooling is ideal for elapsed-time
reconciliation.

Future model:
- persist/track an explicit thermal timestamp;
- clamp elapsed time to a documented maximum if necessary;
- evaluate `T=Tamb+(T0-Tamb)*exp(-k*elapsed)` directly rather than discarding
  a valid large interval.

### RB-56 — a parking brake that has exceeded hold capacity stops contributing forced thermal demand
**CONFIRMED_STATIC / MODEL LIMIT**

For thermal input the source forces `pedal=1` only when:
`parkBrakeOn and not parkHoldExceeded`.

But `parkHoldExceeded` is precisely the state in which the parked vehicle may
roll/drag against the residual parking brake.

Therefore the current thermal model can under-represent frictional heating
during a dragged/slipping failed parking brake.

A brake-work model fixes this naturally:
- if the actuator still develops brake torque and the wheel rotates, it
  dissipates energy and heats;
- no special parking-state thermal heuristic is required.

### RB-57 — input actions do not use the collision-safe registration pattern learned from RDS/PTO
**CONFIRMED_STATIC / UX-COMPATIBILITY**

RB declares:
- `RB_EXHAUST_TOGGLE` default `B`;
- `RB_PARK_BRAKE` default `N`;
with `ignoreComboMask=false`.

Vehicle action registration uses the ordinary `addActionEvent` call and does
not:
- request the optional collision-bypass registration used by current RDS/native
  RE PTO;
- explicitly call `setActionEventActive(..., true)`;
- expose registration-failure telemetry.

This is not proof that the defaults currently collide, but the stack has
already produced real silent input-collision failures in RDS/PTO work.

If RB enters the target stack:
- test both actions in the full keymap;
- add observable registration health;
- preserve user bindings during any future default migration.

### RB-58 — capability modules cannot be cleanly disabled independently
**CONFIRMED_STATIC / INTEGRATION HIGH**

The physical specialization bundles:
- parking;
- engine/exhaust brake;
- thermal/fade;
while trailer air is separately toggleable through settings.

There is no equivalent stable user/config/API switch to keep, for example,
thermal fade while disabling only RB engine-brake physical ownership under MR.

This materially affects stack adoption.

A high-value upstream improvement would expose independent capability switches:
```text
parkingEnabled
serviceThermalEnabled
engineRetarderEnabled
trailerPneumaticEnabled
```
with authoritative server settings.

That could make "keep RB external" much easier than writing compatibility
suppression around global hooks.

### RB-59 — schema registration itself is duplicated across two installation paths
**CONFIRMED_STATIC / MAINTAINABILITY**

The source deliberately attempts save-schema registration from both:
- `RealisticBrakes.initSpecialization()`;
- an appended `Vehicle.init` callback,

guarded by `RBRegister.schemaRegistered`.

The defensive intent came from real save bugs and is understandable, but the
duplication helped make `parkBrakeOn` easy to omit from both places.

General lesson:
- define the schema field list once;
- call one idempotent registrar from any necessary lifecycle entry;
- test the final registered schema rather than duplicating field declarations.

### RB-60 — service-brake thermal technology should be profile-driven if ever replaced
**DESIGN OPPORTUNITY**

RB distinguishes car/truck/tractor through heating/cooling multipliers but uses
one vehicle-level fade/damage curve.

A future higher-fidelity implementation should separate:
- brake family: dry disc / drum / wet multi-disc / other;
- effective thermal mass;
- cooling coefficient;
- fade curve;
- burn/damage thresholds;
- front/rear or axle bias when justified.

This is the brake-domain analogue of RDS glow-technology profiles and
TerraFarm-style declarative capability profiles.

Do not infer the final brake family from store category alone.
