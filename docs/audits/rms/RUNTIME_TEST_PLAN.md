# RMS runtime test plan

Baseline: RMS `0.10.0.0`, ZIP SHA-256 `6741f193f22a5f85f5543c73d7f566b6686ab90bf7b705fd66d6d3421cb0d021`.

Purpose: validate only findings whose severity/incidence depends on GIANTS runtime behavior or active-stack composition. Static defects do not need runtime proof before being reported upstream, but a reproduction is still useful before carrying any RC hotfix.

## T1 — client reinitialize authorization
Dedicated server with a non-master client.
Attempt to send the reinitialize event from that client.
Expected after fix: server rejects it; fleet condition/log state unchanged.

## T2 — start-button controller authorization
Two clients, two vehicles.
Have client A send a start-button request for client B's controlled vehicle.
Current source prediction: request is accepted if the vehicle is synchronized.
Expected fixed behavior: rejected.

## T3 — client start-effect authorization
Repeat cross-client targeting for the three allowed start-related effect IDs.
Capture status/timer changes and final start path.

## T4 — connection-mask lifecycle
Dedicated server.
Repeatedly join/leave clients while one RMS vehicle stays loaded.
Instrument `rmsPendingByConnection` key count and memory.
Confirm whether dead connection objects remain.

## T5 — long maintenance history join cost
Generate increasingly large log histories on multiple vehicles.
Measure:
- vehicles.xml growth;
- initial stream bytes/time;
- join latency;
- client deserialize time.

## T6 — 100 ms hitch invariance
Create a repeatable active-effect timer/control scenario.
Compare normal frame cadence with injected 300–500 ms stalls.
Check whether timers/control state under-advance as predicted.

## T7 — state-snapshot hitch invariance
Repeat for 50/200/500 ms sampled state:
- wheel slip windows;
- differential acceleration;
- chassis vibration;
- braking-under-mass;
- implement/lift state.

Separate harmless observation aliasing from lost physical accumulation.

## T8 — core catch-up burst
Large RMS fleet.
Inject a severe server hitch.
Measure one-frame RMS CPU work, vehicle core updates executed and residual scheduler debt.

## T9 — fleet wake-scan scaling
Profile server-frame cost with progressively larger parked/running RMS fleets.
Compare motor OFF vs unattended motor ON.

## T10 — MTBF helper cadence
Harness or controlled runtime with an effect using `getChancePerFrameFromMeanTime`.
Compare event rate under different fixed dt/cadence values against exponential hazard expectation.

## T11 — diff-lock request across release speed
Request lock below threshold.
Accelerate above release speed, then slow below it without pressing the lock input again.
Current source prediction: it releases and stays unrequested.
Expected documented behavior: effective lock re-engages while request remains.

## T12 — native lock strength
Choose a vehicle whose original axle differential `maxSpeedRatio` is clearly > locked target.
Measure left/right wheel-speed difference:
- open;
- RMS lock;
- reduced/non-native graph where applicable.

## T13 — wind-up surface matrix
Same vehicle/steering/speed/load on:
- asphalt;
- gravel;
- dry field;
- wet/soft field.
Compare 4WD-only vs diff-lock wind-up rates.

## T14 — AUTO engage
Controlled low-speed high-load test with little initial slip.
Confirm AUTO engages from load criterion.

## T15 — AUTO slip engage
Controlled low-load wheelspin test.
Confirm AUTO engages from slip criterion.

## T16 — AUTO release hysteresis
After engagement, raise speed and reduce slip.
Verify release delay/hysteresis and graph change.

## T17 — unconventional drivetrain layouts
At minimum test:
- conventional rear-primary tractor;
- four-wheel-steer;
- articulated vehicle;
- twin track;
- any front-primary/unusual machine available.
Validate primary/engageable axle classification and safe fallback.

## T18 — MR driven metadata after RMS topology changes
With MRRMS active, inspect effective MR driven-wheel state through:
2WD -> 4WD -> AUTO engage -> AUTO release.
No stale `mrIsDriven` or count/load/slip aggregates.

## T19 — Reifen FORCE-WEAR topology cache
With exact Reifen 1.2.2.67:
1. establish baseline FORCE-WEAR shares in 4WD;
2. switch RMS to 2WD;
3. inspect cached/share behavior and wear accumulation by axle;
4. switch back to 4WD/AUTO.
Confirm the static stale-cache prediction.

## T20 — Enhanced Vehicle coexistence
Run EV drivetrain control enabled and disabled.
Confirm RMS steps aside only for the owned capability and resumes cleanly when settings change.

## T21 — Enhanced Vehicle second-save cache
Load mission A long enough for EV cache deadline to be high.
Return to menu and load mission B in the same process with different EV settings.
Observe whether RMS delays rereading them.

