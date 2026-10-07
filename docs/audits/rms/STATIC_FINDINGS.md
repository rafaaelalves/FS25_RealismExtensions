# RMS static findings ledger

Baseline: RMS `0.10.0.0`, ZIP SHA-256 `6741f193f22a5f85f5543c73d7f566b6686ab90bf7b705fd66d6d3421cb0d021`.

Static/source scope: architecture, scheduling, networking, persistence, drivetrain, wear/breakdowns, thermal/electrical, service/fluids, AI/leasing and UI. Runtime proof remains separate.

Evidence labels:
- **CONFIRMED_STATIC** — source proves the condition/path.
- **STRONG_CANDIDATE** — source strongly indicates a defect/risk but engine/runtime semantics still matter.
- **DESIGN_RISK** — architectural tradeoff/collision surface rather than a direct bug.
- **POSITIVE_PATTERN** — implementation worth retaining/learning from.
- **RUNTIME_PENDING** — needs controlled FS25 evidence.

## RMS-01 Reinitialize event lacks server-side admin authorization
**CONFIRMED_STATIC**

`RMS_SettingsPage` normally exposes settings changes only to server/master users, but `RMS_ReinitializeVehiclesEvent:run()` accepts any client-originated request and directly calls `RealisticMechanicalSystems.reinitializeAllVehicles()`.

Patch candidate: repeat the same master-user validation on the server event boundary.

## RMS-02 Start-button event does not authenticate vehicle controller
**CONFIRMED_STATIC**

`RMS_StartButtonEvent:run()` accepts a synchronized RMS vehicle, writes its start-button flags and can invoke `RMS_Preheat.requestStart()` on the server.

It does not check `vehicle:getOwnerConnection() == connection` or otherwise bind the request to the player controlling that vehicle.

Patch candidate: mirror the ownership pattern already used by `RMS_DrivetrainEvent`.

## RMS-03 Client start-effect sync trusts target vehicle
**CONFIRMED_STATIC**

`RMS_EffectSyncEvent` intentionally allows client-to-server traffic for three start-related effects:
- `ENGINE_HARD_START_MODIFIER`;
- `GLOW_PLUG_HARD_START_MODIFIER`;
- `ENGINE_FAILURE`.

The server accepts the vehicle/effect payload without verifying the sender controls the vehicle. It also accepts status/timer fields without a strict transition validator.

Patch candidate: authenticate controller + whitelist legal client-origin transitions; keep final start outcome server-owned.

## RMS-04 Pending dirty masks retain connection keys without visible cleanup
**STRONG_CANDIDATE**

`spec.rmsPendingByConnection` is a normal strong-key table. Connections are added during initial stream handling. Pass-1 source scan found no disconnect removal or weak-key mode.

Long dedicated-server sessions with player churn could retain obsolete connection objects per RMS vehicle.

Runtime proof: join/leave many clients and inspect key count / memory. Defensive patch: weak keys or explicit disconnect cleanup.

## RMS-05 Maintenance history is unbounded and fully sent on join
**CONFIRMED_STATIC design/performance scaling issue**

Maintenance entries are append-only, no cap/pruning was found, and the full log is serialized in every vehicle's initial stream as a `UInt16` count plus serialized snapshots.

Each entry stores system/breakdown/effect/indicator state in addition to service metadata.

Short saves are fine; very long fleet saves can grow save size, join bandwidth and deserialize cost without bound.

## RMS-06 100 ms fast path discards missed elapsed intervals
**CONFIRMED_STATIC cadence behavior / DESIGN_RISK**

`onUpdateTimer` uses modulo when it crosses 100 ms, then runs exactly one step with fixed `updateDt=100`. A 400 ms delayed frame does not run four fast steps and does not pass 400 ms into timers/effects.

This bounds work but causes active-effect timers/control accumulators to under-advance across hitches.

Patch research: classify consumers; use elapsed/clamped dt for timers while keeping expensive control sampling bounded.

