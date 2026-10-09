# Native PTO V1.5 — implement response without duplicate physics

Date: 2026-10-09
Status: scoped research and implementation priorities. No runtime changes in this branch.

## Starting point: V1 is on main

- RE PR #33 merged into main at `2534cec4530b4839b608613c0c80453fc1bc5d58`.
- Paired RC PR #16 merged at `ad7461fb7777691f6f64e2327753417c95b6177b`.
- User operator has supported 540/540E/1000/1000E selections, direct hand throttle and mechanical-ratio translation.
- GIANTS/MR AI controls its own engine RPM; RE chooses an available nominal family at AI start and restores the player's gear after disengagement.
- Terrain experimental code is a separate development stream. This PTO roadmap does not alter it.
- V1 AI end-to-end was tested in Lua harness and built by CI, **not** independently proven during successful field work; user's test was obstructed by existing deep ruts. Keep this limitation visible but don't demand repeated save/load tests as a prerequisite for unrelated PTO improvements.

## Exact MR 0.26.10.08 source findings

Source reference: `quadural/MoreRealistic_FS25@b38d5667e073505255cd7ce170ab568616a91221`.

| Component | Confirmed MR behaviour | Consequence for RE |
|---|---|---|
| `MR_PowerConsumer.lua` | Carries `mrPtoCurrentRpm` and `mrPtoCurrentRpmRatio`, supplies torque/power demand; draft force depends on lower shaft-RPM ratio for power harrows and spaders | Don't duplicate torque/fuel/draft penalties |
| `MR_WoodCrusher.lua` | Pauses feeding below `mrPtoCurrentRpmRatio < 0.78`; also pauses for other feeding/power/processing limits | Confirm ratio translation at runtime rather than creating a second wood-chipper limiter |
| `MR_Baler.lua` | Implements input-rate-dependent loading and square-baler plunger power spikes | Do not infer this already scales bale throughput/stroke rate with shaft RPM |
| `MR_WheelsUtil.lua` | Uses `neededPtoTorque` and automatic PTO RPM demand to influence fixed/CVT/hydrostatic motor operation | MR remains authoritative for drivetrain/governor and causal load |
| `MR_PowerConsumer.lua` onLoad | Normalizes declared `ptoRpm > 540` to 540 and rescales needed PTO power in its internal model | RC already scopes the RE mechanical ratio around `mrUpdatePtoPower`; don't compare the raw normalized MR 540 field to the manufacturer's original 1000 requirement |

`MRPTO.getCausalitySample` currently emits `kinematicPtoRpm` from engine RPM / selected ratio, not a directly measured independent PTO shaft sensor. It reports the selected and required shaft families separately. RE's HUD reads the same estimated RPM only when the PTO implement is engaged.

## Ownership contract (must remain intact)

1. **RE:** physical gearbox choice, operator state, exact implement nominal family, machine-specific control/integration when missing, HUD.
2. **MR/GIANTS:** actual physical engine speed, motor load, power, torque, fuel, transmission response and existing machine semantics.
3. **RMS:** mechanical PTO utilization, damage and wear.
4. **RC:** narrow translation between RE state and MR/RMS; never manufacture another persistent shaft state or global synthetic load.
5. **Dynamic PTO:** reference to compare solutions, not a runtime dependency or a license to import indiscriminate work-speed/power multipliers.

## Roadmap, ordered by real value

### P1 — truthfulness and observability

- Make the distinction *selected nominal gear* vs *kinematic RPM estimate* consistently explicit in UI, telemetry and docs.
- A lightweight optional HUD/console readout may present engine-RPM-derived PTO speed, `requiredShaftRpm`, current ratio and percent, but must not claim an independently measured shaft sensor or overload diagnosis.
- Add **event-driven** AI-gear/saved-state diagnostics sufficient to distinguish a missed AI callback from underpowered operation without high-frequency tracing and without making the user redo completed tests.
- Cross-check worker lifecycle with GIANTS events and Courseplay version 8.1.0.3. A source audit of an API/event isn't in-game confirmation of successful powered work.

### P2 — specific actual implement responses, not a universal multiplier

- **Wood chippers:** use existing MR feed pause and power protections first. Investigate only confirmed gaps such as non-MR native fallback or inconsistent nominal 1000 translation.
- **Augers / pumps / conveyors with a real mechanical PTO:** identify GIANTS throughput hooks; if a specific class is not already speed-aware and has enough source evidence, model flow/cycle behaviour from effective drive speed, with realistic minimum cutoff as appropriate. Keep hydraulic/electric-powered machines OUT of PTO classifiers.
- **Mowers, tedders, rakes, power harrows:** investigate whether under-speed affects processing quality or workable forward speed. MR already models power-harrow/spader draft penalty, so only missing output semantics are candidates.
- **Balers:** the physical mechanism distinguishes pickup/feeding from compression/stroke cycles. Investigate whether the cycle frequency and material intake respond to PTO speed; do not multiply feed or delivered bale count blindly because MR already models power transients.
- **Clutches/shear pins:** only after studying GIANTS input/output PTO semantics and RMS failure ownership; distinguish slip/disengagement/protection from an engine stall. Reject always-stall behaviour.

### P3 — machinery diversity only on evidenced demand

Front/rear independent power take-offs; installed options, transmission hardware, specialized nominal speeds (e.g. 750/1300), multiplayer authority and implement dynamic inertia. No horsepower-based 1000 RPM assumption. No blanket ratios for all equipment.

## Technical acceptance without endless manual tests

- Source audit -> identify unowned behaviour -> smallest hook/API -> unit/harness assertions -> CI and paired artifact -> **one** targeted runtime session only where source cannot prove GIANTS behaviour.
- No repeated save/reload request for existing operator mode and hand throttle. Re-open only with a concrete regression.
- Every code patch needs negative cases: non-PTO implement, unknown or conflicting nominal family, selected 540 vs tool 1000, disabled machine, no MR/RC fallback, worker and player ownership.
- Use targeted before/after evidence: `mrPtoCurrentRpmRatio`, actual physical engine RPM, `neededPtoTorque`, operation rate, and MR/RMS existing state. Don't use unrelated terrain blockage as a PTO failure metric.
- No new synthetic load, fuel, generic machine throughput multiplier or engine-stall mechanic unless independent evidence supports that specific implement/system.

## Immediate next coding unit

**Operator-facing live PTO RPM observability, plus event-only AI gear diagnostics**, in an isolated `feat/pto-v1-5-observability` branch based on main. It can reuse already available engine RPM/ratio and avoids touching MR, RMS, RC or any terrain branch. Only once speed/ownership are observable should we add a distinct implement behaviour where MR lacks it.

Do not merge research-only changes into the ongoing experimental terrain branches.
