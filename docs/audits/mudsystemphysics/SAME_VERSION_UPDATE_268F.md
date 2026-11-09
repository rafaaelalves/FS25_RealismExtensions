# MudSystemPhysics 1.3.4.0 same-version rebuild audit

Date: 2026-10-04

## Compared packages

Old known build:
- declared version: `1.3.4.0`
- SHA-256: `29a6a58005eadfed7d7d2530ae5b8964fc314fe4aadbe65837ba6e54ac9828ef`
- 36 Lua files
- ~28,947 Lua lines

New uploaded build:
- declared version: `1.3.4.0`
- SHA-256: `268f64f03c14ae003c16a6a66d5841485c1cd5a1f82393350593ea00daca1f1e`
- 37 Lua files
- ~29,773 Lua lines

## Changed source surface

Gameplay/source differences are limited to:
- `modDesc.xml`;
- `scripts/MudPhysics.lua`;
- `scripts/MudSystemVehicleLifecycle.lua`;
- `scripts/PunctureSystem.lua`;
- `scripts/WheelDirtAddon.lua`;
- `scripts/events/PunctureJackEvent.lua`;
- `scripts/events/PunctureStateEvent.lua`;
- `scripts/events/PunctureSyncRequestEvent.lua`;
- localization;
- new `scripts/ReifenverschleissCompatibility.lua`.

No core local-wetness, field-ground, terramechanics, tire-pressure, wheel-load or drive-coordinator source changed.

## RC contract matrix

| RC surface | Result |
|---|---|
| `FieldLocalWetness.getEffectiveWetnessAt` | unchanged |
| `FieldLocalWetness.getVehicleWetness` | unchanged |
| `FieldGroundMudPhysics.getWheelContactPos` | unchanged |
| `MudPhysics.getWheelContactPos` | unchanged |
| `__MudTerramechanicsModel.getResistanceRatio` | unchanged |
| `PunctureSystem.getWheelFrictionMultiplier` | unchanged |
| `WheelLoadSystem.getWheelLoadData` | unchanged owner/source |
| tire-pressure state/API | unchanged |
| `__fgOrigRadius/__fgDesiredRadius/__fgMudCurExtra` | retained |
| `__mpOrigRadius/__mpDesiredRadius/__mpMudCurExtra` | retained |
| Mud drive coordinator | unchanged |
| Mud artificial motor-load switches | unchanged |

Verdict:
- `MRMud`: SOURCE_COMPATIBLE;
- `MudSoil`: SOURCE_COMPATIBLE;
- `MudRMS`: SOURCE_COMPATIBLE;
- active dual-support extensions to MRMud: SOURCE_COMPATIBLE;
- RC→RE state provider: SOURCE_COMPATIBLE.

## Three-way MR + Mud + Reifen proof

Let:
- `B` = stable pre-Mud Reifen frictionScale baseline;
- `C = B × M` = current scale after Mud multiplier `M`;
- `R(B)` = Reifen wear target evaluated against stable baseline;
- `K` = MR healthy tire-ground coefficient.

Mud's new wrapper yields:
`R(B) × C/B`.

RC MRTireWear converts the Reifen target to a relative factor:
`wearFactor = clamp(R(B)/B, 0, 1)`

and final composition becomes:
`K × C × wearFactor`.

If RC wraps Mud:
`RC(Mud(Reifen)) = K × C × R(B)/B`.

If Mud wraps RC:
`Mud(RC(Reifen)) = K × B × R(B)/B × C/B = K × C × R(B)/B`.

The two install orders are therefore algebraically equivalent for the supported path.

## RE impact

RE consumes wheel state through `RealismCompatStateProvider`.

The provider-critical Mud contracts and markers remain available.

The active RC branch already:
- composes MR total support width into Mud;
- derives applied sink from desired radius where available;
- exposes normalized wetness/load/pressure/sink state to RE.

The new Mud rebuild does not invalidate those changes.

**No RE code update required.**

## New behavior worth testing

1. Reifen wear -> Mud puncture risk in single-player/host.
2. Same feature on dedicated server / multiple farms.
3. MR + Mud + Reifen final friction under low/medium/high wear.
4. Vehicle reset/reload while new global wheel-shape guards are active.
5. New puncture/jack sync with a joining client.
6. New mud-shedding particles at 10–40+ km/h and their cleanup after vehicle reset.
7. Full stack with RC dual-support bridge to confirm no runtime hook reassert/integrity warning.

## Upgrade verdict

**Safe to adopt at source-compatibility level with the current RC/RE code.**

No gameplay-code patch is required before installation.

Because this is a same-version rebuild and includes a new native Reifen compatibility layer, treat first runtime session as a targeted smoke test before promoting the exact hash to fully runtime-verified evidence.