## RMS-07 50/200/500 ms state snapshots also discard missed intervals
**CONFIRMED_STATIC cadence behavior / DESIGN_RISK**

All three snapshot timers use modulo and run once after an overrun with the nominal delay value.

Some snapshot functions are pure observations; others maintain windows/derived accumulators. Those need a focused cadence audit so a hitch does not silently lose physical history.

## RMS-08 Core scheduler can produce an unbounded catch-up burst
**CONFIRMED_STATIC performance architecture**

The 250 ms fleet scheduler preserves accumulated timing debt and computes however many vehicle slots are due. No per-frame upper bound is applied.

This preserves core simulated time but a severe frame/server hitch can cause multiple full fleet rotations on the recovery frame.

Potential patch: bounded updates-per-frame while carrying residual debt.

## RMS-09 Every server frame scans the entire RMS fleet to call raiseActive
**CONFIRMED_STATIC performance architecture**

Before the distributed scheduler, RMS iterates every registered vehicle every frame and calls `raiseActive()` for inactive vehicles whose motor is ON.

This appears to keep unattended running machines alive for fast/thermal paths. It scales with fleet size × server frame rate.

Do not optimize blindly; profile first. Candidate redesign: track running inactive vehicles through motor-state transitions.

## RMS-10 MTBF helper is only linearly timestep-adjusted
**CONFIRMED_STATIC numerical inconsistency**

The primary breakdown probability correctly uses:
`1 - exp(-dt / MTBF)`.

`RMS_Utils.getChancePerFrameFromMeanTime()` instead returns:
`dt / meanTimeMs`.

Several transient breakdown effects use the helper. For normal small `dt` the approximation is close, but it is less timestep-invariant and increasingly inaccurate for large dt relative to mean time.

Low-risk upstream patch: use the exact exponential form consistently.

## RMS-11 Engine/transmission thermal are split-rate, not double-updated
**POSITIVE_PATTERN / prior hypothesis closed**

Source disproves the interrupted-audit concern that thermal systems are accidentally integrated twice.

`onUpdate` requests transmission only; `rmsUpdate` requests engine only.

Future audit should evaluate whether the chosen different cadences are appropriate, not whether duplicate integration exists.

## RMS-12 Workshop service transaction has rollback semantics
**POSITIVE_PATTERN**

Fluid stock allocation, service initialization, requirement verification, exact consumption and money debit are ordered as one server transaction with restoration on failure.

This is a useful reference for future RE persistent-resource systems.

## RMS-13 RMS intentionally destroys vanilla damage as an interoperability signal
**CONFIRMED_STATIC ownership decision / integration opportunity**

`updateDamageAmount` returns zero for managed RMS vehicles and the 100 ms path also resets nonzero vanilla damage to zero.

That is coherent because RMS replaces vanilla mechanical damage/sell-price semantics, but other mods cannot use vanilla damage as a proxy for RMS health.

Integration direction: expose/consume normalized RMS mechanical state through RC instead of reconstructing health from vanilla `Wearable`.

## RMS-14 Release ZIP omits the referenced license/provenance files
**CONFIRMED_STATIC packaging issue**

Lua headers say GPL v3-or-later and `See LICENSE`, but the audited ZIP contains neither `LICENSE` nor `NOTICE`. The official repository contains both.

Upstream packaging cleanup candidate.

## RMS-15 Global/UI hook surface is broad but mostly composable
**DESIGN_RISK / RUNTIME_PENDING**

Pass 1 found global hooks around mission lifecycle, workshop UI, statistics UI, shop attributes and `BuyVehicleData` streams, plus per-vehicle overwritten specialization methods such as motor start, speed limit and vehicle physics.

Most use GIANTS `Utils.*Function`/`superFunc` patterns. Existing runtime logs showed shared hook targets without unknown-hook/veto failures in that session.

Do not patch hook presence alone. Investigate only concrete pointer drift, bypass or ordering failures.

## RMS-16 Primary persistent randomness is server-owned
**POSITIVE_PATTERN**

