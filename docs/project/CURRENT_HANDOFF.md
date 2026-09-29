# Current development handoff

Updated: 2026-09-29

This file is the first place to read when continuing RealismExtensions in a new chat/session.

## Current branch and PR

- Active branch: `feat/terrain-surface-response-v6`
- Draft PR: #23 — `feat: terrain surface response and bounded rutting v6`
- Base branch: `main`
- Latest CI on the v6 branch: green.
- User has downloaded the v6 test ZIP but has not runtime-tested it yet.

## Immediate objective

Turn the successful v5 "SnowRunner-scale deformation proof" into believable agricultural/road terrain response.

v5 proved:
- GIANTS terrain heightmap deformation is strong enough for deep visible ruts;
- stationary wheelspin reaches the RE pipeline;
- progressive excavation can make a vehicle genuinely difficult to move;
- v5 tuning was far too aggressive for normal field work;
- the old binary `soilContact` gate excluded compacted dirt/gravel roads completely;
- RE domain-history persistence does not prove GIANTS heightmap persistence.

## Latest v5 runtime evidence

User report:
- field ruts became extremely large and practically unworkable;
- the result felt recognizably SnowRunner-like and therefore proved the direction is viable;
- compacted dirt road did not deform even while raining;
- user wants realism by surface, not globally stronger/weaker deformation.

Latest captured v5 diagnostics:
- outside supported soil, wheelspin can be detected while all deformation is rejected as non-soil;
- after entering supported field soil, brushes begin immediately;
- peak modeled rut/capacity reached about 0.595 m in the aggressive v5 stationary test;
- no failed terrain-deformation jobs were observed in the captured run;
- asynchronous/overlapping brush diagnostics mean cumulative observed-lowering values must not be interpreted as unique excavated depth or as one-brush response.

## v6 changes awaiting runtime test

`SurfaceResponse.lua` now distinguishes:
- soft field;
- generic field;
- firm field;
- explicit mud terrain layer;
- compacted dirt;
- gravel;
- hard/paved surface.

Initial calibration:
- soft field: ~0.08 m static / ~0.18 m severe-slip cap;
- generic field: ~0.06 m / ~0.15 m;
- firm field: ~0.04 m / ~0.10 m;
- explicit mud: ~0.07 m / ~0.17 m;
- wet compacted dirt: up to ~0.018 m / ~0.050 m, only after wetness+slip gates;
- wet gravel: up to ~0.012 m / ~0.035 m, only after stronger wetness+slip gates;
- asphalt/concrete/paved: no RE deformation.

Excavation cadence changed:
- sample interval: 100 ms -> 250 ms;
- per-sample geometric cap: 0.015 m -> 0.003 m.

These numbers are provisional gameplay calibration, not claimed agronomic constants.

## v6 runtime test requested from user

When the user returns, test at least:

1. Same field used for the v5 crater test:
   - normal driving/field work;
   - repeated passes;
   - stationary wheelspin against obstacle.
2. Compacted dirt road:
   - normal travel while wet;
   - deliberate high slip.
3. Hard/paved surface:
   - verify zero geometric deformation.
4. Save/reload after producing visible geometry:
   - verify whether GIANTS preserves the heightmap;
   - RE sidecar history must be rejected if geometry does not match.

Desired behavior:
- ordinary field work remains viable;
- severe wet/slip conditions can progressively create serious ruts and eventual stuck behavior;
- compacted roads resist normal rain/pass traffic;
- hard surfaces do not deform.

## Stack ownership: current implementation

The architecture is intentionally composition-first.

### MoreRealistic (MR)

Owns:
- base vehicle dynamics;
- drivetrain behavior;
- base wheel/traction simulation;
- slip state used by the current stack.

RE does not overwrite MR wheel dynamics.

### MudSystemPhysics

Owns:
- physical local wetness;
- field ground profile / mud potential;
- temporary sink state;
- terrain/sink/slip resistance and stuck behavior;
- tire pressure and wheel-load state used by the provider;
- freeze/ground-state signals.

RE does not create a second sink/stuck force model.

### RealismCompatibility (RC)

RC is the arbiter/adapter between specialists.