## T22 — differential restore ownership
Use a controlled test mod to change the differential graph after RMS captures layout.
Then force RMS to release control.
Determine whether RMS restores its older snapshot over the later modification.

## T23 — SpeedMeter HUD exception safety
Development-only injected error inside delegated `SpeedMeterDisplay.draw`.
After recovery inspect:
- all child `getDamageAmount` method identities;
- `speedBg` visibility.
Expected current source: restoration can be skipped.

## T24 — second-save leasing hooks
Load mission A, return to menu, load mission B in the same process.
Instrument call counts for:
- `ShopController.sell`;
- `SellVehicleEvent.run`;
- RMS leasing callbacks.
Confirm whether wrappers stack.

## T25 — jumper-cable vehicle deletion
Connect two RMS vehicles.
Delete/sell one without manually disconnecting first.
Inspect the survivor's `externalPowerConnection` and object lifetime.
Expected current source: stale relation persists until overwritten.

## T26 — physical fluid transfer deletion
Begin a manual fluid transfer.
Delete:
- source container;
- target vehicle.
Confirm locks and transfer references clear without leaked/busy circuits.

## T27 — fluid-transfer conservation
Try:
- target nearly full;
- source nearly empty;
- wrong fluid confirmation;
- disconnect/out-of-range mid-transfer.
Verify source + target liters conserve the accepted amount and rollback rejected liters.

## T28 — workshop transaction rollback
Force failures at:
- insufficient stock;
- insufficient money;
- service-init refusal;
- requirement mismatch;
- partial container consumption.
Verify stock, service state and money remain atomic.

## T29 — weather initialization
Start a fresh mission while raining/snowing.
Inspect `RMS_Main.currentWeather` and electrical weather wear from time zero until first meta refresh.
Repeat as second save in one process.

## T30 — thermal cadence
Compare engine and transmission temperature curves at stable workload across different FPS.
Validate the intended engine-250ms/transmission-frame split is numerically stable.

## T31 — electrical cadence/random-load distribution
Record battery current/SOC/voltage under fixed conditions at different render FPS/server cadences.
Because persistent electrical work is server core-owned, distribution should be independent of client FPS.

## T32 — paired external-power solve
Connect two batteries.
Verify exactly one pair solve per mission-time stamp and symmetric charge/current state.
Then move either vehicle beyond disconnect threshold.

## T33 — wear causal matrix
For each system, isolate its high-value factors and compare accumulated condition/stress:
- engine overload/lug/cold/hot;
- transmission overload/slip/wind-up/cold/hot;
- hydraulics load/vibration/fluid/temp;
- PTO utilization/engagement;
- cooling stress;
- electrical cranking/weather/lights;
- chassis vibration/braking/steering/lubrication;
- fuel starvation/cold/idle/high pressure.

The goal is calibration and sign/direction proof, not exact real-world validation yet.

## T34 — breakdown causal selection
Build stress histories biased toward known systems/factors.
Run many controlled breakdown rolls and verify applicable/probability weighting follows causal history rather than unrelated failures.

## T35 — breakdown stage progression
For representative engine/transmission/hydraulic/electrical failures:
- verify stage timers;
- `isCanProgress` gating;
- visibility/detection;
- quick-fix suspension/resume;
- effect aggregation/removal.

## T36 — concurrent-breakdown limit
Fill the selectable breakdown limit, then attempt another random/selectable failure and a nonselectable state failure.
Confirm intended distinction.

## T37 — used-vehicle server determinism
Dedicated MP used vehicle purchase/load.
Confirm randomized subsystem condition and initial breakdown are generated server-side once and all peers receive identical state.

## T38 — AI worker / Courseplay / AutoDrive smoke
For GIANTS AI, Courseplay and AutoDrive:
- heavy load;
- engine overtemp;
- transmission overtemp;
- lowered implement speed limit;
- recovery after stress.
Look for competing cruise-speed ownership or oscillation.

## T39 — contract vehicle protection
Validate mission/contract vehicle behavior with protection enabled/disabled:
- wear/stress;
- AI protection;
- breakdown behavior;
- service state.

## T40 — long-session fleet performance
Representative full realism stack, large fleet, several hours.
Collect:
- RMS per-frame/core CPU;
- dirty-group traffic;
- wake scan cost;
- maintenance history growth;
- connection mask count;
- active breakdown/effect counts;
- memory trend.

## Exit gate

Static/source audit does not require all runtime tests to be executed now.

RMS runtime phase can be considered closed when:
- confirmed source defects targeted for patches have reproductions where useful;
- drivetrain + Reifen + MR composition is proven;
- dedicated-server authority/lifecycle tests pass;
- no cadence/performance blocker appears under a large realistic fleet;
- the active stack has a smoke test for AI/controllers, service and electrical/drivetrain state.


