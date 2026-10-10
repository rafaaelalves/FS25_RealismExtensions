# Real Tire Wear 1.6.0.0 static findings

Exact package:
- version: `1.6.0.0`
- SHA-256: `5bee35b0e0e88b3c8b03f0027abff00935469ef06679b24e309bc43355d314da`

Evidence labels:
- **CONFIRMED_STATIC**
- **POSITIVE_PATTERN**
- **DESIGN_RISK**
- **RUNTIME_PENDING**
- **ASSIMILATION_LESSON**

## RTW-01 Durable wear is server-authoritative
**POSITIVE_PATTERN / CONFIRMED_STATIC**

Wear progression and puncture decisions execute only when `vehicle.isServer`
is true.

Clients receive durable state from the server rather than independently
advancing their own wear simulation.

Adopt this principle for RE.

## RTW-02 Initial and incremental synchronization are explicit
**POSITIVE_PATTERN**

Initial state:
- `onWriteStream/onReadStream`.

Incremental state:
- `TireWearEvent`.

Wear is quantized to UInt8 and damage is a bool.

This is a good fit for slow-changing persistent state.

## RTW-03 Client-originated wear-state writes are rejected
**POSITIVE_PATTERN**

`TireWearEvent:run()` returns when a non-server connection attempts to apply
wear/damaged state on the server.

Durable physical state therefore has a clear authority boundary.

## RTW-04 Persistence is per vehicle, per wheel index
**CONFIRMED_STATIC / DESIGN_RISK**

State is saved under:

`vehicles.vehicle(?).realTireWear.wheel(?)`

with:
- wear;
- airLeak.

This is straightforward, but wheel-index identity can become fragile if vehicle
configuration/order changes between sessions.

Future RE state should have a stable running-gear identity/signature in addition
to transient GIANTS index.

## RTW-05 Base wear is driven by root-vehicle translation distance
**CONFIRMED_STATIC model limitation**

`onUpdateTick()` measures root-node world displacement and passes one common
vehicle distance into every tire.

Consequences:
- stationary/near-stationary wheelspin produces little or zero tread wear;
- turning-radius differences are not represented in base distance;
- wheel circumferential travel is not the primary physical quantity.

Do not copy this wear basis.

## RTW-06 Attached implements can be treated as grounded when their wheel is not
**CONFIRMED_STATIC defect candidate**

`hasWheelGroundContact()` returns true for an attached object merely because
its root vehicle differs from the owner, even after direct
`physics.hasGroundContact` is false and no positive contact force is found.

That can allow lifted/airborne implement wheels to retain a nonzero wear factor.

Future RE must use authoritative contact state only.

## RTW-07 Slip factor is monotonic and easy to diagnose
**POSITIVE_PATTERN**

Effective slip is:
- max(longitudinal slip, 0.70 × lateral slip);
- clamped to 0..2.

The wear multiplier rises piecewise from:
- 1.0 at <=0.20 slip;
- to 2.25 at >=1.0.

The transparency is good.

The physical model is still incomplete because the multiplier is applied to
vehicle translation distance rather than actual slip distance/work.

## RTW-08 Relative load factor is not absolute tire stress
**CONFIRMED_STATIC model limitation**

The mod compares a wheel's contact force with the average contact force of the
currently contacting wheels:

`factor = clamp(0.65 + 0.35 × load/averageLoad, 0.75, 1.60)`

This redistributes wear within a vehicle but cannot distinguish a globally
lightly loaded vehicle from a globally overloaded vehicle if all wheels scale
together.

RE should prefer:
- absolute wheel load;
- support/contact width;
- tire pressure;
- rated/reference load where available.

## RTW-09 Speed multiplier is an independent arbitrary wear amplifier
**DESIGN_RISK**

Up to 10 km/h: 1.0.

10→50 km/h: linear rise to 1.30.

Above: 1.30.

Because wear is already per traveled distance and slip/load are separate, this
speed term approximates heat/high-speed stress without modeling either.

A future RE model should not add a generic speed multiplier unless it represents
a named physical phenomenon.

## RTW-10 Ground multiplier is coarse and likely double-counts soft-soil stress
**DESIGN_RISK**

Factors:
- ROAD 1.00;
- HARD 1.08;
- FIELD 1.15;
- SOFT 1.25.

Slip is already another multiplicative factor.

This makes soft soil intrinsically more abrasive even before its extra slip is
accounted for.

Future RE should separate:
- abrasiveness;
- wetness;
- sink/contact pressure;
- slip work.

## RTW-11 Correlated multipliers are multiplied blindly
**DESIGN_RISK**

`slip × load × speed × ground` is clamped only after multiplication.

Several signals can represent the same underlying stress/energy increase.

The architecture is simple but can double-count causally correlated effects.

Prefer named wear channels or an energy/work model.

## RTW-12 Grip degradation is relative and monotonic
**POSITIVE_PATTERN**

Grip factor:
- 0% wear: 1.00;
- 70%: 0.80;
- 90%: 0.55;
- 100%: 0.40.

The curve is monotonic and is applied as a degradation multiplier to the
current friction multiplier.

