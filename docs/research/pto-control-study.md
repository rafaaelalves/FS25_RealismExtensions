# PTO control architecture

Date: 2026-10-05  
Branch: `feat/pto-control`

## Goal

Own PTO operator control inside RealismExtensions without inheriting the
architecture, names, UI assets or runtime polling model of any external PTO
mod.

The implementation is concept-driven:
- model real tractor PTO selection;
- preserve GIANTS/MR/RMS ownership boundaries;
- expose one stable state contract;
- avoid per-frame state discovery;
- use evidence-backed capability profiles rather than horsepower/name guesses;
- keep UI/visual presentation independent from physical state.

## Real-world behavior chosen

The supported operator model is manual:
- select 540 / 540E / 1000 / 1000E only when the tractor actually supports it;
- set hand throttle independently;
- show current PTO mode/requirement;
- reject gearbox-mode changes while PTO is engaged;
- warn on implement-family mismatch;
- never auto-select a PTO gear on behalf of the operator.

This matches the common real-tractor pattern: PTO speed selection is a cab
control (mechanical lever or electro-hydraulic selector), engagement is a
separate control, and panel indication reports PTO state.

No AUTO mode is implemented.

## Runtime ownership

### RealismExtensions

RE owns:
- selected PTO speed mode;
- hand-throttle request;
- tractor capability resolution;
- attached implement requirement resolution;
- persistence and multiplayer replication;
- generic HUD/dashboard-facing state;
- standalone GIANTS physical adaptation when no external drivetrain owner is
  active.

### RealismCompatibility

RC owns only composition with external specialist owners:
- MR sees selected gearing in its canonical 540-rpm PTO domain;
- RMS computes PTO capacity/utilization through the selected gearing;
- state is scoped to owner calculations and motor state is restored
  immediately.

### GIANTS

GIANTS remains the base power-consumer/motor implementation.

The standalone RE adapter does not write a new ratio every frame. It hooks the
two native queries that already need PTO information:
- `VehicleMotor.getPtoMotorRpmRatio`;
- `VehicleMotor.getRequiredMotorRpmRange`.

The selected ratio is scoped into the native RPM-range calculation because
GIANTS reads the raw `ptoMotorRpmRatio` field internally, then the original
field is restored immediately.

## Performance architecture

There is no PTO `onUpdate` or `onUpdateTick` controller.

State changes only on:
- vehicle load;
- save restore;
- implement attach;
- implement detach;
- operator input;
- network replication.

The public state object carries a monotonic `revision`.

RC caches by:
`vehicle + revision + canonicalPtoRpm`.

Therefore stable PTO state can be consumed by thousands of MR/RMS hot-path calls
without recalculating capability, attachment requirements or motor ownership.

The temporary assetless HUD also caches its rendered string by revision.

## Domain model

Modes:
1. 540
2. 540E
3. 1000
4. 1000E

Mode data contains:
- physical shaft RPM family;
- economy flag.

Capability data contains:
- supported modes;
- native GIANTS motor ratio;
- optional evidence-backed per-mode engine RPM/motor ratio;
- capability source/profile ID.

Unknown tractors are deliberately conservative:
- native 540 only;
- no inference of 1000/E modes from horsepower, price or display name.

## Evidence profiles

Initial evidence profiles are intentionally small.

### Fiat 180-90
- 540
- 1000

No economy PTO mode is assumed.

### HM 10-500 / HM10500 family
- requirement override: 1000 rpm

This profile exists because the game's ordinary power-consumer data can be
normalized/ambiguous in the MR stack; an evidence-backed requirement override
must beat that ambiguous value.

Profiles are additive. Unknown equipment continues through native fallback.

## Requirement resolution

Requirements are resolved recursively across attached implements only when the
attachment graph changes.

Each consumer can report:
- known 540/1000 requirement;
- unknown PTO requirement;
- evidence source.

The root state reports:
- `requiredShaftRpm` when exactly one known family is present;
- `requirementConflict` when simultaneous consumers require different
  families;
- unknown-requirement count;
- selected-vs-required mismatch.

The system warns; it does not silently change the selected gearbox.

## Public contract

`RealismExtensionsPTO.API_VERSION = 1`

