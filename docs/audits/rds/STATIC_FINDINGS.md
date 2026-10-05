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
