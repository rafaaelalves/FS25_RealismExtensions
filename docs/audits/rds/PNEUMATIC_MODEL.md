# RDS compressed-air model audit / RE redesign

Updated: 2026-10-05

Exact current source checked: RDS 1.4.0.0, SHA-256
`a2a983c7754bc4fb3dffc04839fb16cf844c72d7664ae78cfcd70fcf3c15721c`.


## Native AIR backend decision is intentionally open

A later cross-audit found that FS25 already has a native AIR consumer/fill-unit
path and the exact `soundExpansionMP 1.2.0.0` stack depends on its
`consumer.doRefill` state for multiplayer compressor sounds.

Therefore this document defines the **physical model**, not yet the storage
backend.

Before implementation compare:
- native-AIR-backed storage with RE physical policy;
- fully RE-owned reservoir with deliberate native presentation bridge.

Do not keep two independent authoritative air states.

See `NATIVE_AIR_BACKEND.md`.

## RDS 1.2 -> 1.4 source model

RDS uses one equivalent reservoir:
- max 10.0 bar;
- governor cut-out 9.7 bar;
- cut-in 8.5 bar;
- compressor 0.075 bar/s whenever engine ON and governor loaded;
- healthy leak 0.05 bar/hour;
- damaged leak up to 3.0 bar/hour from generic vehicle damage;
- low-air warning 5.5 bar;
- spring-brake threshold 3.5 bar;
- default 4.0 bar.

Service-brake consumption is:

```text
0.25 bar/s * brakePedal * speedFactor * loadFactor * dt
```

Spring brake state is set below 3.5 bar, but full brake is forced only above 5 km/h.

## Real-world reference used

Ontario Ministry of Transportation, **The Official Air Brake Handbook**, updated 2026-02-24:
- engine-driven compressor;
- governor cut-in/cut-out;
- common normal system pressure roughly 100–120 psi, with manufacturer variation;
- low-air warning before 55 psi, often around 60 psi or higher;
- primary/secondary tank structure is common;
- compressor build-up is tested at a defined engine speed (600–900 rpm);
- pressure is deliberately lowered by repeatedly pressing **and releasing** the brake pedal;
- during a held applied-brake leak test, the initial pressure drop is disregarded and subsequent pressure loss is leakage;
- spring brakes are released by air pressure and begin to apply as pressure falls.

Sources:
- https://www.ontario.ca/document/official-air-brake-handbook/air-supply-subsystem
- https://www.ontario.ca/document/official-air-brake-handbook/inspecting-air-brake-system-operation
- https://www.ontario.ca/document/official-air-brake-handbook/spring-parking-and-emergency-brake-subsystem

## Main physical correction

RDS treats reservoir air partly as a proxy for braking energy: more speed/mass and a held pedal continuously consume more pressure.

RE should model **air volume / commanded chamber pressure**, not kinetic energy.

MVP idea:

```text
command = clamp(brakePedal, 0, 1)
positiveDelta = max(command - previousCommand, 0)
applicationDemand = chamberDemand * positiveDelta
reservoirPressure -= pressureDrop(applicationDemand, reservoirVolume)
```

Then model separately:
- leakage;
- repeated applications;
- trailer demand;
- compressor replenishment.

This naturally makes repeated pedal applications consume more air while a stable held application mainly loses air through modeled leaks after its initial demand.

## Proposed RE pneumatic MVP

State:

```text
reservoirPressureBar
compressorLoaded
serviceCommand
springBrakeState
lowAirWarning
pneumaticCondition
revision
```

Design the API so this can later expand to:

```text
supplyPressure
primaryPressure
secondaryPressure
trailerSupplyPressure
```

### Compressor

Use RPM-aware flow, at least approximately:

```text
rpmFactor = clamp(engineRpm / referenceRpm, idleFactor, maxFactor)
flow = ratedFlow * rpmFactor
```

Governor remains hysteretic:
- >= cut-out -> unloaded;
- <= cut-in -> loaded.

Actual thresholds/rates should be profile/calibration data, not copied RDS constants.

### Service air demand

Vehicle/trailer size may influence chamber/circuit volume, but instantaneous vehicle kinetic energy should not directly determine reservoir air consumption.

### Leakage

Separate:
- healthy baseline;
- pneumatic fault/condition;
- active-application leakage if modeled.

Do not use vanilla damage as the sole health signal; RMS managed vehicles intentionally make it unsuitable as generic mechanical condition.

### Low-air / spring brake

Use profile thresholds and hysteresis where appropriate.

