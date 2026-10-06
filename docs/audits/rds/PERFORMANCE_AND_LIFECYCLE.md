# RDS 1.4 performance / lifecycle audit

Updated: 2026-10-05
Baseline: exact RDS 1.4.0.0 archive.

These are **static hot-path candidates and lifecycle findings**, not measured
runtime bottlenecks. Do not assign performance severity without profiling.

## Frame-path inventory

For eligible vehicles RDS registers both `onUpdate` and `onPostUpdate`.

The update path can perform:
- ignition visual compatibility writes;
- key hold/release timing;
- preheat/crank timers;
- warm-up thermal progression;
- compressed-air simulation;
- cold-operation consequence checks;
- state transitions / warnings.

The post-update path calls ignition visual compatibility again.

### Opportunity P1 — make visual compatibility change-driven

`rdsApplyIgnitionVisualStates()` runs in both update and post-update.

Native RE should:
- update contact/dashboard/light intent when START state revision changes;
- perform a late reconciliation only when an external owner changed the
  relevant state;
- avoid two unconditional visual ownership passes every rendered frame.

This is primarily an ownership/maintainability improvement; measure before
claiming material frame-time savings.

## Pneumatic cadence

RDS integrates air state from the server update path at rendered-frame cadence.

Work includes:
- compressor/governor;
- leakage;
- brake-pedal demand;
- vehicle mass;
- spring-brake state;
- dirty/event threshold decision.

None of the physical reservoir dynamics require 60+ Hz integration for useful
gameplay.

### Opportunity P2 — fixed/bounded server cadence

Run pneumatic state at roughly 100–250 ms with elapsed dt, while:
- input/service command can be sampled frame-rate or read from current state;
- discrete warning/spring transitions are emitted immediately after each
  pneumatic step;
- HUD interpolates/presents latest authoritative value.

Benefits:
- lower fleet-wide cost;
- deterministic server behavior independent of client FPS;
- easier MP/network testing;
- cleaner separation between physical state and presentation.

## Repeated mass queries while braking

RDS uses vehicle mass as part of the air-consumption formula and may query total
mass while service braking is active.

The proposed RE air model removes kinetic-energy-style consumption entirely, so
these mass queries disappear from the pneumatic hot path rather than merely
being cached.

General lesson: **fix the model before optimizing the implementation**.

## Thermal cadence

RDS advances its private engine-temperature state every update and now samples
motor load.

Native RE should not own this thermal state when RMS/ADS provides it.

For standalone fallback:
- update thermal state at a fixed lower cadence;
- consume cached/provider revisions for the HUD;
- do not poll the same specialist state independently from multiple RE modules.

## Input timing

Held-key timing is frame-sensitive only while the key interaction is active.

### Opportunity P3 — active interaction gating

Do not keep an input timer path active for every eligible vehicle.
Only the controlled vehicle with a pressed/pending start gesture needs
high-frequency hold timing.

## HUD draw path

RDS 1.4 correctly caches scale-dependent dimensions, but each draw still
resolves/queries the native speedometer anchor and performs protected calls.

### Opportunity P4 — cache semantic HUD anchors

RE shared HUD can cache:
- active HUD instance;
- speedometer anchor/slot rectangle;
- aspect/UI scale;
- active semantic slots.

Invalidate on:
- UI scale event;
- mission HUD recreation;
- resolution/aspect change if exposed;
- owner/slot topology change.

Do not cache blindly if the base HUD can animate/reposition; first verify which
coordinates are static versus animated.

## One-time migration hook

RDS 1.4 appends a global `FSBaseMission.update` function to wait a few seconds
before showing the keybind migration notification.

The hook remains installed after the one-time notification is complete.

### Opportunity P5 — temporary work belongs to the existing scheduler

RE already has a core lifecycle/update owner. Queue delayed one-shot tasks there
instead of adding permanent global hooks for temporary concerns.

## Dead presentation resources

Exact 1.4 source allocates or maintains presentation state no longer used by the
current HUD:
- progress-bar overlays;
- tick mark;
- READY blink timer;
- status text field/path.

### Opportunity P6 — feature retirement checklist

When presentation changes:
1. remove allocations;
2. remove update state;
3. remove persistence/network fields if any;
4. remove console commands;
5. remove cleanup paths;
6. update tests/telemetry.

Dead resources are usually small individually, but they create lifecycle bugs
and make later profiling/noise analysis harder.

## Provider resolution

RDS performs several optional-mod checks dynamically.

Native RE should resolve capability facets per vehicle and cache the result until
a relevant ownership/topology revision changes.

Example cached resolution:
```text
thermalOwner
electricalStartOwner
fuelStartOwner
glowOwner
interlockOwner
motorStartOwner
```

Do not make every HUD/update consumer independently rediscover installed mods or
private tables.

