# Reifenverschleiss crawlers, visuals and EWFS

## 1. Crawler model

Reifen treats each crawler as a first-class track wear object.

Discovery uses:
- `spec_crawlers.crawlers`;
- member wheel resolution;
- local geometry/signature;
- crawler side;
- material/vehicle-family classification.

This is more semantically appropriate than assigning independent tire wear to hidden crawler support wheels.

## 2. Rubber versus steel

The wear model distinguishes:
- `RUBBER_TRACK`;
- `STEEL_TRACK`.

They receive different road/field/hard/soft/mud factors and snow behavior.

Visual support is partly generic and partly family-specific, with explicit paths for machines/material layouts such as T9, Raptor, A8800/Hover and selected steel crawlers.

Lesson for RE:
grouped crawler identity should be generic; special visual/material knowledge should remain outside contact physics.

## 3. Roller wear

Reifen classifies crawler rotating parts by radius:
- largest sprocket/idler class excluded;
- smaller rotating parts treated as road rollers;
- ambiguous structures fail closed;
- a Leitwolf-specific fallback uses reference wheels.

Roller wear is deliberately mileage-only:
- no soil factor;
- no weather;
- no load;
- no slip.

Each track receives a persistent random lifetime factor from approximately 1.7 to 2.5.

That random factor is saved, which is good for long-term consistency after persistence is established.

In MP/new-purchase state, lack of explicit synchronization means peers can potentially create different initial random factors before saved state exists; runtime validation is required.

## 4. Roller speed malus mismatch

Source method:
`getRubberTrackRollerWear01ForSpeedMalus`

explicitly excludes `STEEL_TRACK`.

Only confidently detected rubber-track roller wear can reduce physical max forward speed.

Public/release descriptions state the maximum-speed penalty applies to tracked vehicles with rubber or metal tracks.

Therefore current source and published behavior are inconsistent.

Classification: confirmed implementation/documentation mismatch. Decide intended behavior before patching.

## 5. Visual wear versus physics

Round tire wear affects physical radius.

Crawler wear is predominantly visual/material/geometry handling and does not rewrite hidden crawler-wheel physics radius in the same way.

This separation is sensible: continuous crawler contact geometry cannot be represented correctly by simply shrinking every pseudo-wheel.

## 6. EWFS architecture

EWFS is an electronic five-second startup immobilizer designed to block controller/AI paths that can bypass the normal start sequence.

It wraps many layers:
- Drivable acceleration input;
- Drivable update;
- vehicle-instance `controlVehicle`;
- `Motorized.startMotor/stopMotor`;
- AIVehicleUtil drive methods;
- WheelsUtil smoothed pedals;
- `WheelsUtil.updateWheelsPhysics`;
- `WheelsUtil.updateWheelPhysics`;
- low-level `setVehicleProps`;
- low-level `setWheelShapeProps`.

While locked it can:
- zero acceleration/torque;
- force handbrake/brake;
- zero PTO demand in control path;
- add brake force;
- hard-lock wheel torque.

This is by far the Reifen subsystem with the widest compatibility surface.

## 7. EWFS scope mismatch

OWN-WEAR has careful player-farm/mission ownership filters.

EWFS does not reuse them.

Every ~10 ms it scans `mission.vehicles` and calls `updateBlocker(v)`, which also applies roller max-speed state and registers the vehicle.

Therefore EWFS can touch objects outside the wear domain:
- foreign farm vehicles;
- mission vehicles;
- other synchronized motorized objects.

In multiplayer this is especially undesirable.

Recommended architecture:
reuse one explicit Reifen vehicle-eligibility contract for wear, EWFS, visual physics and workshop state, with intentional exceptions documented separately.

## 8. EWFS numeric-key weak-table bug

`nodeVehicles` and `shapeVehicles` are declared as weak-key tables.

Their keys are numeric node/wheelShape IDs.

Weak-key semantics do not make numeric keys disappear with object collection, while the values are strong vehicle references.

There is no Vehicle.delete cleanup.

Consequences:
- deleted vehicle objects can stay strongly referenced;
- stale node/shape owner mappings survive;
- reused numeric engine IDs can resolve to an old vehicle;
- low-level torque/brake wrappers can consult stale ownership.

This is a concrete lifecycle defect and a plausible contributor to deleted-object error classes.

`rollerMaxForwardSpeedState` is also a normal strong vehicle-key table with no delete cleanup.

## 9. EWFS performance

`UPDATE_INTERVAL = 10` ms.

At common FS update cadence the whole `mission.vehicles` scan therefore executes effectively every frame.

After the scan, every `registeredVehicles` entry is evaluated again in the same update.

This is redundant fleet-wide work.

Better split:
- slow discovery/registration cadence, e.g. hundreds of milliseconds or lifecycle events;
- lightweight update only for known active/relevant motorized vehicles;
- explicit delete cleanup.

## 10. Absolute brake/speed ownership risks

### Startup brake force
EWFS captures `motor.brakeForce`, writes `original + 100`, then restores the captured original.

If another mechanical/damage system legitimately changes brakeForce during the lock window, EWFS restoration can overwrite that newer value.

### Roller maxForwardSpeed
The rubber-track malus writes:
`motor.maxForwardSpeed = original * factor`
using `maxForwardSpeedOrigin` when available.

This can compete with another system that owns a dynamic max-speed failure/limiter.

### AutoDrive cruise cap
Reifen captures/restores cruise speed while applying wear limits.

This is another state-restoration boundary worth testing with controller/vehicle-mode mods.

These are composition risks, not yet proven current-stack regressions.

## 11. EWFS should be separable

The core tire-wear model does not fundamentally require a broad vehicle immobilizer except for specific AD/CP startup workarounds.

From a compatibility architecture standpoint, EWFS would be safer as:
- separately toggleable;
- separately versioned;
- or an optional capability activated only when the affected controller paths are present.

That would substantially reduce Reifen's collision surface while preserving its wear model.
