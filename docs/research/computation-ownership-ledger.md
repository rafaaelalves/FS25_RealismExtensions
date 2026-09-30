# Computation ownership ledger

Updated: 2026-09-29

Purpose: make explicit who computes each physical quantity, which older calculations are disabled, and whether RC/RE reuses state or recalculates it.

## Core rule

A capability has three separate questions:

1. Who owns the physical effect?
2. Who owns the authoritative calculation/state?
3. Does another mod still execute redundant work even though its effect is suppressed?

One-owner architecture solves only the first question. RC/RE should reduce all three where practical.

## Current wheel / ground ledger

| Quantity or effect | Authoritative owner today | RC action | RE action | Duplicate CPU status |
|---|---|---|---|---|
| base drivetrain / wheel dynamics | MoreRealistic | preserve MR ownership | consume normalized state | FarmKit wheel core disabled |
| local physical field wetness | Mud FieldLocalWetness | inject into MR and cache snapshot | reuse fresh RC/MR snapshot | direct RE resample avoided when snapshot is fresh |
| baseline rolling resistance | MoreRealistic | zero Mud baseline term | consume consequences only | duplicate effect removed; Mud sink/slip resistance still evaluated |
| sink/slip excavation resistance | Mud | preserve | consume sink state | required owner calculation |
| permanent tread wear | Reifenverschleiss | compose into MR | consume structural radius | no RE wear calculation |
| structural tire radius | Reifen + RC MRMud composition | resolve/cache structural baseline | reuse fresh snapshot | repeated hierarchy walk avoided when fresh |
| temporary sink radius loss | Mud | keep separate from structural radius | consume sinkDepthM | no RE sink calculation |
| tire pressure | Mud TirePressureSystem | expose state | FootprintModel consumes | owner getter/cache only |
| wheel load | Mud WheelLoadSystem; MR fallback | expose normalized newtons | FootprintModel consumes | no RE mass/axle model |
| longitudinal/lateral slip | MR cached GIANTS slip; GIANTS fallback | expose | TerrainResponse consumes | direct engine slip call avoided when MR cache exists |
| wheel surface speed | MR cache; GIANTS axle fallback | expose | shear model consumes | reuse-first |
| ground profile/freeze | Mud | expose | TerrainResponse consumes | no competing RE profile |
| terrain rut geometry | RealismExtensions | no competing owner | calculate/write | genuinely new capability |
| agronomic/material moisture | MoistureSystem | future bridge | future consumer | intentionally separate from physical wetness |

## FarmKit decomposition

FarmKit is not treated as one indivisible mod.

### Disabled or ceded

- wheel physics/grip core -> MR/Mud/Reifen stack;
- engine RPM/bog mode -> MR/RMS/Dynamic PTO stack;
- ground physics core -> Mud/Reifen/RE path;
- wheel dust -> Mud;
- load spill -> RealPhysics LoadSpill.

These are disabled through FarmKit enable flags where available. The main FarmKit wheel callback can return before executing its grip/sink/deformation calculations when both wheel and ground cores are external.

### Still executing intentionally

- plowing/furrow detection;
- selected presentation/features not yet replaced.

RC suppresses FarmKit's competing suspension write while allowing furrow logic to run. This is semantically correct but not maximally cheap and is tracked as a future absorption/optimization target.

## Reuse-first provider policy

Every RE consumer should prefer:

existing fresh authoritative state -> owner cache/getter -> engine API fallback -> new calculation only when the capability is genuinely RE-owned.

The ExtensionsStateProvider now follows this rule for wetness, structural radius and slip. Provider telemetry measures snapshot hits versus fresh/direct reads.

## Why RE does not pretend to implement calibrated Bekker/Wong physics

Classical terramechanics pressure-sinkage models require terrain parameters such as cohesion/friction-related moduli and sinkage exponent. FS25 maps do not expose a trustworthy calibrated set of those parameters for every ground state.

TerrainResponse v1 is therefore deliberately hybrid:

- measured/composed wheel load and pressure where available;
- observed Mud sink as a physical lower bound;
- local wetness and freeze from Mud;
- measured longitudinal/lateral slip and wheel/body speed;
- bounded saturating shear response;
- explicit provisional calibration constants.

This is more defensible than inventing Bekker constants for every FS25 ground type and presenting them as measured physics.

## Known performance debts

1. FarmKit plowing logic still runs while RC suppresses only its competing suspension write.
2. FarmKit wheel-dust wrapper calls still occur even though the original dust work is bypassed after cleanup.
3. Mud+Soil should be audited for avoidable wetness recomputation.
4. Development telemetry increments counters on hot paths; release configuration must benchmark and reduce/disable it.
5. TerrainDeformation history persistence and crawler support remain unresolved.

These are tracked work, not hidden assumptions.

## External-update propagation rule

RC/RE intentionally distinguishes **authoritative state reuse** from **algorithm copying**.

When an external owner changes an already-exposed runtime result while preserving its contract, downstream consumers inherit the new result without duplicating its algorithm. For example, a Mud update that changes local wetness, sink depth/severity, ground profile, tire pressure or wheel load should affect RE through the normalized provider.

An update does not automatically alter RE-owned consequence logic such as rut capacity, shear accumulation, surface classification or brush geometry. Those remain RE behavior and require deliberate calibration when upstream semantics materially change.

Therefore compatibility with an external update is evaluated at the contract boundary:
1. did the owner still produce the state we consume?
2. did its units/range/meaning remain compatible?
3. did behavior change enough that RE consequence calibration should be revisited?
4. can a new authoritative output replace any remaining RE inference?

This preserves improvements from specialist updates without coupling RE to private formulas or freezing copied implementations.
