# Reifenverschleiss friction, radius and Mud composition

## 1. General wear friction is an absolute owner

`getWearAppliedTarget()` derives a target from:
- wheel OWN-WEAR;
- `wheel.physics.frictionScale`.

The installed hook runs after previous `WheelPhysics.updateFriction` logic and writes:

`physics.tireGroundFrictionCoeff = targetApplied / physics.frictionScale`

Therefore the final product becomes approximately Reifen's target.

The previous `tireGroundFrictionCoeff` is not used as the baseline.

This is a general ownership problem, not only an MR conflict:
- GIANTS terrain coefficient can be replaced;
- MR terrain/wetness/tire coefficient can be replaced;
- Mud-composed coefficient can be replaced;
- any earlier mod using the coefficient can be replaced.

At low wear the target equals `frictionScale`, which often normalizes the final coefficient toward 1.0 rather than preserving upstream terrain semantics.

## 2. Correct RC ownership

The current MRTireWear principle is the right one:

```
composed healthy grip from MR/Mud/etc
          *
relative Reifen wear factor <= 1
          =
final grip
```

Reifen should own **degradation**, not ground-friction baseline.

The same rule would make the mod naturally composable outside the current stack.

## 3. High-wear curve monotonicity risk

Through 75% wear the curve is scaled to the wheel's starting `frictionScale`.

At 75-90% it transitions from:
`nativeStart / 1.8`
to absolute `0.55`.

If `nativeStart < 0.99`, the 75% starting point is below 0.55, so increasing wear toward 90% can increase the absolute target.

At even lower baselines, heavily worn Reifen grip can exceed its clean baseline.

RC's no-boost rule protects the current MR integration. Direct standalone behavior should be sampled across real tire classes before deciding whether this is practically visible.

## 4. Snow path is better designed

Reifen's snow add-on:
- observes the native/current coefficient;
- detects/removes its own previous contribution when necessary;
- applies a relative profile multiplier;
- avoids repeated self-stacking.

This is a good composition pattern and a useful precedent for refactoring the ordinary wear-friction path.

## 5. Structural tread-radius loss

Round tire visual wear is coupled to physical rolling radius on the server.

The visual shader's progressive high-wear curve is mirrored into:
- `wheel.physics.radius`;
- `wheel.radius`.

Reifen records explicit structural state:
- `rvRoundOriginalPhysicsRadius`;
- `rvRoundPhysicalWear`;
- `rvRoundPhysicalRadius`.

This makes permanent tread loss distinguishable from transient Mud pressure/sink effects.

## 6. Mud compatibility

For worn round tires Reifen updates Mud TirePressureSystem's baseline:
`wheel.physics.__tpOrigRadius = rvRoundPhysicalRadius`.

It intentionally does not own Mud's current-frame pressure radius.

This is conceptually correct:
- Reifen -> permanent structural baseline;
- Mud -> transient pressure/soil deformation.

RC's structural-radius policy already follows this distinction and has runtime evidence.

## 7. Mud compatibility version guard: detection without semantic gating

Version 1.2.2.67 adds `RPMudVersionCompatibility`.

Profiles:
- `MUD_1_3_4_ROAD_CONTACT`;
- `MUD_1_3_2_LEGACY`;
- `MUD_UNKNOWN_SAFE_LEGACY`.

However the profile is not consumed by `RPMudCompatibility` or `RPMudOverlayCompatibility` to select a distinct code path. They only ask whether Mud is active.

Unknown/newer Mud therefore still receives the same private-field contract, including `__tpOrigRadius`.

The version detector is useful observability, but it is not a fail-closed compatibility contract.

Lesson for RC hotfixes/integrations:
**version classification must be paired with source-shape/runtime-contract verification.**

## 8. Mud local wetness is absent from wear physics

Reifen's wear ground data reads GIANTS global weather wetness and rain.

