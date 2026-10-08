# ADR 0005 — Selective 4WD automation and active hydraulic suspension

Status: **research decision / implementation deferred**  
Date: 2026-10-08

## Question

Should RealismExtensions (RE) absorb **FS25_4x4TractionSystem 1.7.0.0** and **FS25_HydraulicSuspensionSystem 1.0.0.0** in the user's MoreRealistic + Mud 1.3.6 + Reifen 1.2.2.70 + RMS 0.11 stack?

Evidence: prior **exact-package source audits** of both versions were discussed on 2026-10-06; this ADR is the architectural synthesis, **not** a new binary/hash verification or in-game validation. The older [4x4 preliminary note](../audits/realistic-4x4/PRELIMINARY.md) predates those later audits. Relevant sources:
- Current 4WD published [v1.7 description](https://fs25.net/realistic-4x4-traction-system-v1-0/)
- Current [hydraulic v1.0 description](https://fs25.net/hydraulic-suspension-system-v-beta/)
- RC [RMS 0.11 audit](https://github.com/rafaaelalves/FS25_RealismCompatibility/blob/main/docs/audits/2026-10-07-rms-0.11.0-audit.md)
- [ADR 0002](0002-no-second-traction-or-sink-model.md), [ADR 0004](0004-specialist-ownership-is-provisional.md)

## Verdict

1. **4WD:** Do **not** absorb the external drivetrain or differential solver. Selectively redesign the *sensor / decision / request* capability of 2WD/4WD/AUTO/SMART and diff-lock control. Ideally enhance **RMS**, the existing differential topology, windup, damage, lifecycle, persistence and networking owner. Only place an RE policy/UX module above RMS **if** RMS exposes a stable, versioned command/capability boundary. Do not write differential physics directly from RE or duplicate MRRMS bridge.
2. **Hydraulic suspension:** **Conditional candidate for future clean-room RE implementation**, higher potential value than another 4WD solver. Separate:
   - **ActiveSuspension:** ride-height target, self-leveling/load response, AUTO/WORK/LOCKED/MANUAL policy, real bounded stroke/damping corrections;
   - **LoaderRideControl:** only if actuator is demonstrably bound to suitable vehicle/loader hydraulics; never report "active" while only computing a target;
   - **CabIsolation:** client-side visual/camera comfort, subordinate to actual suspension behavior.
3. **CTIS from 4WD:** Reject current implementation's direct `wheel.physics.radius` manipulation; Reifen owns worn structural radius, Mud contact/sink/pressure and RC coordinates the physical state. Separate future `TirePressureState` would need unit semantics, a capability contract, a single radius owner and controlled behavior per tire/track, not a visual radius hack.
4. **Whole-mod absorption:** Neither justified. Avoid source/asset reuse without licensing clearance. New behavior must be designed independently and reviewed against owner contracts.
5. **Today:** no runtime implementation or bridge. Focus remains active RE/RC stabilization and tests.

## Detailed 4WD reasoning

- RMS 0.11 already reconstructs differential topology, as verified in RC compatibility analysis. Reifen derives/caches wheel torque shares from GIANTS' differential graph and lacks a topology-revision contract from RMS. Adding a *third* system that rebuilds differentials would intensify an existing owner disagreement.
- Useful intelligence: sustained wheel slip, steering angle, brake/reverse rejection, lowered-implement draft, rear axle demand, slope, road speed, load, hysteresis, cooldown/hold, reason codes and confidence. Distinguish engagement request **policy** from actual axle/differential actuation.
- State pipeline concept:
  `MR/Mud/Reifen/RMS measured state -> policy observations -> engagement demand -> RMS accepted command -> RMS actual differential state -> UI`.
- `AUTO` should not be a duplicate fake traction solver, and `SMART` continuous demand must be supported by real actuator semantics; otherwise fall back to valid discrete modes. Engine/load and wheel-slip providers must have defined units/staleness.
- Previous 1.7 source audit found incomplete networked capability state: `manualTirePressure` initializes `hasCtis/ctisMode` in onLoad, menu changes did not rebind and some capability flags were not streamed while CTIS state was. A copy would import this MP fragility.
- Source behavior also assumes compatible differential graphs and vehicle categories. Classify per vehicle **SUPPORTED / READ_ONLY / UNSUPPORTED**, never attach blindly.
- No new RC bridge until an RMS command provider exists or logs prove a missing capability; consider an upstream RMS proposal first.

## Detailed suspension reasoning

- Unique benefits if physically realized: load/implement self-leveling, damping adaptation for work/transport, supported rigid front axle articulation, independent front suspension for compatible machines, realistic front-loader ride control. The user wants materially stronger physical realism, not only animation or mod count reduction.
- The published HSS 1.0.0.0 claims front spring/damper ownership over MR where HSS controls the front. Our 2026-10-06 source audit found HSS directly writing suspension/moving-tool properties and suppressing or displacing MR values. **Do not transplant that mechanism.** Treat MR/vanilla as the baseline and design one *agreed effective actuator*, with owner negotiation and bounded correction, not per-frame competing writes.
- Proposed physical controller:
  `vehicle declared suspension hardware + bound actuator -> measured stroke/load/chassis dynamics + MR baseline -> AUTO/WORK/LOCKED/MANUAL target -> filtered feedback (deadband, rate limits, saturation, anti-windup) -> one authorized actuator -> measured/replicated result`.
- Three separate states: `detected` hardware, `bound` usable actuator, `active` executing control. For unsupported visual skeleton / absent movingTool binding, fail inert rather than silently simulate a floating suspension.
- HSS prior source findings: `HSS-21` LoaderRideControl may claim active without bound actuator; `HSS-22` direct movingTool writes; `HSS-23` lifecycle teardown guard; `HSS-25` locally reconstructed MP visuals a promising pattern; `HSS-27` monolithic specialization needs separation. These are investigation markers, not new tests.
- Distinguish pendulum axle geometry, genuine independent suspension, spring/damper physics and cab camera interpolation. Suspension animation should follow collision/physical wheel movement; never fake contact forces or overwrite MR's load-aware spring correction unless provider arbitration deliberately chooses the single result.
- Vehicle profile/hardware evidence matters (make/model and model XML nodes); restrict first prototype to **one verified front-suspension architecture/tractor**. Larger brand autodetection is a later capability.
- Network: server-authoritative mode/target/physical control; client-side visuals interpolate canonical stroke/mode. Save/load preserves per-vehicle mode/target and can rebuild missing movingTools gracefully. Work when vehicle AI (Courseplay/AutoDrive), stopped, sold, detached, unloaded; no stray dynamic wrappers.

## Comparison / gates

| Criterion | 4WD decision policy | Active suspension |
|---|---|---|
| Missing gameplay phenomenon | moderate: RMS already offers basic 2WD/4WD/AUTO | stronger: adaptive hydraulic ride height & leveling often absent |
| Existing owner conflicts | severe if physical differential solver introduced | severe if MR spring/damper writes compete |
| Potential safe RE slice | small, *only when RMS has request API* | standalone, bounded actuator module *only with one-owner arbitration* |
| Scope | sensor + policy + state display | hardware profile + sensor + stroke/control + MP visual |
| Prototype requirements | 2WD vs 4WD low-slip/high-slip, brake, reverse, steering, hill, implements, save/MP and Reifen topology | loaded vs unloaded, bump, braking, loader operation, true stroke change, suspension energy, MR hook chain, MP and save/teardown |
| Upstream route | **Prefer RMS improvement** | New RE module candidate after physical proof |

## Experiments — no gameplay build authorized yet

**4WD A–H**: choose same capable tractor and controlled conditions; verify RMS current 2WD/4WD/AUTO behavior before claiming gap, brake/reverse rejection, differential topology/lead, MRRMS driven wheel refresh, Reifen force-wear cache, Mud slip/wetness, decision hysteresis and frame-rate independence, Courseplay/AutoDrive behavior, identical result across client/server including settings. A policy that cannot command RMS cleanly is not ready to implement.

**Hydraulics J–P** (from earlier 2026-10-06 audit):
- **J**: MP configuration/mode authority, latency and join;
- **K**: cabin isolation visual and camera ownership;
- **L**: loader stabilizer truly bound to actuators, not false "active";
- **M**: controller auto-level/WORK/LOCKED, stroke and damping against MR baseline, load/bump;
- **N**: lifecycle save/load/delete/sell/teardown;
- **O**: Settings menu and local vs gameplay configuration;
- **P**: client reconstruction of visual articulation after reload/join.

**Promotion bar:** measured real physical benefit, no competing writes, bounded per-vehicle CPU and MP traffic, clear failure/inert behavior, no lost MR/Mud/Reifen/RMS consequence, predictable save/load and AI parity. If benefit is only presentation, scope it as a presentation module and do not call it active physics.

## Status

**Decision recorded. No RE/RC runtime files, tests, build, feature branch, or experimental implementation created by this ADR.** Reassess after a focused one-tractor hardware/actuator feasibility spike; preserve historical exact ZIP/source notes if retrieved.
