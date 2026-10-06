# Native RE start model — canonical readiness / outcome study

Updated: 2026-10-06
Status: research; no implementation

## Problem

RDS, ADS, RMS and fuel-system mods express starting difficulty in different
domains:
- temperature thresholds;
- preheat progress;
- battery/starter capability;
- hard-start seconds;
- probability of a failed attempt;
- fuel quality/block reasons.

Blindly multiplying or translating every number can double-count the same
physical cause.

The start model therefore needs a canonical semantic boundary.

## Separate hard blocks from difficulty

A hard block is not a small probability.

Examples:
- no fuel / fuel shutoff;
- blocked fuel system;
- starter unavailable;
- disallowed transmission/interlock;
- engine mechanically seized;
- server policy refusal.

Represent explicitly:

```text
StartBlock {
    blocked: boolean
    reasonCode
    owner
    retryable
    reasonArgs
}
```

If any authoritative hard block is active, do not roll combustion probability.

## Faceted readiness

Conceptual normalized context:

```text
StartContext {
    revision
    fuelClass
    engineTemperatureC
    ambientTemperatureC

    electrical {
        crankAvailable
        voltage01
        starterCapability01
        owner
    }

    glow {
        required
        readiness01
        technology
        owner
    }

    fuel {
        readiness01
        coldStartFactor01
        blockReason
        owner
    }

    mechanical {
        startCapability01
        hardStartOwner
        owner
    }

    interlock {
        allowed
        reason
        owner
    }

    provenance {
        includedFactorsByOwner
    }
}
```

Not every field must exist in MVP. Missing values are not silently guessed as
"healthy"; fallback policy must be explicit.

## Exactly-once composition

The consumer must know whether an owner already includes another factor.

Example failure:
- ADS hard-start already includes cold temperature;
- RE also converts cold temperature into a second hard-start penalty;
- total difficulty is counted twice.

The RC adapter/provider should expose provenance such as:

```text
mechanical.hardStartIncludes = {
    temperature = true,
    battery = true,
    starter = true,
    glow = false,
    fuel = false
}
```

Then RE contributes only missing facets it genuinely owns.

This is the start-domain analogue of:
- PTO canonical 540-domain translation;
- MR+Soil exactly-once throughput composition.

## Standalone RE combustion model

When no specialist owns final hard-start mechanics, use a continuous-time,
server-authoritative model rather than one fixed per-attempt random roll.

Conceptual form:

```text
lambda = baseCatchRate
       * electricalFactor
       * glowFactor
       * fuelFactor
       * mechanicalFactor

pCatch(dt) = 1 - exp(-lambda * dt)
```

Properties:
- timestep/FPS invariant;
- naturally supports "keep cranking until it catches";
- cold/weak conditions lengthen expected crank time instead of requiring an
  arbitrary single 1.6-second failed attempt;
- server can roll at a fixed bounded cadence.

Hard blocks are evaluated before this equation.

### Important

This is a modeling direction, not a calibrated formula.

Do not assign final coefficients until:
- warm/cold baseline behavior is measured;
- technology profiles are defined;
- starter/fuel owner semantics are known.

## Specialist-owned outcome

If RMS/ADS owns final start outcome:
- RE does **not** run the standalone hazard model;
- RE supplies only missing RE-owned readiness contribution through the adapter;
- RE sends crank intent;
- owner performs its start lifecycle;
- RE observes authoritative RUNNING transition.

The UI can still show composed readiness/reason state without owning the result.

## Preheat technology

Avoid one universal glow curve.

Profile families:
- `none`;
- `legacyGlow`;
- `quickGlow`;
- `modernCeramic`;
- future `intakeGridHeater` or engine-specific strategy.

Each profile may define:
- activation temperature;
- readiness curve;
- minimum/maximum preheat;
- afterglow behavior;
- dashboard/telltale semantics.

Do not infer technology only from tractor age/name unless backed by a curated
profile.

## Contact / crank state machine

Preferred operator state:

```text
OFF
 -> IGNITION
 -> PREHEAT (optional)
 -> READY
 -> CRANKING
 -> RUNNING
```

