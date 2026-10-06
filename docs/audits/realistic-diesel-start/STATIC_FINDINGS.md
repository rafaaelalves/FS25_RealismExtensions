# Realistic Diesel Start 1.4.0.0 static findings

Exact package SHA-256:
`a2a983c7754bc4fb3dffc04839fb16cf844c72d7664ae78cfcd70fcf3c15721c`.

Evidence labels:
- **CONFIRMED_STATIC**
- **POSITIVE_PATTERN**
- **DESIGN_RISK**
- **RUNTIME_PENDING**
- **RC_CONSEQUENCE**

## RDS-01 Native ADS key ownership supersedes the old RC input bridge
**CONFIRMED_STATIC / RC_CONSEQUENCE**

RDS 1.4 wraps the vanilla motor action so RDS-managed vehicles keep the
multi-stage diesel sequence instead of letting another start path jump directly
to motor start.

RDS also reports key-down/held/up state to ADS.

The old RC strategy of replacing ADS `onStartButtonAction` and replacing RDS
action registration is no longer the correct boundary for 1.4.

## RDS-02 Native ADS hard-start crank supersedes old RC gesture ownership
**CONFIRMED_STATIC / POSITIVE_PATTERN**

RDS detects when `startMotor()` did not immediately produce a running engine
and can remain in an external-crank state while the key is held.

ADS can therefore keep the starter active until its own hard-start logic allows
combustion.

This fixes the specific interaction that originally motivated a large part of
RDSADS.

## RDS-03 HUD coexistence is now per vehicle and ADS-exclusion aware
**CONFIRMED_STATIC / FIX**

RDS 1.4 shows/hides its temperature telltale based on whether ADS actually
manages the vehicle.

The old RC behavior deleted the RDS thermometer globally whenever ADS was
loaded.

That old behavior is now harmful: an ADS-excluded vehicle should retain the RDS
thermometer.

## RDS-04 Two thermal sources of truth still exist
**CONFIRMED_STATIC / DESIGN_RISK**

RDS keeps its own normalized `engineHeat` and derives an effective engine
temperature from it.

ADS keeps its own engine temperature.

RDS preheat/warm-up/cold-drive decisions therefore remain capable of using a
different thermal state from ADS.

The reduced RC 1.4 adapter uses ADS temperature only for ADS-managed vehicles and
maps it into RDS's visual/warm-up state.

## RDS-05 Cold-start difficulty is still represented twice under ADS
**CONFIRMED_STATIC**

RDS can independently roll a failed start from:
- effective engine temperature;
- glow/preheat progress;
- optional fuel-system cold-start factor.

ADS independently models hard starts from mechanical/electrical/fuel defects and
cold temperature.

Without composition, one user gesture can therefore be evaluated by two
stochastic start-difficulty owners.

RC 1.4 translates RDS readiness into ADS's hard-start domain and neutralizes only
RDS's duplicate random roll during that ADS-managed attempt.

## RDS-06 Fuel-system cold-start factor is a real semantic input
**POSITIVE_PATTERN**

When available, RDS asks `scGetColdStartFactor()` and includes it in start
difficulty.

This is a better boundary than reading the fuel mod's private quality state.

The reduced RC adapter includes that factor in its glow-readiness → ADS
hard-start translation so the upstream fuel integration is not lost.

## RDS-07 Fuel-system start-block reason is owner-provided
**POSITIVE_PATTERN**

RDS can ask `scGetStartBlockReason(shortText)` when another system refuses the
start.

The owner of fuel-path readiness therefore owns the user-visible reason.

This is the right UX/provider direction.

## RDS-08 Fuel-system capability discovery is unversioned
**DESIGN_RISK**

The contract is inferred from optional function presence.

There is no explicit provider/API version or capability descriptor.

Good semantic boundary; weaker capability negotiation.

## RDS-09 Old global damage disable is too broad for 1.4
**CONFIRMED_STATIC / RC_CONSEQUENCE**