Used-vehicle initialization, service outcomes and persistent breakdown choices are performed on server-owned paths and then synchronized.

This avoids peer-local random divergence for the core mechanical model.

## RMS-17 State synchronization is domain-separated and thresholded
**POSITIVE_PATTERN**

Eleven dirty groups plus per-domain epsilon/change detection prevent the large RMS state model from becoming one monolithic every-frame stream.

Possible refinement is lifecycle cleanup of the per-connection masks, not replacement of the architecture.

## RMS-18 Differential-lock automatic release clears the retained request
**CONFIRMED_STATIC**

The drivetrain deliberately stores `diffLockRequested` separately from `diffLockEngaged`, and the settings tooltip states that locks should disengage above the speed threshold and re-engage below it while still requested.

When speed exceeds the release threshold, however, `updateDiffLockState()` calls `setDrivetrainState(..., false, ...)`, clearing the requested flag itself.

The lock therefore cannot automatically re-engage on deceleration without another player request.

Upstream patch: preserve `diffLockRequested=true`; only drop the effective engaged state while over speed.

## RMS-19 Enhanced Vehicle settings cache can survive a backwards mission clock
**STRONG_CANDIDATE lifecycle defect**

The module-global Enhanced Vehicle cache stores a `nextReadTime` based on `g_time` and is not reset by RMS map lifecycle code.

If a second mission in the same process starts with a lower clock, the previous mission's deadline can remain far in the future and suppress the intended ten-second settings reread.

Patch: reset the cache at map load/delete or explicitly detect backwards time.

## RMS-20 Native differential-lock path may preserve an open axle speed ratio
**DESIGN_RISK / RUNTIME_PENDING**

When the full center graph is installed RMS classifies the lock as `nativeLock`. In that case wheel-to-wheel axle differentials retain their original `maxSpeedRatio` instead of using the configured locked ratio.

If a vehicle's original axle ratio is materially permissive, the resulting lock may be softer than the UI/tutorial description that the inside and outside wheels are forced toward the same speed.

Do not patch until a controlled vehicle with an open original ratio proves the behavior.

## RMS-21 Locked wind-up ignores the sampled surface-compliance factor
**DESIGN_RISK / RUNTIME_PENDING**

Ordinary 4WD wind-up consumes `avgGroundSurfaceFactor`, allowing soft terrain to release driveline strain.

When the differential lock is engaged RMS forces `surfaceFactor=1`. Tire friction still gates wind-up, but the direct surface-compliance input is ignored.

This may overstate locked wind-up on deformable soil. Validate asphalt/gravel/dry field/wet field before changing the model.

## RMS-22 Reifen FORCE-WEAR differential shares become stale after RMS topology changes
**CONFIRMED_STATIC cross-mod mismatch**

Exact-source cross-read closes Reifen finding R-29/R-28 as a real topology mismatch.

Reifen 1.2.2.67:
- traverses `spec_motorized.differentials`;
- computes wheel torque shares;
- stores them in a per-vehicle `rvDifferentialWheelShareCache`;
- reuses those cached shares for FORCE-WEAR.

RMS later removes/rebuilds the live GIANTS differential graph when switching 2WD/4WD/AUTO.

Therefore the cached Reifen shares no longer necessarily represent the effective graph. A disconnected axle can stop being reported as live-driven while the remaining active axle still carries only its old full-graph share, under-allocating FORCE-WEAR; crawler/reference paths can be affected more directly.

Existing RC `MRRMS` fixes the analogous MoreRealistic metadata problem, not Reifen's cache.

Preferred fix: Reifen invalidates/recomputes on topology change or topology signature. Cleaner future contract: RMS exposes effective driven-wheel/topology state.

## RMS-23 Restoring the captured differential graph can overwrite a later owner
**DESIGN_RISK**

RMS captures its original differential graph when it builds the layout and later uses that snapshot to restore drivetrain ownership.

If another mod intentionally changes the graph after that capture, an RMS restore can reinstate the older snapshot.