Transitions are explicit and complete.

Input gesture must have no timing hole:
- press edge establishes contact/intent;
- hold threshold can request crank;
- release before threshold is always a deterministic short-press action;
- once CRANKING, release means release starter intent, not "stop a motor that
  just caught".

RUNNING is entered only from authoritative motor-state confirmation.

## Interlock facet

Possible conditions:
- clutch;
- neutral;
- brake;
- PTO disengaged;
- parking state;
- provider-specific mechanical requirement.

Rules:
- consume actual drivetrain/provider state where possible;
- profile declares which interlock applies;
- do not invent a synthetic clutch as universal truth;
- no filename/category heuristic should silently block physics.

## Cold idle / warm-up

Do not use RDS-style direct cold torqueScale ownership or speed-based damage.

Possible RE role:
- derive an advisory cold/warm state;
- optionally create a `COLD_IDLE` minimum-RPM demand for profiles that
  represent real elevated cold idle;
- submit it to the shared EngineRpmDemand aggregator;
- let MR/RMS own actual engine response and mechanical consequences.

No generic "drive > 8 km/h while cold = damage" rule.

## PTO / hand-throttle interaction

Engine start and PTO hand throttle can coexist.

Questions must be profile/state-driven:
- does a mechanical hand throttle retain its position while engine is off?
- does the vehicle require PTO disengaged for start?
- does start logic ignore hand-throttle floor until RUNNING?
- what is the allowed cold-idle vs hand-throttle maximum/minimum composition?

Do not globally reset PTO hand throttle on restart without evidence.

## AI / automation

AI skips human gesture, not physical readiness.

Policy sequence:
1. resolve block/readiness;
2. ignition/preheat automatically;
3. request crank;
4. wait for authoritative start;
5. prepare pneumatic state if needed;
6. depart.

Timeouts:
- bounded;
- reasoned;
- diagnostic;
- no infinite helper loop.

Courseplay/AutoDrive must be tested separately because MR control paths can
differ under those controllers.

## Server authority

Server owns:
- transition acceptance;
- stochastic catch outcome in standalone mode;
- persistent start state;
- provider action authorization.

Client sends intent:
- ignition toggle/request;
- crank held/released.

Server validates:
- controlling connection;
- vehicle state;
- allowed transition graph.

## Persistence

Persist only stable state:
- contact/ignition policy if desired;
- selected profile/version where needed;
- possibly preheat thermal residue only if physically owned by RE.

Do not persist transient local key timers or CRANKING half-state blindly.

On reload, normalize transient states to a safe valid state.

## Diagnostics

Expose:
- resolved facet owners;
- block reason;
- readiness factors/provenance;
- crank intent;
- final start owner;
- transition revision;
- rejected/unauthorized transitions;
- average crank time by profile in development telemetry.

This makes calibration and compatibility failures explainable instead of
presenting one generic "failed to start" message.


## GIANTS fallback state is richer than the RDS fallback

Cross-checking current FS25 `Motorized` shows that the base game already
maintains several useful fallback facts:

- `spec_motorized.motorTemperature.value`;
- a native motor-temperature update that uses load, RPM, wind cooling and fan
  cooling;
- `getIsMotorInNeutral()`;
- motor clutch-pedal state exposed through the native motor/dashboard path;
- `getCanMotorRun()`;
- authoritative `MotorState` transitions.

Therefore a minimal standalone RE start provider should **prefer native state**
before inventing duplicate state.

Suggested fallback order:

```text
thermal:
  RMS/ADS normalized provider
  -> GIANTS motorTemperature
  -> ambient-only conservative fallback

interlock:
  specialist/drivetrain provider
  -> GIANTS neutral / real clutch state
  -> profile fallback

motor outcome:
  specialist owner
  -> GIANTS Motorized
```

This may eliminate the need for an RE-owned standalone engine-temperature
integrator entirely.

Do not assume GIANTS motor temperature is calibrated enough for mechanical
damage. It is, however, a stronger fallback input for start/preheat UX than a
second independent RDS-style `engineHeat` timer.