Spring/parking state should remain physically effective at all speeds. This does not imply an infinite lock: official guidance notes some vehicles can still be driven against applied spring brakes. The correct target is continuous available brake force/torque, not a special `speed > 5 km/h` rule.

### Brake lights

Service brake lamps follow service-brake demand. Spring/parking state gets its own indicator. Do not force service brake lights because spring brakes are applied.

Exact RDS 1.4 source fixes this ownership error: the pneumatic path no longer
forces or clears service brake lamps. The vanilla/service-brake owner is left
alone.

## Trailer supply boundary

Exact RDS 1.4 source adds two public vehicle methods:
- `rdsGetAirPressure()`;
- server-only `rdsSetAirPressure(bar)`.

Its comments state Realistic Brakes 1.3.0.0 uses this contract to equalize/fill
a trailer reservoir from the truck.

This is a good interoperability direction but a weak physical transaction
contract: an external consumer can assign an absolute pressure without the RDS
owner proving volume/mass conservation.

RE direction:
- do not implement trailer air in the first pneumatic MVP;
- audit Realistic Brakes first;
- represent reservoir capacity/air amount explicitly enough to conserve
  transfer;
- expose owner-managed transfer/withdraw/deposit operations rather than a
  general absolute pressure setter;
- manualAttach / Interactive Control may provide hose connectivity, not
  pneumatic physics ownership.

## Network / persistence

Server authority for all pressure/circuit state.

Persist:
- pressure(s);
- RE-owned pneumatic faults/condition;
- explicit elapsed-time timestamp if leakage is advanced across sleep/reload.

Synchronize:
- full initial state;
- revisioned dirty updates;
- thresholded/quantized pressure;
- discrete warning/spring state immediately.

RDS's 10-bit pressure event is a useful efficiency precedent, but RE should not inherit RDS's missing initial-stream compromise.

## Calibration policy

Do not treat RDS constants or one jurisdiction's handbook as universal vehicle constants.

Use:
- profiles;
- measurable test scenarios;
- transparent calibration provenance.

First scenarios:
- governor cycle;
- low-pressure startup;
- idle/reference RPM build-up;
- repeated full brake applications;
- held-application leak;
- sleep/reload leakage;
- spring brake drag.


## Exact 1.4 changes relevant to pneumatics

### AI deadlock workaround

1.4 fixes the helper stop/go problem by clamping AI-controlled vehicles to at
least governor cut-in pressure.

This is a valid **interaction-policy lesson**: AI must not deadlock on a
player-facing readiness mechanic.

Do not copy the physical mutation literally. The clamp can create free
persistent compressed air and the player may inherit that state afterward.

Preferred RE pattern:
- physical reservoir remains physical;
- AI readiness policy can perform a bounded abstract pre-trip preparation or
  temporarily bypass player interaction;
- if simulated fill is used, advance the compressor/engine state consistently.

### Brake-light fix

1.4 removes spring-brake service-light writes. This closes the earlier
ownership defect.

### Unchanged physical blockers

Exact source confirms these remain unchanged in 1.4:
- constant compressor rate independent of engine RPM;
- continuous held-pedal air consumption;
- speed/mass multiplier on air use;
- one scalar reservoir;
- vanilla damage as leak-health source;
- truck-category eligibility heuristic;
- spring-brake physical force applied only above the drag-speed threshold;
- same pressure threshold for engage/release;
- no full initial stream.

Therefore no pneumatic redesign item from the first audit should be removed.

## API lesson: pressure is not the conserved quantity

A useful future representation is:

```text
reservoir:
    volumeLiters
    absolutePressureBar
    airAmountNormalized  -- or equivalent mass/moles abstraction
    temperature optional later
```

For an MVP we do not need thermodynamic simulation, but transfer should still
obey a simple conservation rule.

A pressure-only `setPressure` contract cannot tell whether a 5 bar 20 L
reservoir or a 5 bar 100 L reservoir supplied the trailer. Capacity/amount is
therefore needed before trailer equalization becomes physically meaningful.


## Conserved air quantity refinement

The earlier pressure-state proposal is now refined to a simple fixed-volume,
isothermal equivalent.

For each reservoir:

```text
Q = P_abs * V
```

where:
- `Q` is equivalent stored air in bar·L;
- `P_abs` is absolute pressure;
- `V` is reservoir volume.

Gauge pressure remains:

```text
P_gauge = P_abs - P_atmosphere
```

This is deliberately not a full thermodynamic model.

It is sufficient to make:
- reservoir size meaningful;
- compressor flow capacity-aware;
- trailer equalization conservative;
- transfer APIs physically interpretable.

### Compressor

Prefer adding equivalent amount:

```text
dQ/dt = ratedFlowBarLitersPerSecond * rpmFactor * efficiency
```

