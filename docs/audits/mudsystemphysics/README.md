# MudSystemPhysics deep architecture/compatibility audit

Updated: 2026-10-06

## Exact source baselines

MudSystemPhysics has now produced two materially different packages that both declare version `1.3.4.0`.

### Earlier audited 1.3.4.0 build
- ZIP SHA-256: `29a6a58005eadfed7d7d2530ae5b8964fc314fe4aadbe65837ba6e54ac9828ef`
- Lua files: 36
- Lua source: ~28,947 lines

### Later audited 1.3.4.0 rebuild
- ZIP SHA-256: `268f64f03c14ae003c16a6a66d5841485c1cd5a1f82393350593ea00daca1f1e`
- Lua files: 37
- Lua source: ~29,773 lines
- still declares `<version>1.3.4.0</version>`

This is therefore a **same-version source rebuild**, not a normal version-number update. Future audit/provenance must identify this Mud line by version **and hash/source shape**, not version alone.

## Current 1.3.6.0 package

- ZIP SHA-256: `fba0536405f082c3bec2e69452591fe2e051a87d652ee0be66f4124f855601f7`
- 36 Lua files / 29,412 Lua lines
- source audit: **closed**
- RC result: existing bridges remain valid; focused MR+Mud+Reifen API-v1 ordering hardening prepared in `research/mud-1.3.6-compat`
- upgrade status: **recommended after targeted runtime smoke with the RC hardening**

Key 1.3.6 changes:
- chunked/atomic local-wetness scheduling;
- reduced redundant tire visual/friction writes;
- stronger Reifen structural-radius/API integration;
- temporary removal of TractorTerrainDynamics integration.

See [1.3.6 update audit](./UPDATE_1_3_6.md).

## Recommendation

**KEEP + INTEGRATE.**

MudSystemPhysics remains the physical ground/mud specialist.

Current ownership:
- Mud: local physical ground wetness, sink/mobility, mud-specific resistance, stuck behavior, tire-pressure effects, wheel dirt/mud effects, punctures and related UI/MP state;
- MR: base drivetrain, healthy wheel physics, base friction/rolling resistance;
- RC: composition between specialist owners and normalized state for RE;
- RE: persistent terrain geometry/consequences, not a second Mud traction/sink solver.

The new rebuild does not change that ownership.

## Historical 1.3.4 rebuild decision

The SHA `268f64f0...daca1f1e` was **source-compatible with the then-current RC/RE contracts**.

No RC gameplay-code change is required before updating from the older SHA `29a6a580...9828ef`.

No RE gameplay-code change is required.

Reasons:
- `FieldLocalWetness.lua` is byte-identical;
- `FieldGroundMudPhysics.lua` is byte-identical;
- `MudTerramechanicsModel.lua` is byte-identical;
- `TirePressureSystem.lua` is byte-identical;
- `WheelLoadSystem.lua` is byte-identical;
- `DrivePhysicsCoordinator.lua` is byte-identical;
- `TractorTerrainDynamicsCompatibility.lua` is byte-identical;
- `UseYourTyresCompatibility.lua` is byte-identical;
- `PunctureSystem:getWheelFrictionMultiplier()` is byte-identical;
- `MudPhysics:getWheelContactPos()` is byte-identical;
- the structural/sink markers used by RC remain present.

The active RC dual-support branch also relies on:
- `WheelLoadSystem.getWheelLoadData`;
- `__fgOrigRadius / __fgDesiredRadius / __fgMudCurExtra`;
- `__mpOrigRadius / __mpDesiredRadius / __mpMudCurExtra`;
- `__MudRadiusCombiner`;
- `mrTotalWidth`.

The Mud-side ownership and fields used by that bridge remain intact in this rebuild.

## New native Reifenverschleiss integration

The rebuild adds `scripts/ReifenverschleissCompatibility.lua` (~565 lines).

It has two production-facing responsibilities:

1. **friction composition**
   - captures the stable `frictionScale` entering `WheelPhysics.updateTireFriction`;
   - asks Reifenverschleiss for its wear target against that stable baseline;
   - reapplies the Mud friction multiplier exactly once.

