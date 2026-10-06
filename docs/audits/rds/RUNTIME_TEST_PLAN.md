# RDS absorption runtime test plan

Status: future native RE implementation gate.

## Eligibility / profiles

### T1 — diesel-only activation
Diesel tractor, gasoline vehicle, electric vehicle and ambiguous mod vehicle.
Expected: glow/start control activates only with valid capability evidence.

### T2 — glow technology profiles
Legacy / quick / modern profiles at identical temperatures.
Expected: different readiness timing; no universal 25-second curve.

## Input / state machine

### T3 — press-duration sweep
Exercise releases around every threshold.
Expected: every duration has deterministic behavior; no 401–549 ms dead zone.

### T4 — full-stack input collision
Keyboard/gamepad with current large mod stack.
Expected: actions remain registered; no silent collision loss.

### T5 — transition correctness
Rapid contact/crank/release/stop plus failed and successful provider starts.
Expected: HUD never shows RUNNING before authoritative confirmation.

## Standalone provider

### T6 — warm/cold start
Validate minimal fallback without arbitrary generic vehicle damage.

### T7 — save/reload state
Reload around OFF/IGNITION/PREHEAT.
Expected: explicit recovery policy; no invalid half-crank state.

## RMS provider

### T8 — thermal ownership
RE reads RMS temperature; no second RE temperature state.

### T9 — battery/starter/glow faults
Weak battery, glow fault, hard-start fault.
Expected: RMS remains final mechanical authority.

### T10 — MR + RMS + RE
No direct RE `motor.torqueScale` write and no pointer/ownership drift.

## ADS provider

### T11 — ADS 0.9.2.8 normal cold start
Preheat -> ADS starter -> confirmed running.

### T12 — ADS hard-start fault
Hold crank through difficult start without bypassing preheat or stopping incorrectly on release.

### T13 — historical bridge comparison
Compare native RE+ADS behavior with:
- old RC RDSADS semantics;
- exact RDS 1.4 behavior for held ADS hard-start.

Expected: RE keeps one key owner, passes crank intent cleanly and waits for
authoritative start confirmation without private ADS table writes.

### T13b — fuel-start facet composition
With a compatible fuel-system provider:
- premium/high-cetane fuel;
- stale/low-cetane fuel;
- filter/air-line hard block.

Expected: fuel factor/reason composes with starter/glow state instead of
replacing it.

## Pneumatic MVP

### T14 — governor cycle
Start below cut-in, build to cut-out, deplete to cut-in.
Expected: stable hysteresis/no chatter.

### T15 — RPM dependence
Compare build at idle/reference/higher RPM.
Expected: monotonic bounded response.

### T16 — repeated vs held brake application
Same starting pressure:
- repeated press/release;
- one full application held.
Expected: repeated applications consume materially more air; held application loses only initial demand + modeled leakage.

### T17 — low-air / spring thresholds
Sweep pressure down/up.
Expected: stable warning/spring behavior and intentional hysteresis.

### T18 — movement against spring brakes
Attempt launch at low and higher speeds.
Expected: brake effect exists continuously; movement results from physics overcoming brake torque, not a 5 km/h special case.

### T19 — brake lamps
Spring/parking state alone must not force service brake lights.

### T20 — condition/leak provider
Healthy vs damaged specialist state.
Expected: leakage uses normalized pneumatic/mechanical condition, not vanilla damage.

### T21 — elapsed game time
Park, sleep/fast-forward, reload.
Expected: one explicit time basis with consistent leakage.

## Multiplayer / authority

### T22 — join in progress
Join with unusual start state and low air.
Expected: full correct initial state immediately.

### T23 — unauthorized request
Client A targets client B's vehicle.
Expected: server rejection.

### T24 — stochastic outcome authority
Any fallback random start outcome is rolled once on server and agreed by all peers.

### T25 — dedicated-server churn
Repeated join/leave; inspect state/memory.

## AI / controllers

### T26 — cold helper start
AI automatically satisfies ignition/preheat.

### T27 — low-air helper departure
AI builds required air or fails safely; never freezes indefinitely.

Contrast against RDS 1.4's reference workaround (instant pressure floor):
RE must not create unexplained persistent pressure merely because AI took
control.

### T28 — Courseplay / AutoDrive smoke
No oscillation between manual RE start state and external controller behavior.

## HUD / lifecycle

### T29 — RMS/ADS coexistence
No duplicate authoritative temperature indicator by default.

