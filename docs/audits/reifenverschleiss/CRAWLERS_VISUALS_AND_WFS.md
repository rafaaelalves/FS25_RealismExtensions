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


## 12. Raptor visual asymmetry is lost

Status: **CONFIRMED_STATIC**.

The core persists one wear value per crawler/track, but the Raptor visual path:
1. collects render refs for all Raptor crawlers into one vehicle-level list;
2. computes one scalar wear equal to the **maximum** wear across all Raptor crawlers;
3. applies that same scalar to every Raptor render ref.

Therefore left/right track wear can be physically/persistently different while both visible tracks render at the more worn side.

The generic crawler and T9 paths keep per-crawler wear separately; this loss is specific to the Raptor renderer.

Recommended fix:
store refs grouped by crawler and apply each crawler's own wear.

## 13. Special crawler workshop/native reset is incomplete

Status: **CONFIRMED_STATIC**.

The generic full reset path (`resetVehicleWearState -> resetVehicleWearVisuals`) and the explicit `resetVehicleWearVisualsImmediate` crawler reset primarily write `trackProfileWear` on `crawler.scrollerNodes[].node`.

But special crawler renderers use different parameters:
- Raptor: `crawlerProfileWear`;
- A8800/Hover: `a8800ProfileTestWear`;
- Hannibal: `hannibalProfileWear`;
- Volvo: `volvoProfileWear`.

`resetVehicleWearVisualsImmediate` then invokes only the T9 worker, not the generic/Raptor/special-steel worker.

Consequences:
- custom `ALL` replacement can clear state while a special crawler remains visually worn;
- native repair/repaint uses the same incomplete generic reset;
- the correct renderer may only catch up later if the vehicle becomes/currently is processed by the mission visual worker.

Ironically, component-specific `TRACKS` replacement is better because `resetRunningGearWorkshop` calls `refreshVehicleWearVisualsImmediate`, which routes to the appropriate crawler worker.

Recommended fix:
all reset paths should finish through the same dispatcher used by `refreshVehicleWearVisualsImmediate`.

## 14. Numeric weak-key misuse also exists in Visual

Status: **CONFIRMED_STATIC lifecycle defect**.

Several tables are documented/used as weak per-node caches but are keyed by numeric entity IDs:
- `trackWearNodes`;
- `trackWearMaterialSlots`;
- `raptorTrackWearMaterialSlots`;
- `a8800TrackWearMaterialSlots`;
- `specialSteelTrackWearMaterialSlots`;
- `trackProfileClaasSpecial`.

Numeric keys are not collectable object references, so weak-key semantics do not remove these entries when a vehicle/node is destroyed.

Additional `trackProfileBodyY` is a normal strong table keyed by numeric node ID.

This is especially important because comments explicitly say the slot tables guarantee one fresh material per *live node lifetime*. With numeric keys and no delete cleanup, a reused engine node ID can inherit stale slot state from an old vehicle.

Potential effects:
- material installation skipped on a newly spawned/re-rented vehicle;
- stale original/replaced material bookkeeping;
- incorrect CLAAS special classification/body data;
- retained numeric cache growth.

This is the same underlying Lua-lifecycle mistake as EWFS's `nodeVehicles/shapeVehicles`.

## 15. Volvo immediate-load safety flag is dead

Status: **CONFIRMED_STATIC dead guard / safety risk**.

The Volvo steel-track path contains an explicit safety check:

`if RVV._inImmediateLoadRefresh == true then return false end`

The comments say this guard exists because material replacement during `onFinishedLoading` previously caused a native engine crash.

But `_inImmediateLoadRefresh` is never assigned anywhere in the package.

Immediate refresh code sets `_forceCrawlerVisualRefresh`, not `_inImmediateLoadRefresh`.

A second guard requiring the Volvo to be the controlled vehicle usually prevents early material replacement, so a crash is **not** proven. However the safety mechanism described in the source is objectively nonfunctional and should be repaired.

## 16. Early negative crawler classification can become permanent

Status: **STRONG_CANDIDATE**.

`rvDetectCrawlerMotionPathKind` caches `false` when `crawler.loadedCrawler` is not yet available.

`rvGetCrawlerVehicleType` then caches a vehicle-level classification.

Those caches have no retry/invalidation path.

If classification occurs before crawler render geometry is ready, a steel crawler can be cached as the fallback generic-rubber class for the rest of that vehicle lifetime.

The onFinishedLoading/settling queue likely makes this uncommon, so runtime timing evidence is required before calling it an observed bug.

## 17. Generic/Raptor material caches retain the dead-entity pattern

Status: **STRONG_CANDIDATE**.

The A8800/special-steel code explicitly says an earlier global material cache could hand a dead GIANTS material entity to a newly spawned/returned vehicle, and therefore intentionally builds a fresh material per live node/slot.

However:
- `trackMaterialCache[originalMaterialId]` remains global for generic/T9 rubber paths;
- `raptorTrackMaterialCache[originalMaterialId]` remains global for Raptor.

Both keys are numeric material IDs and there is no mission/vehicle deletion invalidation.

Given the source's own documented dead-material failure mode, generic/Raptor return/rent/reload scenarios deserve a targeted lifecycle test.

## 18. Generic crawler renderer mutates GIANTS scroller data

Status: **DESIGN_RISK**.

When `crawler.scrollerNodes[].nodes` is absent, Reifen synthesizes a table from `entry.node` and writes it back into:

`entry.nodes = targets`.

This is convenient for its own traversal, but changes a GIANTS-owned crawler structure rather than keeping an internal normalized view.

A later mod/engine routine can no longer distinguish "GIANTS supplied nodes" from "Reifen synthesized nodes".

Prefer a Reifen-local normalized target list.

## 19. Passive-object visual gate tests pcall success, not attachment result

Status: **CONFIRMED_STATIC low-severity logic issue**.

`initializeWheelVisuals` defines `isPassiveObject` using:

`... and pcall(vehicle.getAttacherVehicle, vehicle)`

In boolean context this uses only pcall's first return value (the call succeeded), not the returned attacher vehicle.

An unattached object with a working `getAttacherVehicle` method is therefore classified as passive.

The practical consequence is limited: it only broadens the alternative shader-parameter entry path, but the code/comment do not match the actual predicate.

## 20. EWFS per-mission VehicleSystem hook is not reinstalled

Status: **CONFIRMED_STATIC lifecycle defect**.

`WFS.install()` wraps the current mission's `vehicleSystem.setEnteredVehicle` and sets:
- `WFS.installed=true`;
- `WFS.vehicleSystemEnterHooked=true`.

Neither flag is reset by mission unload.

On the next save loaded in the same process, `WFS.install()` returns immediately, so the new mission's new VehicleSystem instance never receives the enter-vehicle refresh hook.

Global class/engine wrappers remain installed, so EWFS still largely works. What is lost is the intended immediate state/HUD refresh at the mission-specific vehicle-entry boundary.

This parallels the repair/repaint message-subscription reload bug and supports adding one explicit Reifen mission-lifecycle reset.
