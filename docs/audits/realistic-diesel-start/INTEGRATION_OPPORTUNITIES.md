# Realistic Diesel Start 1.4 integration opportunities

## Primary decision

RDS remains an external specialist.

There is no current justification to absorb diesel ignition/air systems into RE.

The 1.4 update primarily changes **RC ownership**, not RE ownership.

## RDSADS 1.4 target boundary

### Upstream owns

RDS 1.4:
- diesel ignition/contact UX;
- glow-plug state machine;
- clutch-start UX;
- key-down/held/up lifecycle;
- RDS HUD;
- compressed-air truck tank;
- air-compressor state;
- native Realistic Brakes air API;
- native Diesel Fuel System queries.

ADS:
- starter/battery/mechanical failure state;
- hard-start execution;
- engine damage/mechanical consequences;
- authoritative engine thermal state for ADS-managed vehicles.

### RC owns only the semantic composition gap

For ADS-managed vehicles:

```
ADS engine temperature
        |
        +--> RDS preheat/warm-up presentation
        |
RDS glow readiness
+ fuel cold-start factor
        |
        v
RC translation
        |
        v
ADS ENGINE_HARD_START_MODIFIER
        |
        v
native RDS 1.4 external-crank lifecycle
```

RC also suppresses only RDS's duplicate:
- cold torque consequence;
- cold-drive damage consequence;

while ADS owns those domains.

For ADS-excluded vehicles:
- do not intervene;
- preserve full native RDS thermal/cold behavior.

## Why not remove RDSADS completely?

RDS 1.4 fixes:
- key ownership;
- held-key synchronization;
- ADS hard-start wait;
- HUD duplication.

It does not establish one shared:
- engine temperature;
- cold-start probability;
- cold torque consequence;
- cold-operation damage model.

Without a narrow adapter, two cold-mechanical models remain active.

## Why not keep the legacy bridge unchanged?

The legacy bridge would actively regress 1.4:
- globally deletes RDS temperature UI even on ADS-excluded vehicles;
- globally disables RDS damage;
- steals native key routing;
- bypasses Diesel Fuel System logic by replacing too much of `tryCrank()`;
- duplicates upstream ADS input synchronization.

Therefore exact 1.4 requires its own branch/path inside RDSADS.

## Fuel-quality composition

RDS 1.4's `scGetColdStartFactor()` is a good semantic input.

The reduced RC adapter includes it when translating RDS readiness into ADS
hard-start time.

Conceptually:

```
thermalDifficulty
× fuelColdStartFactor
× incompleteGlow
        ↓
RDS readiness difficulty
        ↓
translated into ADS hard-start domain
```

Do not make RC own fuel quality itself.

A future Diesel Fuel System audit should decide whether:
- the factor is correctly calibrated;
- start-block reasons are authoritative;
- the provider should become versioned.

## Realistic Brakes

No bridge.

The current contract is already close to ideal:

```
RDS truck air tank owner
   getAirPressure
   setAirPressure (server)
          |
          v
Realistic Brakes
   trailer reservoir/hose owner
```

If future stack components need truck-air state, prefer a normalized read-only
provider rather than another writer.

## Possible future AirSystem provider

Do not build merely because RDS has an API.

A normalized provider becomes justified if at least two independent consumers
need:
- tank pressure;
- compressor state;
- spring-brake state;
- available service-brake air.

Potential consumers:
- Realistic Brakes;
- future dashboard/HUD;
- mechanical damage;
- trailer diagnostics.

Until then, direct narrow RDS API is sufficient.

## Settings/authority lesson

Separate:
- local UX settings;
- server physical settings.

If RC/RE ever owns an analogous system, a physical setting descriptor should
state:
- authority;
- persistence;
- replication;
- apply semantics.

Do not infer network authority from a disabled UI control.

## Better air-system model if ever absorbed

The RDS air system is useful gameplay, but not a first-principles pneumatic model.

A more physical future model would distinguish:
- compressor flow (L/min at engine RPM);
- reservoir volume;
- governor cut-in/cut-out pressure;
- brake-chamber/application volume;
- trailer supply/emergency line;
- leakage;
- spring-brake release threshold.

Air consumption would follow pressure-volume/application cycles rather than a
direct speed/mass multiplier.

This is engineering research only; no current RE ownership proposal.

## Diesel eligibility

The project should keep semantic engine/fuel classification separate from
whether a vehicle merely has Motorized specialization.

Preferred future capability:

```
PowertrainFuelType:
  DIESEL
  GASOLINE
  ELECTRIC
  HYBRID
  UNKNOWN
```

RDS currently uses a broad motorized/non-electric scope.

RC's existing diesel consumer classification is retained as the target-stack
policy until a stronger normalized engine capability exists.

## Upstream solution-quality summary

| Boundary | Classification | Project response |
| --- | --- | --- |
| RDS ↔ ADS key/held-state | GOOD_AND_ADOPT_PRINCIPLE | retire RC duplicate routing |
| RDS ↔ ADS whole cold-start model | PAIRWISE_FIX_ONLY | keep narrow thermal/readiness composition |
| RDS ↔ Realistic Brakes | GOOD_AND_ADOPT_PRINCIPLE | no RC bridge |
| RDS ↔ Diesel Fuel System | GOOD_DIRECTION | preserve; audit provider later |
| RDS client damage event | FRAGILE / OWNER DEFECT | document, do not normalize into RC |
| RDS air replication | GOOD_AND_ADOPT_PRINCIPLE | reuse slow authoritative-state principle |

## RC retirement matrix

### Remove for 1.4
- `disableRdsTemperatureHud` usage;
- global RDS damage setting override;
- `registerRdsClutchOnly`;
- ADS `onStartButtonAction` takeover;
- full RC `tryCrank` state machine;
- RC-owned input synchronization.

### Keep legacy-only for 1.2
All of the above remain in the historical exact 1.2 path because that version
was already runtime validated with those ownership assumptions.

### New 1.4 path
- source/version exact gate;
- per-vehicle ADS management detection;
- ADS temperature projection;
- preheat/fuel readiness → ADS hard-start;
- duplicate cold consequence suppression;
- transient lifecycle + telemetry.

## RE impact

No functional RE code required.

Potential learning:
- narrow owner APIs;
- authoritative slow-state replication;
- per-vehicle capability exclusion;
- provider-owned user-facing block reasons.

RDS remains external until a future capability audit demonstrates a reason to
replace the entire ignition/air system.