Key public fields:
- `revision`;
- `mode`;
- `modeToken`;
- `shaftRpm`;
- `economy`;
- `effectiveMotorRatio`;
- `nativeMotorRatio`;
- `handThrottlePercent`;
- `handThrottleRpm`;
- `requiredShaftRpm`;
- `requirementKnown`;
- `requirementConflict`;
- `hasPtoConsumer`;
- `mismatch`;
- `capabilitySource`;
- `capabilityProfileId`;
- immutable `availableModeMask`.

Internal profile/mode tables are not exported.

## Persistence / multiplayer

Persisted per vehicle:
- selected mode;
- hand-throttle percentage.

Server authority:
- client requests state change;
- server validates supported mode and PTO-engaged safety;
- accepted state is replicated;
- dirty-stream sync remains available for ordinary state replication.

## Controls

Temporary default keyboard bindings:
- Ctrl + PageUp: next PTO speed;
- Ctrl + PageDown: previous PTO speed;
- Ctrl + Up: hand throttle +100 engine rpm;
- Ctrl + Down: hand throttle -100 engine rpm;
- Ctrl + 0: release hand throttle to ROAD (Ctrl + Numpad0 is a secondary fallback).

These bindings are transitional and may be changed after gameplay feedback.

## Dashboard indicator

The runtime-validation text line has been superseded by an RE-owned graphical
dashboard indicator.

The indicator deliberately does **not** depend on an RMS API. Exact RMS
0.10.0.0 source review showed that its dashboard additions are positioned from
the vanilla speed-meter anchor:

`speedMeter.speedBg position + speedGaugeCenterOffset`

RE uses that same vanilla anchor and FS25 pixel-to-screen scaling. Therefore the
same indicator can sit beside RMS dashboard additions when RMS is present and
still render on the vanilla HUD when RMS is absent.

Presentation:
- original RE PTO pictogram overlay;
- dynamic `540 / 540E / 1000 / 1000E` text below the pictogram;
- dim white = PTO available but disengaged;
- amber = PTO engaged;
- red selector text while disengaged = selected/required PTO mismatch;
- blinking red/amber while engaged = mismatch or advisory transport-speed
  warning.

The transport-speed warning is presentation only. The initial threshold is
25 km/h and is intentionally configurable; it does not disengage PTO, limit
vehicle speed or alter drivetrain physics.

Live physical PTO rpm continues to be calculated from engine rpm / selected
effective PTO ratio for diagnostics and a possible later display revision, but
is intentionally not rendered in this first compact cluster layout.

The pictogram is an original vector asset derived from the user's design
reference and converted to DDS during CI. No Dynamic PTO or RMS visual asset is
copied.

Future presentation may still add:
- optional live PTO-rpm readout if the cluster remains legible;
- GIANTS DashboardValueType values for compatible in-cab indicators;
- vehicle-specific dashboard profiles.

None of those should change the PTO state/physics contract.

## Migration guard

While the old external PTO owner is installed, RE's native PTO specialization
does not attach to vehicle types.

This prevents duplicate ownership during migration.

RC keeps both bridge families temporarily:
- legacy external-PTO composition;
- native RE-PTO composition.

Only one can become active because RE disables its owner state while the
external owner exists.

After native runtime validation, the external PTO mod can be removed and the
legacy bridge family can be deprecated separately.

## Validation completed in CI

RE harnesses cover:
- mode/family math;
- capability fallback;
- evidence profile matching;
- recursive implement requirement/conflict handling;
- operator selection;
- mode-change rejection while PTO engaged;
- hand-throttle state;
- event-driven requirement refresh;
- standalone GIANTS physical ratio/rpm-range scoping;
- assetless HUD revision cache.

RC harnesses cover:
- native API availability;
- revision-based snapshot reuse;
- canonical 540-domain translation;
- MR scoped ratio + hand-throttle composition;
- RMS scoped PTO capacity composition;
- restoration of native motor state after every scope.

## Runtime gate

First native runtime test should remove/disable the external PTO owner.

Expected:
1. RE log:
   `PTOControl active; vehicleTypes=...`
2. With MR installed:
   standalone GIANTS adapter reports inactive because drivetrain ownership is
   external.
3. RC:
   `MRPTO=ACTIVE`;
   `RMSPTO=ACTIVE` when RMS is applicable;
   legacy external-PTO bridges INACTIVE.
