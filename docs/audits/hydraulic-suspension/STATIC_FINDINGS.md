# Hydraulic Suspension System static findings

Baseline: exact `1.6.9.0` ZIP SHA-256 `d2dd55186758dcaa5d61feeae8f3d25c442208e73e5d4723f04df2178e17e10c`.

Evidence labels:
- **CONFIRMED_STATIC**
- **STRONG_CANDIDATE**
- **DESIGN_RISK**
- **POSITIVE_PATTERN**
- **RUNTIME_PENDING**

## HSS-01 Client mode event has no controller authorization
**CONFIRMED_STATIC**

`HydraulicSuspensionModeEvent:run()` accepts a synchronized vehicle and immediately applies mode/manual offset. For client-originated traffic it then broadcasts the state.

No controlling-player, owner-connection or farm authorization check exists on the server boundary.

Impact:
- another connected client can potentially mutate a suspension state it should not control if it can send a valid vehicle reference.

Fix for any future implementation:
- server validates current controller/permission;
- server validates mode capability;
- server clamps ride-height request.

## HSS-02 Manual offset is not validated at the event/state boundary
**CONFIRMED_STATIC / defense-in-depth**

User input normally clamps its target.

`setMode()`, however, accepts the event's float into `spec.manualOffset` without clamping it.

Later physical use applies limits, so this is not proof of arbitrary wheel movement. It is still poor authority hygiene and can persist an invalid state.

## HSS-03 MoreRealistic suspension requests are deliberately suppressed
**CONFIRMED_STATIC ownership conflict**

For controlled front wheels `claimWheel()` replaces `setSuspensionMultipliers`.

Calls made while `hssCalling` are passed through.

All other calls:
- are stored as `hssExternalSpring/hssExternalDamp`;
- are not applied.

The values are never composed back into the HSS target.

Result:
- HSS does not compose with the active MR baseline;
- it becomes exclusive front suspension owner.

This is the most important reason not to port the implementation.

## HSS-04 Per-wheel getVisualInfo replacement has no identity/teardown contract
**DESIGN_RISK**

The source directly replaces each wheel physics object's `getVisualInfo` with a closure.

It marks `hssHooked`, but no onDelete/uninstall/restoration path is registered.

The vehicle object will normally disappear on deletion, so this is not necessarily a persistent global leak. It is still fragile if:
- another mod later replaces the same method;
- the feature is disabled/reinitialized;
- the vehicle's wheel representation is rebuilt.

A proper adapter should record pointer identity and restore only when still owner.

## HSS-05 Wheel visual hierarchy is reparented
**DESIGN_RISK / RUNTIME_PENDING**

The mod creates lift transform groups and reparents wheel representation nodes so hydraulic movement can be rendered separately.

This is powerful, but it creates a stronger ownership assumption than a pure shader/visual offset:
- other animation/moving-tool systems may assume original parents;
- no explicit hierarchy restoration path exists.

Validate on vehicles with complex front-link/moving-tool animations before using this technique.

## HSS-06 positionY becomes a repeatedly asserted actuator
**DESIGN_RISK**

The mod changes wheel physics `positionY` and reasserts it whenever another game system changes the position.

This solves a real loss-of-offset problem, but it means HSS wins by persistence against any other legitimate position owner.

Future RE must explicitly arbitrate position ownership rather than rely on repeated reassertion.

## HSS-07 User settings are destroyed on settingsVersion upgrade
**CONFIRMED_STATIC**

The package says modSettings are kept through updates.

If the saved settings version is older than the current `settingsVersion`, exact source:
1. deletes/closes the old XML;
2. writes a new default file;
3. returns.

Custom profile changes are not migrated.

This contradicts the user-facing persistence claim for schema/profile upgrades.

## HSS-08 Eligibility falls back to broad brand inference
**DESIGN_RISK**

After tractor/mass/travel/crawler checks, profiles can match an entire brand.

That can attach a specific suspension behavior to a vehicle merely because:
- it is a sufficiently heavy tractor;
- the game XML gives its front wheels some suspension travel;
- the brand generally offers a relevant system.

For simulation fidelity, explicit verified model/capability data should outrank broad coverage.

## HSS-09 Several physical profile values are acknowledged estimates
**CONFIRMED_STATIC model limitation**

The source/changelog explicitly notes that pendulum angle and some independent-articulation travel values are estimates.

Spring/damping multipliers are also described as gameplay tuning rather than factory data.

This is acceptable for a prototype, but RE should separate:
- verified hardware capability;
- sourced physical limits;
- tunable controller parameters;
- unknown values.

## HSS-10 Power-hop detector primarily observes slip oscillation
**DESIGN_RISK**

A deviation of front slip from its smoothed average can latch WORK mode for several seconds.

Power hop is a coupled vertical/longitudinal oscillation.

A stronger detector would observe:
- suspension stroke/velocity;
- vertical axle load;
- chassis pitch/vertical acceleration;
- periodic slip as a corroborating signal.

## HSS-11 Pitch control derives acceleration from getLastSpeed delta
**DESIGN_RISK**

The 200 ms controller differentiates the vehicle's reported last speed, filters it, then temporarily multiplies damping.

This can work, but the signal includes whatever filtering/semantics `getLastSpeed` has.

Prefer chassis/root-body longitudinal acceleration when available.

## HSS-12 Controller filters use first-order Euler alpha
**DESIGN_RISK / low severity**

Load and level filters use approximately `alpha = dt / tau` with clamping.

At the normal 200 ms cadence this is reasonable, but exact exponential smoothing `1-exp(-dt/tau)` is more timestep-invariant under hitches/cadence changes.

## HSS-13 Slow controller + per-frame actuator split
**POSITIVE_PATTERN**

The source runs expensive decisions/load leveling around 200 ms but moves cylinders/spring ramps each frame.

This is a strong architecture to preserve conceptually.

## HSS-14 Spring change is compensated by cylinder motion
**POSITIVE_PATTERN**

When spring target changes, the code adjusts cylinder offset in the same frame based on changed expected sag.

This avoids an artificial ride-height jump during mode transitions.

The exact equation need not be copied; the invariant is valuable:
> changing passive stiffness must not teleport vehicle ride height.

## HSS-15 Real draft can gate work mode
**POSITIVE_PATTERN**

When Soil & Draft Physics exists, WORK state can depend on actual draft kN.

With MR but no Soil Draft, the mod can use MR implement force.

This is better than relying exclusively on implement-lowered state.

Future implementation should consume a normalized provider rather than private mod tables.

## HSS-16 Server-authoritative physical simulation
**POSITIVE_PATTERN**

Physics/controller execution is server-owned.

Clients receive state needed for visualization.

This is the correct high-level MP direction.

## HSS-17 Synthetic pendular/independent articulation writes wheel support positions
**DESIGN_RISK / RUNTIME_PENDING**

When the mod decides the vehicle lacks a physical axle component, it simulates pendular or independent articulation by moving the two front wheel support positions in opposition according to suspension-length difference.

This can improve a visually/physically rigid vanilla setup, but it is effectively adding suspension kinematics on top of vehicle XML physics.

Do not generalize this into RE without controlled comparison on:
- actual rigid axle with joint;
- vanilla pseudo-independent wheel suspension;
- model with movingTools tied to wheel positions;
- MR active.

## HSS-18 Mode/profile capability model is worth retaining
**POSITIVE_PATTERN**

Manual height, lock speed and axle type are capability fields rather than one universal behavior.

That distinction is a strong foundation for a cleaner RE profile schema.