### T30 — HUD scale / RMS UI
Test 0.75 / 1.0 / >1.0 with RMS.
Expected: RE indicators remain anchored in controlled-entity HUD.

### T31 — second mission same process
Save A -> menu -> Save B.
Expected: no stale HUD/settings references or console-command ownership leaks.

RDS 1.4 reference defects to guard against:
- overlay allocated but not deleted;
- console command registered by HUD instance but not removed.

## First replacement milestone exit gate

External RDS can be disabled in the project test stack when:
- eligibility/input tests pass;
- standalone + RMS provider paths pass;
- ADS path is functionally equivalent or better;
- initial MP state is proven;
- pneumatic T14–T21 pass for a baseline air-brake vehicle;
- AI cannot deadlock;
- no new RC ownership collision is introduced;
- exact RDS 1.4 source lessons/regressions are covered by the relevant gates.


## Reference-mod runtime characterization (optional before native code)

The exact RDS 1.4 source is now available. A short external-RDS characterization
session can improve calibration without making RDS the design authority.

### R1 — input boundary sweep
Measure 350 / 400 / 450 / 500 / 550 / 600 ms release/hold behavior.
Expected source prediction: 401–549 ms is inert.

### R2 — ADS hard-start handoff
With ADS difficult-start condition, hold key until ADS catches.
Verify RDS remains CRANKING and transitions only on real motor start.

### R3 — AI pressure clamp inheritance
Start with low air, hand vehicle to helper, then take control back.
Measure whether physical pressure permanently jumps to >= cut-in as predicted.

### R4 — second-save HUD lifecycle
Use `rdsHudSinADS` in save A, return to menu, load save B and inspect command
registration/behavior.

### R5 — join-in-progress low-air
Join while an unattended truck has non-default air pressure and inspect time to
first correct client state.

These tests are not prerequisites for the clean-room RE architecture; they are
useful behavioral/calibration evidence.


## Cross-stack gates added by final audit

### T32 — GIANTS native temperature fallback
Without RMS/ADS thermal ownership:
- compare RE-resolved temperature against `spec_motorized.motorTemperature.value`;
- warm engine under different load/RPM;
- stop/cool/reload.

Expected: RE uses native state instead of creating a duplicate standalone
temperature integrator unless a concrete gap is proven.

### T33 — neutral / clutch interlock provenance
Manual transmission, automatic/CVT and MR-managed vehicle.

Expected:
- interlock facet reports source;
- actual neutral/clutch state is consumed where available;
- no universal synthetic clutch is required.

### T34 — EngineRpmDemand composition
Only after a second RPM-demand consumer exists.

Combine:
- PTO hand throttle;
- cold idle;
- optional compressor fast-idle.

Expected:
- one final minimum-RPM application;
- no stacked controlVehicle wrappers;
- strongest compatible demand wins with explainable source;
- CRANKING does not receive normal RUNNING floor.

### T35 — PTO start interlock profile
One profile that requires PTO disengaged and one that does not.

Expected:
- interlock follows explicit profile;
- no global guessed restriction;
- native RE PTO state is consumed by revision.

## Native AIR backend characterization

### T36 — native AIR capability inventory
On representative vanilla/mod trucks/tractors:
- locate AIR consumer;
- fill unit;
- capacity;
- refill threshold/fill speed;
- dashboard state;
- compressor/release samples.

Record whether the metadata is physically interpretable enough for a stable
backend.

### T37 — native AIR save/reload
Alter AIR fill level, save/reload.

Expected: establish exactly which state GIANTS persists and whether RE can rely
on it without parallel persistence.

### T38 — native AIR multiplayer
Host/client:
- braking air use;
- refill state;
- join in progress.

Expected: establish native fill/state synchronization boundaries.

### T39 — soundExpansionMP composition
Exact soundExpansionMP 1.2.0.0:
- compressor start/run/stop;
- reverser forward/reverse braking;
- MP remote player.

Expected: a native-AIR-backed RE prototype preserves `consumer.doRefill`
semantics and produces one compressor sound lifecycle.

### T40 — native AIR policy replacement
Development prototype only:
- prevent native duplicate brake consumption/refill inside a narrow scope;
- apply RE physical policy to the same storage;
- verify unrelated fuel/DEF/methane consumers remain untouched.

Fail gate: any solution requiring broad permanent replacement of
`Motorized.updateConsumers` without safe ownership composition.

## Brake-owner composition

### T41 — RMS parking vs forced spring brake
With RMS parking brake active:
1. normal manual parking request;
2. low-air forced spring demand;
3. throttle;
4. AI takeover;
5. pressure recovery.