4. Fiat 180-90 exposes 540 and 1000 only.
5. HM 10-500 requirement resolves to 1000.
6. Selecting 540 with that implement shows mismatch.
7. Selecting 1000 clears mismatch.
8. Selector refuses a mode change while PTO is engaged.
9. Hand throttle commands an MR engine-RPM governor without requiring
   accelerator input.
10. No persistent overwrite of native `motor.ptoMotorRpmRatio`.

The first runtime log decides whether this branch moves from architectural/CI
validation to gameplay validation.


## Runtime/source re-audit after first native test — 2026-10-05

First runtime build:
- RE commit `0e6567c421972ff0e0ae60061c8de155debe0a0b`;
- native PTO specialization attached to 50 vehicle types;
- MoreRealistic correctly disabled the standalone GIANTS adapter;
- RC native PTO state was consumed heavily and hand throttle reached MR, but the
  temporary global-listener HUD was not visible.

Exact-source re-audit inputs:
- Dynamic PTO RPM 1.1.3.0 supplied archive;
- Realistic Mechanical Systems 0.10.0.0 supplied archive.

### UI lifecycle finding

Dynamic PTO attaches its presentation to the controlled vehicle specialization
through `onDraw`. RMS creates its HUD during `onStartMission`, registers it in
`mission.hud.displayComponents`, and appends its drawing to
`mission.hud.drawControlledEntityHUD`.

The original RE temporary HUD instead depended on a free-standing mod-event
`draw()` listener and mission-level controlled-vehicle lookup. The isolated
harness proved only text formatting, not the real FS25 controlled-HUD lifecycle.

Correction:
- PTO HUD v2 attaches to `mission.hud.drawControlledEntityHUD` after mission
  startup;
- local-player current vehicle is the primary vehicle lookup;
- mission/speed-meter lookup remains fallback only;
- the temporary line renders after the existing controlled-HUD chain and shows
  live physical PTO RPM when engaged;
- HUD and operator actions expose runtime counters so the next log can separate
  input, state, rejection and rendering failures.

### Clean-room parity review

| Dynamic PTO concept | RE native status | Decision |
| --- | --- | --- |
| 540 / 540E / 1000 / 1000E model | implemented | retained |
| manual PTO selection | implemented | retained |
| independent hand throttle | implemented | retained |
| save + multiplayer state | implemented | retained |
| implement requirement + mismatch | implemented, evidence-first | retained |
| live PTO RPM presentation | HUD v2 | retained as presentation, not per-frame domain state |
| exact tractor capability profiles | implemented, small evidence catalog | expand only from evidence |
| AUTO gear selection | not implemented | intentionally rejected |
| horsepower-based 1000/E inference | not implemented | intentionally rejected |
| synthetic engine grunt/load | not implemented | MR/RMS own mechanics |
| baler overload/stall solver | not implemented | specialist owner concern |
| dynamic implement output/work-rate scaling | not implemented | specialist owner concern |
| front/rear selector | not implemented | deferred; no current ownership need proven |
| large settings/menu/HUD surface | not implemented | intentionally simplified |
| clickable hand-throttle bar | not implemented | deferred UX |
| in-cab/dashboard indicators | not implemented | final presentation phase |

The absorption target is therefore **behavioral/architectural parity for the
selected PTO-control boundary**, not feature-for-feature cloning.

### RC canonical-domain note

Do not replace the RC formula
`effectiveCanonicalRatio = physicalSelectedRatio * requiredPtoRpm / 540`
with a selected-family multiplier.

MR normalizes PTO consumers into a canonical 540-rpm domain. The implement
requirement is therefore necessary to preserve the physical shaft/requirement
ratio, including deliberate mismatch cases such as selecting 540 for a
1000-rpm implement. This was re-derived during the source audit and remains the
correct bridge contract.


### Hand-throttle load clarification — runtime follow-up

The first native runtime follow-up clarified two different load mechanisms that
must not be conflated:

1. **RE hand throttle + MR response**
   - RE publishes an operator-selected engine-RPM target;
   - RC scopes that target into MR's own `controlVehicle` engine-governor
     boundary;
   - MR then produces whatever physical engine/load response is necessary to
     reach/hold that requested RPM.
   - This is legitimate drivetrain behavior and must remain.

