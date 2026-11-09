# Realistic Harvesting 1.6.2.0 update from 1.6.0.0

Date: 2026-10-08

## Decision

For the current single-player/trusted-local stack:

**YES — update from 1.6.0.0 to 1.6.2.0.**

Conditions:
- back up the save;
- inspect the actual target-engine-load value after update;
- perform one normal harvest;
- save/reload once;
- keep dedicated-server validation separate.

No RC/RE functional code change is required before installation.

## Why this is a real behavior update

The official tag comparison is 22 commits.

The changes alter the physical calibration and controller, not only UI/history.

### Processing-energy recalibration

Many crop-specific energy coefficients were lowered/rebalanced.

Examples from the source delta:
- grain corn: 4.4 -> 3.8 HP/(t/h);
- sunflower: 19.0 -> 14.5;
- canola: 11.0 -> 9.2;
- soybean: 11.5 -> 8.8;
- oats: 12.5 -> 9.5;
- several cereals/legumes receive similar changes.

Forage flow is split more explicitly between:
- dry windrow pickup;
- wilted/fresh pickup;
- direct-cut standing crop;
- corn silage/other forage.

Therefore the same machine/crop can have a different equilibrium speed even
with identical settings.

## Target load changes from 88% to 80%

Fresh/new defaults are now 80%.

This deliberately makes the speed controller target more reserve capacity.

Important migration nuance:
saved combine/profile values can preserve 88%.

Do not compare the versions without first checking the target load shown by RHM.

## Power model expansion

1.6.0 effective conceptual model:

```
P_total =
  P_base
+ P_header
+ P_process
+ P_soil
```

1.6.2 expands this with explicit chopper/forage context:

```
P_total =
  P_base
+ P_header
+ P_process
+ P_chopper
+ P_soil
```

For forage machines, process demand also exposes:
- feed-roll share;
- cutterhead/drum share;
- blower/accelerator share.

These are diagnostic/process stages; RHM still avoids becoming a second
drivetrain torque solver.

## Mechanical inertia / controller changes

Mass-flow smoothing becomes an explicit ~1.3 s rotor/flywheel response.

Engine/process utilization smoothing becomes asymmetric:
- faster response into rising load;
- slower easing as stored rotating energy dissipates.

Speed control:
- default target 80%;
- chopper demand enters speed equilibrium;
- forage can reach a 2.5 km/h minimum instead of generic 3.5;
- general surge detector is less trigger-happy;
- pickup has its own more sensitive surge rule;
- AI can additionally reduce speed when controllable crop-loss exceeds the farm
  threshold.

Overall expectation:
less twitchy controller, more explicit reserve, more context-sensitive load.

## Straw chopper

When RHM determines the chopper is available and swath mode is off:
- chopping consumes extra process power;
- crop type changes the chopper coefficient;
- idle rotor drag exists while spinning without crop.

This is an appropriate process-demand feature.

It does not solve FarmKit Straw Refeed material-flow integration.

## Weed canopy

1.6.2 samples live weed density just ahead of the cutter.

The ratio can increase:
- header resistance;
- threshing/process resistance.

This is a new physical input and should be included in a normal wide-header
runtime smoke.

## Moisture changes

### External provider remains preferred

RHM still detects `g_currentMission.MoistureSystem`.

It first attempts object/fill-specific moisture.

### Fallback is no longer zero

If provider-specific crop moisture is unavailable, RHM can use:
- positional environmental moisture;
- then a built-in diurnal/rain crop-moisture approximation.

This means enabling RHM moisture in 1.6.2 can produce meaningful moisture
effects even without the separate Moisture System.

For the target stack:
**keep Moisture System as the preferred moisture owner/provider.**

Do not substitute Mud wheel/soil wetness.

## Loss model changes

### Overload loss

The overload curve is recalibrated:
- threshold remains around 80% process load;
- quadratic coefficient changes;
- >110% overload gets a steeper extra penalty.

### New slope loss

Above roughly 4 degrees of body tilt, cleaning-shoe loss can grow to a capped
maximum.

The measured angle is low-pass filtered to avoid suspension-bump spikes.

### New moisture/dew/rain loss

Above 14% moisture, RHM can add separator loss.
Rain adds an additional penalty.

### Wear anti-double-counting

