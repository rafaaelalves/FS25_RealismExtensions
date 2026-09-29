# Initial external-mod capability audit

Date: 2026-09-29

Scope:

- `FS25_MoistureSystem`
- `FS25_aiTracks` / True AI Tracks
- `FS25_RealPhysics_LoadSpill`
- `FS25_LooseLoad`
- `FS25_Mud_Sprayer`
- `FS25_soundExpansionMP`

This audit combines:
- the completed RC FarmKit ownership audit;
- exact-ZIP observations made during the preceding working session;
- current public ModHub/GitHub behavior rechecked on 2026-09-29.

Detailed hook-level source claims must be revalidated before production code depends on them when the exact ZIP/source is not retained in-repo.

---

## MoistureSystem

Current public line checked: `2.0.0.5`.

Public source:
https://github.com/Ozz-Modding/FS25_MoistureSystem

ModHub:
https://www.farming-simulator.com/mod.php?mod_id=354130&title=fs2025

### Observed scope

MoistureSystem is not a small "wet ground" helper. It is a deep agronomic/material simulation covering:

- terrain-aware field moisture;
- regional/weather profiles;
- irrigation;
- crop quality / price consequences;
- harvest moisture capture;
- pile/material property tracking;
- tedding/drying;
- hay conversion / re-wetting behavior;
- ground material rot;
- bale moisture/rotting;
- storage/silo drying;
- HUD/menus;
- multiplayer state/events.

Its public source exposes `getMoistureAtPosition(x, z)` and uses it broadly across crop, mower, baler, cutter, windrower and material paths.

### Ownership decision

**KEEP specialist + BRIDGE.**

Do not merge MoistureSystem into RE.

The important architectural correction is to distinguish its agronomic/material moisture from Mud's physical wheel-ground wetness:

```text
physicalGroundWetness   -> Mud
agronomicFieldMoisture  -> MoistureSystem
materialMoisture        -> MoistureSystem
```

### License/source policy

The audited public repository tree does not expose a conventional `LICENSE` file, and the project README states that code/XML/documentation pull requests are not accepted.

RE therefore treats MoistureSystem as an integration/provider source only. Do not copy code or assets without explicit permission/license.

---

## True AI Tracks

Current public line checked: `2.2.0.1`.

ModHub:
https://www.farming-simulator.com/mod.php?mod_id=318473

### Observed scope

True AI Tracks is intentionally narrow:

- AI vehicles deform terrain;
- recursive attached-implement processing;
- per-wheel processing;
- implement-wheel deformation;
- duplicate prevention;
- corrected 150 ms vehicle scan cadence in 2.2.0.1.

The author's public MR discussion describes the core motivation as restoring ground deformation for AI rather than inventing a second traction/sink model.

### Ownership decision

**KEEP initially; candidate REPLACEMENT by TerrainDeformation.**

This is exactly the kind of small, focused capability that RE can clean-room reproduce and then extend:

- player slip/scrub deformation;
- AI baseline deformation;
- implement-wheel deformation;
- authoritative wetness/footprint inputs;
- shared duplicate-processing/performance policy.

Until RE reaches parity and runtime proof, True AI Tracks remains AI owner and RE should avoid double deformation.

---

## RealPhysics LoadSpill

Public line checked: `1.0.0.0`.

Author page:
https://tubez47.itch.io/fs25-realphysics-loadspill

### Observed scope

RealPhysics focuses on:

- rollover/tip-angle spill;
- recoverable ground deposit plus some gameplay loss;
- loose-material allowlisting;
- multiplayer;
- normal discharge rate driven by trailer tip animation/angle;
- discharge-area/length changes while tipping.

Prior exact-ZIP inspection also showed this mod is small and focused compared with broader systems.

### Ownership decision

**KEEP specialist initially.**

Do not treat "load spill" as one atomic future feature. Preserve its strong ownership of rollover spill and discharge dynamics until a unified RE loose-material module is explicitly designed.

---

## Loose Load

Current public line checked: `1.0.0.0`.

ModHub:
https://www.farming-simulator.com/mod.php?mod_id=370216

### Observed scope

Loose Load overlaps rollover spill but adds a distinct loading/containment capability family:

- spill on rollover in multiple orientations;
- overflow while continuing to fill a full trailer;
- spill when loading a trailer with a closed cover;
- a closed cover contains the load during rollover;
- delayed overflow onset;
- cargo-colored dust and pouring sound;
- multiplayer and in-game configuration.

### Ownership decision

**KEEP / COMPARE BY SUB-CAPABILITY.**

RealPhysics and Loose Load are not interchangeable.

Decompose future ownership into:

```text
rolloverSpill
loadingOverflow
coverContainment
dischargeDynamics
spillPresentation
materialRules
```

Both mods can compete for `rolloverSpill`, so do not assume they should run together unchanged. Verify configuration granularity before building a combined stack profile.

A future RE module may unify the best behavior cleanly, but it is not a TerrainDeformation prerequisite.

---

## Mud Sprayer

Current public line checked: `1.0.0.0`.

ModHub:
https://www.farming-simulator.com/mod.php?mod_id=355179&title=fs2025

### Observed scope

Public behavior is presentation-focused:

- dry-field driving emits dry mud/dust-like spray;
- wet-field driving emits wet mud spray.

Prior ZIP inspection indicated a small amount of logic wrapped around mostly effect assets.

### Ownership decision

**Do not absorb code/assets. Behavior is replaceable.**

MudSystemPhysics already owns the physical wheel-ground domain and its particle consequences in the current stack.

If RE later creates `SurfaceContamination`, it should:
- consume authoritative ground/wheel state;
- add only missing presentation;
- avoid duplicate Mud wheel particles;
- use original RE assets or properly licensed assets.

Mud Sprayer is therefore not a physics dependency and not a first implementation target.

---

## Multiplayer Game Sound Expansion

Current public line checked: `1.2.0.0`.

ModHub:
https://www.farming-simulator.com/mod.php?mod_id=354574

### Observed scope

This is a patchpack for game/MP sound-adjacent behavior, including:

- compressor and blow-off sounds;
- vehicle/attachment/tool operating sounds;
- tree-fall sound handling;
- reverse warning/lights timing;
- cruise-control interaction;
- passenger interior/exterior camera sound behavior.

The completed RC FarmKit audit already established a provisional composition:

```text
MoreRealistic      -> drivetrain/load/RPM synthesis semantics
soundExpansionMP   -> additional operational/MP sound behaviors
FarmKit            -> spatial propagation of tagged drivetrain samples
```

### Ownership decision

**KEEP external.**

No current evidence justifies absorbing this patchpack into RE.

If RE eventually replaces FarmKit engine-sound propagation, keep that as a narrow acoustic-propagation module and preserve soundExpansionMP operational behaviors.

---

## Resulting priority

```text
1. TerrainDeformation
   - recover player slip/scrub ruts lost by RC's safe FarmKit profile
   - coexist with AITracks first
   - later replace AITracks after parity/performance proof

2. State/provider boundaries
   - Mud physicalGroundWetness
   - RC-composed slip/tire state where available
   - MoistureSystem agronomic/material moisture only where relevant

3. Surface/crop/furrow modules
   - only after TerrainDeformation is stable

4. LooseMaterialConsequences
   - independent later design
   - capability-level RealPhysics/LooseLoad comparison

5. PTOSystem / TireWearState
   - deliberate future replacement projects, not incidental scope growth
```

Vehicle Control Addon is removed from the current FS25 survey until a concrete FS25 implementation exists.
