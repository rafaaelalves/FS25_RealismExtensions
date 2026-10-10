# MoreRealistic drivetrain, PTO and workload model

## VehicleMotor ownership

MR globally overwrites the VehicleMotor path and replaces substantial vanilla logic. Converted MR vehicles add richer transmission metadata/calibration, but many of the methods below are installed for all VehicleMotor instances:
- gear shifting;
- direction changes;
- min/max gear ratio;
- automatic gear selection;
- clutch/start-in-gear behavior;
- gear application;
- engine speed/torque handling;
- motor run authority.

This is the primary reason transmission/damage/controller mods require explicit compatibility review.

A wrapper around vanilla `VehicleMotor.updateGear` is not sufficient if MR calls its own `mrUpdateGear` directly.

## Transmission families

The exact source supports:
- ordinary manual/automatic gearbox logic;
- manual-clutch semantics;
- power reverser behavior;
- hydrostatic behavior;
- MR CVT behavior;
- PTO-aware operating ranges.

MR also contains deliberate compatibility fallbacks:
- active AutoDrive vehicle -> use previous/base `WheelsUtil.updateWheelsPhysics`;
- CVTaddon configurations other than MR-supported mode -> use previous/base path.

These fallbacks are partial. Global MR WheelPhysics remains installed.

Therefore PLAYER / GIANTS AI / AutoDrive / CVTaddon can experience different control algorithms while still sharing MR friction/mass physics.

## Confirmed hydrostatic wrong-object lookup

In `VehicleMotor.mrUpdate`, exact 0.26.08.03 tests:

`not self.mrTransmissionIsHydrostatic`

Here `self` is the VehicleMotor.

The flag is loaded onto the vehicle in `Vehicle.mrLoad`.

The expected lookup appears to be:

`not self.vehicle.mrTransmissionIsHydrostatic`

Status: **CONFIRMED_STATIC** field/owner mismatch. Runtime impact pending.

## Hydrostatic engine-brake initialization order

`Motorized.mrLoadMotor` chooses the default engine-braking factor based on `self.mrTransmissionIsHydrostatic`.

But `Vehicle.mrLoad` reads the transmission flag only after its `superFunc` load returns.

This strongly suggests the default hydrostatic 1.5 factor can be missed at motor-load time and the ordinary 0.85 factor selected instead unless XML explicitly overrides it.

Status: **STRONG_CANDIDATE** until GIANTS load-order/harness evidence proves the exact lifecycle.

## Engine load and braking

MR intentionally removes/changes vanilla damping/braking behavior:
- no invisible automatic downhill braking;
- power reverser uses explicit braking/engine-load logic;
- engine braking is translated to per-driven-wheel force;
- PTO over-demand can feed braking/load back into wheel control.

This is a core MR ownership domain. RC should not independently implement generic engine braking.

## PTO canonicalization

Exact MR treats tractor-side PTO ratio as effectively 540-rpm-domain and normalizes tools declaring >540 rpm by scaling required power and setting the consumer's canonical PTO rpm to 540.

This is why Dynamic PTO required RC composition: player-selected physical PTO ratio must be translated into MR's expected domain without permanently corrupting GIANTS/native state.

## Confirmed turn-on peak defect

`PowerConsumer.mrGetConsumedPtoTorque` contains:

`ignoreTurnOnPeak == nil and ignoreTurnOnPeak == false`

A single value cannot satisfy both comparisons.

The turn-on peak power multiplier therefore cannot activate through this condition.

Status: **CONFIRMED_STATIC**.

Potential impact:
- PTO tools lose intended startup/transient peak demand;
- engine may not bog on engagement as strongly as configured;
- turn-on peak XML values can become ineffective in MR's torque path.

Runtime test should compare a tool with an exaggerated/known turn-on peak before and after a harness/local patch.

## Draft-force model

MR implements real force rather than relying only on a speed limiter.

Draft force depends on:
- tool max force;
- actual tool speed;
- tool category;
- global ground wetness;
- field state/crop state;
- whether the soil appears already worked;
- PTO rpm ratio for some soil tools;
- configured work-area/checkpoint geometry;
- low-speed penalty.

The force direction follows actual tool motion at useful speed.

### Already-worked detection

MR samples a checkpoint ahead of relevant work areas and inspects:
- fruit/growth state;
- field density/ground type.

Already-loosened/worked soil receives a lower draft multiplier.

This is conceptually valuable but creates compatibility boundaries with any mod that changes field-state semantics.

## Throughput-based process models

MR converts process output into mechanical demand for multiple machine classes.

### Combine
Tracks liters/sec and crop-specific factors:
- capacity;
- threshing demand;
- chopper demand;
- unloading demand.

Speed can be limited by header/capacity/engine load.

### Baler
Material flow influences:
- power;
- tons/hour;
- speed limit;
- density behavior;
- netting/unload timing.

### Mower / Tedder / Windrower / Forage wagon
Material/area throughput is smoothed and translated into required power.

### Fruit preparer
Worked area/sec becomes power demand with a configured cap.

### Woodcrusher
MR substantially reworks feed/traction and power consumption; it is closer to a subsystem replacement than a coefficient tweak.

## General cross-mod rule

Any mod that modifies:
- yield;
- pickup liters;
- work-area output;
- processing output;
- fill density;
- tool state;
after MR samples those values can make **mechanical demand diverge from the final gameplay output**.

The MR+SoilCompaction combine mismatch was one concrete instance of this general class.

RC should compose dataflow/order rather than duplicate formulas.

## Timestep-dependence watchpoint

Several MR smoothing paths use fixed per-call coefficients rather than `dt`-normalized filters.

Examples include:
- dynamic friction smoothing;
- rolling resistance smoothing;
- wheel load/speed smoothing;
- fuel-use smoothing;
- CVT target smoothing;
- turn-off PTO power decay.

Some process models update their smoothed state only on coarser windows, reducing the concern. Wheel/control paths need runtime cadence testing.

Status: **RUNTIME_PENDING**, not declared a gameplay bug yet.


## Second-pass finding: draft-force early returns abort PTO bookkeeping

Status: **CONFIRMED_STATIC**.

Inside `PowerConsumer.mrOnUpdate`, the draft-force block can return from the entire function when:
- `getLinearVelocity(forceNode)` yields no usable X/Z velocity; or
- the configured force node is farther from terrain than `mrPowerConsumerMaxGroundDistanceToApplyDraftForce`.

Those returns occur before:
- decrementing `turnOnPeakPowerTimer`;
- calling `PowerConsumer.mrUpdatePtoPower(self, dt)`.

The intent appears to be "do not apply ground draft force in this state", but the implementation also suppresses unrelated PTO/update bookkeeping for the frame.

This is not purely theoretical: multiple converted headers configure both a nonzero PTO demand/maxForce and `maxGroundDistance`.

Preferred fix shape:
- skip only the draft-force calculation;
- always continue to the common timer/PTO update tail.

## Process-model warm-up state

Status: **CONFIRMED_STATIC, low severity**.

Several throughput models initialize their sampling timestamp to zero and clear the material/area buffer when work stops without necessarily resetting the timestamp at the same transition.

Examples include Mower, Tedder, Windrower and ForageWagon; Combine/Baler use related buffer-start-time schemes.

After a long idle, the first fresh sample can therefore be divided by an elapsed interval that includes inactive time, temporarily under-reporting throughput/power until the next sample window.

This is a lifecycle/warm-up artifact rather than persistent material loss. Any telemetry/calibration test should discard the first sample after activation unless/until the model is changed.
