# RMS 0.11.0.0 update audit

Date: 2026-10-07

## Exact package

- archive: `FS25_RealisticMechanicalSystems.zip`
- title: Realistic Mechanical Systems
- author: Squallqt
- modDesc version: `0.11.0.0`
- SHA-256: `75f092abcec813cc8d56af6b7e84a21ca204d39e6825d34054ba4e376d6932cd`
- declared multiplayer support: true
- package entries: 316
- Lua: 68 files / 58,657 lines
- XML: 60 files
- executable payload/path traversal: none found
- LICENSE/NOTICE inside supplied ZIP: not found
- official repository: `Squallqt/FS25_RealisticMechanicalSystems`
- official tag: `v0.11.0.0`
- official release published: 2026-10-04
- official release asset digest: exact match with supplied ZIP
- repository license: GPL-3.0-or-later
- official release is marked prerelease/alpha

Previous exact audit baseline:
- RMS `0.10.0.0`
- SHA-256 `6741f193f22a5f85f5543c73d7f566b6686ab90bf7b705fd66d6d3421cb0d021`

## Executive result

Recommendation remains:

**KEEP + INTEGRATE. DO NOT ABSORB RMS WHOLESALE.**

Upgrade recommendation at source level: **YES**, with the RC candidate
`research/rms-0.11-current-base` and runtime smoke before promoting the version
to VERIFIED.

The 0.11 release is large in workshop/electrical/maintenance/PTO/fluids/AI/UX,
but the three RC-owned compatibility boundaries remain valid:

| RC bridge | 0.11 decision |
| --- | --- |
| `MRRMS` | **KEEP / SOURCE_COMPATIBLE** |
| `MudRMS` | **KEEP / SOURCE_COMPATIBLE + one required hardening** |
| `RMSDynamicPTO` | **KEEP / SOURCE_COMPATIBLE** |

No existing bridge is superseded.

No new generic RMS patch/bridge is justified by the source audit.

## Solution-quality gate

### MRRMS
Classification: **GOOD_EXISTING_BOUNDARY / KEEP**

The exact 0.11 source preserves the contracts MRRMS actually composes.

Text-identical between tags 0.10.0.0 and 0.11.0.0:
- `RMS_Drivetrain.buildLayout`;
- `RMS_Drivetrain.initSpec`;
- `RMS_Drivetrain.applyState`;
- `RMS_Drivetrain.setDrivetrainState`.

The exact RMS breakdown applicators consumed by MRRMS are also unchanged:
- `GEAR_SHIFT_FAILURE_CHANCE`;
- `POWERSHIFT_ENGAGEMENT_LAG_AND_HARSH_EFFECT`;
- `TRANSMISSION_SLIP_EFFECT`;
- `CVT_SLIP_EFFECT`;
- `CVT_MAX_RATIO_MODIFIER`;
- `CVT_PRESSURE_DROP_CHANCE`.

RMS still contains only limited direct MoreRealistic awareness: its dynamic motor
load path trusts MR's motor-load percentage instead of adding its vanilla
driveline-vibration correction. It still does not preserve the RMS transmission
effects through MR's replacement gear paths or synchronize MR driven-wheel
metadata after RMS rebuilds the differential graph.

Therefore MRRMS remains a real compatibility bridge.

### MudRMS
Classification: **KEEP, BUT REMOVE PRIVATE-NAME DEPENDENCE**

0.11 renames the source module:
- 0.10: `RMS_Consumptables`;
- 0.11: `RMS_Consumables`.

The physical registered vehicle methods remain:
- `updateRadiatorClogging(dt, canAccumulate)`;
- `updateAirFilterClogging(dt)`.

Both still read GIANTS global:

`weather:getGroundWetness()`.

Therefore MudRMS still owns a meaningful bridge:
- Mud = local physical wetness owner;
- RMS = radiator/air-filter consequence owner;
- RC temporarily presents local wetness to the exact RMS consequence call.