rather than incrementing pressure by one universal bar/sec.

### Trailer equalization

For idealized complete equalization:

```text
Q_total = Q_truck + Q_trailer
P_final_abs = Q_total / (V_truck + V_trailer)
```

Line losses/restrictions can be introduced later without changing the conserved
state representation.

This is a substantial improvement over external
`setPressure(targetPressure)` semantics.

## Brake-demand / actuator separation

The pneumatic state owner should output demand, not seize wheel physics.

Conceptual result:

```text
BrakeDemand {
    service01
    springForced01
    parkingRequested01
    releaseAllowed
    reasonMask
}
```

A final adapter composes this with the active brake owner.

Important RMS interaction:
- RMS may auto-release its ordinary parking brake for throttle/AI;
- low-air spring-brake demand is a forced safety state and must remain effective
  until pressure permits release;
- do not encode forced pneumatic braking as an ordinary RMS parking request.

Important MR/Mud/Reifen interaction:
- RE does not increase tire friction or zero vehicle velocity;
- final brake torque acts through the existing drivetrain/wheel/ground stack;
- whether wheels slide or the engine drags the brakes is a physical consequence.

## Auxiliary compressor engine load — future feature

An engine-driven compressor consumes power when loaded.

This is not required for the first pneumatic MVP, but the architecture should
leave room for:

```text
Pneumatic compressor loaded
    -> AuxiliaryEngineLoad demand
    -> one RC/MR owner adapter
    -> real engine load/fuel response
```

Do not add an artificial generic "load percentage" directly.

If implemented:
- calibrate compressor power/flow profiles;
- compose with MR/RMS once;
- keep compressor load separate from optional fast-idle RPM demand.

## Profile architecture

Reuse the TerraFarm/RE profile lesson:

```text
native capability inference
 -> pneumatic family defaults
 -> declarative vehicle override
 -> runtime sanity validation
```

Candidate `PneumaticProfile` fields:
- storage backend preference;
- reservoir volume;
- nominal/max/cut-in/cut-out/low-air pressures;
- spring apply/release thresholds;
- compressor flow/reference RPM;
- service chamber equivalent volume;
- optional circuit family;
- trailer supply capability.

Category/name heuristics are not acceptable as final physical truth.


## Service/failure ownership — deliberately deferred

Do not let the pneumatic MVP silently grow its own workshop/maintenance economy.

MVP:
- profile baseline leakage;
- externally supplied fault/condition if one exists;
- no random compressor/line/chamber wear system.

Future degradation can include:
- compressor condition/efficiency;
- reservoir/line leakage;
- chamber leakage;
- brake-adjustment effectiveness;
- dryer/valve faults.

Preferred ownership:
1. extend RMS/service through an explicit subsystem/provider API when practical;
2. otherwise expose RE pneumatic condition through a normalized mechanical
   contract that an external service owner can consume;
3. only create an independent RE service lifecycle if no existing mechanical
   owner can represent the capability cleanly.

This follows RMS's strong Condition / Stress / Service separation.

## Actuator topology must stay evolvable

Official air-brake documentation confirms:
- primary/secondary service circuits can feed different wheel groups;
- brake chamber sizes affect force;
- spring brakes are a separate subsystem and need not map identically to all
  service-brake wheels.

Therefore a scalar `springDemand01` is only an MVP convenience.

Future-capable output:

```text
BrakeDemand {
    service {
        global01
        wheelGroups[] optional
    }
    spring {
        global01
        wheelGroups[] optional
    }
    manualParking {
        global01
        wheelGroups[] optional
    }
    reasonMask
}
```

The first implementation may use only the global fields, but the public
contract must not assume every axle receives identical spring/service demand.

This also improves later trailer modeling.

## Compressor mechanical load — future fidelity feature

The current RDS compressor changes pressure without imposing engine power
demand.

A later RE refinement may model:
- compressor shaft/power demand while governor is loaded;
- optional compressor fast-idle request.

Do not synthesize a generic "load percentage".

Preferred composition:
- compressor computes physical auxiliary power/torque demand;
- RC translates that once into the active MR/GIANTS engine owner;
- optional fast-idle uses the shared EngineRpmDemand path.

Keep RPM demand and power demand separate.

Do not create a generic auxiliary-load bus until a second concrete consumer
justifies it.

## Safe persistence / wake ordering

When restoring low pressure:
1. restore storage state;
2. derive low-air/spring state;
3. apply forced-brake demand;
4. only then permit normal wake/motion.

A vehicle/trailer must not receive one free physics frame before its safety
brake returns.

This is an explicit save/load and join-in-progress gate.