No failure is demonstrated in the target stack. This is an ownership-contract reason to prefer a public topology/provider boundary over independent graph writers.

## RMS-24 SpeedMeterDisplay draw override is not exception-safe
**CONFIRMED_STATIC robustness defect**

RMS directly assigns `SpeedMeterDisplay.draw`.

For selected-tool display it temporarily replaces `getDamageAmount` on child vehicles and hides the native speed background, calls the previously captured draw function, then restores those mutations.

There is no protected/finally-style restoration. If the delegated draw errors, temporary methods and visibility state can remain modified after the exception.

Patch candidate:
- use a protected call with guaranteed restoration;
- where practical, prefer a composable GIANTS wrapper installation.

## RMS-25 Leasing hooks stack when Mission00.load is invoked again in the same Lua process
**CONFIRMED_STATIC conditional lifecycle defect**

`RMS_Leasing.init()` prepends `RMS_Leasing.preLoad` to `Mission00.load`.

Every execution of `preLoad` then wraps the current:
- `SellVehicleEvent.run`;
- `ShopController.sell`.

There is no installed-function guard and no teardown. A second mission load in the same process therefore wraps the already wrapped RMS functions again.

Runtime consequence can be duplicated/nested leasing UI or return-charge logic depending on call path.

Patch: install these global wrappers once, or store/check the installed wrapper identity.

## RMS-26 Deleted external-power partner can remain referenced
**CONFIRMED_STATIC lifecycle cleanup gap**

Jumper cables store reciprocal `spec.externalPowerConnection` vehicle references.

The normal explicit disconnect path clears both sides, but RMS vehicle `onDelete()` does not call `clearExternalPowerConnection()`.

If one connected vehicle is deleted without the cable workflow explicitly disconnecting first, the survivor can retain the deleted vehicle object. `updateBatteryChargingModel()` stops treating a non-existing entity as an active pair, but it does not clear the stale relation in that invalid-partner branch.

Patch: clear the reciprocal external-power relation during vehicle deletion and when an invalid/deleted partner is observed.

## RMS-27 Used-vehicle condition randomization is server-owned
**POSITIVE_PATTERN**

Used-vehicle system-condition variance and initial breakdown presence are rolled only from the server registration path, then synchronized.

This preserves the desirable variation without peer-local divergence.

## RMS-28 Breakdown registry is capability-complete at source level
**POSITIVE_PATTERN**

The exact registry contains 45 breakdown definitions, 35 of them selectable. Source cross-check confirms every selectable breakdown has both repair-price and progression-multiplier metadata.

Applicability functions separate transmission types, electrical/fuel/PTO/hydraulic/chassis capabilities rather than relying on vehicle filename allowlists.

## RMS-29 Physical fluid transfer has continuous authority validation and conservation rollback
**POSITIVE_PATTERN**

Manual transfer validates requester identity/farm ownership, player/container/vehicle distance, stationary/motor-off state, circuit capacity and source product compatibility.

The transfer is revalidated continuously while active. The source fluid is removed transactionally; any liters the target cannot accept are restored.

This is a strong reference implementation for interactive persistent-resource movement.

## RMS-30 Weather state is initialized lazily
**CONFIRMED_STATIC low-severity initialization/lifecycle issue**

`RMS_Main.currentWeather` is initialized once to SUN and updated only inside the 30-second per-vehicle meta path. Individual vehicle meta timers are randomized across that window.

On a fresh rainy/snowy mission, and especially after loading a second mission in the same process, electrical weather-exposure wear can temporarily use the previous/default weather until the first meta refresh occurs.

Patch: initialize current weather explicitly in `loadMap()`; reset it in `deleteMap()`.

## RMS-31 CVT-addon transmission branch contains dead locals
**CONFIRMED_STATIC cleanup only**

`prevStress` and `normalizedCVTdamage` are calculated in the CVT-addon wear path but never consumed.

No behavioral defect follows from this alone; remove or use them to reduce misleading audit/debug surface.