## Shared EngineRpmDemand

Native PTO already needs a minimum engine-RPM request for hand throttle.

A future cold-idle feature or optional compressor fast-idle would create the
same output domain.

Do not let each module install a separate MR/control wrapper.

Conceptual aggregate:

```text
EngineRpmDemand {
    source
    minRpm
    reason
    active
    revision
}
```

Possible sources:
- `PTO_HAND_THROTTLE`;
- `COLD_IDLE`;
- future `AUX_COMPRESSOR_FAST_IDLE`.

The effective request is composed once, normally from the strongest compatible
minimum-RPM demand, then adapted once into MR/GIANTS control.

Phase rules:
- CRANKING is not normal idle-governor operation;
- demands take effect only when the motor phase supports them;
- profile-specific behavior may preserve a mechanical hand-throttle setting
  across OFF/START without applying the running RPM floor during crank.

This should become shared RE/RC infrastructure only when the second real
consumer exists; do not generalize prematurely in the PTO branch.

## Exact-once adapter rule

For every start adapter document:

```text
source owner
input domain
output domain
included physical factors
missing physical factors
authority
revision/lifetime
```

This prevents the same temperature/glow/fuel penalty from being translated more
than once when multiple specialists are active.

The rule comes directly from previous PTO canonicalization and MR+Soil
throughput composition work.


## Single-owner channels vs contributor sets

The exact RDS 1.4 + RMS/ADS/fuel cross-pass shows that not every facet should
be resolved with the same ownership primitive.

### Authoritative channels
Normally one owner at a time:
- engine temperature;
- battery/SOC/voltage;
- starter active/failed state;
- final motor state.

Shape:
```text
AuthoritativeChannel<T> {
    value
    owner
    revision
    sourceVersion
}
```

### Contributor sets
Several independent causes may coexist:
- start interlocks;
- fuel delivery/quality constraints;
- hard blocks;
- advisory reasons.

Shape:
```text
ConstraintSet {
    contributors[]
    hardBlocks[]
    modifiers[]
    provenance
}
```

This prevents a common design error:
"FuelFacet belongs to provider X, therefore provider Y's clogged-filter state
must disappear."

RMS fuel-system degradation and an independent diesel-fuel-quality specialist
can both legitimately contribute if they describe different physical causes.

Every contributor must identify its cause domain so duplicate adapters can be
detected.

## Provider availability must be optional per capability

The existing RE StateContract is currently wheel-context centric and validates
`getWheelContext()`.

Do not make native start depend on that provider.

EngineStartControl should be able to operate with:
- RE profile;
- native GIANTS Motorized state;
- no RC/external provider.

External START/MECHANICAL contexts are optional enrichments.

Provider metadata should version contexts separately so adding START does not
break WHEEL consumers.

Conceptual discovery:
```text
native GIANTS/profile fallback always available
+ optional RC START context
+ optional RC MECHANICAL context
```

The coordinator fills missing values according to explicit fallback policy.

## Controller policy is not physics ownership

Add controller identity to start orchestration:

```text
PLAYER
GIANTS_AI
COURSEPLAY
AUTODRIVE
```

The transition graph remains server authoritative in every case.

Only the interaction policy changes:
- PLAYER uses key gesture;
- automated controllers perform contact/preheat/crank automatically;
- physical readiness/hard blocks still apply.

A controller that calls native `startMotor()` directly must not bypass the
same readiness policy. Runtime adapters/tests are required for Courseplay and
AutoDrive.

## Auxiliary RPM demand phase rules

If `EngineRpmDemand` becomes real after a second consumer exists, define
phase arbitration explicitly.

Candidate rules:
- OFF/IGNITION/PREHEAT: no running-RPM floor;
- CRANKING: running idle/PTO/compressor floors are inhibited;
- RUNNING: compatible floors compose;
- PTO mechanical hand-throttle setting may persist through OFF without being
  physically applied during CRANKING.

Do not use a simple unconditional `max(allDemands)` across all motor phases.