RHM still reports wear-derived loss but excludes wear from its own extra
fill-unit subtraction because the native game damage path already changes
output.

This is the correct ownership direction.

### Stale comment

The code comment still says the physical subtraction is only speed/settings.

The actual code subtracts all RHM physical loss except wear, therefore slope and
moisture are real tank losses too.

## New Harvest History / tracker

The server now tracks:
- current trip;
- per-combine trip;
- fleet totals;
- field totals;
- year totals;
- season history;
- financial loss;
- cause attribution;
- efficiency rank;
- optional heatmap samples.

Positive:
- server authority;
- initial full sync;
- dirty/throttled delta sync;
- season history cap = 50;
- field heatmap cap = ~800 points per field.

### Tracker accounting defect

The new tracker receives RHM's pre-loss/gross `liters`, stores that as
`harvestedLiters`, then separately stores calculated `lostLiters`.

Later it computes:

```
lossPct =
lostLiters / (harvestedLiters + lostLiters)
```

But `harvestedLiters` already contains the gross quantity from which the
physical loss was removed.

Result:
displayed historical loss percentage is slightly understated.

This affects analytics, not actual fill-unit content.

### Cause-attribution defect

The physical loss passed to history excludes wear.

However, that physical lost volume is proportionally distributed across
speed/moisture/**wear**/slope using a denominator that includes wear.

Result:
history can label some physically deducted RHM liters as wear even though RHM
explicitly did not deduct wear.

Again: analytics defect, not physics.

Preferred action:
upstream issue/fix, not RC.

## Public API expansion

1.6.2's API is a stronger integration boundary.

Useful additions include:
- straw chopper state/power;
- forage stage power;
- pickup/forage state;
- fresh-matter throughput;
- richer combine discovery;
- tracker/history queries;
- callbacks for overload/crop/settings changes.

A major semantic improvement is returning `nil` for unmanaged targets in many
places instead of ambiguous zero/false defaults.

Use this API before considering any private hook.

## FarmKit Straw Refeed

Still unresolved.

The API exposes process state but no stable external material-flow injection
point.

Do not:
- write private RHM accumulators;
- fake extra `lastLiters`;
- double count material through the fill unit.

Current RC `strawRefeed=UNBRIDGED` remains correct.

## MR / RMS compatibility

RHM remains a harvesting-process model, not a replacement for MR/RMS.

No new direct torque/drivetrain owner was found.

The normal speed-limit query composes using the lowest limit.

Watch the direct `motor:setSpeedLimit` fallback during controllers/AI because
its release writes `math.huge`.

No RC patch is justified without actual lost-limit evidence.

## SoilCompaction

RHM still sees post-chain harvest output and applies its process/operator loss
later.

The existing MRSoilHarvest composition remains valid.

Root harvester soil-cutting demand remains width-based and does not consume
SoilCompaction/Mud local state.

This is a future research question, not an update blocker.

## Settings / persistence migration

### Existing global crop-loss default quirk

The settings object initializes crop loss enabled, while the manager's
file-missing default remains disabled.

This existed in 1.6.0; it is not a new regression.

### New persistent analytics

1.6.2 adds `realisticHarvestingData.xml`.

The old combine calibration state still lives through vehicle/profile save
paths.

Because the project previously observed an older RHM save-path error and 1.6.2
changes persistence substantially, one save/reload is mandatory for promotion
in the user's save.

## Multiplayer

New statistics are correctly server-owned.

However:
- global settings sync does not verify admin/master on receipt;
- per-combine settings sync does not validate requester control/farm rights;
- newer farm-rights helper fails open when user lookup returns nil.

For trusted co-op this is primarily hardening debt.

For an untrusted dedicated server it is a real authority concern.

Additionally, upstream issue #67 currently reports missing telemetry on a
dedicated server after the current release.

## Update verdict

### Physics / stack architecture
**PASS STATIC**

### Existing RC ownership
**UNCHANGED**

### Required RC patch
**NONE**

### Required RE patch
**NONE**

### User can update
**YES, single-player/trusted stack**

### Mandatory first-session evidence
- normal combine harvest;
- moisture sanity;
- optional Courseplay pass;
- Harvest History opens/populates;
- save;
- reload;
- no RHM errors.

### Dedicated server
**DO NOT PROMOTE AS FULLY VALIDATED YET**