The legacy RDSADS bridge forced RDS `damageEnabled=false` whenever ADS was
loaded.

In 1.4:
- ADS can exclude individual vehicles;
- RDS air-pressure damage is a different physical domain from ADS cold-start
  composition.

Global suppression would erase valid RDS behavior.

The 1.4 RC path removes this global setting override.

## RDS-10 RDS cold torque overlaps ADS mechanical consequences
**CONFIRMED_STATIC**

RDS applies a reduced torque scale while cold/warming.

ADS owns engine-condition/cold mechanical consequences in the target stack.

Running both independently can stack cold penalties.

RC 1.4 suppresses RDS cold-torque consequence only when ADS manages the vehicle.

## RDS-11 RDS cold-operation damage overlaps ADS damage ownership
**CONFIRMED_STATIC**

RDS can add damage for operating the engine cold.

ADS is the target-stack mechanical damage owner.

RC 1.4 suppresses this RDS consequence only for ADS-managed vehicles and leaves
it intact for ADS-excluded vehicles.

## RDS-12 ADS-excluded vehicles are first-class coexistence cases
**POSITIVE_PATTERN / RC_CONSEQUENCE**

RDS explicitly checks ADS exclusion state.

This means compatibility cannot be decided only at mod-presence level.

Project principle:
> coexistence policy should be capability/vehicle scoped when the upstream owner
> can opt out per vehicle.

## RDS-13 Diesel classification remains broader upstream than the project wants
**CONFIRMED_STATIC / PROJECT-SCOPE MISMATCH**

The modDesc describes the sequence for all motorized vehicles and RDS primarily
uses electric-vs-non-electric bypass semantics.

For the user's diesel-specific realism stack, gasoline/other combustion
equipment should not automatically receive glow-plug behavior.

The existing RC diesel-consumer classification remains useful.

This is a project-scope decision, not necessarily an upstream bug.

## RDS-14 Air pressure is server-authoritative
**POSITIVE_PATTERN**

The compressed-air simulation is updated by the server.

Clients receive pressure/spring-brake state rather than simulating persistent
tank pressure independently.

Good ownership model.

## RDS-15 Air-state replication is compact and change-driven
**POSITIVE_PATTERN**

`RDSAirStateEvent` sends:
- pressure quantized into 10 bits over 0..10 bar;
- spring-brake state.

Broadcast occurs only after meaningful pressure/state change.

This is an efficient slow-state replication pattern.

## RDS-16 Initial air state has a JIP convergence tradeoff
**DESIGN_RISK / RUNTIME_PENDING**

The current source intentionally does not send the air state in the normal
initial vehicle stream.

A joining client may briefly begin from local/default state until the next
natural air-state event.

That may be acceptable presentation latency, but it should be measured with:
- parked vehicle;
- low-pressure vehicle;
- spring-brake-active vehicle.

## RDS-17 Realistic Brakes air API is narrow and well-owned
**POSITIVE_PATTERN**

RDS exposes semantic truck-tank access:
- `rdsGetAirPressure()`;
- server-owned `rdsSetAirPressure(bar)`.

Realistic Brakes 1.3 consumes those functions while owning trailer reservoir and
hose behavior.

No cross-mod private-state mutation or generic monkey-patching is required for
the air transfer itself.

Classification:
**GOOD_AND_ADOPT_PRINCIPLE**.

No RC bridge is recommended.

## RDS-18 Air-consumption model is a gameplay proxy
**DESIGN_RISK / MODEL_BOUNDARY**

Brake-air consumption is influenced by inputs such as:
- brake pedal;
- speed;
- load;
- time.

In a physical pneumatic brake system, chamber/application volume and pressure
cycle are the more direct consumption drivers; vehicle speed/mass mainly change
braking demand, not tank volume consumed per se.

The current model is plausible gameplay calibration, not a pneumatic-system
reference model.