## RMS-32 AI cruise protection is server-side and time-normalized
**POSITIVE_PATTERN**

RMS's AI worker controller builds a stress signal from dynamic load plus engine/transmission temperature, filters it with dt-normalized dynamics, uses PID-like reduction/recovery rates and respects lowered-implement speed limits.

It also has emergency temperature reduction and Precision Farming soil-sampling exceptions.

Cross-mod behavior with Courseplay/AutoDrive still needs runtime smoke, but the control model itself is substantially more deliberate than a fixed arbitrary speed cap.


# RMS 0.11.0.0 delta findings

Exact package:
- version `0.11.0.0`;
- SHA-256 `75f092abcec813cc8d56af6b7e84a21ca204d39e6825d34054ba4e376d6932cd`.

RMS-01 through RMS-32 remain the historical 0.10 baseline. The following
findings record the 0.11 delta without rewriting that baseline.

## RMS-33 RC-critical drivetrain/effect contracts are source-stable
**POSITIVE_PATTERN / CONFIRMED_STATIC**

The MRRMS-relevant drivetrain functions are text-identical between 0.10 and
0.11:
- `buildLayout`;
- `initSpec`;
- `applyState`;
- `setDrivetrainState`.

The six MRRMS effect-applicator blocks consumed by RC are also text-identical.

This justifies integration-specific SOURCE_COMPATIBLE evidence for MRRMS 0.11,
not global verification of the entire RMS release.

## RMS-34 Private module rename breaks name-based integrations
**CONFIRMED_STATIC / RC FIX**

0.11 renames:
- `RMS_Consumptables` -> `RMS_Consumables`.

MudRMS previously required the old private table name as a runtime gate even
though the bridge actually hooks the registered vehicle functions.

That would reject 0.11.

RC now validates the real semantic boundary:
- RMS specialization present;
- registered `updateRadiatorClogging`;
- registered `updateAirFilterClogging`.

Lesson:
> bind to the smallest semantic contract actually consumed, not an upstream
> source-file/table name merely because it was convenient to probe.

## RMS-35 MudRMS remains semantically necessary
**CONFIRMED_STATIC**

0.11's radiator and air-filter models still call global:

`weather:getGroundWetness()`.

They do not consume Mud `FieldLocalWetness`.

Therefore RC still has a genuine cross-owner role:
- Mud owns local physical wetness;
- RMS owns clogging consequence;
- RC scopes the local wetness into the exact RMS calculation.

## RMS-36 Clogging calibration is decoupled from maintenance wear
**POSITIVE_PATTERN**

0.10 tied clogging rate partly to `BASE_SERVICE_WEAR` and a dedicated RMS
clogging-speed setting.

0.11 uses the game's washable interval multiplier plus explicit physical
operating-hour calibration.

This is cleaner domain separation:
> maintenance/service cadence should not secretly set the accumulation rate of
> a different physical phenomenon.

## RMS-37 PTO capacity contract expands into engagement-shock sizing
**CONFIRMED_STATIC / CROSS-MOD IMPACT**

`RMS_Utils.getPtoNativeCapacityData(vehicle,totalTorque)` remains text-identical.

0.11 newly reuses it inside `getPtoEngagementDamage()` to scale high-RPM PTO
engagement shock by implement size.

RMSDynamicPTO already scopes this helper through the selected/effective PTO
ratio.

Therefore the existing bridge now correctly influences:
- continuous PTO capacity/utilization;
- engagement-shock size.

No new bridge is needed, but runtime validation must cover the new call site.

## RMS-38 PTO event damage and continuous wear are separated
**POSITIVE_PATTERN**

0.11 distinguishes:
- engagement clutch loss;
- high-RPM engagement shock;
- continuous overload;
- raised-implement operation;
- expired-service contribution.

Engagement shock samples engine RPM before the game's PTO-induced rev-up.

This is a strong modeling principle:
> transient event damage and continuous operating wear should remain separate
> channels.

## RMS-39 Battery charger feeds the authoritative electrical solver
**POSITIVE_PATTERN**

