# MudSystemPhysics static findings ledger

Current baseline: MudSystemPhysics `1.3.6.0`, SHA-256 `fba0536405f082c3bec2e69452591fe2e051a87d652ee0be66f4124f855601f7`.

Historical MUD-01 through MUD-18 describe the 1.3.4 lineage. MUD-06's two-order wrapper proof is **not sufficient for the 1.3.6 API-v1 fast path**; MUD-22 below supersedes that part for 1.3.6.

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


# MudSystemPhysics 1.3.6.0 delta findings

## MUD-19 Core RC runtime contracts survive 1.3.6
**CONFIRMED_STATIC positive compatibility result**

The exact 1.3.6 package retains the RC-critical public/private owner surfaces used by:
- MRMud;
- MudRMS;
- MudSoil;
- ExtensionsStateProvider.

Retained contracts include local wetness, wheel contact, WheelLoadSystem, terramechanics resistance, puncture grip, tire-pressure state and field/generic Mud desired-radius markers.

No existing RC Mud bridge is invalidated solely by source shape.

## MUD-20 Dual/twin support width is still not native
**CONFIRMED_STATIC retained compatibility need**

No `mrTotalWidth` consumption was found in Mud 1.3.6.

Mud's own width/load/radius logic therefore still does not receive MoreRealistic's total dual/triple tire support width automatically.

RC's MRMud support-width composition remains required.

## MUD-21 Reifen structural-radius channel is now an explicit capability
**POSITIVE_PATTERN / INTEGRATION OPPORTUNITY**

Mud 1.3.6 publishes:

`__MudRadiusCombiner.supportsReifenverschleissRadiusChannel = true`

and consumes:
- `__rvOrigRadius`;
- `__rvDesiredRadius`.

The same combiner capability is exposed to Reifen's private environment when the coordinated API is available.

This is preferable to independent inference of permanent worn radius.

RC now consumes that contract explicitly.

Engineering lesson:
> publish capability plus semantic state together; do not require peers to infer a contract from the accidental presence of private fields.

## MUD-22 Reifen API-v1 changes wrapper-order semantics
**CONFIRMED_STATIC cross-mod compatibility change**

Mud 1.3.6 can obtain the Reifen wear target through:

`getWearAppliedTargetForScale(vehicle, wheel, baseScale)`

rather than calling its captured original `getWearAppliedTarget`.

That is a cleaner Mud↔Reifen API, but it invalidates the 1.3.4 assumption that RC MRTireWear necessarily remains in the call chain regardless of wrapper order.

If:
1. RC wraps Reifen first;
2. Mud installs its API-v1 compatibility wrapper later;

then Mud's outer wrapper may bypass RC's older inner wrapper.

The normal expected startup order is favorable, but Mud's delayed partner-discovery retry makes the adverse order plausible.

RC therefore gained a narrow identity-checked ordering repair for the known Mud API-v1 wrapper.

## MUD-23 Native Mud↔Reifen integration does not replace RC MRTireWear
**CONFIRMED_STATIC ownership result**

The native bridge composes:
- Reifen wear with Mud friction scale;
- Reifen worn structural radius with Mud radius effects;
- Reifen wear with Mud puncture probability.

It does not compose Reifen wear with MoreRealistic's healthy terrain/wetness coefficient.

MRTireWear remains necessary in an MR stack.

## MUD-24 Permanent wear becomes the base for Mud temporary radius effects
**POSITIVE_PATTERN**

Mud's field sink, generic mud, tire pressure and puncture systems now recognize the Reifen structural radius channel when available.

This expresses a useful state hierarchy:

`permanent structure -> temporary equipment/terrain deformation -> effective radius`

That is better than each owner independently preserving an unworn "original" radius and relying on later arbitration.

## MUD-25 Local wetness job slices computation but commits atomically
**POSITIVE_PATTERN**

The revised local wetness layer performs its heavier update in staged/budgeted work using non-committed buffers.

The externally visible moisture state is replaced only after the complete pass is ready.

The vehicle-wetness cache includes committed-buffer identity, so a completed publication naturally changes its cache generation.

This is an important RE terrain precedent:

> distribute computation over frames while preserving atomic publication of observable simulation state.

A consumer should see generation N or N+1, not a spatial mixture of both.

## MUD-26 In-progress wetness work does not become savegame truth
**POSITIVE_PATTERN**

Persistence uses the last complete committed moisture state rather than partially publishing an unfinished staged job.

This is the persistence counterpart to MUD-25.

For future RE long-running terrain transforms:
- working state may be incremental;
- save state should represent a coherent committed generation.

## MUD-27 Tire visual discovery adds bounded negative caching
**POSITIVE_PATTERN**

An empty tire visual cache is no longer rebuilt on every call. Discovery retries after a bounded delay.

General lesson:
- cache negative/empty lookups when repeated discovery is expensive;
- pair the negative cache with time/generation invalidation so late-created resources remain discoverable.

## MUD-28 Tire deformation/friction paths use more semantic dirtying
**POSITIVE_PATTERN**

The update avoids several unchanged repeated writes:
- unchanged tire deformation shader state;
- unnecessary physical friction updates.

This reinforces:
> update cadence and actuator dirty cadence are separate design decisions.

The controller may run frequently while the expensive engine write occurs only after a meaningful effective-state change.

## MUD-29 TractorTerrainDynamics compatibility is removed upstream
**CONFIRMED_STATIC scope change**

The 1.3.6 package no longer contains `TractorTerrainDynamicsCompatibility.lua` and no TTD references remain in the current source.

Current RC Mud bridges do not require that integration, so this is not a direct RC regression.

Do not recreate it in RC without a dedicated exact-TTD audit and evidence that the active target stack actually needs the lost behavior.

## MUD-30 1.3.6 remains SOURCE_COMPATIBLE for MRMud/MudSoil/MudRMS
**CONFIRMED_STATIC project evidence**

After exact-source review:
- MRMud: SOURCE_COMPATIBLE;
- MudSoil: SOURCE_COMPATIBLE;
- MudRMS: SOURCE_COMPATIBLE;
- MRMud dual-support extension: SOURCE_COMPATIBLE;
- RC→RE provider: SOURCE_COMPATIBLE after recognizing the new Reifen structural-radius channel.

The upgrade still requires runtime smoke before promotion to runtime-verified evidence.
