# TerraFarm architecture audit for RealismExtensions

Updated: 2026-10-02
Source audited: `scfmod/FS25_TerraFarm`, commit `b50e677cdef062d605ab188f8982ae1faa2789e7`.

Purpose: learn from TerraFarm's implementation architecture and TerrainDeformation usage. This is not a patch/bridge proposal and does not imply runtime dependency.

## High-value architectural findings

### 1. Machine state, work-area geometry and landscaping operation are separate layers

TerraFarm's `Machine` specialization owns activation/cadence/state. `MachineWorkArea` owns spatial nodes, terrain contact and input/output routing. `LandscapingBase/Input/Output` and operation subclasses own TerrainDeformation execution.

This separation is valuable for RE. TerrainRecovery currently combines Cultivator semantics, work-area interpretation, recovery policy and writer scheduling more tightly than ideal.

Candidate RE direction:
- **Work detector:** answers whether an implement is physically working.
- **Work footprint:** produces spatial coverage independent of agricultural state changes.
- **Terrain operation:** LOWER/SMOOTH/RAISE execution and callbacks.
- **Policy/reconciliation:** decides how physical results affect SpatialHistory.

### 2. TerraFarm determines physical machine contact directly

`MachineWorkArea:update()` samples terrain height under configured area nodes and marks each node active when terrain reaches the node. Input deformation runs only when area nodes are active.

For cultivator recovery, RE should prefer GIANTS' work-area activation semantics where available, but TerraFarm demonstrates an important principle: do not infer physical work from an unrelated outcome metric.

This directly reinforces the v22 correction: GIANTS `Cultivator.processCultivatorArea` returns `realArea` (changed agricultural state) separately from `area` (processed area). Repeated passes can have zero `realArea` while remaining real physical work.

### 3. Spatial coverage is machine-defined and sampled across width

`MachineWorkArea` creates nodes across machine width using configurable density (default 0.5, XML-clamped 0.25..4). Wide tools therefore get multiple physical sample/deformation points rather than a single center point.

RE v21/v22 already moved toward full work-area coverage; future refactoring should make coverage a first-class reusable object rather than reconstructing it inside TerrainRecovery.

### 4. Terrain operations use small composable classes

Smooth/flatten/slope/paint operations inherit common input/output behavior. The common layer owns brush creation, constraints, async apply and post-change housekeeping. The operation subclass mainly configures TerrainDeformation mode/target.

RE's TerrainWriter already centralizes much of this lifecycle. The lesson is to keep mode-specific policy outside the generic writer and avoid accumulating Cultivator-specific semantics there.

### 5. TerraFarm is cadence-controlled

`Machine` uses a 50 ms update interval for input operations rather than submitting terrain work every frame. Work-area state can still be updated continuously while expensive deformation is rate-limited.

RE uses different budgets/cooldowns for different physics goals, so 50 ms should not be copied blindly. The reusable principle is explicit cadence ownership.

### 6. Smoothing contract

Input smooth:
- `TerrainDeformation.new(g_terrainNode)`
- `setAdditiveHeightChangeAmount(0.05)`
- `enableSmoothingMode()`
- active work-area nodes receive soft circle/square brushes
- default input state: radius 2 m, strength 0.25, hardness 0.2
- async `apply(false, callback, self)`

Output smooth uses the same smoothing mode but a much larger height-change amount (0.75), because it serves material-output behavior rather than simple input surface conditioning.

Important correction to RE history: TerraFarm's default input strength is **0.25**, not 0.50. RE previously matched Construction-style strength 0.50 while borrowing TerraFarm's API shape. This is not automatically a bug; it means our value is a model choice and must be calibrated rather than described as TerraFarm parity.

### 7. Constraints and dynamic objects are explicit

Input/output operations set outside-area constraints and explicitly configure blocked/dynamic-object displacement before apply. RE should audit its TerrainWriter contract against these constraints instead of assuming default TerrainDeformation behavior is appropriate.

### 8. Async completion owns side effects

TerraFarm applies density/field/AI-dirty/material consequences only from successful deformation callbacks. This is the same general direction RE uses for physical realization and SpatialHistory reconciliation and should remain a hard rule.

### 9. Server owns terrain work

Machine terrain operations execute on server state; client work handles effects/UI/networked state. RE's server-only terrain writer is aligned with this.

## What not to copy

- TerraFarm is an earthmoving/landscaping system; its machine activation and material semantics are not agricultural soil physics.
- Its radii/strength/height amounts are gameplay configuration, not empirical soil constants.
- Its direct terrain-contact nodes solve configured-machine operation, not wheel/soil contact modeling.
- Its resource/filltype accounting does not replace RE/Mud/SoilCompaction ownership.

## Immediate RE lessons

1. Keep v22's separation of physical work from `realArea`.
2. Add a reusable WorkOperationContext rather than passing loosely related scalars.
3. Promote work-area coverage into its own component.
4. Keep operation lifecycle/callback ownership centralized.
5. Compare TerrainWriter constraints against TerraFarm's explicit TerrainDeformation constraints.
6. Treat smoothing strength/radius/cadence as calibrated RE policy, not copied constants.
7. Add causal window telemetry before further physical tuning.

## Follow-up audit

Still worth auditing in detail:
- Machine type/configuration abstraction;
- `getIsAvailable()` activation chain;
- flatten/slope preview-before-apply behavior;
- collision/update strategy;
- material-volume accounting;
- multiplayer events and state synchronization;
- landscaping-area target planes and how they avoid destructive overshoot.

Those are architecture candidates, not prerequisites for the v22 runtime test.
