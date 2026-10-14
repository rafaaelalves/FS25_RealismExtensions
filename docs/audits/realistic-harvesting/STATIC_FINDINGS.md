# Realistic Harvesting 1.6.2.0 static findings

Exact source:
- package SHA-256 `34419a1d37436b10cf4e45318bfaf697c13627ed15d2e65fb74f49f227de66dd`;
- official tag `V.1.6.2.0`;
- commit `02dad49c4d6f12bbcfb13a469df257fdd28ac372`.

Evidence labels:
- **CONFIRMED_STATIC**
- **POSITIVE_PATTERN**
- **DESIGN_RISK**
- **RUNTIME_PENDING**
- **UPSTREAM_DEFECT**
- **INTEGRATION_OPPORTUNITY**

## RH-01 The 1.6.2 update changes the physical calibration materially
**CONFIRMED_STATIC**

The 1.6.0 -> 1.6.2 delta retunes many crop-specific processing-energy values
and the generic custom-crop fallback.

Examples include grain corn, sunflower, canola, soybean, oats and many cereals.

Forage pickup/direct-cut behavior is also reworked.

Therefore a different harvesting speed/load after update is not automatically a
regression. It can be intentional 1.6.2 calibration.

## RH-02 Default target load changes from 88% to 80%
**CONFIRMED_STATIC / MIGRATION_NOTE**

1.6.0 combine defaults used 88%.

1.6.2 defaults use 80% in:
- combine schema;
- combine memory;
- profile fallbacks;
- network full-profile defaults;
- speed controller fallback.

Existing saved combine/profile values can override the new default.

Therefore two previously identical vehicles can behave differently after update
if one carries an old saved 88% target and another is reset/new at 80%.

Runtime smoke should inspect the actual target load before comparing speeds.

## RH-03 Harvest process demand remains separate from drivetrain ownership
**POSITIVE_PATTERN**

RHM estimates:
- base machine demand;
- header demand;
- process demand;
- chopper demand;
- soil cutting demand;
- forage feed/drum/blower demand.

It primarily converts those demands into harvesting-process utilization and a
working-speed ceiling.

It does not install a parallel torque/transmission solver.

MR and RMS remain appropriate owners of drivetrain/mechanical physics.

## RH-04 “Engine load” API semantics are process utilization, not canonical motor load
**CONFIRMED_STATIC / API SEMANTICS**

`RHM_Api.getEngineLoad*` describes the RHM harvesting process model.

It should not automatically be treated as:
- MR motor load;
- RMS mechanical motor stress;
- a generic physical engine load provider.

Future consumers must preserve the semantic name/meaning.

## RH-05 Normal speed limiting composes conservatively
**POSITIVE_PATTERN**

The `getSpeedLimit()` path calls the existing/super chain and applies the
lower result.

This preserves stricter upstream/other-owner working-speed ceilings.

## RH-06 Direct motor speed-limit enforcement is less composable
**DESIGN_RISK / RUNTIME_PENDING**

For active player/AI harvesting, RHM can also call:

`motor:setSpeedLimit(currentLimit)`

to catch controllers that bypass the normal query.

When RHM releases that direct limit it writes:

`motor:setSpeedLimit(math.huge)`.

If another system independently owns the same motor-level limit, RHM can
potentially erase that owner's value.

Do not create an RC patch without an observed conflict.

Runtime check:
manual harvesting, Courseplay and any controller that writes motor speed limits.

## RH-07 Throughput smoothing is improved as a named inertia model
**POSITIVE_PATTERN**

The old fixed smoothing coefficient becomes a first-order rotor/flywheel
inertia filter with a ~1.3 s time constant.

This is clearer and timestep-aware.

RHM also uses asymmetric load smoothing for load rise vs unload.

Principle:
> model named physical inertia with time constants rather than frame-dependent
> magic averaging coefficients.

## RH-08 Straw chopper becomes an explicit process-demand channel
**CONFIRMED_STATIC**

When grain combine straw is being chopped rather than swathed, RHM adds
crop-dependent chopper demand.

Chopper demand participates in the speed equilibrium.

It remains process demand, not a new PTO/motor torque solver.

## RH-09 Forage processing is decomposed by stage
**POSITIVE_PATTERN**