2. **Dynamic PTO `gruntLoadExtra`**
   - the exact 1.1.3.0 source derives this extra value from baler overload and
     tractor PTO-power shortage;
   - it then adds the value directly to motor/load-percentage getters and
     smoothed/raw load fields.
   - This remains a synthetic feedback layer and is intentionally not absorbed
     into RE while MR/RMS already own physical load/stress.

Therefore the absorption rule is not "remove load caused by hand throttle".
It is "do not add a second synthetic load percentage on top of specialist
drivetrain physics."

### Input registration follow-up

The exact Dynamic PTO source registers vehicle action events with the optional
`ignoreCollisions=true` argument (with compatibility fallback) and explicitly
activates each event through `setActionEventActive(..., true)`.

The first RE native UI test showed the HUD working while Ctrl+PageUp/PageDown
and Ctrl+0 appeared inert. RE had simplified action registration and silently
returned when a collision prevented registration.

Correction:
- PTO combo actions now attempt collision-safe registration first, preserving
  coexistence with other bindings instead of claiming them exclusively;
- explicit action-event activation is restored;
- failures and successful collision-bypass registrations are counted in
  runtime diagnostics;
- rejected PTO-speed changes while the shaft is engaged now produce a visible
  warning instead of a silent no-op.


### RMS dashboard layout study — graphical indicator implementation

Exact RMS 0.10.0.0 source was re-opened before implementing the graphical PTO
indicator.

Relevant RMS pattern:
- creates overlays through `g_overlayManager`;
- scales UI dimensions from pixel-space values;
- anchors dashboard elements to the vanilla speed-gauge centre;
- tints one white/neutral source icon at runtime instead of maintaining a
  separate texture for every state;
- appends its own draw to `mission.hud.drawControlledEntityHUD`.

RE now follows those *layout/rendering principles* independently:
- one white PTO pictogram source;
- runtime tint;
- text mode rendered separately;
- vanilla speed-meter anchor;
- same controlled-entity draw lifecycle already validated by the first HUD
  repair.

RE does not read `RMS_Main.hud`, `RMS_Hud`, RMS indicator tables, RMS
positions or RMS configuration. This is deliberate: RMS presence is a visual
coexistence case, not a feature dependency.

Initial tuning constants live under `RealismExtensionsConfig.ptoHud`, so
runtime screenshots can refine offset/size without redesigning the ownership
boundary.


### Graphical HUD first-runtime follow-up — engagement + live layout tuning

The first in-game graphical-indicator test validated:
- vanilla speed-meter anchoring;
- DDS overlay creation;
- controlled-HUD draw order;
- scale matching at 1920x1080 / UI scale 1.0.

It also exposed two development needs.

#### Engagement semantics

The initial indicator queried `getIsPowerTakeOffActive()` on the root tractor.
That is not a valid generic engagement source: GIANTS' base PowerTakeOffs
implementation on an output PTO vehicle returns false. PTO-consuming implement
specializations such as TurnOnVehicle/Dischargeable/FillUnit/BaleLoader extend
that function with their actual operating state.

RE now resolves engagement across the attached implement graph:
1. query each attached PTO consumer's `getIsPowerTakeOffActive()`;
2. for modded PTO consumers with an incomplete overwrite chain, fall back to
   `getIsTurnedOn()`;
3. recurse through intermediate implements.

The same resolver is used by both the dashboard lamp and the safety rule that
blocks PTO-speed selection while an attached PTO consumer is operating.

Diagnostics now expose `engageSource` so runtime logs distinguish
`IMPLEMENT_PTO_ACTIVE`, `IMPLEMENT_TURNED_ON` and no active consumer.

#### Live layout tuning

HUD placement is visual calibration, not PTO domain logic. Rebuilding the mod
for every 2–5 pixel adjustment is unnecessary, so development console commands
are now available:

- `rePTOHud`
  - prints the current layout;
  - optional: `rePTOHud x y width height textSize textGap`.
- `rePTOHudMove dx dy`
  - relative pixel movement; positive X = right, positive Y = up.
- `rePTOHudScale factor`
  - scales icon, mode text and their gap together.
- `rePTOHudReset`
  - restores branch defaults.

These changes are local/session-only by design. Once a layout is visually
approved, the selected numbers should be committed to
`RealismExtensionsConfig.ptoHud`. This mirrors normal HUD authoring practice:
stable anchor + live development tuning + fixed production defaults.