## Legacy RDS state migration

RDS 1.4 persists:
- `realDieselStart#airPressure`;
- `realDieselStart#engineHeat`;
- `realDieselStart#lastStamp`.

When RDS is eventually retired, a one-time migration may preserve air state.

Rules:
- import only after the chosen backend/profile defines how bar maps to stored
  air;
- apply bounded elapsed leakage with a documented time basis;
- never inject RDS `engineHeat` into RMS/ADS thermal state;
- schema/version marker makes migration one-shot;
- emit diagnostics describing source and conversion.

If native AIR storage wins P0, conversion waits until native AIR capacity
semantics are proven.

## Connected truck/trailer resource solver

Future trailer air should behave like a paired conserved-resource solve, not
two scripts writing each other's pressure.

Rules:
- each vehicle persists only its own reservoir;
- connection topology is transient;
- solve each connected pair once per server step;
- amount transfer is symmetric/conservative;
- detach/delete clears both sides;
- stale partner references fail closed;
- client input never supplies an arbitrary pressure/amount;
- server validates connection state and action authority.

This mirrors the lifecycle lesson from RMS external-power relationships and the
transaction-validation lesson from RMS fluid transfer.


## Exact Realistic Brakes 1.3 closure

Exact package:
- FS25_RealisticBrakes 1.3.0.0
- SHA-256 c6cec8b89fb7bf409ee55f2a2421b989ff7392da0f5c5dedf65bc5d76912aa05

The source closes the trailer-air research gap and adds several corrections to
the target model.

### Supply and service hoses are separate state

RB correctly identifies native hose types as red supply and yellow control,
but its current lock test treats any disconnected air hose as an emergency.

The RE model must instead expose:
- supplyConnected;
- serviceConnected.

Consequences:
- supply lost / supply pressure low -> spring brakes apply;
- service line lost -> service brake command unavailable/degraded;
- healthy supply can continue holding spring brakes released even if the
  service/control line is disconnected.

Do not use one allHosesConnected boolean.

### Tractor protection valve is now an explicit requirement

RB instant equalization can pull truck pressure down into the trailer.

The future model must stop trailer supply flow when towing-vehicle supply falls
below its protection threshold.

This protects truck reserve while allowing trailer pressure to fall and its
spring brakes to apply.

### Finite transfer

RB pressure equalization is conservation-inspired but instantaneous.

Future transfer must be bounded by flow/valve capacity.

This is necessary for:
- realistic trailer charge time;
- meaningful hose/valve profiles;
- stable server stepping;
- truck reserve/protection behavior.

### Native trailer service-demand metadata

FS25 Attachable exposes airConsumer#usage and getAttachbleAirConsumerUsage().

This becomes a new PneumaticProfile evidence source.

It may calibrate relative service chamber/circuit demand, but the final RE
service-air law remains application-based rather than continuously draining
air while a pedal is held.

### Trailer reservoir network state

RB persists trailer pressure but does not synchronize a dedicated trailer
reservoir state.

That works only because connected pressure is instantly equalized to RDS.

Finite transfer requires:
- full initial trailer state;
- revision/dirty sync;
- discrete spring/service availability state.

### Detached trailer

RB defers detached braking to vanilla Attachable instead of using its persisted
pneumatic pressure.

Native RE should keep one physical truth:
- disconnected supply state;
- stored trailer air;
- spring release/apply result;
- final BrakeDemand.

Vanilla parking behavior is then composed with or suppressed by the selected
actuator owner rather than silently replacing pneumatics.

### Actuator improvement

RB's trailer path proves a useful concept:
- apply brake force to wheels;
- let wheel/ground physics decide dragging/skid.

Do not copy its exact torque formula:
- assumed mu=1;
- total trailer mass divided uniformly among wheels;
- all wheels assumed spring-braked.

Target:
- hardware/profile brake torque;
- measured/normalized load only for diagnostics/calibration where needed;
- wheel-group topology;
- no assumed road friction inside actuator capacity.

### Controller policy

RB main and trailer paths use different AI detection and both bypass physics in
some automated-control situations.

RE target remains:
- same pneumatic/spring physical state;
- controller-specific interaction/preparation only.

AutoDrive, Courseplay and GIANTS AI are acceptance gates.

### Realistic Brakes itself is not a new default owner

This exact audit does not change the project's current decision to build a
clean RDS-derived pneumatic model eventually.

RB may still be used externally in the stack first, but:
- engine/Jake brake conflicts with MR;
- parking brake conflicts with RMS/Enhanced Vehicle ownership;
- trailer model is incomplete.

See ../realistic-brakes/README.md.