The old RC runtime gate unnecessarily required the private
`RMS_Consumptables` table even though the bridge never hooked that table.

That would make RC reject RMS 0.11.

The current RC candidate removes this private-name dependency and validates the
actual public/registered vehicle-function contract instead.

This is preferable to supporting both typo/corrected table names forever.

### RMSDynamicPTO
Classification: **KEEP / CONTRACT EXPANDS CLEANLY**

`RMS_Utils.getPtoNativeCapacityData(vehicle,totalTorque)` is text-identical
between 0.10 and 0.11.

The existing bridge remains correct:
- Dynamic PTO owns selected/effective shaft gearing;
- RMS owns mechanical PTO wear/stress;
- RC scopes RMS capacity calculations through the effective PTO ratio;
- Dynamic PTO's feedback-only `gruntLoadExtra` is still prevented from becoming
  a second RMS stress input.

0.11 now additionally calls `getPtoNativeCapacityData()` from
`getPtoEngagementDamage()` to size the implement during PTO engagement shock.

This is a **valid extension** of the existing contract, not a new bridge:
RMS should see the effective selected PTO gearing when calculating reflected
implement size.

Runtime validation should explicitly cover this new call site.

## Important upstream improvements

### PTO wear is more physically decomposed
0.11 separates:
- continuous PTO utilization/overload;
- raised-implement operation;
- service expiry;
- clutch damage per engagement;
- high-RPM engagement shock scaled by implement size.

It samples engine RPM before PTO-induced rev-up for engagement shock.

This is a useful principle:
> event damage and continuous operating wear are different channels and should
> not be hidden inside one generic multiplier.

### Clogging is decoupled from maintenance scaling
0.10 derived radiator/air-filter accumulation partly from:
- washable dirt duration;
- `BASE_SERVICE_WEAR`;
- RMS clogging-speed setting.

0.11 instead uses the game's washable dirt-speed multiplier and explicit
operating-hour calibration.

This removes an artificial coupling between:
- how often a mechanical system needs service;
- how quickly field dust physically clogs a radiator/filter.

**GOOD_AND_ADOPT_PRINCIPLE**.

MudRMS remains useful because wetness provenance is still global GIANTS weather.

### Battery charger composes with the existing electrical owner
The new Telwin charger does not integrate a second battery state.

It asks the authoritative RMS battery solver for a current contribution through:

`RMS_BatteryCharger.getChargingCurrent(target, ctx)`.

The single RMS battery integration remains owner of:
- SOC;
- battery temperature/health acceptance;
- electrical loads;
- net current;
- voltage.

The charger also publishes state only when current/SOC/voltage materially
changes.

Classification:

**GOOD_AND_ADOPT_PRINCIPLE**

This is a strong reference for future RC/RE accessory design:
> accessories contribute bounded inputs/constraints to the owner solver rather
> than duplicating the state machine.

### Battery-charger request authority is strong
Server request handling validates:
- requester context;
- charger farm ownership;
- spectator rejection;
- player proximity;
- player not being inside a vehicle;
- target validity/mode/busy/full state.

The charger cleans its target relation on delete by calling its authoritative
stop path.

This is stronger than several older RMS client-request surfaces.

### Mobile Workshop compatibility is upstream
0.11 adds explicit `FS25_mobileWorkshop` support and workshop-type semantics.

RC must **not** add a mobile-workshop compatibility bridge merely because the
feature is new.

The upstream owner already covers this boundary.

### Settings were intentionally simplified
0.11 removes many user knobs for physical constants and replaces them with
internally coherent behavior, including several:
- wear/stress scaling knobs;
- clogging-speed tuning;
- drivetrain release-speed tuning;
- AI fine-tuning controls;
- smoke/plume controls;
- maintenance/pricing multipliers.

This is a useful design lesson when applied carefully:
> expose policy/experience choices, not every physical constant merely because
> the constant exists.

