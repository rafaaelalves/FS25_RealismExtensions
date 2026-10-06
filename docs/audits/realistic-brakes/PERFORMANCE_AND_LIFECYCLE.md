# Realistic Brakes — performance and lifecycle audit

Updated: 2026-10-06  
Exact baseline: 1.3.0.0

These are static cadence/hot-path findings unless the source itself records measured runtime impact.

## A valuable upstream lesson: bounded wake after a real FPS regression

RB source documents a previous implementation that repeatedly:
- `raiseActive()`;
- woke rigid bodies;
- forced wheel physics

for unattended vehicles whose parking brake was "exceeded".

The source records user-observed FPS losses around 25–50% depending on map/vehicle count.

Current 1.3 bounds this forced wake to:
`PARK_ROLL_WAKE_SEC = 8`.

This is a strong positive engineering lesson:
- inactive-physics recovery must have a finite retry budget;
- after a bounded attempt, let ordinary physics/event state take over;
- never maintain fleet-wide rigid bodies awake indefinitely to preserve one feature.

## Remaining manual physics call

Inside the bounded wake window RB may explicitly invoke:
`WheelsUtil.updateWheelsPhysics(...)`.

This goes through the effective global wrapper chain.

With MR/other mods this can execute code outside its normal game call site.

Classification:
**RUNTIME-SENSITIVE workaround, not automatically a bug.**

If RE ever needs similar wake behavior:
- prefer a supported activation/physics API;
- avoid manually invoking a globally-overwritten core physics function;
- if unavoidable, identity/version gate and instrument the call.

## Main per-frame work

Server `onUpdate` can run:
- engine-brake control;
- brake thermal integration;
- parking mass/slope logic;
- manual-clutch parking enforcement;
- Enhanced Vehicle neutralization;
- wake workaround.

Client `onUpdate` also:
- recalculates engine brake for local prediction;
- neutralizes EV parking;
- updates audio.

These domains do not all need the same cadence.

## Existing good cache — parking diagnostics

Mass/slope parking calculation is rate-limited to ~250 ms.

This is a good precedent:
- slope and total mass do not need frame-rate recomputation;
- discrete "hold exceeded" transition can be detected after each low-rate sample.

If physical parking becomes actuator-based, even this classifier can disappear from the physical path and become diagnostics only.

## Existing good cache — AI/controller detection

RB caches controller detection for ~250 ms.

This avoids repeated Courseplay/FollowMe/native-AI probing from hot physics paths.

Generalizable:
- controller identity is a context;
- resolve/cached state centrally;
- invalidate on controller transitions where possible.

Future RE can do better with explicit controller revision/events rather than repeated probes.

## Engine-brake cadence

Player retarder response benefits from fast cadence while:
- player controls the vehicle;
- retarder/exhaust mode is active or can change.

It does not need fleet-wide frame processing for every parked vehicle.

Future rule:
```text
controlled + active demand -> frame
otherwise -> no engine-brake update
```

The drivetrain owner should consume demand once.

## Brake thermal cadence

Thermal state is slow.

A 50–200 ms fixed server cadence is adequate for:
- brake-work integration;
- cooling;
- fade state;
- damage threshold integration.

Use elapsed `dt` so heat/cooling remains correct.

Presentation can interpolate if needed.

This reduces active-vehicle frame work and makes server behavior less dependent on render cadence.

## Exact exponential cooling

RB's exponential cooling allows low-rate updates without introducing Euler-step drift.

This is a strong fit for a coarser thermal scheduler.

## Trailer air cadence

Current `rbTrailerAir:onUpdate` can:
- evaluate hose state;
- equalize pressure;
- detect state transitions;
- reapply braking.

Future pneumatic transfer should run on a bounded fixed server cadence, e.g. 50–200 ms depending flow fidelity.

Hose connect/disconnect itself should be event/change-driven where GIANTS exposes suitable lifecycle signals.

Spring-brake discrete transition should be applied immediately after each pneumatic step.

## Instant equalization masks network/cadence needs

Current RB can avoid trailer-pressure replication because one call instantly equalizes pressure.

Once finite flow exists:
- pressure evolves over time;
- own dirty/revision state is required;
- transfer cadence becomes a real design parameter.

Do not preserve the no-stream shortcut after changing the physics.

## HUD

RB globally appends `FSBaseMission.draw` and draws its HUD each frame.

It contains careful coordinate/layout handling, but this remains another independent overlay.

