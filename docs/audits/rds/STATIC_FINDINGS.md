# RDS 1.2 static findings

Baseline: `FS25_RealisticDieselStart 1.2.0.0`, SHA-256 `e22816e712ef6a48c8f0210209f9983a7c4da3bc55a6267a7fbaad5c5f6bacbd`.

Labels: **CONFIRMED_STATIC**, **DESIGN_RISK**, **UPSTREAM_CHANGE_REPORTED**, **POSITIVE_PATTERN**.

## High-value findings

### RDS-01 — diesel sequence is injected into every motorized type
**CONFIRMED_STATIC / HIGH**

Registration adds the specialization to every vehicle type with `motorized`. Runtime excludes electric vehicles, but the source does not require an explicit diesel consumer.

RE: explicit diesel capability/profile first. Do not give gasoline/unknown vehicles glow-plug semantics by default.

### RDS-02 — input timing contains a dead band
**CONFIRMED_STATIC / MEDIUM-HIGH**

Short press is <=400 ms; crank triggers at >=550 ms. Releasing at 401–549 ms performs neither action.

RE: complete press/hold state machine with no uncovered duration.

### RDS-03 — start interlock is a virtual clutch
**CONFIRMED_STATIC / DESIGN_RISK**

RDS has its own clutch input used only for starting, independent of actual drivetrain clutch state. Public 1.4 changelog moved the binding from L to Alt+L after a real FS25 input collision.

RE: consume real clutch/neutral/brake interlock where authoritative state exists; fallback input only if necessary.

### RDS-04 — RDS owns a duplicate engine-temperature model
**CONFIRMED_STATIC / HIGH**

RDS persists `engineHeat`, maps it from ambient to an 85 C operating target and uses it for glow/warm-up.

RMS/ADS already own deeper thermal state. RE should use a provider and only have a minimal standalone fallback.

### RDS-05 — cold warm-up directly mutates `motor.torqueScale`
**CONFIRMED_STATIC / HIGH**

RDS caches the motor's torque scale and writes a 65%->100% cold derate.

This collides with MR/RMS ownership. RE should not write shared motor torque directly.

### RDS-06 — cold-driving damage is a speed heuristic
**CONFIRMED_STATIC / HIGH**

Before 70 C, speed above 8 km/h accumulates generic vehicle damage at a fixed rate.

Speed alone is not a defensible cold-engine stress proxy. Load/RPM/lubrication/thermal state matter, and generic damage is the wrong domain.

RE: expose cold-operation state to RMS/ADS rather than porting this formula.

### RDS-07 — start failure randomness is player-path/local
**CONFIRMED_STATIC / HIGH**

`tryCrank()` computes a temperature/preheat failure probability and rolls `math.random()` before the generic damage path reaches the server.

RE: mechanically meaningful start outcomes should be server authoritative.

### RDS-08 — client damage event is under-authorized
**CONFIRMED_STATIC / HIGH**

The client->server event accepts a synchronized vehicle and float amount, then applies damage. It does not bind the request to the controlling connection or derive the consequence on the server.

RE: client sends start intent; server derives legal consequence.

### RDS-09 — no full initial air-state stream
**CONFIRMED_STATIC / HIGH**

RDS source explicitly removed specialization initial-stream sync because its dynamic injection could disturb vehicle stream order. Pressure arrives later through broadcast events.

RE's native specialization can avoid this compromise: full initial stream plus semantic dirty sync.

### RDS-10 — service-brake air usage drains continuously while held
**CONFIRMED_STATIC / PHYSICS HIGH**

RDS subtracts pressure continuously from:

`0.25 bar/s * brakePedal * speedFactor * loadFactor * dt`.

This treats reservoir air as braking energy. A pneumatic system primarily consumes air when chamber/circuit pressure is changed; a stable held application should mainly expose leakage after the initial pressure drop.

RE: application/pressure-change model, separate leakage.