Expected:
- ordinary parking can follow RMS policy;
- low-air forced spring demand cannot release because of throttle/AI;
- final physical write has one owner.

### T42 — spring brake on low/high grip
Asphalt vs wet/soft surface.

Expected:
- RE supplies the same brake demand;
- MR/Mud/Reifen determine resulting lock/slide/drag;
- RE never boosts friction.

### T43 — engine can drag brakes
Loaded vehicle with applied spring demand.

Expected:
- movement, if any, results from engine/brake/ground balance;
- no artificial 5 km/h switch;
- no kinematic zero-speed lock.

## Pneumatic conservation

### T44 — reservoir-size pressure response
Same compressor amount flow, different reservoir volumes.

Expected: smaller reservoir gains pressure faster for the same added equivalent
air amount.

### T45 — repeated vs held application
Same initial state:
- repeated pedal applications;
- one held application.

Expected:
- application deltas consume air;
- held state mainly exposes leak after initial fill.

### T46 — idealized reservoir equalization
Development unit/harness:
- known truck/trailer volumes and pressures.

Expected:
- conserved `Q=P_abs*V`;
- final pressure matches analytic equalization;
- no absolute setter creates/destroys air.

### T47 — compressor RPM curve
Idle / reference / elevated engine RPM.

Expected:
- bounded monotonic amount flow;
- pressure response also reflects reservoir volume.

### T48 — optional compressor engine load
Only if feature is implemented.

Expected:
- load enters MR/engine owner once;
- no direct fake load-percentage write;
- loaded/unloaded governor state changes engine demand predictably.

## Provider/action contract gates

### T49 — context version independence
Extend/start provider while wheel context remains active.

Expected: START contract evolution does not invalidate existing WHEEL consumers.

### T50 — provider cache/invalidation
Repeated reads under stable owner state.

Expected:
- high cache hit/revision reuse;
- immediate invalidation on owner/profile/state change;
- no repeated private-table discovery in HUD/hot paths.

### T51 — read/action separation
Instrumentation must prove:
- StateContract calls do not mutate external owners;
- crank/brake actions pass only through Action/Interop adapter;
- RE gameplay modules do not write RMS/ADS private tables.

### T52 — exactly-once start factors
Construct overlapping cold/start conditions where a specialist already includes
temperature/battery.

Expected:
- provenance says which factors are included;
- RE contributes only missing factors;
- no double cold penalty.

## Configuration / authority gates

### T53 — local preference divergence
Host/client intentionally use different HUD colors/layout/key bindings.

Expected: presentation differs locally but simulation outcome is identical.

### T54 — simulation-config authority
Attempt divergent client preheat/pneumatic gameplay settings.

Expected: server/save SimulationConfig wins and is synchronized.

### T55 — illegal transition fuzz
Send out-of-order/repeated ignition/crank/release requests.

Expected:
- server transition validator rejects illegal state edges;
- no stuck CRANKING/ghost RUNNING state.

## Controller matrix extension

### T56 — PLAYER / GIANTS AI / Courseplay / AutoDrive start parity
Same cold vehicle.

Compare:
- owner resolution;
- start readiness;
- motor outcome;
- departure readiness.

Expected: controllers may skip gestures, not physical blocks.

### T57 — pneumatic AI readiness without free air
Begin below safe pressure.

Expected:
- bounded pre-trip behavior;
- no infinite helper loop;
- no unexplained permanent pressure jump merely because AI took control.

## Presentation/audio

### T58 — one semantic sound owner
Stacks:
- native only;
- soundExpansionMP;
- RMS/ADS start owner;
- future Realistic Brakes when audited.

Expected:
- one starter/compressor/release/parking sound event;
- no doubled loops or remote desync.

### T59 — shared HUD slot packing
Enable start + PTO + pneumatic + RMS presentation.

Expected:
- semantic slots pack without module-specific "with X mod" layouts;
- UI scale/aspect changes invalidate geometry once;
- no per-frame layout rebuild.

## Dependency gate — Realistic Brakes

### T60 — exact-source audit required before trailer phase
Do not execute trailer-air implementation test until current Realistic Brakes
source is available and audited for:
- reservoir representation;
- spring-brake physics;
- parking brake;
- engine/Jake brake;
- thermal fade;
- hose/connectivity;
- AI behavior;
- Enhanced Vehicle ownership;
- RDS pressure API use.

Public behavior alone is not sufficient to choose final ownership.