Future shared RE HUD:
- one controlled-entity presentation lifecycle;
- cached anchor geometry;
- update only semantic state revisions;
- UI draw remains per frame but expensive state discovery does not.

## Settings UI hooks

RB appends:
- settings-frame update;
- settings-frame open.

This is reasonable as mod-lifetime setup.

If assimilated into RE, reuse the existing RE settings owner instead of adding another global settings hook.

## Console command surface

RB registers many commands:
- diagnostics;
- safe mode;
- HUD calibration;
- temp thresholds;
- settings.

This is valuable during development.

No corresponding `removeConsoleCommand` path was found.

As a mod-lifetime singleton this may be acceptable, but RE should:
- register once;
- separate dev commands from production commands;
- make mission-scoped commands lifecycle-safe;
- avoid stale command target tables after reload.

## Audio

Per-vehicle samples are cleaned in `onDelete`.

The exhaust path has historically used both:
- per-vehicle 3D sample;
- global 2D fallback.

Source comments document multiple sound regressions and duplicated sound behavior.

Future principle:
- one semantic sound owner;
- prefer vehicle/native sample;
- only use fallback when primary unavailable;
- never run two loops merely to compensate for uncertain loading.

## Classification work

Vehicle class is resolved and cached at post-load, not re-discovered every frame.

Good.

If profiles replace classification, resolve once and retain:
- source;
- revision;
- fallback reason.

## Trailer custom force

RB recalculates trailer lock torque whenever braking runs because load may change.

If future authoritative wheel-load context is available:
- consume cached measured wheel loads/revision;
- do not recompute whole-vehicle mass every brake call;
- group spring-brake torque can update only when load/profile/topology revision changes materially.

## Multi-rate target architecture

Suggested if assimilating relevant features:

```text
input / player retarder intent       frame while controlled
final brake actuator                 physics cadence / owner call
thermal integration                  50–200 ms server
parking diagnostics                  200–500 ms or state change
pneumatic transfer                   50–200 ms server
controller ownership                 transition/event or 250 ms cache fallback
HUD draw                             render frame
HUD state discovery                  revision/change-driven
offline leak/cooling                 elapsed-time reconciliation
```

## Instrumentation to add before optimizing

If RB is tested in stack, measure:
- active RB vehicle count;
- server `onUpdate` calls;
- thermal update duration;
- parking cache refresh count/duration;
- manual wake attempts/vehicles;
- wheel-physics manual calls;
- AI/controller resolver cache hit rate;
- trailer-air steps/pair count;
- HUD draw duration;
- exhaust downshift requests.

Do not declare every per-frame call a real bottleneck without profiling.

## Lifecycle test targets

- vehicle sell/delete while exhaust sample playing;
- save A -> menu -> save B without restart;
- Enhanced Vehicle loaded/unloaded across test sessions;
- attach/detach trailer repeatedly;
- trailer delete while connected;
- Courseplay/FollowMe controller start/stop;
- player -> AI -> player handoff;
- settings/HUD recalibration then reload.

Static conclusion:
RB contains both a cautionary performance history and several good corrective patterns. Its best reusable lesson is **bounded work by semantic cadence** rather than permanent physics wake or fleet-wide frame ownership.


## Long-gap thermal reconciliation

RB's use of exact exponential cooling is ideal for sparse scheduling, but the
current clock bridge discards measured gaps >=300 seconds and falls back to one
ordinary frame dt.

This creates a lifecycle artifact rather than a CPU issue:
- long inactive vehicles can remain artificially hot;
- sleep/time acceleration can be under-accounted;
- save/reload has no thermal timestamp.

Future low-rate thermal scheduler should:
- carry elapsed simulation time explicitly;
- cap only for documented gameplay/sanity reasons;
- evaluate the closed-form exponential directly;
- persist a timestamp if temperature itself is persisted.

This allows thermal work to run less often **and** become more correct.

## Input registration observability

RB actions currently lack the collision-safe/diagnostic registration pattern
learned from native PTO and current RDS.

If the mod enters the full stack, add development counters for:
- action registration attempts/success/failure;
- event active state;
- callback counts;
- last callback time/rejection reason.

This is primarily debugging/lifecycle observability, not a measured
performance optimization.

## Schema duplication lesson

RB's persistence field declarations are repeated in two registration paths.

A future RE module should keep:
- one declarative schema field table;
- one idempotent registrar;
- multiple lifecycle callers only when necessary.

This reduces maintenance drift and gives tests one canonical schema surface.
