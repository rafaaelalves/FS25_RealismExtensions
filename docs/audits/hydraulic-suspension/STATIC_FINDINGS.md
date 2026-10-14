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


# Release 1.0.0.0 delta findings

Delta package SHA-256: `b338a28d13cadfe8b00949c7d0461079a04f6ee29a5afdd6fc79c3567038d40e`.

The original HSS-01 through HSS-18 findings remain applicable unless explicitly superseded below. In particular:
- HSS-01/HSS-02 multiplayer request validation remain unresolved;
- HSS-03 MoreRealistic spring/damper ownership conflict remains unchanged;
- HSS-04/HSS-05/HSS-06 lifecycle and actuator-ownership risks remain;
- HSS-07 destructive settings-version reset remains;
- HSS-08 through HSS-12 model/controller caveats remain;
- HSS-13 through HSS-16 remain useful positive patterns.

## HSS-19 Server/client configuration can diverge
**DESIGN_RISK / RUNTIME_PENDING**

The authoritative suspension controller runs server-side, but clients load their own local `modSettings` and reconstruct profile/UI/visual information from local configuration.

Examples:
- HUD profile/system/spring/damping presentation is recomputed locally;
- visual camber configuration is local;
- fast visual bump sharing uses local visual parameters.

This means a dedicated server with customized settings/profiles can run one physical model while a client presents another interpretation.

Future RE rule:
- distinguish local presentation preferences from authoritative simulation configuration;
- synchronize authoritative capability/profile identity and effective parameters needed for truthful UI/visual reconstruction;
- do not make clients independently infer authoritative physics profiles.

## HSS-20 Cab suspension is camera isolation and reparents the camera hierarchy
**CONFIRMED_STATIC / MODEL_BOUNDARY / DESIGN_RISK**

The release calls the feature cab suspension, but the implementation is a client-side camera filter:
- it inserts HSS transform nodes into the interior-camera hierarchy;
- estimates low-frequency vehicle pitch/roll;
- applies an opposing fraction to the camera.

That can create a useful isolation sensation, but it does not simulate a cab mass, cab mounts, suspension stroke or force transfer.

There is also no explicit uninstall/restoration path for the original camera parent relationship.

Learning:
- retain the idea of a cheap presentation-only isolation layer when full cab physics is unnecessary;
- name/model it honestly as visual/camera isolation;
- any RE implementation needs lifecycle-safe hierarchy ownership and compatibility with camera mods.

## HSS-21 Loader ride control can report active without a bound arm actuator
**CONFIRMED_STATIC functional mismatch**

The loader detector can create a valid boom state from the front-loader attachment/joint and set:
- `boomWant = true`;
- `boomActive = true`;
- `boomPhysics = true`;

based on speed and feature state.

Actual arm motion is performed later by `armSim()`, which separately searches the attached tool's movingTools for an axis/axisName containing `ARM`.

If no matching movingTool is found:
- `armSim()` returns without applying a correction;
- the HUD can still represent the ride control as active;
- the suspension fallback is disabled because `boomPhysics` was already considered available.

This is a useful architectural lesson:

> capability detected, actuator bound and controller active are three different states.

Future RE should expose them separately and only claim an actuator after binding succeeds.

This is an external-mod defect to document, not a reason to add an HSS-specific RC repair.

## HSS-22 Loader ride control directly owns movingTool rotation
**DESIGN_RISK / RUNTIME_PENDING**

The active loader simulation modifies the chosen movingTool's `curRot` and marks it dirty.

The implementation tries to preserve operator/base motion by subtracting its previous offset before adding the new transient offset. That is a thoughtful local invariant, but it is still direct shared-resource ownership.

Risks:
- another controller can write the same movingTool;
- operator motion and active correction may be sampled at different moments;
- attachment implementations may not expose a compatible movingTool;
- the chosen `ARM` heuristic is naming-dependent.

Future RE should use an actuator adapter with explicit binding/ownership and a defined composition point between:
- operator/base command;
- implement animation/controller state;
- transient ride-control correction.

## HSS-23 Loader arm simulation is called outside the vehicle-physics guard
**DESIGN_RISK / RUNTIME_PENDING**

The main specialization guards the server suspension controller/actuator path with `isAddedToPhysics`.

The subsequent loader `armSim()` call is outside that guard.

If stale loader state survives a reset, workshop/configuration transition or another temporary physics-removal path, the arm controller can be asked to run while the main suspension controller is intentionally dormant.

Runtime testing must characterize whether this causes a real lifecycle issue.

Future RE rule:
- physical actuator execution should share an explicit lifecycle gate with the state/controller that owns it;
- reset transient state on detach/delete/physics removal.

## HSS-24 Loader contains a dormant joint-spring prototype path
**CODE_QUALITY / LEARNING**

The release contains an alternate joint-translation spring path gated by `loaderJointSpring == true`.

That flag is not present in the normal default/user settings path, while the active public feature uses the movingTool arm simulation.

Some related constants/helpers are therefore effectively experimental/dormant in normal configuration.

This is not inherently harmful, but for our codebase:
- experimental actuator strategies should be behind explicit named experimental flags with diagnostics, or
- removed once the design decision is made.

Avoid carrying two half-authoritative physical models in production code.

## HSS-25 Fast client visual reconstruction + slow authoritative synchronization
**POSITIVE_PATTERN**

The release extends a useful networking pattern:
- server owns the physical controller;
- slow/effective suspension state is synchronized;
- clients reconstruct high-frequency wheel visual response locally.

This avoids streaming visual physics every frame while preserving responsive presentation.

Principle worth retaining:
> synchronize authoritative low-band state and derive deterministic/non-authoritative high-band presentation locally when divergence cannot affect gameplay.

The exact HSS visual model need not be copied.

## HSS-26 Shared/declarative Settings UI hook
**POSITIVE_PATTERN / VERSION_FRAGILITY**

The settings helper centralizes a single hook around the native General Settings frame and lets feature modules register declarative controls into it.

Positive:
- avoids every module installing an independent frame hook;
- separates option declaration from most UI plumbing;
- can coexist with multiple modules using the same registry pattern.

Risk:
- it depends on internal native control/template identifiers and layout structure;
- a game UI update can invalidate those assumptions.

Lesson for RE:
- if we build shared settings infrastructure, use one capability-checked adapter around native UI internals;
- feature modules should remain declarative and unaware of concrete template IDs.

## HSS-27 Release broadens one specialization into multiple ownership domains
**ARCHITECTURE_LEARNING**

The release now puts under one specialization:
- front-wheel active suspension;
- wheel visual reconstruction;
- camera isolation;
- front-loader active motion;
- HUD;
- settings interaction.

This is convenient for a self-contained external mod but not the architecture we should reproduce in RE.

The capabilities have different:
- lifecycles;
- authority domains;
- compatibility surfaces;
- failure modes.

If absorbed, split them conceptually:
- `ActiveSuspension`;
- `LoaderRideControl`;
- optional `CabIsolation`;
- UI/settings adapters.

A vehicle-level orchestrator may coordinate them, but should not collapse them into one ownership object.