### RDS-11 — compressor fill rate ignores engine RPM
**CONFIRMED_STATIC / MEDIUM**

Pressure rises at one constant bar/sec whenever engine ON and governor loaded.

RE: at least an RPM-normalized compressor-rate model/profile.

### RDS-12 — one scalar reservoir hides system topology
**CONFIRMED_STATIC / DESIGN LIMIT**

RDS uses one `airPressure`. This is acceptable only as an MVP equivalent reservoir.

RE architecture should permit later supply/primary/secondary/trailer circuits without breaking the API.

### RDS-13 — pneumatic eligibility relies on truck/category heuristics
**CONFIRMED_STATIC / MEDIUM**

Air capability is inferred from store/category identity rather than an evidence-backed pneumatic profile.

RE: explicit capability/profile resolver.

### RDS-14 — leakage depends on vanilla generic damage
**CONFIRMED_STATIC / MEDIUM-HIGH**

Leak rate is driven by `getDamageAmount()`. RMS deliberately makes vanilla damage unsuitable as a mechanical-health signal on managed vehicles.

RE: normalized pneumatic/mechanical condition provider, not vanilla damage.

### RDS-15 — spring brake is speed-gated and lacks hysteresis
**CONFIRMED_STATIC / PHYSICS HIGH**

Below 3.5 bar the state is engaged, but full physical braking is only forced above 5 km/h. Apply/release use the same threshold.

RE: continuous brake-state/force ownership with appropriate hysteresis/profile thresholds; compose with MR/RMS rather than a speed-triggered call.

### RDS-16 — spring brake directly owns service brake lights
**CONFIRMED_STATIC / MEDIUM; UPSTREAM_CHANGE_REPORTED**

1.2 forces brake lamps with spring-brake state. Public 1.4 changelog says this was fixed after causing parked battery drain with another realism mod.

RE: service brake lamps follow service demand, not parking/spring state by default.

### RDS-17 — visual RUNNING is written before authoritative confirmation
**CONFIRMED_STATIC / MEDIUM; UPSTREAM_CHANGE_REPORTED**

The successful crank branch calls `startMotor()` then immediately writes electronics/visual-running/dashboard state. Public 1.3 changelog reports fixing an engine that appeared running when startup did not actually occur.

RE: visual state follows authoritative transition.

### RDS-18 — ignition visual compatibility writes run twice per frame
**CONFIRMED_STATIC / MEDIUM**

The same compatibility visual-state function runs in both `onUpdate` and `onPostUpdate`.

RE: avoid duplicated per-frame ownership writes.

### RDS-19 — broad light/electrical overwrite surface exceeds start ownership
**CONFIRMED_STATIC / MEDIUM**

RDS overwrites motor/electronics/dashboard getters plus multiple light/high-beam/beacon/turn/hazard paths.

RE should own contact intent, not become a second electrical/battery/light simulation.

### RDS-20 — one global glow curve cannot represent diesel generations
**CONFIRMED_STATIC / MODEL LIMIT**

1.2 uses one 1.5–25 s temperature curve for all vehicles. Real glow technology spans roughly old ~20 s systems to modern ~2 s high-speed/ceramic systems.

RE: profile glow technology (legacy / quick / modern / none), not one universal curve.

### RDS-21 — AI bypass and air readiness were not fully coordinated
**CONFIRMED_STATIC / DESIGN RISK; UPSTREAM_CHANGE_REPORTED**

Manual start UX is bypassed for AI, but public 1.3 changelog reports a helper freeze while air filled.

RE: AI skips gestures but automatically satisfies readiness with bounded fail-safe logic.

### RDS-22 — settings/HUD are another independent global UI surface
**DESIGN_RISK**

RDS clones/settings-patches native UI and maintains a separate HUD. This is exactly the fragmentation RE is already reducing.

RE: central settings plus shared controlled-entity HUD.

## Positive patterns worth retaining conceptually