This is a stronger semantic pattern than an absolute final target.

Adopt the **relative-degradation principle**, not necessarily these exact values.

## RTW-13 Physical grip writes run every update tick
**CONFIRMED_STATIC performance/ownership risk**

For every serviceable wheel, `updatePhysicalWear()` can call
`setWheelShapeTireFriction()` every tick.

This happens even though durable wear changes very slowly.

The base traction state may also be owned/updated by MR/Mud in the target stack.

Future RE should publish a wear factor and let the final traction owner compose
it, rather than becoming an independent high-frequency friction writer.

## RTW-14 Visual tire wear is also refreshed every update tick
**CONFIRMED_STATIC performance issue**

Normal wheel visual wear is traversed/applied from `onUpdateTick()` even when
wear has not changed.

Material installation is cached per tire/node, but shader parameter writes still
do not need to follow the simulation tick.

Prefer dirty/quantized visual updates.

## RTW-15 Puncture checking runs per wheel every tick to service a 60-second test
**CONFIRMED_STATIC optimization opportunity**

Each wheel advances a puncture timer every update tick.

The actual random check interval is 60,000 ms.

A scheduler/vehicle-level next-check time can remove most of that hot-path work.

## RTW-16 Puncture probability depends almost entirely on wear
**CONFIRMED_STATIC model limitation**

Every 60 s while moving/grounded:

`chancePercent = 0.001 × (1 + 7 × wear²)`

At 0% wear: 0.001% per check.
At 100% wear: 0.008% per check.

Not modeled:
- pressure/underinflation;
- overload;
- heat;
- impact;
- terrain sharpness;
- severe slip;
- sidewall state.

Useful UX, weak failure physics.

## RTW-17 Air-loss progress is cosmetic/local, not authoritative pressure state
**CONFIRMED_STATIC**

Network state is only:
- `damaged` bool.

Each client animates `airLoss` locally over ~8 s.
Join-in-progress state is loaded as already leaked/flat.

This is acceptable for presentation because physical state is not derived from
the continuous air-loss value.

A native RE failure model should instead integrate with the authoritative tire
pressure owner when present.

## RTW-18 A flat tire has no dedicated per-wheel physical traction/rolling model
**CONFIRMED_STATIC**

The puncture adds:
- visible deformation;
- sound;
- global combination speed cap to 15 km/h;
- service requirement.

Grip continues to be driven by tread wear, not by pressure loss.
No explicit puncture rolling-resistance/sidewall/contact-patch consequence is
applied.

Do not copy this physical simplification.

## RTW-19 Combination-wide flat speed cap is useful UX but coarse physics
**ASSIMILATION_LESSON**

`getSpeedLimit()` recursively checks attached implements and caps the whole
combination when any tire is flat.

The propagation behavior is useful.

A future RE model should derive safe/effective speed from failure severity and
vehicle role rather than a single hard-coded 15 km/h limit.

## RTW-20 Structural tread-radius loss is effectively absent
**CONFIRMED_STATIC**

The source defines:
- `PHYSICS_TREAD_LOSS_FACTOR`;
- tread-depth/radius constants.

But `PHYSICS_TREAD_LOSS_FACTOR` is not used.

`updatePhysicalRadius()` targets the stored original radius, meaning the
function holds/restores the original physics radius instead of shrinking it with
wear.

Do not infer structural-radius ownership from the feature description.

Reifen 1.2.2.70 is the stronger architectural reference for wear-only structural
radius.

## RTW-21 Crawler wear is not a first-class persistent track object
**CONFIRMED_STATIC**

Persistent wear remains attached to member wheel entries.

Crawler visual wear discovers member tires and averages their wear.

Service mode has special paired-wheel heuristics for all-crawler vehicles.

For RE, use a typed first-class `RUBBER_TRACK` / `STEEL_TRACK` wear unit and
treat internal wheels/rollers separately.

## RTW-22 Crawler discovery contains several heuristic fallbacks
**DESIGN_RISK**

Membership can be inferred via:
- crawler wheel tables;
- wheel indices;
- node identity;
- nearest crawler geometry;
- positional pairing;
- side fallback.

This is resilient, but also evidence that the underlying identity model is not
canonical.

Normalize contact/running-gear identity once and reuse it.

## RTW-23 Global crawler material-slot cache has no explicit lifecycle cleanup
**CONFIRMED_STATIC lifecycle risk**

`TireWear.trackWearMaterialSlots` is a global table keyed by engine node IDs.

It is not weak and is not cleared in a mod-level delete lifecycle.

Reused numeric entity IDs can therefore retain stale material association.

Do not reproduce this cache ownership.

## RTW-24 Normal tire visual cache is better scoped
**POSITIVE_PATTERN**

`tire.realTireWearNodes` belongs to the per-vehicle/per-wheel state.

When the vehicle disappears, the state naturally disappears with it.

Prefer object-owned caches over global numeric-node caches.

## RTW-25 Workshop replacement is axle-aware
**POSITIVE_PATTERN**

The workshop discovers axle groups using local Z coordinates with a 0.10 m
grouping tolerance.