A future user-facing movable HUD/settings screen is optional and should only be
added if players actually need per-user placement rather than development-time
calibration.


### Operator-control correction after 6R 155 runtime — 2026-10-05

The second graphical-HUD runtime clarified three separate behaviours.

#### Selector actions were firing

The 6R 155 session recorded repeated mode-next/mode-prev callbacks while the
display remained at 540. This was not an input-registration failure: the
vehicle was still on the evidence-first unknown-tractor fallback, which exposes
only native 540. Cycling a one-entry mode set therefore returned 540 again.

RE now has an evidence-backed John Deere 6R 155 profile based on Deere's
published factory PTO packages. The default/base package is represented as:
- 540 at 1987 engine rpm;
- 540E at 1753 engine rpm;
- 1000 at 2000 engine rpm.

The alternative factory package 540E/1000/1000E is not merged into the same
profile because these are mutually exclusive PTO packages and the FS25 vehicle
does not expose which option is installed. Thus the default 6R 155 intentionally
cycles 540 -> 540E -> 1000, not all four modes.

A selector command on a genuinely one-mode profile now produces visible/log
feedback instead of silently returning the current mode.

#### Hand throttle is engine-RPM control

The previous native design stored a normalized hand-throttle percentage and RC
translated it into a floor on `VehicleMotor.getRequiredMotorRpmRange()`.
Runtime proved that the bridge was exercised, but that boundary describes PTO
consumer requirements; it is not a convincing operator governor.

The operator model is now engine-RPM based:
- Ctrl+Up = +100 engine rpm;
- Ctrl+Down = -100 engine rpm;
- the first increase after ROAD/released state starts from the current engine
  rpm neighbourhood;
- Ctrl+0 releases the governor back to ROAD;
- persistence/networking remain backward-compatible by normalizing the RPM
  target into the existing 0..1 serialized field.

With MoreRealistic active, RC no longer injects the hand throttle as a fake PTO
requirement. Instead it temporarily wraps the vehicle instance's
`controlVehicle` while the MR-owned `WheelsUtil.updateWheelsPhysics` and
`Motorized.onUpdate` paths execute. The requested engine rpm raises MR's
minimum/target engine-rotation arguments while preserving accelerator input,
gearbox logic, clutch, PTO torque and load simulation. The wrapper is restored
immediately after each scoped MR call.

This deliberately differs from Dynamic PTO's exact implementation, which can
write motor RPM state fields directly. RE/RC use the drivetrain owner's control
boundary instead of forcing displayed/simulated RPM values.

#### Reset binding and HUD calibration

The tested graphical HUD position is now the production default:
- x = -53 px;
- y = -11 px;
- icon = 30 x 18.75 px;
- text = 9 px;
- gap = 5 px.

Live tuning commands remain available.

Ctrl+0 did not reach the reset callback in the runtime log even though the
other action callbacks did. The primary Ctrl+0 binding remains, with
Ctrl+Numpad0 added as a secondary keyboard fallback. Decreasing the governor
below its first usable RPM step also returns to ROAD, so release is no longer
dependent on a single physical key.

The dashboard texture is now supersampled to 512x320 and packaged as
uncompressed ARGB DDS to avoid DXT block artifacts at the small ~30 px rendered
size. The SVG remains the editable source of truth.


## Runtime semantics checkpoint — manual PTO causality — 2026-10-06

The first full 6R 155 runtime with the RPM-based hand throttle corrected an
important conceptual assumption.

### Manual PTO baseline

For the realism target of RE, the default/manual causal model is:

1. operator selects the PTO gear/family (540, 540E, 1000, etc.);
2. operator engages the PTO clutch;
3. operator/governor raises engine RPM with the hand throttle;
4. physical PTO shaft RPM follows from engine RPM and the selected PTO ratio;
5. the implement imposes torque/load on the drivetrain and performs according
   to the shaft speed/power it actually receives.

An attached implement demanding PTO power is therefore **a load**, not by
itself an operator engine-speed command.

Modern tractors may provide automatic engine/PTO management that raises or
maintains engine speed when PTO work is active, but that is a distinct
automation feature and must not be assumed for every tractor or every manual
PTO workflow.

This distinction is now a project requirement: do not describe automatic
engine-speed enforcement caused by an active PTO consumer as inherently
realistic manual PTO behaviour.