2. **puncture-risk input**
   - reads Reifen per-wheel wear;
   - starts increasing puncture risk after 20% wear;
   - reaches a configured maximum of x10 near full wear;
   - Mud remains the puncture owner; Reifen supplies wear state.

It also provides temporary console-only wear overrides for testing and warns when both Use Your Tyres and Reifenverschleiss are active together.

### Interaction with RC MRTireWear

The new native Mud↔Reifen bridge does **not** make `MRTireWear` redundant.

They solve different boundaries:
- Mud native bridge: Mud friction scale × Reifen wear target;
- RC MRTireWear: MR healthy/base grip × Reifen relative degradation.

For the 1.3.4 compatibility path, static composition analysis reduced both wrapper orders to:

`MR grip × Mud scale × Reifen wear factor`

Mud 1.3.6 later introduced the API-v1 `getWearAppliedTargetForScale` fast path, which changes that wrapper-order call graph. The old algebra remains historical evidence for 1.3.4 but is **superseded for 1.3.6** by the focused RC hardening documented in `UPDATE_1_3_6.md`.

## New current-build changes

The exact delta from the earlier `1.3.4.0` SHA is intentionally narrow:

Changed:
- `modDesc.xml`;
- `MudPhysics.lua`;
- `MudSystemVehicleLifecycle.lua`;
- `PunctureSystem.lua`;
- `WheelDirtAddon.lua`;
- puncture network events;
- localization files.

Added:
- `ReifenverschleissCompatibility.lua`.

### MudPhysics / WheelDirt
A new wheel-mud shedding effect reuses the existing per-wheel particle allocation. It is presentation-side and does not change the sink/friction/terramechanics contract consumed by RC/RE.

### Vehicle lifecycle
Mud now globally guards:
- `getWheelShapeContactPoint`;
- `getWheelShapeSlip`;
- `getWheelShapeAxleSpeed`;

against nil/zero/deleted wheel-shape reads during reload/lifecycle transitions.

Valid wheel-shape calls still delegate to the previously installed function.

### Puncture multiplayer
The rebuild improves:
- farm-access checks;
- jack authority;
- sender resynchronization;
- post-stream puncture/jack state;
- settings-before-state join synchronization;
- retry behavior.

These are primarily correctness/lifecycle improvements and do not alter the RC puncture-grip API.

## Important new cross-mod risk

Mud's random puncture roll is server-owned, and the new Reifen risk multiplier asks Reifen for per-wheel wear on that server path.

The Reifen 1.2.2.67 audit already found that Reifen's ongoing wear model is scoped around the current player's farm and lacks an explicit authoritative continuous MP replication model.

Therefore:

**Mud puncture probability based on Reifen wear is source-correct in single-player/host, but dedicated/multi-farm parity is runtime-pending.**

This does not block the Mud update, but it should be included in the Reifen/Mud multiplayer test matrix.

## Prior audit conclusions retained

The earlier deep source audit remains valid where the underlying files are unchanged.

Important retained findings:
- ordinary Mud width logic uses the wheel's own width and does not inherently understand MR total dual/twin support width; RC's dedicated support-width composition remains justified;
- raw Mud sink accumulator is not always equal to physically applied sink after radius/minimum/crawler/width constraints; RC→RE should consume applied desired-radius consequence where available;
- RE should consume normalized physical wetness/sink/load/pressure through the RC provider rather than duplicate Mud private-state resolution;
- physical ground wetness from Mud must remain distinct from agronomic/material moisture systems;
- Mud's numerous wheel/global hooks make ownership coordination preferable to another independent terrain/traction solver;
- Mud private fields are useful implementation evidence, but should stay behind RC/provider boundaries where practical.

## Audit status

Static/source audit: **UPDATED / CLOSED through Mud 1.3.6.0 SHA `fba05364...5601f7`**.

Runtime validation for the current rebuild is not yet recorded.

Further source work should be triggered by:
- a runtime regression;
- another silent same-version rebuild;
- a genuine new integration consumer;
- a Mud 1.4.x ownership change.

See:
- `STATIC_FINDINGS.md`
- `SAME_VERSION_UPDATE_268F.md`
