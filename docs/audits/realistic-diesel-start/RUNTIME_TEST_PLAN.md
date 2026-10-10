# Realistic Diesel Start 1.4 runtime test plan

The exact-source/static audit is complete. These tests are the remaining gate
before promoting the RDS 1.4 + RC adapter to runtime-validated.

## A. Upgrade/bootstrap

Stack:
- RDS 1.4.0.0;
- ADS 0.9.2.8;
- RC branch `research/rds-1.4.0-current-base`;
- otherwise normal target stack.

Expected startup:
- RDS detected as `1.4.0.0 SOURCE_COMPATIBLE` for RDSADS;
- ADS remains `0.9.2.8 VERIFIED`;
- `RDSADS ACTIVE`;
- adapter mode `RDS_1_4_NATIVE_AWARE`;
- no old HUD/input takeover diagnostics.

## B. Diesel / non-diesel / electric classification

Test:
1. normal diesel tractor;
2. electric vehicle;
3. non-diesel combustion vehicle if available.

Expected target-stack policy:
- diesel -> RDS sequence active;
- electric -> bypass;
- other combustion -> bypass diesel glow sequence unless explicitly configured.

This validates that broad upstream Motorized registration does not leak diesel
semantics into unrelated powertrains.

## C. Warm ADS-managed start

Engine already warm.

Expected:
- RDS key/contact sequence remains native;
- no meaningful preheat delay;
- RC hard-start contribution = zero;
- ADS owns actual start;
- no duplicate damage;
- RDS thermometer remains suppressed as upstream intends for ADS-managed vehicle.

## D. Cold ADS-managed start — full preheat

Cold engine; wait until READY before cranking.

Record:
- ADS engine temp;
- RDS effective temp/preheat progress;
- fuel cold-start factor if provider exists;
- RC translated hard-start seconds;
- native ADS hard-start effect;
- start result.

Expected:
- RDS and ADS agree on thermal source;
- near/full glow readiness contributes little/zero extra hard-start;
- one start lifecycle, not two random failure rolls.

## E. Cold ADS-managed start — incomplete preheat

Repeat at similar temperature but crank early.

Expected:
- RC produces a larger transient RDS readiness contribution;
- native RDS 1.4 sees the temporary "ready" value only inside its duplicate
  random-failure branch;
- actual persisted/displayed preheat progress is restored immediately;
- ADS starter keeps cranking while key remains held;
- engine catches according to ADS hard-start lifecycle;
- no RDS early-start damage is stacked on ADS for the same cause.

Compare against old RC0111 reference behavior.

## F. ADS native hard-start fault + incomplete glow

If safely reproducible through ADS diagnostics/test tooling:
- weak battery / starter / wiring / fuel pump / injector hard-start;
- cold engine;
- incomplete glow.

Expected:
- ADS native effect and RC glow-readiness contribution compose by max/owner
  semantics, not additive double punishment;
- starter remains active while key held;
- successful start clears transient RC contribution;
- releasing key clears it without leaving stale ADS state.

## G. ADS-excluded vehicle

Use a vehicle explicitly excluded by ADS.

Expected:
- RDS thermometer visible;
- native RDS engineHeat/effective temperature used;
- native RDS cold torque works;
- native RDS cold-drive damage works;
- no RC preheat→ADS transient;
- no RC cold-consequence suppression.

This is a critical regression test because the old bridge could not preserve this
case correctly.

## H. Diesel Fuel System provider

When/if that mod is available in the stack:

Compare:
- premium/high-cetane fuel;
- stale/low-cetane fuel;
- explicit start-block condition such as air/filter if safely configurable.

Expected:
- `scGetColdStartFactor()` changes RC/RDS readiness contribution;
- owner-supplied `scGetStartBlockReason()` remains visible;
- RC does not erase the fuel system's reason or priming behavior;
- ADS still owns the actual starter/hard-start lifecycle.

## I. Realistic Brakes trailer air

RDS 1.4 + Realistic Brakes 1.3.

Attach a trailer with air brakes.

Observe:
- truck pressure before attach;
- trailer reservoir before attach;
- truck pressure immediately after supply;
- compressor recovery;
- trailer disconnect/reconnect.

Expected:
- RDS truck tank loses the transferred quantity;
- Realistic Brakes owns trailer air;
- compressor restores truck pressure;
- RC does not intervene.

## J. Air system server authority / JIP

Dedicated server preferred.

Create:
1. full-pressure running truck;
2. low-pressure truck;
3. spring-brake-active truck.

Join with a second client.

Measure:
- initial local pressure;
- delay until first authoritative `RDSAirStateEvent`;
- spring-brake display/behavior during convergence.

Goal:
characterize the intentional absence of initial-stream air sync.

## K. Physical/profile setting divergence

Dedicated server and client with deliberately different profile/console
physical settings where possible:
- damageEnabled;
- airSystemEnabled;
- scales.

Observe:
- actual server physics;
- client HUD/presentation;
- any client-side decisions that use local values.

Goal:
determine which settings need stronger authority if future RC/RE consumers rely
on them.

## L. Damage-event authority test

Controlled local/dedicated harness only.

Attempt a client-originated `RDSDamageEvent`:
- for own controlled vehicle;
- for another synchronized vehicle if the test environment permits safely;
- with an exaggerated positive amount.

Expected from static source:
- server accepts vehicle+amount without full requester/cause revalidation.

Purpose:
confirm owner-mod security semantics for documentation. Do not create an RC
hotfix merely to repair it.

## M. Air/brake physical calibration

Optional engineering study:
- reservoir from full to low pressure;
- equal pedal applications at different speed/load;
- compressor recovery at idle vs raised RPM;
- leakage while parked;
- trailer fill.

Goal:
separate gameplay calibration from physically grounded pressure-volume behavior.

Not a blocker for version upgrade unless behavior is broken.

## N. Multi-save/process lifecycle

Without restarting FS25:
- load save A;
- exercise RDS;
- return to menu;
- load save B.

Check:
- motor key wrapper duplicates;
- HUD duplicates;
- action events;
- stale air/HUD state;
- RC transient table cleanup.

## Promotion gate

RDS 1.4 + RC may be considered runtime-validated when:
1. cold/warm ADS-managed starts behave correctly;
2. incomplete glow influences ADS exactly once;
3. held-key ADS hard start works;
4. key release cleans up correctly;
5. ADS-excluded vehicle retains full native RDS behavior;
6. no duplicate RDS cold torque/damage under ADS;
7. diesel/electric/non-diesel classification is sane;
8. no RC-attributable Lua error;
9. RDSADS telemetry proves the native-aware path is executing;
10. normal RDS air behavior remains healthy.

Fuel System, Realistic Brakes and dedicated-MP tests can be closed separately if
those mods/environments are unavailable during the first smoke, but they remain
documented follow-up gates for the relevant cross-mod contracts.