1.6.2 exposes approximate:
- feed roll demand;
- cutterhead/drum demand;
- blower/accelerator demand.

The public API exposes this breakdown.

This is a useful future integration surface for discrete failures/blockages
without needing to inspect RHM private fields.

## RH-10 Pickup choking becomes a distinct flow bottleneck
**CONFIRMED_STATIC**

For forage windrow pickup, excessive fresh-mass flow can increase feed-stage
demand sharply.

This is a stronger domain model than treating every forage load as only total
engine power.

It may become useful for a future external blockage provider.

## RH-11 Live weeds add physical harvesting resistance
**CONFIRMED_STATIC**

RHM samples live weed density ahead of the cutter and adds:
- up to about 15% header resistance;
- up to about 25% process drag.

Dead/herbicide-replaced weed states are deliberately excluded.

## RH-12 Weed sampling is bounded but adds a new density-map hot path
**RUNTIME_PENDING PERFORMANCE**

During relevant harvesting RHM samples roughly 3–9 points across cutter width.

Map/channel metadata is cached.

This is bounded, but wide-header harvesting should be included in a performance
smoke because it is a new active density-map query path.

## RH-13 Slope loss is smoothed before consequence
**POSITIVE_PATTERN**

Lateral/up-vector angle is low-pass filtered with an approximately 1.8 s time
constant before slope loss is applied.

Short suspension bumps therefore do not instantly become cleaning-shoe loss.

## RH-14 Physical loss deliberately excludes GIANTS wear loss from the extra actuator
**POSITIVE_PATTERN**

RHM reports equipment-wear loss based on GIANTS damage state, but subtracts:

`physicalLossPct = totalCropLoss - wearLossPct`

from the fill unit.

The stated purpose is to avoid applying wear loss twice because native vehicle
damage/yield logic already applies a consequence.

This is good anti-double-counting ownership.

## RH-15 Slope and moisture losses are physically subtracted despite a stale comment
**CONFIRMED_STATIC**

The source comment says it subtracts “only speed overload and settings loss”.

The actual code subtracts every total-loss component except wear.

Therefore 1.6.2 physically deducts:
- overload/separator loss;
- settings loss;
- slope loss;
- moisture/dew/rain loss.

The behavior is coherent with the feature set; the comment is stale.

## RH-16 Forage and cotton are explicitly excluded from grain-loss logic
**CONFIRMED_STATIC**

Forage harvesters and cotton harvesters bypass the grain-loss sum.

This avoids applying grain-separator semantics to whole-biomass/cotton flows.

## RH-17 Moisture provider boundary is more flexible but still semantically ambiguous
**DESIGN_RISK**

Resolution order:
1. external object/fillType moisture;
2. external positional moisture;
3. built-in diurnal/rain fallback.

The object/fillType path is the strongest semantic source.

The positional path can represent soil/environment moisture rather than
standing-crop moisture; RHM then transforms it using time of day.

A future provider contract should distinguish:
- crop moisture;
- soil moisture;
- ambient humidity/dew;
- precipitation.

## RH-18 Built-in diurnal moisture fallback makes RHM a fallback moisture model
**CONFIRMED_STATIC**

Without an external provider, 1.6.2 no longer means “moisture unavailable”.

It synthesizes a standing-crop moisture estimate based on time and rain.

In the target stack, Moisture System remains the preferred owner/provider.

Do not bridge Mud soil/wheel wetness into RHM merely because the names are
similar.

## RH-19 Moisture can affect both process demand and physical loss
**CONFIRMED_STATIC**

When enabled:
- moisture above crop limit increases processing difficulty;
- high moisture/dew/rain can also add crop loss.

These are different physical consequences and are intentionally separate.

Runtime calibration should ensure the combined penalty is not excessive for the
user's Moisture System values.

## RH-20 Public API is substantially better in 1.6.2
**POSITIVE_PATTERN**

The public API now:
- returns nil for unmanaged targets in many places instead of ambiguous zeros;
- recognizes more harvester classes/hierarchies;
- exposes power breakdown including chopper;
- exposes forage stages;
- exposes pickup/chopper state;
- exposes fresh-matter throughput;
- exposes harvest tracker/history context;
- supports callback listeners.

Classification:
**GOOD_AND_ADOPT_PRINCIPLE**

Prefer this API for any future integration.