- **RDS-P01:** staged contact -> preheat -> ready -> crank interaction.
- **RDS-P02:** governor hysteresis rather than one compressor threshold.
- **RDS-P03:** server-owned pneumatic pressure.
- **RDS-P04:** thresholded/quantized air-state sync.
- **RDS-P05:** pressure persistence and elapsed-time leakage concept.
- **RDS-P06:** HUD anchored to the speedometer/UI scale rather than fixed pixel assumptions.
- **RDS-P07:** defensive clamping/sanitization around external values.

## Source-audit conclusion

RDS is a good **behavioral reference**, not a source-port target. The strongest reasons to absorb are the ignition UX and unique pneumatic capability; the strongest reasons to redesign are mechanical ownership, networking authority and the air-brake model.


## Exact 1.4 status review

Current exact baseline: `FS25_RealisticDieselStart 1.4.0.0`, SHA-256 `a2a983c7754bc4fb3dffc04839fb16cf844c72d7664ae78cfcd70fcf3c15721c`.

| Finding | 1.4 status | Notes |
|---|---|---|
| RDS-01 broad motorized eligibility | **PRESENT** | still injects into every motorized vehicle type and explicitly excludes only electric |
| RDS-02 400/550 ms dead band | **PRESENT** | release at 401–549 ms still does nothing |
| RDS-03 synthetic start clutch | **PRESENT / improved migration** | moved to Alt+L; one-time default-binding migration preserves custom mappings |
| RDS-04 duplicate engine temperature | **PRESENT** | `engineHeat` remains authoritative for RDS preheat/warm-up |
| RDS-05 direct torqueScale cold derate | **PRESENT** | unchanged ownership concern |
| RDS-06 speed-based cold damage | **PRESENT** | unchanged ownership/model concern |
| RDS-07 local start randomness | **PRESENT** | `math.random()` remains in local `tryCrank` |
| RDS-08 under-authorized damage event | **PRESENT** | no controller/amount derivation on server |
| RDS-09 no full air initial stream | **PRESENT** | source still explicitly documents the compromise |
| RDS-10 continuous held-brake air drain | **PRESENT** | speed/mass-scaled formula remains |
| RDS-11 compressor ignores RPM | **PRESENT** | constant bar/sec remains |
| RDS-12 one scalar reservoir | **PRESENT** | external getter/setter added, topology unchanged |
| RDS-13 truck category heuristic | **PRESENT** | unchanged |
| RDS-14 vanilla damage leakage | **PRESENT** | unchanged |
| RDS-15 speed-gated spring brake | **PRESENT** | unchanged |
| RDS-16 spring brake owns brake lights | **FIXED** | 1.4 deliberately stops touching service brake lights |
| RDS-17 visual running before confirmation | **FIXED** | request is verified and later `onStartMotor` can confirm external hard-start completion |
| RDS-18 duplicate visual writes | **PRESENT** | still called in update + post-update |
| RDS-19 broad light/electrical ownership | **PRESENT / partially softened** | persistent lights behavior improved, overwrite surface remains |
| RDS-20 one global glow curve | **PRESENT / recalibrated** | max/slope improved; still one technology curve |
| RDS-21 AI pneumatic deadlock | **FIXED BY ABSTRACTION** | AI pressure is forced to at least governor cut-in; effective but physically magical |
| RDS-22 independent HUD/settings | **PRESENT / much improved** | scale/ADS coexistence better; surface is larger |

## New 1.4 findings

### RDS-23 — ADS compatibility is private-contract-heavy
**CONFIRMED_STATIC / HIGH MAINTENANCE RISK**

RDS writes ADS private start-button fields directly and optionally invokes `ADS_StartButtonEvent.send`. It also globally wraps `Motorized.actionEventToggleMotorState` to suppress the vanilla/ADS direct path for RDS-owned vehicles.

The composition is clever and fixes real behavior, but it is brittle across ADS updates.

