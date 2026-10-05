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
Compare native RE+ADS behavior with the old RDSADS semantics before retiring that bridge.

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
Expected: no stale HUD/settings references.

## First replacement milestone exit gate

External RDS can be disabled in the project test stack when:
- eligibility/input tests pass;
- standalone + RMS provider paths pass;
- ADS path is functionally equivalent or better;
- initial MP state is proven;
- pneumatic T14–T21 pass for a baseline air-brake vehicle;
- AI cannot deadlock;
- no new RC ownership collision is introduced;
- current RDS 1.4 source has been rechecked if it becomes available.