### Current MR behaviour observed

The 2026-10-06 runtime shows a separate owner behaviour still present in
MoreRealistic:

- RE hand throttle was released (`handTarget=0`);
- selected PTO mode was 1000;
- the attached consumer was active;
- actual PTO speed remained roughly 1080 rpm.

MR source review explains the behaviour. When consumed PTO torque is positive,
MR resolves `motor:getRequiredMotorRpmRange()` into `minRotForPTO` and uses
that value in its own `controlVehicle` calls. In several drivetrain states,
that minimum/target engine rotation can raise the engine without any RE hand
throttle target.

Therefore:
- the RE/RC hand-throttle governor is not responsible for this automatic RPM
  rise;
- the behaviour belongs to MR's PTO requirement/control model;
- whether RC should suppress, reinterpret or leave this owner behaviour is
  **deferred for a dedicated design decision and controlled runtime test**;
- no change is made at this checkpoint.

The desired future comparison is:
- ROAD + PTO engaged + implement active;
- explicit low hand-throttle target + implement active;
- correct rated hand-throttle target + implement active;
- load high enough to pull RPM below target.

The test should distinguish requested engine RPM, actual engine RPM, actual PTO
RPM, consumed PTO torque and fuel consumption.

### Runtime results retained

The same test validated:
- 6R 155 profile is active and exposes mode mask 7 (540 / 540E / 1000);
- selector changes are reaching the state model;
- implement mismatch presentation works;
- selecting 1000 for a 1000-rpm consumer clears mismatch;
- attached-consumer engagement detection works;
- transport-speed warning enters the warning state while PTO work remains
  active;
- RC native MR and RMS bridges are active and heavily exercised;
- the RPM-based MR governor bridge is reached during explicit hand-throttle use.

Transport warning consequences remain deliberately deferred. It is currently
advisory presentation only.

### Fuel-consumption observation

Gameplay observation reported:
- stationary high engine RPM via hand throttle consumed more fuel than idle;
- in one moving comparison, displayed fuel consumption was substantially lower
  than the stationary high-RPM case.

The current log does not record enough fuel-rate / engine-load data to validate
that comparison. Do not infer a fuel-model bug or correctness from this session.
A future controlled test should capture the same engine target, actual RPM,
gear/speed, engine load/torque, PTO state and fuel-rate measurement.

### PTO dashboard asset follow-up

The supersampled uncompressed DDS improved source-edge preservation but FS25
logs a performance warning for the raw DDS format. This is not considered a
final asset solution.

The final small HUD pictogram should be authored for its actual ~30 px display
size (simpler silhouette / thicker features / controlled negative space) and
then packaged in a GPU-friendly compressed texture format. Increasing source
resolution alone is not sufficient to make a dense icon legible when reduced.


## Runtime follow-up — causal probe and savegame persistence — 2026-10-06

The next mixed PTO session validated the native migration boundary:

- RC detected the external Dynamic PTO owner as inactive;
- MR+RE PTO and RMS+RE PTO were ACTIVE;
- the 6R 155 profile continued to expose 540 / 540E / 1000;
- mismatch cleared when 1000 was selected for the 1000-rpm consumer;
- implement engagement and transport warning states were observed;
- the MR bridge continued to exercise ratio and hand-throttle scopes heavily.

### Causality telemetry instrumentation miss

The first RC causality probe did not emit any detailed runtime samples even
though the bridge itself was active. The end-of-session RC summary reported
`causalitySamples=0` while `motorizedUpdateCalls`,
`effectiveRatioScopes`, `handThrottleGovernorScopes` and related counters
were non-zero.

This is a diagnostic failure, not evidence of a PTO physics failure.

RC now samples from its already-existing `Motorized.onUpdate` bridge path,
after the MR motor update, only for the controlled vehicle, at 1 Hz while
MRPTO telemetry is DETAILED. Probe-health counters distinguish polls, samples
and misses. No gameplay/physics hook was added.

### Savegame path defect found and corrected

The runtime save exposed a separate RE defect. GIANTS called the
specialization `saveToXMLFile` callback with an already namespaced key:

`vehicles.vehicle(N).FS25_RealismExtensions.realismExtensionsPTO`

RE incorrectly appended `FS25_RealismExtensions.realismExtensionsPTO` a
second time, producing an unregistered XML path and preventing mode / hand
throttle persistence.

