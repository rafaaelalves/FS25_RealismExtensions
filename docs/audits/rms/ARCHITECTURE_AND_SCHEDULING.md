# RMS architecture and scheduling — pass 1

Baseline: RMS `0.10.0.0`, ZIP SHA-256 `6741f193f22a5f85f5543c73d7f566b6686ab90bf7b705fd66d6d3421cb0d021`.

## Component map

Large core modules include:
- `RMS_Specialization.lua` — vehicle integration, shared state, overwrite registration, core update;
- `RMS_BreakdownRegistry.lua` / `RMS_Breakdowns.lua` / `RMS_SpecBreakdowns.lua` — failure catalog, effects, selection and progression;
- `RMS_SpecWear.lua` — system wear/stress;
- `RMS_Thermal.lua` — engine/transmission thermal;
- `RMS_Electrical.lua` — battery/alternator/external power;
- `RMS_Drivetrain.lua` — 2WD/4WD/AUTO/diff locks/parking brake/wind-up;
- `RMS_SpecService.lua` / `RMS_FluidWorkshop.lua` — service/economy transaction;
- `RMS_SpecSaveLoad.lua` / `RMS_SpecStreams.lua` — persistence and network state;
- `RMS_SpecVehicleState.lua` — sampled authoritative inputs;
- `RMS_Consumptables.lua` / `RMS_FluidTransfer.lua` / `RMS_HandTools.lua` — field care and physical fluids.

## Vehicle ownership

The specialization is injected into compatible vehicle types and then registration is runtime-gated.

Type-level requirements:
- `motorized`;
- `wheels`;
- `enterable`.

Rejected classes include attachables, push hand tools, locomotives and motorbikes.

Runtime registration requires:
- property state OWNED, LEASED or MISSION;
- a valid non-spectator owner farm;
- RMS not suppressed by Advanced Damage System;
- the RMS specialization present.

This is a good capability-first model compared with filename allowlists.

## Scheduler hierarchy

Configured cadences:
```text
rendered frame            onUpdate / postUpdate / postUpdateTick
50 ms                     state snapshot group 1
100 ms                    fast RMS control/effect path
200 ms                    state snapshot group 2
250 ms                    fleet-distributed core simulation
500 ms                    state snapshot group 3
30,000 ms                 metadata / roof / weather refresh
```

### Frame path

Every active specialization update:
- updates field-inspection sound;
- advances state-snapshot timers;
- server updates transmission thermal only;
- refreshes start-button action events;
- advances preheat;
- client post paths ease exhaust presentation and restore final native exhaust heat.

### 100 ms path

`onUpdate` accumulates `dt`; once >=100 ms it uses modulo and executes one fixed `updateDt=100` step.

Responsibilities include:
- vehicle registration;
- temperature smoothing;
- fuel/motor-load derived state;
- dead-battery/voltage/air-filter/overheat state;
- warning and AI control;
- drivetrain update;
- breakdown active functions;
- client exhaust targets;
- vanilla damage reset.

Missed 100 ms intervals are deliberately discarded rather than replayed.

### State snapshots

`RMS_SpecVehicleState` has three bounded sampling groups.

50 ms:
- PTO state and engagement transitions;
- differential acceleration window;
- dynamic motor load.

200 ms:
- starter state;
- wheel slip;
- chassis vibration;
- low-speed steering;
- braking under mass.

500 ms:
- active draft stats;
- wheel-ground state;
- attached implement chain/lifted mass;
- fuel state;
- roof state.

These timers also use modulo and execute only once after a delayed frame. This bounds work, but elapsed state integration can be under-counted after a long hitch.

### 250 ms core scheduler

`RMS_Main` does not update the complete fleet in one burst under normal timing.

It computes:
```text
timePerVehicle = CORE_UPDATE_DELAY / numVehicles
vehiclesToUpdate = floor(updateAlphaTimer / timePerVehicle)
```

It then rotates through `RMS_Main.vehicles`, calling each selected vehicle with a fixed `rmsUpdate(250, workshopOpen)`.

Core work includes:
- real operating-time accumulation;
- engine thermal only;
- battery charging model;
- active service progress;
- radiator/air-filter state;
- breakdown progression and new failure rolls;
- service level;
- eight system wear models;
- overall condition and general wear;
- lubrication and physical fluid levels;
- overload rolling state;
- dirty-group comparison.

### Thermal split

Prior-chat hypothesis of duplicate thermal integration is rejected by source.

`onUpdate(dt)` calls:
```lua
updateThermalSystems(dt, false, true)
```

`rmsUpdate(250)` calls:
```lua
updateThermalSystems(dt, true, false)
```

Therefore transmission thermal is responsive at the active-vehicle/frame cadence while engine thermal is part of the distributed core scheduler. This is an intentional split-rate architecture.

## Catch-up behavior

The core scheduler carries timing debt in `updateAlphaTimer`. After a long frame it may process multiple 250 ms-equivalent vehicle slots, including multiple full rotations of the fleet.

Positive:
- core wear/service time is not silently lost;
- long-term rate stays closer to elapsed simulation time.

Risk:
- there is no per-frame catch-up budget;
- a severe hitch can cause a large number of heavy core updates on the recovery frame, amplifying the hitch.

A possible improvement is a bounded catch-up budget that keeps residual debt for following frames.

## Per-frame fleet wake scan

Before scheduling core work, the server loops over every registered RMS vehicle every frame. Any non-excluded inactive vehicle with motor state ON receives `raiseActive()`.

This supports unattended running engines and keeps their per-frame/100 ms RMS paths alive, but it makes fleet-size work proportional to rendered server frames.

Potential alternatives to study:
- event-driven motor-state activation;
- a lower-frequency wake scan;
- a dedicated set of running/inactive RMS vehicles maintained on motor transitions.

Do not patch this until runtime profiling proves the scan material at realistic fleet sizes.

## Cadence principle

RMS mixes three timing strategies:
1. actual frame `dt` for responsive state;
2. fixed-step sampled updates that intentionally discard missed intervals;
3. a debt-carrying distributed core scheduler.

That mixture is not inherently wrong, but every state accumulator should be classified as:
- instantaneous sample;
- real-time integrator;
- bounded-control loop;
- stochastic hazard;
- presentation.

Future passes should flag any variable whose semantics do not match the timing strategy used.