# Project status

Updated: 2026-09-29

## Repository state

Project foundation / audit phase.

No production gameplay code has been committed yet.

## Current upstream baseline

The companion RC repository is at **0.2.0.0** on `main` with conservative FarmKit ownership merged.

Relevant RC behavior:

```text
MR / Mud / Reifen -> base wheel physics, traction, sink/resistance
Mud                -> wheel-ground particles
MR                 -> suspension ownership during FarmKit plowing
True AI Tracks     -> AI ground-deformation owner in the conservative profile
RealPhysics        -> load-spill owner when installed
FarmKit            -> Planner/PF, furrow collider behavior, crop damage,
                      implement dust, road spray, engine-sound propagation,
                      straw refeed routing
```

Important RC limitation that RE is designed to solve:

- FarmKit `densityEnabled` couples custom slip/scrub ruts with its own overlapping ground/sink core.
- RC therefore disables the whole FarmKit ground core when the specialist stack is present.
- Custom player slip/scrub ruts are intentionally lost in the safe RC profile.

## First implementation target

### TerrainDeformation

Goal: restore richer terrain consequences without owning traction, sink or drivetrain physics.

Initial capability set:

- player longitudinal-slip ruts;
- lateral scrub / steering ruts;
- optional native-style AI wheel deformation;
- attached-implement wheel deformation;
- physical-wetness modulation from the active ground owner;
- tire/footprint-aware deformation inputs when authoritative state is available;
- no traction/friction writes;
- no sink-radius writes;
- no stuck/speed-cap writes;
- no permanent tire-wear writes.

### AI ownership transition

Initial safe stack can keep True AI Tracks as the AI deformation owner while RE develops player slip/scrub deformation.

Once RE's AI/implement path reaches parity and passes performance/runtime validation, True AI Tracks becomes a candidate for full behavioral replacement.

## Modules under consideration

```text
TerrainDeformation        -> PRIORITY / design next
SurfaceContamination      -> candidate; visual/effect layer only
CropInteraction           -> candidate evolution of FarmKit crop consequences
FurrowInteraction         -> candidate evolution of FarmKit plowing/furrow behavior
LooseMaterialConsequences -> candidate; spill/overflow/discharge split by capability
PTOSystem                 -> future candidate; Dynamic PTO currently remains specialist
TireWearState             -> future candidate; Reifen currently remains specialist
```

## Initial six-mod survey status

| Mod | Current RE decision |
|---|---|
| MoistureSystem | **KEEP specialist + BRIDGE** |
| True AI Tracks | **KEEP initially; candidate REPLACEMENT by TerrainDeformation** |
| RealPhysics LoadSpill | **KEEP specialist initially** |
| Loose Load | **KEEP / COMPARE by spill sub-capability** |
| Mud Sprayer | **Do not absorb assets/code; visual behavior is replaceable** |
| Multiplayer Game Sound Expansion | **KEEP external; compatibility smoke, not absorption target** |

Vehicle Control Addon is not part of the FS25 roadmap unless a concrete FS25 release/source is identified.

## Next engineering gate

Before writing TerrainDeformation production code:

1. define the normalized read-only input contract;
2. identify the exact GIANTS terrain-deformation entry points required for player, AI and implement wheels;
3. preserve current owner boundaries from RC;
4. build a small harness/prototype proving that deformation can be added without traction/sink writes;
5. define update cadence and duplicate-processing guards;
6. validate save/load and multiplayer semantics;
7. compare runtime with True AI Tracks before deciding when RE may replace it.

## Audit confidence

- RC/FarmKit ownership: source- and runtime-backed by the RC repository.
- MoistureSystem: public source and current ModHub behavior rechecked.
- True AI Tracks / Loose Load / Mud Sprayer / soundExpansionMP: public current behavior rechecked; detailed source-hook notes from the prior ZIP session must be revalidated before implementation depends on them.
- RealPhysics LoadSpill: public behavior plus prior exact-ZIP observations; detailed source-hook map should be preserved in a dedicated re-audit before replacement work.