## Networking positives

The RDS pneumatic event has useful efficiency ideas:
- server-owned pressure;
- compact 10-bit pressure encoding;
- only send after meaningful pressure delta or discrete spring-state change.

RE should preserve the **principle**, while adding:
- full initial state;
- revisioned dirty group;
- explicit authority/controller validation for requests;
- server-authoritative start outcome.

## Settings/lifecycle split

RDS uses one local modSettings surface for both:
- local player preference/presentation;
- simulation-affecting parameters.

This is a multiplayer correctness issue and also complicates caching.

RE should separate:
- `LocalPreferences`: HUD, input, colors;
- `SimulationConfig`: save/server authority, replicated/versioned;
- `DevCalibration`: diagnostics/tuning only.

Each layer can then have an appropriate invalidation strategy instead of
polling/reloading all settings together.

## Suggested performance instrumentation for the native module

Before tuning:
- EngineStartControl frame calls / active-interaction calls;
- provider resolutions / cache hits / invalidations;
- pneumatic steps / avg/max duration;
- HUD draw duration / geometry invalidations;
- dirty-group sends / bytes/quantized pressure changes;
- AI readiness transitions;
- one-shot scheduler tasks.

The target is not "zero hooks"; it is that work frequency matches the physical
or interaction cadence that actually needs it.


## Cross-audit optimization additions

### P7 — eliminate duplicate thermal ownership before optimizing it

Current FS25 already has `spec_motorized.motorTemperature`; RMS/ADS may own a
richer temperature.

Native RE should resolve/copy a normalized temperature value, not integrate a
second thermal model merely because RDS did.

This can remove an entire frame-updated subsystem from the replacement.

### P8 — resolve capability owners once per vehicle/revision

Start resolution may involve:
- thermal;
- starter/electrical;
- glow;
- fuel;
- interlock;
- final motor-start owner.

Do not rediscover mods/tables from every HUD/update callback.

Cache a resolved owner/context signature and invalidate on:
- vehicle load/reinitialize;
- provider runtime revision;
- relevant active-mod ownership change;
- profile change.

Expose cache hit/miss/invalidation telemetry during development.

### P9 — use native AIR infrastructure if it reduces duplicate work

If the native AIR backend proves viable, preserve:
- fill-unit state;
- standard save/network path;
- compressor sound state;
- native dashboard compatibility.

Replace only the weak physical calculation.

This is potentially cheaper and safer than:
- an RE reservoir;
- RE networking;
- RE sounds;
- a native-AIR suppression bridge

all executing together.

### P10 — one RPM actuator wrapper

If PTO, cold idle and compressor fast idle all need a minimum RPM, aggregate
their demands and install one final owner adapter.

This converts wrapper count from approximately "one per feature" to one per
physical actuator domain.

### P11 — pneumatic physics need not scale with render FPS

For each pneumatic vehicle:
- retain last service command;
- integrate at fixed/bounded server cadence;
- process command delta and leak;
- update governor/compressor;
- mark dirty only after meaningful quantized change/discrete transition.

A 100–250 ms physical step is the initial research range, not a final calibrated
constant.

### P12 — event-driven start state when idle

Most vehicles spend almost all their time in stable OFF or RUNNING states.

Do not continuously execute a large start state machine for every eligible
vehicle.

Fast work is needed only during:
- active input;
- preheat;
- cranking;
- transition timeout.

Stable states can rely on owner/provider revisions and low-frequency safety
checks.

### P13 — separate simulation settings from local UI settings

A synchronized `SimulationConfig` eliminates repeated local-settings ambiguity
and allows revision-based invalidation.

`LocalPreferences` can remain client-local and should never wake server
physical simulation.

### P14 — avoid duplicated audio work

If native AIR + soundExpansionMP already drives compressor samples, do not
maintain an RE loop sample in parallel.

Semantic state is cheaper and more composable than duplicate sample ownership.

### P15 — budget catch-up, do not lose elapsed time

Learn from RMS:
- timers/physics should use elapsed time;
- expensive catch-up should have a per-frame budget with residual debt.

For pneumatics/offline leak this is easy because dynamics are slow.

For crank/start hazard, use a bounded fixed cadence plus elapsed-time-correct
probability rather than executing hundreds of catch-up rolls.

## Suggested performance acceptance metrics

Before enabling replacement by default collect:
- eligible vehicles;
- active-start vehicles;
- start-context reads / cache hits / misses;
- action adapter calls;
- pneumatic vehicles;
- pneumatic steps per second;
- mean/max pneumatic step cost;
- native AIR backend hits/fallbacks;
- dirty pressure updates / discrete state updates;
- HUD slot geometry invalidations;
- duplicated owner/sound suppression count;
- second-save resource/command counts.

Compare with external RDS baseline only after functionally equivalent scenarios
are established.