The correction is intentionally narrow:

- `saveToXMLFile` writes `key .. "#mode"` and
  `key .. "#handThrottle"` directly;
- `onPostLoad` remains based on the vehicle-level `savegame.key`, then
  resolves the registered mod/specialization namespace;
- the harness now covers both callback key contracts so a future refactor
  cannot silently duplicate the namespace again.

This defect affected persistence only; it does not explain the runtime PTO
ratio/hand-throttle behavior observed before the save.


## Runtime causality result — 2026-10-06

The corrected RC causality probe produced 235 successful samples with zero
sample misses. This resolves the earlier ambiguity around the observed fuel
usage.

### Fuel chain

The 6R 155 data supports the intended causal architecture:

`PTO / drivetrain demand -> motor torque and RPM -> MR power/load -> MR fuel`.

Representative observations:

- ~900 rpm idle, no PTO load: ~2.58 L/h;
- hand throttle ~2300 rpm while stationary and PTO disengaged: ~23.35 L/h;
- active PTO consumer while stationary: MR raises the engine to ~2160 rpm,
  with fuel ~25.34 L/h;
- the same active PTO consumer while accelerating raises motor torque/power
  and fuel to roughly ~45 L/h;
- road acceleration around ~1892 rpm can consume ~40.5 L/h because the motor
  is delivering substantially more torque/power than at 2300 rpm;
- forcing ~2300 rpm while moving reduced applied torque/power in this
  drivetrain state and fuel fell to ~27.75 L/h.

Therefore no RE fuel multiplier is justified. The apparent paradox “higher
RPM but lower fuel” is explained by lower delivered torque/power, which MR
weights much more heavily than RPM.

### Important PTO-behavior finding

The log also proves the current MR behavior that motivated the original
Dynamic PTO comparison.

With the PTO consumer activated and RE hand throttle still at ROAD:

- engine RPM rises automatically from idle to about 2160 rpm;
- MR reports `mrMinPtoRpm ~= 2160` and
  `mrMinPtoIdleRpm ~= 2160`;
- the 1000-rpm mode's 2.0 effective ratio then yields roughly 1080 shaft rpm.

So the current native RE+RC integration still lets MR request the engine speed
needed by the implement automatically. The player is **not yet required** to
raise engine RPM manually before the implement reaches useful PTO speed.

That differs from the desired Dynamic-PTO-like operating model where an
under-speed shaft may run slowly or fail to perform until the operator raises
engine speed.

Next design study should therefore target the upstream MR PTO requirement
path, not fuel consumption:

1. trace how MR derives `mrLastMinRotForPTO` /
   `mrLastMinRotForPTOidle` from the active consumer;
2. compare that path with Dynamic PTO's under-speed implementation;
3. determine whether RE should expose selected ratio while allowing actual
   engine RPM to remain operator-controlled;
4. preserve real PTO torque demand and natural motor/fuel consequences;
5. avoid synthetic load, direct fuel penalties, and permanent mutation of MR
   or GIANTS state.

No under-speed behavior should be implemented until that ownership/flow study
is complete.


## Under-speed runtime evidence and MR source follow-up — 2026-10-07

Runtime with RC build `03e6e23b...` validated the corrected SI telemetry:
`kinematicPtoRpm`, explicit kN*m/N*m torque fields and corrected kW all
matched the observed drivetrain state.

The session adds an important nuance to the previous conclusion that MR
"forces PTO RPM automatically".

### Runtime observation

With the 6R 155 in 1000 mode and the PTO consumer engaged while travelling
near 53 km/h:

- RE hand throttle remained ROAD / 0;
- MR requested `mrMinPtoRpm=2160` and `mrMinPtoIdleRpm=2160`;
- actual engine speed remained around 1725–1730 rpm for several seconds;
- ratio-derived shaft speed remained only ~862–866 rpm;
- the implement still consumed substantial PTO torque (~0.82 kN*m);
- RE correctly reported `engaged=true` and transport warning.

Therefore `mrMinPtoRpm` is a requested control target, not an absolute clamp.
Gear/drivetrain state can leave the PTO genuinely under-speed even while MR
requests nominal working RPM.

Later, around 31–35 km/h, the drivetrain did reach ~2160–2180 engine rpm and
~1080–1090 PTO rpm.

