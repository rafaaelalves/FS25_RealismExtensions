# Realistic Brakes trailer air + RDS integration

Updated: 2026-10-06  
Exact baseline: RB 1.3.0.0 + exact RDS 1.4.0.0 cross-read.

## Why this matters

This exact source closes the largest intentionally-open RDS audit gap:
- how current Realistic Brakes consumes RDS truck pressure;
- how trailer reservoirs are represented;
- how hoses control spring brakes;
- how final trailer braking is applied;
- what is still missing physically/network-wise.

## Current architecture

```text
RDS truck
  spec.airPressure
  rdsGetAirPressure()
  rdsSetAirPressure()
        |
        v
RBTrailerAir
  trailer spec.presion
  ConnectionHoses state
        |
        +--> pressure equalization
        |
        +--> spring-brake state
                  |
                  v
        setCustomBrakeForce + pedal
                  |
                  v
             wheel physics
```

This is a useful proof that a narrow public RDS API reduced private coupling.

It is not yet a complete pneumatic system.

---

## Hose semantics

RB recognizes GIANTS hose types:
- `airDoubleRed` -> supply;
- `airDoubleYellow` -> control/service.

That mapping is useful.

However, the current state test marks `SIN_MANGUERAS` when **any compatible air hose is disconnected**.

### Physical correction

Supply and service lines have different consequences.

Target semantics:
```text
SUPPLY/EMERGENCY line
  fills trailer reservoir
  maintains spring-brake release
  loss/low pressure -> spring brakes apply

SERVICE/CONTROL line
  carries service-brake command
  loss -> trailer service braking unavailable/degraded
  does not by itself require dumping spring release pressure
  while healthy supply remains
```

Therefore future connector state should expose:
```text
supplyConnected
serviceConnected
```
separately.

Do not collapse them into `allAirHosesConnected`.

---

## Reservoir model

RB persists one scalar gauge pressure per trailer:
```text
spec_rbTrailerAir.presion
```

New trailer default: 0 bar.

Detached trailer retains its stored scalar in save data.

When connected to an RDS truck, RB computes:
```text
pEqual =
  (pTruck * VTruckProxy + pTrailer * VTrailerProxy)
  / (VTruckProxy + VTrailerProxy)
```

Proxy volumes:
- truck = 12 * wheel count;
- trailer = 8 * wheel count.

### Positive lesson

This is materially better than:
```text
trailerPressure = truckPressure
```

It attempts to conserve stored air across two capacities.

That validates the RE direction:
```text
Q ~ P_abs * V
```
rather than treating pressure alone as a resource.

### Limits

The proxy volumes are not actual reservoir/chamber sizes.

Wheel count cannot represent:
- chamber diameter/stroke;
- tank capacity;
- multi-axle brake architecture;
- tractor fifth-wheel load transfer;
- different trailer designs.

Use:
- native metadata where meaningful;
- profiles;
- curated evidence.

---

## Instant equalization

RB equalizes truck/trailer pressure immediately in one server call.

There is no:
- hose flow limit;
- valve conductance;
- line volume;
- supply-valve restriction.

The user still experiences longer refill because the RDS compressor must refill the combined pressure after the instant drop, but connection equalization itself has no transient.

Target future transfer:
```text
maxTransferAmount = flowCapacity * dt
requestedDelta = pressure/capacity-driven
actualTransfer = min(requestedDelta, maxTransferAmount, safety limits)
```

This makes:
- hose/valve size;
- trailer fill time;
- protection valve
meaningful.

---

## Tractor-protection / supply reserve

RB source comments correctly mention that a real towing vehicle is protected,
but the algorithm does not implement a protection cutoff.

An empty/low trailer can lower truck pressure immediately through equalization.

Future RE requirement:
```text
if truck supply pressure <= protectionCutoff:
    stop trailer supply transfer
```

This preserves towing-vehicle reserve and lets:
- trailer supply fall;
- trailer spring brakes apply;
- truck retain its own braking capacity.

The exact threshold must be profile/calibration data rather than copied blindly.

---

## Spring/service priority

RB has:
- one trailer pressure;
- one release threshold (~60 psi / 4.14 bar).

It does not model:
- spring-brake priority;
- service-brake priority;
- separate effective circuit availability.

Future topology can remain simple in MVP but should not make the API impossible to extend.

Possible state:
```text
trailerSupplyPressure
springReleaseAvailable
serviceBrakeAvailable
```

Later:
```text
springReservoir / serviceReservoir
```
only if fidelity justifies it.

---

## Trailer service-air consumption — missing in RB

The custom RB trailer reservoir is not consumed by ordinary service-brake applications.

This is a major gap.

### Native GIANTS opportunity

FS25 Attachable already exposes:
```text
vehicle.attachable.airConsumer#usage
getAttachbleAirConsumerUsage()
```

The attacher chain aggregates attached implement air usage into the towing vehicle's air-consumer usage.

This is valuable evidence for the RDS/RE native AIR study:
- trailers already declare a semantic air demand in XML;
- RE may be able to consume/reinterpret that metadata;
- it can be stronger evidence than wheel-count inference.