Do not copy it as first-principles physics.

## RDS-19 Spring-brake behavior is more important than generic brake weakening
**CONFIRMED_STATIC**

The low-air model uses a spring-brake threshold and can impose drag/locking.

The helper that would represent normal service-brake scaling does not implement
a rich continuous loss curve above that threshold.

Public descriptions of "reduced braking" should therefore not be read as proof
of a detailed service-brake pressure model.

## RDS-20 Physical/profile settings are not an authoritative network contract
**DESIGN_RISK**

RDS settings persist per profile in
`FS25_RealisticDieselStart_config.xml`.

The UI exposes mainly local UX choices, but other physical/configuration values
can still be changed through profile/console state.

There is no general server-snapshot contract ensuring clients interpret every
physical option identically.

This echoes the settings-authority lesson from the 4x4/HSS audits.

## RDS-21 Client damage event lacks requester authorization
**CONFIRMED_STATIC MP/SECURITY DEFECT**

`RDSDamageEvent` sends:
- synchronized vehicle reference;
- client-provided Float32 damage amount.

The server applies the amount to the target vehicle without reconstructing the
amount from authoritative state and without validating requester control/farm
permission.

A controlled client can therefore request an arbitrary damage increment for a
synchronized vehicle.

This is an owner-mod defect to document, not an automatic RC hotfix.

## RDS-22 Damage amount is not server-clamped to the physical cause
**CONFIRMED_STATIC MP/SECURITY DEFECT**

The damage event accepts the transmitted amount directly.

Future authoritative design should send an intent/cause or let the server own
the complete damage decision.

## RDS-23 Global motor-action hook has process lifetime
**DESIGN_RISK**

RDS installs a global `Motorized.actionEventToggleMotorState` wrapper to
preserve its ignition sequence.

The wrapper is correctly scoped by the presence/state of the RDS specialization,
but there is no full install/uninstall ownership lifecycle.

Runtime multi-save behavior remains worth observing.

## RDS-24 Specialization registration is broad
**ARCHITECTURE_LEARNING**

RDS dynamically adds its specialization across motorized vehicle types and then
uses runtime classification/bypass logic.

This is robust for heterogeneous mod vehicles but broader than an ideal
capability registration.

A future native system should register only where a reliable engine/fuel
capability says the feature applies.

## RDS-25 Air state persists cleanly
**POSITIVE_PATTERN**

Compressed-air pressure and related durable state are saved in the vehicle
savegame state.

This matches the physical expectation that a parked truck can retain/lose air
across time rather than respawning at a full/default tank.

## RDS-26 Internal version provenance is stale
**CODE_QUALITY**

The package declares 1.4.0.0, but a source-side diagnostic string still
identifies the main script as 1.2.0.0.

Compatibility decisions must use modDesc version/hash and source contract, not
developer debug labels.

## RDS-27 Upstream 1.4 makes the old RDSADS bridge partially obsolete
**ARCHITECTURE_CONCLUSION**

For exact RDS 1.4, retire:
- RC HUD deletion;
- RC engine-key/ADS action routing;
- clutch-only action-registration replacement;
- global RDS damage disable;
- full `tryCrank()` replacement.

Retain/redesign only:
- diesel eligibility;
- ADS thermal authority where ADS manages the vehicle;
- glow + fuel readiness translation into ADS hard-start semantics;
- suppression of duplicate RDS cold mechanical consequences under ADS;
- transient hard-start lifecycle/telemetry.

This is a concrete **SUPERSEDES_RC (partial)** result.

## RDS-28 The reduced RC bridge must preserve upstream native integrations
**RC_CONSEQUENCE**

The RDS 1.4 RC path must not erase:
- Diesel Fuel System factor/block reason;
- ADS external-crank state;
- ADS-exclusion HUD logic;
- Realistic Brakes air API.

This is why wrapping a small semantic boundary is preferable to replacing the
entire RDS state machine.
