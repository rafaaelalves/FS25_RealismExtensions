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

## Additional audit: guarded terrain operations

TerraFarm's flatten/slope output path uses a useful two-stage pattern:
1. build the deformation and call `apply(true, previewCallback)`;
2. inspect the preview's displaced volume;
3. only call the real `apply(false, callback)` when the predicted change exceeds a radius-scaled threshold.

Its input flatten path also gates each node against the target height and can refuse grading upward unless explicitly allowed.

This suggests a broader RE design principle: **predict/gate destructive or target-seeking terrain operations before committing them when the engine exposes a preview contract**.

For TerrainRecovery SMOOTH specifically, do not change v22 before its runtime test just to add preview semantics; smoothing's desired metric is roughness reduction, not displaced volume. But future recovery modes (target-plane grading, mass-conserving redistribution, maintenance) should evaluate whether preview-first execution can prevent pathological writes and unnecessary jobs.

## Audit-derived engineering questions

- Can RE wrap TerrainDeformation constraints (outside-area, blocked-area, dynamic-object displacement) in one explicit operation profile instead of relying on defaults?
- Should future WorkFootprint sample configured/derived nodes across implement width similarly to TerraFarm rather than regenerate a generic grid per call?
- Can target-plane recovery use preview-before-apply to enforce a maximum physically predicted displacement?
- Which operation telemetry belongs in the generic TerrainOperation layer versus recovery policy?

## Additional audit: explicit machine availability chain

TerraFarm does not infer "working" from terrain output. Its `Machine:getCanActivateMachine()` and `Machine:getIsAvailable()` separate prerequisites such as:
- global/mod enabled state;
- per-machine enabled/active state;
- access/permission;
- powered/turned-on requirements when applicable;
- fill/capacity constraints;
- configured driving-direction policy.

Only after availability is true does `Machine:onUpdate()` use physical work-area contact (`isAreaNodeActive`) and the 50 ms cadence to execute terrain input.

This is a strong precedent for RE's future `WorkDetector`: represent work eligibility as explicit facts rather than infer it from a downstream result like changed field area. The detector should be able to explain *why* work is active/inactive with reason counters suitable for diagnostics.

Do not retrofit the full abstraction before v22 validation. The current GIANTS Cultivator work-state path is the minimal targeted fix; extraction should follow runtime proof.


## Deep-audit expansion (2026-10-02)

The initial audit above remains valid. It is now supplemented by focused documents:

- `MACHINE_LIFECYCLE.md` — machine discovery/configuration, dynamic specialization injection, availability chain, work-area contact, cadence, registry/events and collision behavior.
- `TERRAIN_PIPELINE.md` — TerrainDeformation operation classes, constraints, preview/apply lifecycle, callback ownership, material-volume accounting, density side effects and AI navigation dirtying.
- `PERSISTENCE_AREAS_NETWORKING.md` — savegame/network model, persistent path/polygon landscaping areas, target planes, map resources and initial client synchronization.
- `INTEGRATION_OPPORTUNITIES.md` — compatibility tiers, RC/RE ownership arbitration, event-driven adapters, SpatialHistory strategy, profile registries and proposed runtime tests.

### New high-value conclusions

1. **TerraFarm has two useful extension patterns, but only one is low-risk for RE.**
   - Low-risk precedent: external XML machine-configuration registry.
   - Higher-risk mechanism: dynamic per-instance Machine specialization injection through an overwritten `Vehicle.load`.
   RE should strongly prefer a profile/configuration registry over runtime specialization injection.

2. **Machine family and operation mode are separate concepts.**
   TerraFarm machine types describe capability while `LOWER/SMOOTH/FLATTEN/RAISE/PAINT/MATERIAL` describe current intent. This is a strong precedent for separating RE `TerrainRecoveryProfile` from active `TerrainOperation`.

3. **Work contact and terrain execution are deliberately decoupled.**
   Work-area nodes update contact continuously; expensive terrain input executes on an explicit cadence. This reinforces RE's separation between WorkContext/PassTracker and TerrainWriter budgets.

4. **Physical callback volume is the material-accounting authority.**
   TerraFarm does not assume requested excavation/deposition equals realized volume. This is directly relevant to the planned SoilMassTransport redesign.

5. **Successful heightfield edits have secondary world consequences.**
   TerraFarm marks modified bounds dirty in GIANTS' AI system. RE currently lacks this path. Large future grading/municipal/world-recovery operations should coalesce modified regions and invalidate AI navigation after successful physical writes.

6. **Persistent target geometry is a mature concept in TerraFarm.**
   Path areas define 3D corridors and target slope; polygon areas define bounded target planes. These are useful mathematical precedents for road/public maintenance and target-plane grading, but their metadata does not represent RE property/ownership policy.

7. **TerraFarm already offers clean event-driven observation surfaces.**
   Its machine manager publishes machine add/remove events and its area system publishes register/update/delete events. An optional adapter can observe these instead of adding another global vehicle scan or another `Vehicle.load` wrapper.

8. **Lazy physical SpatialHistory reconciliation remains the preferred compatibility mechanism.**
   It solves TerraFarm, Construction landscaping and other terrain writers generically. Directly patching TerraFarm deformation callbacks should not be required for baseline correctness.

9. **Visual tire tracks and physical terrain are separate compatibility domains.**
   TerraFarm documents a multiplayer limitation where client-side tire tracks are not removed by terraforming because base-game tire tracks are not synchronized for that behavior. RE should not assume a repaired heightfield implies repaired/removed visual track decals on all clients.

10. **Compatibility should be layered, not all-or-nothing.**
    Start with coexistence/diagnostics, then optional ownership awareness, then semantic mapping only if justified. Do not make TerraFarm a hard RE dependency.

## Clean-room / licensing boundary

TerraFarm's repository currently declares Creative Commons Attribution-NonCommercial-NoDerivatives 4.0.

For this project, treat the audit as a **behavioral/architectural precedent only**:
- document observed engine contracts and design patterns;
- implement RE/RC behavior independently;
- do not copy TerraFarm source into RE/RC;
- do not distribute modified/adapted TerraFarm code as part of this project;
- where an integration is needed, communicate through runtime state/events/contracts rather than vendoring or modifying TerraFarm.

This is an engineering boundary for the project, not legal advice. Any future code-sharing/collaboration arrangement would require checking the applicable upstream permission/license terms separately.

## Recommended near-term follow-up research

Before writing a TerraFarm adapter:
1. runtime probe the TerraFarm environment and exact event objects;
2. inspect ModMixer chains with TerraFarm + RE/RC loaded;
3. verify whether active TerraFarm operations and RE rut writers overlap in practice;
4. prototype read-only machine registry subscription;
5. validate multiplayer visibility of `spec_machine`, active mode and work-area contact;
6. test large RE heightfield modifications against GIANTS AI path recalculation;
7. then decide whether RC needs a TerraFarm detector/adapter.

No TerraFarm bridge is required to continue TerrainPassTracker/RecoveryProfile/ContactFootprint development.