## RH-21 Public API remains read-oriented, not an external process-flow injection point
**CONFIRMED_STATIC / INTEGRATION_OPPORTUNITY**

The API can expose RHM process state, but it does not provide a stable function
such as:
- addExternalFeedFlow;
- setExternalHarvestStress;
- registerMaterialFlowProvider.

Therefore the known FarmKit Straw Refeed integration remains unbridged.

Do not modify RHM private mass accumulators from RC.

## RH-22 AI/Courseplay detection is broad and server-side tuning is explicit
**POSITIVE_PATTERN**

RHM recognizes GIANTS AI plus Courseplay/root/attacher arrangements and can
auto-tune combine settings based on electronics tier.

1.6.2 adds a farm-configurable AI speed limiter based on controllable loss.

Courseplay remains a required runtime smoke because the direct motor-limit
fallback is controller-facing.

## RH-23 New harvest tracker is server-authoritative
**POSITIVE_PATTERN**

Trip/fleet/field/year state is accumulated on the server.

Initial join and periodic updates use dedicated network events.

Delta updates are throttled/dirty-driven rather than transmitting every
simulation tick.

## RH-24 Season history and field heatmap memory are bounded
**POSITIVE_PATTERN**

- season history is capped to the latest 50 entries;
- each field heatmap is capped at roughly 800 ring-buffer points.

This avoids obvious unbounded growth in the two largest new presentation data
structures.

## RH-25 Yearly statistics are naturally unbounded by career years
**DESIGN_NOTE**

`yearlyStats` persists a record per in-game year and is not pruned.

Growth is slow and likely harmless for ordinary careers, but it is conceptually
unbounded.

No project action is justified.

## RH-26 Harvest History double-counts loss in its efficiency denominator
**UPSTREAM_DEFECT / TELEMETRY ONLY**

The combine passes `liters` captured before RHM's negative fill-unit loss
subtraction into `onCombineHarvestTick()`.

Tracker then stores:

`harvestedLiters += liters`

and separately:

`lostLiters += liters * physicalLossPct`.

Efficiency later uses:

`totalBio = harvestedLiters + lostLiters`.

Because `harvestedLiters` already represents the gross pre-RHM-loss amount,
adding lost liters again makes the denominator too large and slightly
understates the displayed loss percentage.

This does not change physical tank content.

## RH-27 Loss-reason attribution can assign physical-loss liters to wear
**UPSTREAM_DEFECT / TELEMETRY ONLY**

Physical loss explicitly excludes wear:

`physicalLossPct = totalLossPct - wearLossPct`.

But tracker partitions those `lostLiters` across:

- speed;
- moisture;
- wear;
- slope;

using a denominator that still includes `wearPct`.

Therefore some physically deducted RHM loss can be labeled as “wear” in history
analytics even though wear was intentionally not physically deducted by RHM.

Fix belongs upstream.

## RH-28 Crop-loss setting default mismatch is old, not introduced by 1.6.2
**CARRY-FORWARD CONFIG QUIRK**

`RHMSettings.new()` initializes `enableCropLoss=true`.

But `RHMSettingsManager.defaultConfig.enableCropLoss=false`.

This existed in 1.6.0 as well.

On a truly fresh settings file, manager defaults can therefore make physical
crop loss disabled unless the user enables it.

Do not misattribute this behavior to the 1.6.2 update.

## RH-29 Existing calibration can preserve the old 88% target after update
**MIGRATION_NOTE**

1.6.2's new default is 80%, but saved profiles/combine memory can override it.

The upgrade does not imply every existing calibrated combine immediately moves
to 80%.

Before comparing 1.6.0 and 1.6.2 harvesting speeds, inspect/reset the target
load deliberately.

## RH-30 Global settings event lacks server-side admin verification
**UPSTREAM MP AUTHORITY GAP**

`RHM_SettingsSyncEvent` describes incoming requests as admin requests, but its
server path does not actually verify the connection is master/admin before
applying, saving and rebroadcasting global RHM settings.

It also does not semantically clamp all UInt8 mode values.

Trusted local/co-op is not meaningfully blocked.

Untrusted/dedicated server deserves caution.

## RH-31 Per-combine settings event lacks requester ownership/control verification
**UPSTREAM MP AUTHORITY GAP**