It does not consume:
- `FieldLocalWetness`;
- Mud field wetness;
- Mud brush wetness/state.

Consequences:
- Mud can make one field locally much wetter/drier than global weather;
- sink/resistance respond locally;
- Reifen DIST/SLIP wear still uses global rainfall wetness.

Also, `getGroundWearClass` prioritizes FIELD before MUD. A wet field remains FIELD in Reifen's wear matrix.

This is a genuine integration opportunity:
temporarily supply Reifen's existing wear model with normalized local wetness, without copying its wear formulas into RC.

## 9. Mud visual overlay ownership

The overlay adjusts only visible mud profile for round worn tires.

It intentionally reads the actual shader every update instead of trusting its own cached last target, because GIANTS/Mud can rewrite the shader after Reifen.

Performance policy:
- moving/near vehicles: every frame;
- stationary and >200 m: ~1 Hz.

The behavior is ownership-aware but still scans the whole vehicle fleet from a mission-update wrapper.

Minor lifecycle note:
`M._last` is declared weak-key but is keyed by numeric node IDs; numeric keys are not usefully weak. The table is not reset in `deleteMap`. This is a small cache hygiene issue, not a known visual correctness failure.

## 10. Physical-radius race watchpoint

The normal visual worker directly writes the worn structural target into `physics.radius` when wear changes.

Mud compatibility subsequently prepares the pressure baseline rather than immediately recomputing the transient Mud radius itself.

Because wear changes slowly and current stack runtime was healthy, this is a watchpoint rather than a proven conflict. Still, a cleaner future owner contract would express structural radius to Mud before any current-radius writer executes.


# 1.2.2.70 API/radius update

## Compatibility API v1

The release now exposes an explicit compatibility surface:

```lua
getCompatibilityApiVersion() -- 1
getWearAppliedTargetForScale(vehicle, wheel, nativeStart)
getWheelWearRadius(vehicle, wheel)
getWheelCompatibilityData(vehicle, wheel, nativeFrictionScale)
```

This materially improves the ownership model.

### Friction

`getWearAppliedTargetForScale` evaluates Reifen's own curve against a
caller-provided stable scale. The caller no longer needs to mutate
`physics.frictionScale` temporarily just to ask Reifen a question.

However, the final Reifen hook is still absolute:

```lua
physics.tireGroundFrictionCoeff = targetApplied / physics.frictionScale
```

So MRTireWear remains required with MR.

Important RC design decision:
- **do not wrap API v1 itself** to inject MR;
- doing so would change a public Reifen provider into an RC-composed provider;
- keep the API semantically pure and compose only at the exact final-target
  boundary already used by Reifen/Mud.

### Radius

`getWheelWearRadius` explicitly defines:
- `wearRadius`: Reifen-owned wear-only structural radius;
- `originalRadius`: unworn baseline;
- `wear01`: Reifen wear state.

The source contract explicitly permits a temporarily smaller external/effective
radius without allowing that value to become Reifen's next structural baseline.

This cleanly separates:

```
permanent tread loss     -> Reifen wearRadius
pressure/puncture/sink   -> temporary external/effective radius
final physics.radius     -> engine actuator
```

RC now prefers the public wearRadius for current Reifen source.

## Mud 1.3.6 coordinated path

When Mud publishes
`__MudRadiusCombiner.supportsReifenverschleissRadiusChannel=true`, Reifen uses
`__rvOrigRadius/__rvDesiredRadius/__rvWear01` and stops overloading
`__tpOrigRadius` for permanent wear.

That is a semantic improvement.

It is still a private shared-state bridge, so RC treats it as fallback when the
public Reifen API can answer the structural question directly.

## What this update does not solve

- local Mud wetness is still absent from Reifen's wear accumulation inputs;
- Reifen still has an absolute final friction writer;
- the high-wear low-baseline monotonicity edge remains;
- visual current-radius writes still require runtime observation beside Mud
  transient radius updates.