Important current MRMud behavior:
- inject Mud local wetness into MR where appropriate;
- preserve MR as base rolling-resistance/traction owner;
- suppress the overlapping Mud baseline-resistance term while keeping Mud sink/slip resistance;
- decouple Mud temporary sink-radius loss from structural tire radius;
- preserve Mud speed-cap/stuck consequences;
- expose a versioned normalized wheel context to RE.

RC also caches hot-path state so RE can reuse it instead of recomputing:
- MR slip snapshots;
- local Mud wetness snapshots;
- structural radius snapshots;
- wheel load;
- tire pressure;
- ground profile/mud potential;
- sink depth/severity;
- freeze state.

### RealismExtensions (RE)

Owns the missing consequence:
- persistent/visible terrain rut geometry;
- rut-domain history;
- surface-dependent geometric response.

RE consumes normalized state from RC and should not directly patch MR/Mud physics functions.

## Evidence that reuse-first works in runtime

In the latest v5 log, the ExtensionsStateProvider recorded:
- 13,099 wheel contexts in the first captured session;
- 13,099 slip snapshot hits;
- 0 direct slip reads;
- 9,715 wetness snapshot hits vs 3,368 fresh wetness reads;
- 9,696 structural-radius snapshot hits vs 3,363 fallback structural resolves.

The second captured session showed the same pattern:
- 8,606 wheel contexts;
- 8,606 slip snapshot hits;
- 0 direct slip reads;
- 7,766 wetness snapshot hits vs 824 fresh reads;
- 7,718 structural-radius snapshot hits vs 848 fallback resolves.

Interpretation: RE is predominantly consuming already-computed specialist state instead of running a parallel traction/wetness/radius simulation.

## How external mod updates propagate

### Changes that usually propagate automatically

If a Mud/MR update changes the value of an already-exposed authoritative state while preserving the runtime contract, RE should inherit it automatically. Examples:
- different local wetness result;
- different sink depth/severity;
- different ground mud potential/profile;
- different MR slip result;
- different tire-pressure result;
- different wheel-load result;
- different structural-radius composition.

### Changes that do NOT automatically propagate

RE has its own consequence model. Therefore an external update does not automatically retune:
- RE rut-cap constants;
- RE shear saturation constants;
- RE surface-classification thresholds;
- RE brush cadence/hardness/geometry;
- RE persistence format;
- new external state that is not exposed through the provider contract.

These require compatibility review or deliberate provider-contract evolution.

### Contract-break handling

RC/RE should prefer:
1. version/runtime-contract detection;
2. reuse fresh authoritative state when valid;
3. fall back narrowly where safe;
4. fail closed for unsupported state rather than silently inventing a second owner.

## Important design rule

Do not "absorb" a specialist merely by copying its formulas.

A specialist should only be replaced after a clean-room capability audit demonstrates a material benefit such as:
- better physics;
- lower bounded runtime cost;
- fewer conflicting global hooks;
- simpler authoritative state;
- simpler persistence/network behavior;
- elimination of large compatibility bridges.

Until that bar is met, composition is preferred.

## Known open questions

1. v6 calibration still needs runtime validation.
2. Terrain layer names vary by map; dirt/gravel/mud classification needs multi-map testing.
3. Ground profile naming exposed by Mud may vary and should be logged/validated.
4. Heightmap persistence across save/reload is still not solved.
5. Geometry diagnostics are affected by overlapping/asynchronous jobs and need a less misleading measurement strategy.
6. RE TerrainResponse is still a separate consequence model; future work can make it depend more strongly on authoritative Mud response signals without duplicating Mud forces.
7. Crawler/track grouped footprint modeling remains unresolved.
8. Release-mode telemetry cost still needs benchmarking/reduction.

## Next work that does not require user testing

Safe work while waiting for v6 runtime feedback:
- improve documentation and update-propagation rules;
- add surface-category diagnostics so the next log tells us exactly which classification was used;
- improve terrain geometry telemetry so overlapping async jobs do not masquerade as one-brush depth;
- audit current provider contract for any Mud outputs worth exposing instead of re-deriving;
- keep gameplay tuning changes minimal until the user's v6 field/road test returns.
