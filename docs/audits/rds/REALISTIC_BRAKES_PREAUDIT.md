# Realistic Brakes 1.3 preliminary ownership gate for RDS assimilation

Updated: 2026-10-06
Status: **public-description pre-audit only; exact source not yet available**

Purpose: preserve what must be checked before RDS-derived pneumatics expands into
trailer air or generalized brake simulation.

## Current public line

Public pages dated 2026-10-04 describe `FS25_RealisticBrakes 1.3.0.0` by
GN Realism.

Relevant public claims:
- manual/parking brake;
- dynamic engine braking;
- reinforced/Jake-style engine braking;
- brake temperature / efficiency / failure presentation;
- trailer air-brake hoses;
- trailer-owned air reservoir;
- trailer spring brakes apply when supply hoses are disconnected;
- manualAttach and Interactive Control hose-state integration;
- automatic game coupling connects hoses automatically;
- with RDS, trailer reservoir fills from truck supply and truck pressure drops;
- trailer spring brakes release around a reported pressure threshold;
- Enhanced Vehicle coexistence;
- AI bypass/exclusion changes in earlier versions;
- ADS-aware HUD positioning.

Public references:
- https://www.fs25.info/realistische-bremsen/
- https://fs25.net/realistic-brakes-v1-0/

These descriptions are **not source proof**.

## Why this blocks RDS trailer Phase P4

The mod now appears to own capabilities adjacent to both RE pneumatics and MR/RMS:

```text
parking brake
service/final wheel brake effects
engine/Jake braking
brake thermal/fade
trailer spring brakes
trailer air reservoir
hose connectivity
```

Implementing those blindly in RE risks duplicating another active specialist.

## Exact-source questions

### Final brake actuator
- Which GIANTS/MR/RMS function actually receives parking/spring brake force?
- Is the mod applying brake input, wheel torque, direct velocity constraint or
  another mechanism?
- Does its path remain active under AutoDrive / Courseplay / GIANTS AI?

### Parking brake physics
Public text says holding force depends on vehicle weight and slope.

Need source to distinguish:
- a fixed actuator/brake-torque capability tested against required grade force;
- versus recomputing "brake force" directly from current weight/slope.

The first is physically coherent; the second may hide the actuator limit inside
the demand calculation.

### Engine/Jake brake
MR already owns engine braking in the target stack.

Need exact source for:
- hook;
- gear-ratio semantics;
- torque sign/magnitude;
- interaction with MR engine-load/brake path;
- manual/automatic activation;
- whether "Jake" is a separate retardation owner.

Until then:
**do not absorb or enable a second engine-brake algorithm as part of RDS work.**

### Thermal / fade
Need:
- state units;
- integration cadence;
- server/client authority;
- cool-down model;
- wheel/axle granularity;
- failure threshold;
- persistence;
- AI bypass;
- relationship to RMS brake/chassis stress if any.

### Trailer reservoir
Need:
- stored quantity/units;
- capacity;
- pressure mapping;
- fill/equalization algorithm;
- whether RDS `rdsSetAirPressure` is used as an absolute assignment or a
  conservation-aware transfer;
- separation of truck safety reserve from trailer fill;
- release/apply thresholds;
- offline leakage/persistence.

### Spring brake actuator topology
Need:
- which trailer wheels/axles are braked;
- whether all wheels are locked uniformly;
- brake torque versus direct lock;
- release hysteresis;
- low-speed behavior.

### Hose topology
Need:
- manualAttach API contract;
- Interactive Control API contract;
- automatic coupling state;
- MP authority;
- detach/delete cleanup;
- save/load topology;
- whether hose visuals/connection are state providers or physical owners.

### AI
Public older changelog says AI vehicles were fully excluded from brake
simulation to stop freezes.

Need source to decide whether 1.3 still:
- bypasses thermal/wear/parking/spring physics;
- bypasses only interaction;
- treats trailers differently.

Native RE target remains: AI skips manual gestures, not physical safety state.

### Enhanced Vehicle
Need exact ownership arbitration for parking brake.

RMS also has an optional parking-brake owner and already steps aside for
Enhanced Vehicle.

A future RE brake-demand adapter must not create a three-way ownership fight.

### HUD/audio
Need:
- current HUD lifecycle;
- ADS-aware layout logic;
- air/parking sound ownership;
- cleanup on vehicle delete;
- duplicate low-air/compressor presentation with native AIR/soundExpansion.

## Likely ownership boundary after source audit

Until disproven:

```text
RE PneumaticBrakeSystem
    owns truck supply state + low-air/spring demand policy

Realistic Brakes
    candidate owner for trailer actuator/hoses and broader brake mechanics

MR
    engine-brake/drivetrain owner in target stack

RMS / EV
    parking/brake mechanical state may require arbitration

RC
    composes exact overlap only after source evidence
```

This is intentionally provisional.

## Acceptance before P4

Do not implement trailer-air replacement until:
1. exact current Realistic Brakes ZIP/source obtained;
2. source audit completed;
3. final brake owner identified under MR/RMS/EV;
4. trailer stored-air units/conservation understood;
5. hose lifecycle and MP authority understood;
6. AI/controller behavior classified;
7. decision made: KEEP / INTEGRATE / FUNCTIONALLY ABSORB by capability.