`RHM_CombineSettingsEvent` validates target vehicle existence and RHM state,
but does not strongly verify:
- requester controls the combine;
- requester belongs to the owning farm;
- requester has management rights.

Do not hide this in RC.

## RH-32 New farm/reset permission helper fails open when user resolution is nil
**UPSTREAM MP AUTHORITY GAP**

The newer farm settings/reset surfaces route through farm management rights.

However the common helper returns true if the resolved user is nil.

That weakens the intended authority boundary in unusual/disconnected cases.

## RH-33 Dedicated-server behavior has a fresh upstream report
**CURRENT_UPSTREAM_SIGNAL / RUNTIME_PENDING**

Upstream issue #67, opened 2026-10-08, reports that after the recent update a
dedicated server does not show combine/header load and forage speed/output
telemetry.

Root cause is not established.

Do not infer an RC conflict without reproduction.

This is enough to keep dedicated-server validation separate from the
single-player update recommendation.

## RH-34 Global update/draw re-entry guards are not exception-safe
**LIFECYCLE DESIGN_RISK**

RHM's mission update/draw wrappers set a boolean guard before calling manager
logic and clear it afterward.

There is no protected-finally restoration.

If manager update/draw throws, that guard may remain set and suppress later
calls for the Lua environment.

No current failure is observed; monitor rather than patch in RC.

## RH-35 UI compatibility hook initialization is one-shot
**LOAD_ORDER DESIGN_RISK**

`RHM_ModCompatibility.init()` marks itself initialized after attempting
optional UI hooks.

If an optional class genuinely loads later, normal repeated `init()` calls can
return early.

The calibration-open path calls the specific hook functions again, which
mitigates part of this, but the architecture is not a full capability
registration/lifecycle system.

## RH-36 RC detection remains intentionally version-agnostic
**PROJECT_DECISION**

RC detects `FS25_RealisticHarvesting`, but no RC integration calls RHM private
functions or assumes a version-specific API shape.

Therefore adding a 1.6.2 version whitelist to RC would create false precision.

No RC code change is needed for the update itself.

## RH-37 FarmKit Straw Refeed remains explicitly unbridged
**CONFIRMED_STATIC**

1.6.2 adds better chopper/pickup/process telemetry but does not expose an
external feed-flow injection contract.

Current RC status `strawRefeed=UNBRIDGED` remains correct.

A future bridge should use a stable provider API rather than editing RHM private
throughput state.

## RH-38 MRSoilHarvest ownership remains independent and compatible
**CONFIRMED_STATIC**

RHM's area/fill hooks call the existing super chain and observe resulting
harvest flow.

RC MRSoilHarvest continues to compose:
- SoilCompaction agronomic yield consequence;
- MR throughput accounting.

RHM then applies its own harvest-process/operator/environment loss.

No RHM-specific MRSoilHarvest patch is justified.

## RH-39 RHM does not become an RMS mechanical-wear owner
**CONFIRMED_STATIC**

RHM reads GIANTS vehicle/header damage for harvest-quality loss.

It does not replace RMS mechanical condition/wear.

A future RHM↔RMS mapping would only be justified if RMS exposes a stable
component-condition provider and runtime evidence shows GIANTS damage no longer
represents the intended mechanical state.

## RH-40 Root-harvester soil demand remains a simple width-based approximation
**MODEL LIMITATION / FUTURE OPPORTUNITY**

Root crop subsurface demand is approximately fixed HP per working-width meter.

It does not consume:
- Mud physical soil wetness;
- SoilCompaction state;
- local terramechanics resistance.

This is a potential future semantic composition question, but adding those
inputs blindly risks double-counting traction/soil resistance.

Do not bridge without controlled evidence.

## RH-41 Package omits repository GPL license file
**PROVENANCE/PACKAGING**

Official repository declares GPL-3.0.

The supplied runtime ZIP contains no LICENSE/NOTICE.

This is upstream packaging debt, not a stack compatibility blocker.

## RH-42 1.6.2 is an external specialist worth retaining
**PROJECT_DECISION**

RHM has:
- a maintained crop database;
- large UI/analytics surface;
- dedicated harvesting domain knowledge;
- public API;
- active upstream maintenance.

There is no current architectural value in absorbing this capability into RE.

Classification:
**KEEP + INTEGRATE**.