RE lesson: a `StartMechanicalProvider` should own this boundary. External private adapters, if unavoidable, belong in RC.

### RDS-24 — event-confirmed external start is a strong positive pattern
**POSITIVE_PATTERN**

When another system owns a difficult start, RDS stays in external CRANKING and waits for `onStartMotor` before declaring success.

This is substantially better than assuming a command succeeded.

### RDS-25 — optional fuel-system methods are a strong provider precedent
**POSITIVE_PATTERN**

RDS detects `scGetColdStartFactor` / `scGetStartBlockReason` by capability and lets the fuel owner explain start refusal.

This directly supports RE's provider-oriented design.

### RDS-26 — absolute pneumatic setter has weak conservation semantics
**DESIGN_RISK**

The new Realistic Brakes boundary exposes server-only `rdsSetAirPressure(bar)`.

It is much better than private-table writes, but a consumer can replace reservoir pressure without an explicit conservation/transaction invariant.

RE: expose capacity/volume plus transfer operations, or an atomic owner-managed transfer request.

### RDS-27 — keybind migration is a reusable positive pattern
**POSITIVE_PATTERN**

The one-time L -> Alt+L migration changes only the obsolete exact default, preserving custom player mappings.

RE should reuse this principle for future input migrations.

### RDS-28 — the migration notification adds an unnecessary global hot hook
**CONFIRMED_STATIC / LOW PERFORMANCE DESIGN ISSUE**

A global `FSBaseMission.update` append exists solely to count down a 6-second one-time notification timer.

The work is tiny, but the architectural lesson matters: reuse the project core scheduler/update owner rather than creating a permanent global hook for a temporary concern.

### RDS-29 — HUD scale invalidation is a positive optimization pattern
**POSITIVE_PATTERN**

The HUD subscribes to UI-scale changes and recalculates cached geometry only when needed.

This should inform the RE shared HUD.

### RDS-30 — HUD has dead resources/state and lifecycle leaks
**CONFIRMED_STATIC**

In 1.4:
- `showBar` is never set true;
- `statusText` is never assigned;
- `readyBlinkTimer` continues to be maintained after blinking was removed;
- `barBg` and `barFill` are still allocated for a progress bar path that never renders;
- `tickMark` is allocated and never used;
- `tickMark` is not deleted;
- `rdsHudSinADS` is registered but not removed by `RDSHud:delete()`.

This deserves a second-save lifecycle test upstream and is a useful RE cleanup/CI lesson.

### RDS-31 — 1.4 runtime version string is stale
**CONFIRMED_STATIC**

The archive's main script still prints:
`[RealisticDieselStart] Script principal cargado (v1.2.0.0)`.

RE's generated BuildIdentity avoids this class of provenance error.

### RDS-32 — warm-up description claims RPM/load but implementation uses load only
**CONFIRMED_STATIC / DOCUMENTATION-MODEL DRIFT**

1.4 comments describe warm-up as RPM/load-sensitive. The implementation samples `getSmoothLoadPercentage()` but does not sample engine RPM.

The load-sensitive progression is still a useful improvement, but its calibration/provenance should match the actual model.

### RDS-33 — per-vehicle ADS HUD ownership check is a positive pattern
**POSITIVE_PATTERN**

HUD coexistence checks whether ADS actually manages the current vehicle, including ADS exclusions, instead of only checking whether the mod is installed.

General rule: resolve capability ownership per entity, not per installed package.

## Updated conclusion

The 1.4 source materially improves compatibility and presentation quality, but the original architectural absorption recommendation remains intact.

The most valuable new lessons are:
- event-confirmed outcomes;
- optional capability APIs;
- safe input migration;
- event-driven HUD scale invalidation;
- per-vehicle owner resolution.

The strongest remaining reasons not to clone RDS are:
- private ADS coupling;
- local stochastic authority;
- duplicate thermal/torque/damage ownership;
- weak pneumatic physics;
- lifecycle/dead-state accumulation.