If geometry is unknown it falls back to ordered pairs.

This is a useful generic discovery heuristic for service presentation.

The normalized axle topology should be built outside the UI layer and reused by
wear/service/diagnostics.

## RTW-26 Workshop price is simple but not component-grounded
**DESIGN_RISK**

Full tire set price:
`2.5% × vehicle price`.

Selected service scales by fraction of units and by average wear.

A damaged unit establishes a minimum cost contribution equivalent to 25% wear.

This is usable gameplay, but does not reflect:
- tire configuration;
- size;
- brand/type;
- track vs tire;
- part availability;
- labor.

Use only as fallback inspiration.

## RTW-27 Replacement validates funds but not requester authority
**CONFIRMED_STATIC MP/security gap**

The server:
- finds the vehicle owner's farm;
- checks that farm's money;
- debits that farm.

It does not validate that the requesting connection is authorized to service
that farm/vehicle.

A malicious/incorrect client request could therefore target another farm's
vehicle if it can reference it.

Future RE service events must validate requester farm/permission/server context.

## RTW-28 Continuous wear sync is efficient
**POSITIVE_PATTERN**

The server sends a wear event only when the packed UInt8 wear value changes or
damage changes.

At 500 km default lifetime this is intrinsically low-frequency.

This is a good durability-state networking pattern.

## RTW-29 Workshop UI hooks broad global GUI surfaces
**DESIGN_RISK**

The mod:
- appends WorkshopScreen open/close/setVehicle;
- overwrites `Gui.mouseEvent`;
- appends `Gui.draw`;
- can re-register/recreate the workshop screen.

This is invasive for one service feature and increases UI compatibility risk.

RE should prefer supported screen extension/composition points or a shared
native RE service panel rather than global GUI ownership.

## RTW-30 Workshop hook installation has weak explicit teardown
**CONFIRMED_STATIC lifecycle risk**

`deleteMap()` clears local UI references/action events but does not restore the
global WorkshopScreen/Gui wrappers.

Flags also persist at module scope.

Multi-save/same-process lifecycle deserves caution.

Do not copy this hook model.

## RTW-31 Hard-coded external-mod exclusion is technical debt
**CONFIRMED_STATIC**

`isExcludedVehicle()` contains a specific check for
`fs25_lsfmfarmequipmentpack`.

That may be pragmatic for the author's support matrix, but is not acceptable as
the normal architecture of a native RE capability.

Use semantic wheel eligibility/capability checks instead.

## RTW-32 Wheel eligibility is visual/serviceability based
**DESIGN_RISK**

A wheel is serviceable if it:
- looks like a tire through `WheelVisualPartTire`;
- or is classified as crawler by several heuristics.

It does not explicitly distinguish:
- pneumatic tire;
- solid tire;
- helper/caster;
- roller;
- crawler member;
- non-contact visual wheel.

This reinforces the existing RE/RC need for a normalized WheelEligibility /
RunningGearUnit contract.

## RTW-33 No explicit integration exists with MR/Mud/RMS/Reifen
**CONFIRMED_STATIC**

Source contains no stack-specific contract for:
- MoreRealistic;
- MudSystemPhysics;
- RMS;
- Reifenverschleiss.

Running Real Tire Wear beside Reifen would create duplicate wear ownership.
Running it beside MR/Mud can create friction-order ownership dependence.

Do not add an RC bridge merely to make two tire-wear owners coexist.

## RTW-34 The physical-friction formula is composition-friendly in concept
**POSITIVE_PATTERN / RUNTIME_PENDING ordering**

The mod derives:

`finalFriction = currentBaseFriction × wearGrip`

rather than choosing a new absolute coefficient.

This is the correct semantic direction.

However it then directly calls the wheel-shape actuator, so execution order
against MR/Mud still matters.

RE should publish the relative factor and let the correct final owner apply it.

## RTW-35 Current update cadence mixes state, presentation and actuator work
**ARCHITECTURE_LEARNING**

One `onUpdateTick` path performs:
- tire-node discovery;
- puncture timer/update;
- grip calculation;
- tire shader update;
- wheel friction write;
- crawler visual update;
- server wear progression;
- network replication.

Future RE should split:
- slow persistent wear integration;
- event/dirty failure state;
- physics composition;
- presentation refresh;
- network replication.

Different domains deserve different cadences.

## RTW-36 Default lifetime is 500 km unless vehicle XML overrides it
**CONFIRMED_STATIC**

`DEFAULT_LIFETIME = 500000` meters.

This is simple, but one global distance is not physically appropriate across:
- tractor road tires;
- implement tires;
- forestry tires;
- high-speed transport tires;
- rubber tracks.

RE should use class/profile parameters, with config override as policy rather
than one hidden universal constant.

## RTW-37 License/provenance is ambiguous
**CONFIRMED_STATIC / PROJECT_POLICY**

The supplied archive has no LICENSE file.

The source header states that the script must not be changed without author
permission.

A public distribution page labels the file GPL.

Until an authoritative license grant is resolved, all assimilation must remain
clean-room:
- study behavior/architecture;
- write new code/shaders/assets;
- do not transplant implementation.
