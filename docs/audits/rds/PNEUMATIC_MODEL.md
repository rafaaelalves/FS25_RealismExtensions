# RDS compressed-air model audit / RE redesign

Updated: 2026-10-05

Exact current source checked: RDS 1.4.0.0, SHA-256
`a2a983c7754bc4fb3dffc04839fb16cf844c72d7664ae78cfcd70fcf3c15721c`.

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
