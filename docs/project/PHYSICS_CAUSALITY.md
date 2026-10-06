# Physics causality and derived consequences

Updated: 2026-10-06

## Principle

RE/RC should prefer **causal physical state** over direct consequence patches.

A subsystem should modify the quantity it actually owns. Downstream
consequences should emerge from the existing simulation whenever that simulation
already models the causal chain.

Examples:

- PTO/implement work:
  implement torque/power demand -> drivetrain/engine load -> engine power ->
  fuel model. Do **not** add an arbitrary "PTO active = +X fuel" modifier.
- Tire pressure:
  pressure -> contact/traction/rolling/sink behaviour -> drivetrain demand ->
  engine load -> fuel. Do **not** make the tire-pressure system write fuel use.
- Mud:
  local wetness/sink/slip/resistance -> wheel/drivetrain demand -> motor load.
  Do not add a second generic motor-load penalty when MR already owns drivetrain
  load.
- Wear:
  wear should alter its physical/material property first; performance,
  efficiency or maintenance consequences should derive from that property where
  possible.

## Ownership consequence

This principle reinforces the project boundary:

- specialist mods own their physical domain;
- RC composes/normalizes overlapping specialist state and removes duplicate
  effects;
- RE adds missing persistent consequences/features;
- downstream systems should not receive duplicated synthetic penalties merely
  because an upstream state is active.

A direct consequence modifier is acceptable only when:
1. the game/specialist simulation has no usable causal path;
2. the missing relationship is explicitly identified and documented;
3. the chosen approximation has a clear owner and does not double-count another
   model.

## Fuel-specific checkpoint

MoreRealistic already follows a causal fuel path in its
`Motorized.mrUpdateConsumers` implementation. Its fuel factor is primarily
derived from actual engine power/load (applied torque × RPM), with a smaller RPM
component and an efficiency correction. It does not require a PTO-active or
tire-pressure fuel surcharge.

Therefore any surprising fuel result must first be traced through:
- actual engine RPM;
- applied/external torque;
- MR load values;
- PTO torque / required RPM;
- wheel resistance/slip/pressure;
- the final `lastFuelUsage` value;
- wrappers around `Motorized.updateConsumers`.

Do not patch fuel consumption until this causal chain is proven incomplete.

## Current compatibility alignment

The existing RC MRMud policy is consistent with this principle:
- MR retains baseline rolling resistance/drivetrain ownership;
- Mud retains extra sink/slip/excavation resistance;
- Mud's separate artificial motor-load injection is disabled while MR owns the
  drivetrain;
- duplicated Mud baseline resistance is suppressed.

This is deliberate: the additional terrain resistance should reach fuel use by
making the drivetrain do more physical work, not through an independent fuel
multiplier.

## Diagnostic rule

Telemetry/probes may reproduce or expose intermediate values but must remain
read-only and must not become gameplay logic.

The native PTO study now uses RC causality telemetry to observe, together:
engine RPM, selected/required/actual PTO RPM, hand-throttle target, MR PTO
minimum RPM state, applied/external torque, load, fuel rate, consumed PTO torque
and, when Mud is available, tire pressure/slip/drag.