# RMS 0.11 upgrade runtime matrix

The original tests remain useful where their finding still exists. Add the
following version-specific gates before promoting 0.11 to VERIFIED.

## T33 — RC bootstrap/version confidence
With RMS 0.11 and current RC candidate:
- MRRMS = ACTIVE / SOURCE_COMPATIBLE;
- MudRMS = ACTIVE / SOURCE_COMPATIBLE;
- if legacy external `FS25_DynamicPTO_FFM` is installed, RMSDynamicPTO = ACTIVE / SOURCE_COMPATIBLE;
- if native RE PTO is used instead, `RMSDynamicPTO` is expected to be INACTIVE because that RC bridge targets only the legacy external owner;
- no reference to missing `RMS_Consumptables`;
- no RC-attributable Lua errors.

## T34 — MRRMS drivetrain metadata
Cycle:
- 2WD;
- 4WD;
- AUTO engage/disengage;
- differential lock where supported.

Verify MR driven-wheel metadata matches RMS effective topology after every RMS
graph application.

## T35 — MRRMS transmission effects
Exercise/force:
- powershift engagement lag;
- gear shift failure;
- transmission slip/CVT effects where applicable.

Confirm MR replacement paths do not bypass RMS effects.

## T36 — MudRMS with 0.11 clogging model
Dry and locally wet field cells.

Record:
- GIANTS global wetness;
- Mud local wetness;
- RMS radiator debug wetness/factor;
- RMS air-filter debug wetness/factor;
- RC substitution counters.

Expected:
- RMS consequence uses local wetness during the scoped call;
- the weather method is restored afterward;
- the new 0.11 clogging rate remains owned by RMS.

## T37 — PTO continuous utilization

### Native RE PTO path
Use the current native RE PTO build with `FS25_DynamicPTO_FFM` disabled.
For at least two physical PTO modes with different effective ratios:
- same implement torque;
- compare RMS `ptoMotorSideTorque`, native capacity and utilization.

Expected:
RMS sees the effective RE PTO ratio exactly once through the VehicleMotor ratio contract.
The RC `RMSDynamicPTO` bridge remains INACTIVE in this path.

### Legacy external Dynamic PTO regression
Only if `FS25_DynamicPTO_FFM` is tested separately, expect RC `RMSDynamicPTO`
to become ACTIVE and preserve the older compatibility path.

## T38 — PTO engagement shock
Using a disposable/test vehicle, engage the same PTO implement:
- near idle;
- at high engine RPM;
- under two effective PTO ratios if supported.

Capture:
- RMS engagement torque;
- effective ratio;
- computed size/utilization;
- `ptoEngagementDamage`.

Goal:
verify the existing RMSDynamicPTO capacity scope correctly extends to the new
0.11 engagement-shock model and does not double-count Dynamic PTO feedback load.

## T39 — diff-lock request regression
Repeat the old lock test on 0.11:
- request below 10 km/h;
- exceed 10 km/h;
- slow below 10 without pressing the input again.

Static prediction:
request is cleared and lock does not re-engage.

This is owner-mod evidence, not an RC promotion blocker unless it breaks current
gameplay expectations.

## T40 — RMS/Reifen FORCE-WEAR topology
Use exact RMS 0.11 + Reifen 1.2.2.70.

Compare Reifen cached driven shares before/after:
- 2WD -> 4WD;
- 4WD -> 2WD;
- AUTO transition.

Measure actual wear divergence.

This remains the gate for a future narrow topology provider/invalidation bridge.

## T41 — 0.10 save upgrade / migration
On a backup:
- load an RMS 0.10 save in 0.11;
- inspect maintenance schedules;
- fluid levels/capacities;
- workshop prices/value;
- overhaul state;
- old RMS physical fluid containers;
- removed settings.

Separate expected 0.11 migration changes from RC defects.

## T42 — battery charger authority/reference
Optional architecture-reference test:
- charge owned vehicle;
- attempt other-farm access on dedicated server;
- move player out of range;
- delete/store charger while connected;
- start-assist during cranking.

This is not an RC compatibility gate; it validates the positive upstream pattern.

## T43 — Mobile Workshop
Only if the target stack uses `FS25_mobileWorkshop`.

Verify upstream RMS inspection/service integration directly.

RC should remain uninvolved.

## 0.11 promotion gate

Promote RMS 0.11 from SOURCE_COMPATIBLE only after:
1. T33 passes;
2. MRRMS topology/transmission smoke passes;
3. MudRMS local-wetness smoke passes;
4. native RE PTO continuous + engagement-shock smoke passes; legacy external Dynamic PTO is optional regression coverage;
5. save upgrade shows no unexpected state corruption;
6. no new RC-attributable errors.

RMS/Reifen T40 remains a separate bridge decision and is not required merely to
adopt RMS 0.11.