The new charger contributes charging/start-assist current through the existing
RMS battery integration.

It does not own a parallel battery SOC/temperature/health model.

The electrical owner still determines:
- acceptance;
- loads;
- net current;
- SOC;
- voltage.

This is a strong provider/consumer pattern for future RC/RE accessories.

## RMS-40 Battery charger request boundary is well defended
**POSITIVE_PATTERN**

Server request handling checks:
- requester context;
- farm ownership;
- spectator state;
- player proximity;
- player not inside a vehicle;
- charger/target/mode validity.

The charger also tears down through its authoritative stop path on delete.

This is stronger than several older RMS event surfaces.

## RMS-41 Mobile Workshop compatibility belongs upstream
**POSITIVE_PATTERN / NO_RC_ACTION**

0.11 contains explicit `FS25_mobileWorkshop` behavior and workshop-type
restrictions.

There is no reason for RC to add a second mobile-workshop integration.

This is a clean case of upstream owning its own service-domain compatibility.

## RMS-42 Settings simplification reduces accidental physics policy surface
**ARCHITECTURE_LEARNING**

0.11 removes many user-facing physical constants and multiplier knobs and
replaces them with internally coherent defaults/models.

The exact UX policy is subjective, but the architectural lesson is useful:
> expose meaningful policy/experience choices; keep calibration constants out
> of user settings unless they genuinely define user policy.

Development diagnostics/calibration controls should remain available separately.

## RMS-43 Existing diff-lock re-engage defect remains
**CONFIRMED_STATIC / CARRY-FORWARD RMS-18**

0.11 replaces the configurable release threshold with fixed
`DIFF_LOCK_RELEASE_KMH = 10`, but the release path still calls
`setDrivetrainState(..., false, ...)`.

That clears `diffLockRequested`.

Therefore the original requested-lock intent still cannot naturally re-engage
after speed drops.

No RC hotfix is added.

## RMS-44 No drivetrain topology revision/provider was added
**CONFIRMED_STATIC / CROSS-MOD**

0.11 still exposes no stable:
- topology revision;
- effective driven-wheel set;
- current torque-share provider.

Reifen 1.2.2.70 FORCE-WEAR still caches GIANTS differential shares.

The RMS↔Reifen mismatch remains open behind the existing runtime magnitude gate.

## RMS-45 New upstream direct integrations do not supersede RC bridges
**CONFIRMED_STATIC**

0.11 adds/improves direct compatibility in areas such as:
- Mobile Workshop;
- GIANTS ignition-key behavior;
- MoreRealistic-aware motor-load handling.

None covers the semantic boundaries of:
- MRRMS;
- MudRMS;
- RMSDynamicPTO.

Therefore no current RC bridge should be retired from source evidence alone.

## RMS-46 Several old authority/lifecycle defects remain byte-for-byte
**CONFIRMED_STATIC**

The source remains unchanged or materially equivalent for:
- fleet reinitialize authorization;
- start-button target/controller authorization;
- client-originating start-effect sync;
- SpeedMeter temporary method replacement without exception-safe restoration;
- mission-load leasing wrapper installation;
- vehicle onDelete external-power peer cleanup.

The 0.11 feature work does not make those findings obsolete.

## RMS-47 Release ZIP still omits repository license files
**CONFIRMED_STATIC / CARRY-FORWARD RMS-14**

The official repository is GPL-3.0-or-later, but the supplied official release
ZIP still contains no LICENSE/NOTICE file.

This is packaging provenance, not an RC compatibility blocker.

## RMS-48 0.11 upgrade intentionally changes persistent/economic semantics
**UPGRADE_RISK / DOCUMENTED_UPSTREAM**

The release changes:
- fluid container implementation;
- fluid capacities;
- maintenance intervals/schedules;
- overhaul outcomes;
- vehicle value/depreciation calculations;
- available settings.

Some old fillType-based RMS containers can disappear after upgrade.

Use a save backup and distinguish expected migration changes from RC regressions.