This does **not** mean the vanilla algorithm is physically correct. GIANTS still drains AIR continuously from brake input.

But the metadata itself may be reusable as:
- relative chamber/circuit demand;
- capability evidence;
- fallback profile calibration.

### Target service demand

For the RE physical model:
```text
positive service-command change
 -> fill service chambers/circuit
 -> withdraw stored air amount

stable held command
 -> no repeated full fill
 -> only leakage / control corrections

release
 -> chamber air vents
 -> not returned to reservoir
```

---

## Trailer leakage

RB has no trailer leak model.

Future:
- healthy baseline leak;
- optional condition/fault leak;
- elapsed-time reconciliation;
- no generic random wear in MVP.

Disconnected trailers should slowly lose air according to the selected physical policy rather than retaining pressure forever.

---

## Spring-brake release/apply

RB release threshold:
~60 psi.

Its state has no separate apply/release hysteresis.

Future:
- explicit profile thresholds;
- modest hysteresis if appropriate to prevent chatter;
- server-owned discrete state.

Spring brake must remain physically active at every speed.

---

## Final wheel actuation

RB uses:
- `setCustomBrakeForce()`;
- forced brake pedal;
- wheel physics.

This is a strong directional pattern:
- do not set velocity;
- do not alter tire friction;
- apply brake capability.

### Improvement

RB computes a "lock torque" from:
```text
mu=1 * estimated wheel load * wheel radius
```

Future actuator should instead expose actual brake hardware capacity:
```text
availableBrakeTorqueByWheelGroup
```

Then:
- MR/GIANTS owns wheel dynamics;
- Mud/grip decides whether it skids;
- Reifen can naturally observe wear/slip.

---

## Semi-trailer load distribution

RB deliberately uses trailer total mass divided by its wheels even though some semi-trailer load is carried by the tractor.

That overestimates spring-brake torque.

Future options:
1. authoritative per-wheel load provider from Mud/MR/RC;
2. native physics load if stable;
3. conservative profile fallback.

Do not infer wheel normal force from total trailer mass when a better state exists.

---

## Detached trailer behavior

RB returns LIBRE when detached and relies on vanilla Attachable deactivation/parking.

So:
- custom trailer pressure persists;
- custom pneumatic spring state is not the physical detached owner.

This is a split ownership.

A future native pneumatic system should explicitly define:
- disconnected supply;
- stored trailer pressure;
- spring release state;
- final detached brake demand.

Then base-game parking can be composed/disabled rather than silently replacing the pneumatic state.

---

## Multiplayer

Server:
- owns persisted trailer pressure;
- performs equalization.

Client:
- has no dedicated trailer-pressure stream;
- assumes connected trailer pressure equals RDS truck pressure.

This works only because equalization is instantaneous.

Finite-flow transfer requires:
- trailer initial state;
- dirty/revision updates;
- discrete hose/spring state.

Do not base future network correctness on equal-pressure assumption.

---

## AI/controller behavior

Trailer path bypasses only:
`root:getIsAIActive()`.

Main RB has a broader resolver for:
- Courseplay;
- Follow Me;
- GIANTS AI.

AutoDrive remains absent.

This inconsistency can make a controller exempt from truck/main RB physics but still subject to trailer spring-brake locking.

Future RE policy:
```text
same physical pneumatic state
+ controller-specific interaction/preparation
```

No controller-specific creation/removal of air or spring-brake physics by default.

---

## ConnectionHoses integration

One of the best architectural choices in RB:

RB consumes the final GIANTS hose connection state.

Therefore:
- automatic attach;
- manualAttach;
- Interactive Control
can all become connector-state providers without RB owning their UI/actions.

Future RE should preserve this:
```text
connector mod -> GIANTS ConnectionHoses state -> PneumaticConnectorContext
```

No direct dependency unless an external mod bypasses GIANTS state.

---

## Sound

Disconnecting the supply line reuses the towing vehicle's native air-release sample.

Good pattern:
- semantic physical event;
- reuse authoritative/native presentation where available.

Do not create another release/compressor loop if native AIR/soundExpansion already owns it.

---

## RDS consequence

The exact RB source confirms that the future RDS-derived RE pneumatic system should provide a stronger external contract than:
`getPressure/setPressure`.

Recommended high-level API:
```text
getPneumaticContext(vehicle)
requestAirTransfer(source, target, connector, dt)
getBrakeDemand(vehicle)
```

Storage remains private behind:
`PneumaticStorageBackend`.

External consumers must not assign absolute pressure.

---

## Revised RDS trailer phase

Before P4 implementation:

1. native AIR probe includes **Attachable airConsumer metadata**, not only truck AIR;
2. define supply vs service hose states separately;
3. select storage backend;
4. implement finite conservation-aware transfer;
5. implement tractor protection;
6. implement trailer service demand;
7. implement leakage;
8. server-sync trailer reservoir;
9. define spring/service wheel groups;
10. integrate ConnectionHoses;
11. prove PLAYER / AI / Courseplay / AutoDrive;
12. compare against exact RB 1.3 runtime behavior.

Realistic Brakes can remain an external reference/optional owner while this work is deferred.