### MR source ownership

Current MR source confirms this behavior is native and already partly models
under-speed:

- `MR_WheelsUtil.lua` obtains the consumer's required motor RPM and stores it
  in `mrLastMinRotForPTO`; the idle control floor is normally based on
  `mrMinEcoRot + 10`, unless `mrForcePtoRpm` is set;
- `MR_PowerConsumer.lua` continuously computes
  `mrPtoCurrentRpmRatio = actualPtoRpm / requestedPtoRpm`;
- consumed PTO torque uses the current ratio, clamped to a minimum 0.85 ratio,
  so mechanical shaft power naturally falls when the shaft is sufficiently
  under-speed rather than inventing a separate fuel penalty;
- power-harrow and spader draft calculations already increase resistance when
  PTO RPM is low;
- `MR_WoodCrusher.lua` explicitly disables the feeding mechanism below
  `mrPtoCurrentRpmRatio < 0.78`.

MR previously contained a generic "turn implement off when engine RPM is too
low" hook, but that feature is commented out in the current source because it
caused problems for manual-clutch users.

### Design implication

Do **not** implement a generic synthetic under-speed penalty yet. MR already
owns useful pieces of the physical degradation model.

The remaining design problem is narrower:
- when stopped / normal field operation, MR often raises engine RPM toward the
  consumer requirement automatically;
- we want the RE hand throttle to be meaningful and operator-driven without
  breaking MR's real PTO torque/current-ratio model;
- category-specific consequences should continue to come from the specialist
  simulation when they already exist.

Next study should identify the smallest scoped intervention around MR's
minimum-RPM request/control path that removes unwanted automatic governing
while preserving:
1. `mrPtoCurrentRpmRatio`;
2. consumed PTO torque;
3. category-specific low-RPM consequences;
4. AI / unattended PTO behavior;
5. no permanent mutation of MR/GIANTS state.


## Final manual-governor implementation candidate — 2026-10-07

The source study is now implemented on the isolated finalization branches:

- RE: `feat/pto-manual-governor-final`;
- RC: `feat/pto-manual-governor-final`.

The branches intentionally do not absorb the parallel Mud 1.3.6, Reifen
1.2.2.70 or RMS 0.11 research lines. This keeps the PTO change reviewable and
allows the parallel compatibility work to finish independently before a final
integration/squash merge.

### Standalone RE

When MR is absent, `PTOPhysics` now:
- keeps the selected effective PTO ratio scoped into native motor reads;
- removes the implement PTO RPM request from the player's required motor-RPM
  range;
- suppresses GIANTS' separate `PowerConsumer.getMaxPtoRpm` auto-rev read
  only while `VehicleMotor.update` executes for that same root vehicle;
- preserves normal automatic PTO RPM management for AI;
- preserves the selected ratio for AI/native automatic calculations;
- restores every global/raw field immediately.

### RC + MR

MRPTO now separates physical load from automatic engine management.

For player/non-AI native PTO ownership:
- real `neededPtoTorque` remains untouched;
- MR `getRequiredMotorRpmRange` sees no PTO-specific RPM request;
- hydrostatic PTO-mode RPM targets are scoped back to normal road-mode targets;
- MR's PTO-only eco-idle floor and its explicit unattended ~1200-rpm floor are
  removed when recognizable;
- accelerator input is preserved;
- the RE hand throttle is applied only after those automatic PTO floors are
  removed;
- selected PTO ratio remains visible to MR power/torque calculations.

For AI, all automatic MR PTO RPM management remains native.

For unattended non-AI equipment, ROAD releases PTO-specific RPM management;
a persisted hand-throttle target remains the operator-owned minimum.

### Harness status

Both final branches pass their complete CI/harness suites.

The remaining gate is runtime only. No further source-level behavior patch is
planned before that test.

Runtime acceptance should prove:
1. PTO engaged + ROAD does not auto-jump to nominal implement engine RPM;
2. shaft RPM follows actual engine RPM and selected ratio;
3. consumed PTO torque remains present;
4. hand throttle raises the engine in 100-rpm steps;
5. MR under-speed consequences remain functional;
6. AI still self-governs PTO RPM;
7. unattended hand throttle persists;
8. save/load remains schema-clean.

Once those pass, PTO causality telemetry can return from DETAILED to SUMMARY
and the functional development can be closed.