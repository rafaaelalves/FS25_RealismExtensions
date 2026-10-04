# MudSystemPhysics static findings ledger

Current baseline: MudSystemPhysics `1.3.4.0`, SHA-256 `268f64f03c14ae003c16a6a66d5841485c1cd5a1f82393350593ea00daca1f1e`.

Evidence labels:
- **CONFIRMED_STATIC**
- **STRONG_CANDIDATE**
- **DESIGN_RISK**
- **POSITIVE_PATTERN**
- **RUNTIME_PENDING**

## MUD-01 Same version number identifies multiple source builds
**CONFIRMED_STATIC provenance issue**

The earlier audited package and the current uploaded package both declare `1.3.4.0`, but their hashes and source trees differ.

Earlier:
`29a6a58005eadfed7d7d2530ae5b8964fc314fe4aadbe65837ba6e54ac9828ef`

Current:
`268f64f03c14ae003c16a6a66d5841485c1cd5a1f82393350593ea00daca1f1e`

Version-only source evidence is therefore insufficient for this Mud line.

## MUD-02 Core RC local-wetness/terramechanics contracts are unchanged
**CONFIRMED_STATIC positive compatibility result**

The files owning the RC-sensitive local wetness, field mud, terramechanics, tire pressure, wheel load and drive coordinator are byte-identical between the two known 1.3.4.0 builds.

No MRMud/MudSoil/MudRMS gameplay rewrite is required by this rebuild.

## MUD-03 RC puncture-grip contract is unchanged
**CONFIRMED_STATIC positive compatibility result**

`PunctureSystem:getWheelFrictionMultiplier(wheelPhysics)` is byte-identical.

MRMud may continue consuming the puncture consequence exactly as before.

## MUD-04 Mud wheel-contact contract is unchanged
**CONFIRMED_STATIC positive compatibility result**

`MudPhysics:getWheelContactPos(wheel)` is byte-identical.

RC/RE contact-position fallback remains valid.

## MUD-05 Native Mud↔Reifen friction composition added
**CONFIRMED_STATIC**

The current rebuild adds `ReifenverschleissCompatibility`.

It captures stable pre-Mud `frictionScale`, evaluates Reifen wear against that baseline, then reapplies the Mud multiplier once.

This is a real ownership improvement over relying on load order.

## MUD-06 Native Mud↔Reifen bridge and RC MRTireWear are algebraically composable
**CONFIRMED_STATIC source-composition result**

Evaluated in both possible wrapper orders, the two bridges reduce to:

`MR healthy grip × Mud friction scale × Reifen relative wear factor`.

The new native bridge therefore does not create an inherent double-Mud or double-Reifen penalty with the current RC design.

Runtime smoke is still required for hook-order/integrity proof.

## MUD-07 Reifen wear now increases Mud puncture probability
**CONFIRMED_STATIC feature change**

The new compatibility layer exposes Reifen wear to `PunctureSystem`.

Risk starts increasing after 20% wear and can reach x10 at extreme wear using the configured nonlinear curve.

Mud remains puncture owner; Reifen is a wear-state provider.

## MUD-08 Multiple tire-wear providers use strongest risk instead of multiplication
**POSITIVE_PATTERN**

If Use Your Tyres and Reifen are both detected, Mud does not multiply both puncture-risk signals.

It takes the strongest per-wheel multiplier and also warns the player that running both wear mods is unsupported.

## MUD-09 Reifen-driven puncture risk has a dedicated-server authority dependency
**RUNTIME_PENDING cross-mod risk**

Mud's random puncture roll is server-owned.

The Reifen audit found continuous wear state/player-farm ownership concerns in multiplayer. The current Mud rebuild queries Reifen wear on the server puncture path.

Dedicated/multi-farm testing is required to prove the server sees the same per-wheel wear state intended by Reifen.

## MUD-10 Global wheel-shape read guards added
**CONFIRMED_STATIC**

Mud now wraps:
- `getWheelShapeContactPoint`;
- `getWheelShapeSlip`;
- `getWheelShapeAxleSpeed`.

Invalid node/shape reads return safe nil/zero values instead of reaching native physics.

Valid calls delegate unchanged.

This is useful lifecycle hardening, but it expands Mud's global hook surface.

## MUD-11 Invalid wheel-shape guards may convert unavailable slip/speed into zero
**DESIGN_RISK / RUNTIME_PENDING**

For invalid wheel shapes, slip and axle speed return zero rather than "unavailable".

Consumers that cannot distinguish reset/reload state from a real zero may transiently interpret the safe fallback as physical data.

RC/RE already have broader vehicle/wheel eligibility gates, so no immediate code change is justified. Test during vehicle reset/reload if terrain artifacts appear.

## MUD-12 Puncture join/repair synchronization is materially improved
**POSITIVE_PATTERN**

The rebuild adds vehicle post-stream puncture/jack state and explicit server-settings response before client state handling, plus retry semantics.

This directly addresses missed events during joining/loading.

## MUD-13 Jack/state broadcasts now include sender reconciliation
**POSITIVE_PATTERN**

Server-adjusted jack placement is sent back to the requesting client instead of assuming the request itself is the accepted final state.

## MUD-14 Wheel mud shedding is presentation-only
**CONFIRMED_STATIC**

A new `MudPhysics:updateWheelMudShedding()` path is called from `WheelEffects.update`.

It reuses existing per-wheel particle systems and is client/presentation gated. It does not alter RC/RE physical sink/friction inputs.

## MUD-15 Dual/twin support width remains an external composition concern
**CONFIRMED_STATIC retained finding**

The current rebuild does not change the core Mud width/load/radius files.

Mud still does not natively consume MR's `mrTotalWidth` as the total support width for dual/twin configurations.

The active RC support-width bridge remains justified.

## MUD-16 Raw sink remains distinct from applied sink
**CONFIRMED_STATIC retained finding**

The current rebuild leaves the field/mud sink/radius code unchanged.

RC→RE must continue preferring applied desired-radius delta over raw sink accumulators where the former is available.

## MUD-17 Physical wetness remains a specialist domain
**CONFIRMED_STATIC ownership**

Mud local wetness remains physical wheel-ground state and should not be conflated with MoistureSystem agronomic field/material moisture.

## MUD-18 Private-state dependence should stay behind RC
**DESIGN_RULE**

Useful Mud fields include `__fg*`, `__mp*`, pressure/load state and drive-coordinator state.

RE feature modules should consume the RC normalized provider instead of adding direct private Mud dependencies.
