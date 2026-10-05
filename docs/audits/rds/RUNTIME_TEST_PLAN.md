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