Do not copy the exact settings policy blindly; retain diagnostics/calibration
paths for development.

## Important old findings that remain

The update does **not** close the core architectural findings below:

- RMS-01: fleet reinitialize request still lacks explicit master/admin
  authorization in the event;
- RMS-02: client start-button state still lacks controller/farm authorization;
- RMS-03: the three client-originating engine-start effect sync paths still
  trust the target vehicle;
- RMS-04: `rmsPendingByConnection` still uses connection keys without visible
  disconnect cleanup;
- RMS-05: maintenance history remains unbounded and joins with the vehicle;
- RMS-06/RMS-07: skipped scheduler/snapshot intervals are still discarded;
- RMS-08/RMS-09: scheduler/fleet active-work concerns remain;
- RMS-10: MTBF probability remains the linear approximation `dt / meanTime`;
- RMS-18: speed release of diff lock still clears `diffLockRequested`, so the
  request cannot naturally re-engage below the threshold;
- RMS-19: Enhanced Vehicle config cache remains mission-clock sensitive;
- RMS-20/RMS-21: native lock ratio/wind-up concerns remain;
- RMS-22: Reifen FORCE-WEAR cache still has no RMS topology revision contract;
- RMS-23: captured differential graph restoration can still overwrite a later
  owner;
- RMS-24: SpeedMeter draw wrapper is still not exception-safe;
- RMS-25: leasing hooks are still installed from a `Mission00.load` prepended
  path and can stack in same-process mission reload scenarios;
- RMS-26: vehicle deletion still does not visibly sever the older
  vehicle-to-vehicle external-power peer relation;
- RMS-30: main weather state still defaults to SUN and is not eagerly resolved
  at mission start.

No RC hotfix is added solely because these owner-mod defects remain.

## Current Reifen cross-mod status

The exact current pair is now:
- RMS 0.11.0.0;
- Reifen 1.2.2.70.

RMS still dynamically rebuilds the GIANTS differential graph.
Reifen FORCE-WEAR still caches shares from `spec_motorized.differentials`.
RMS 0.11 adds no:
- topology revision;
- effective-driven-wheel provider;
- driven-share provider.

Therefore RMS-22 remains a confirmed cross-mod mismatch.

Decision remains:
**do not add a speculative bridge before runtime magnitude evidence**.

The existing Reifen T19/T20 test gate remains the correct next step.

## Upgrade/migration notes

The official 0.11 changelog contains intentional save/profile-visible changes:
- existing RMS fluid containers from the old fillType-based implementation can
  disappear after update;
- physical fluid capacities are rebalanced;
- maintenance intervals/schedules are reworked;
- several old settings no longer exist;
- overhaul outcomes and vehicle value calculations change.

Before adopting 0.11 on the main save:
- use a save backup;
- do not treat economic/service deltas as an RC regression until compared with
  the 0.11 migration behavior.

## RC implementation result

Candidate branch:
`research/rms-0.11-current-base`

Changes:
1. register RMS 0.11 as SOURCE_COMPATIBLE specifically for:
   - MRRMS;
   - MudRMS;
   - RMSDynamicPTO;
2. keep RMS 0.10 as VERIFIED;
3. update MRRMS source-contract documentation;
4. harden MudRMS to bind to registered vehicle functions rather than the renamed
   private module table;
5. run all three behavior harnesses using RMS 0.11 evidence.

No new RC module was added.

No old RC bridge was removed.

## Current evidence

Functional CI:
- workflow run `37567867453`;
- head `0ef4d167440d0eb7345b7b230f9fd63362fc0054`;
- result: **success**.

The full RC harness suite passed after the MudRMS private-name hardening.

## Static status

RMS 0.11 source audit: **complete enough for compatibility promotion**.

RC compatibility: **SOURCE_COMPATIBLE / CI GREEN**.

In-game/runtime: **pending**.

Do not promote RMS 0.11 to VERIFIED until the targeted runtime matrix passes.
