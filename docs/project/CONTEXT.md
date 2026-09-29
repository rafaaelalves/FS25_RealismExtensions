# Project context

Updated: 2026-09-29

## Why this repository exists

FS25 Realism Extensions (RE) is a modular realism-extension project for Farming Simulator 25.

It is intentionally separate from [FS25 Realism Compatibility (RC)](https://github.com/rafaaelalves/FS25_RealismCompatibility):

- **RC coordinates ownership between existing specialist mods.** It should not become a new physics/gameplay overhaul.
- **RE adds missing consequences and selectively replaces narrow features** when doing so gives a cleaner, more complete or more compatible implementation.

The immediate trigger for RE is RC 0.2.0.0's conservative FarmKit integration. RC correctly suppresses FarmKit's overlapping wheel/ground core when MoreRealistic, MudSystemPhysics, Reifenverschleiss and/or True AI Tracks own that state. The side effect is that FarmKit's custom slip/scrub rut deformation is unavailable because the current FarmKit density toggle couples ruts to its competing sink/ground model.

RE exists to recover capabilities like those ruts without restoring duplicate traction, sink, stuck or drivetrain physics.

## Design rules

1. **Capability ownership first**
   - Decide ownership per phenomenon, not per mod name.
   - A mod can remain authoritative for one capability while RE replaces another.

2. **Do not duplicate specialist physics**
   - MoreRealistic remains drivetrain/base vehicle dynamics owner.
   - MudSystemPhysics remains physical ground wetness/sink/resistance/stuck owner.
   - Reifenverschleiss remains permanent tire-wear owner unless a later explicit replacement is justified.
   - SoilCompaction remains persistent compaction/agronomic-memory owner.
   - MoistureSystem remains agronomic/material moisture owner.
   - Dynamic PTO remains PTO-mode/effective-ratio owner until a later deliberate replacement project.

3. **Read authoritative state; write only the missing consequence**
   - Prefer normalized state exposed by RC when available.
   - Otherwise use narrow read-only adapters with explicit version/runtime contracts.
   - Never infer a second physical model merely to drive an effect.

4. **Modular by construction**
   - Each RE capability can be enabled/disabled independently.
   - No module should require the whole realism stack unless its semantics actually depend on it.

5. **Clean-room / license conservative**
   - Public behavior is a specification, not permission to copy implementation.
   - Do not copy Lua, XML, textures, sounds, i3D assets or other authored content without an explicit compatible license or permission.
   - When a source repository/package has no explicit compatible license, implement independently from documented/runtime behavior.
   - Attribution is still preserved in audit notes even when no code is reused.

6. **Performance is a feature**
   - Avoid per-frame world scans when event-, wheel-, or vehicle-scoped work is enough.
   - Cache only authoritative data with safe invalidation.
   - AI/implement processing must avoid duplicate traversal.

7. **Multiplayer from the start**
   - Prefer deterministic effects derived from synchronized owner state.
   - Server owns gameplay-changing consequences; client-only presentation remains presentation.

## Moisture vocabulary

RE must not collapse all "moisture" into one scalar.

```text
physicalGroundWetness
  -> MudSystemPhysics
  -> wheel/soil consequence: deformation depth, resistance context, contamination effects

agronomicFieldMoisture
  -> MoistureSystem
  -> crop/field management: harvest windows, irrigation, withering, drying context

materialMoisture
  -> MoistureSystem
  -> harvested material/piles/bales/storage/quality/drying
```

Terrain deformation consumes **physicalGroundWetness**.

Harvesting, drying, hay/straw and storage systems consume **agronomicFieldMoisture** and/or **materialMoisture**.

These domains may correlate but are not interchangeable.

## Relationship with FarmKit

RC 0.2.0.0 currently retains FarmKit capabilities that do not collide with stronger owners, including:

- Planner / Precision Farming aggregation
- realistic-plowing collider/furrow behavior (while RC protects MR suspension ownership)
- speed-based crop damage
- implement dust
- road spray
- drivetrain sound propagation
- straw refeed routing

RE does not need to replace all of these at once.

The first goal is to recover the missing ground-deformation capability cleanly. Other retained FarmKit features can be replaced later only when RE offers a demonstrably better standalone module.

## Source-audit continuity note

The initial RE survey began from exact ZIPs supplied during the 2026-09-29 working session. Those transient uploads are not persisted in this repository. The capability conclusions from that source inspection are preserved in the audit documents here, but any detailed hook-level implementation claim must be revalidated from source before production code depends on it.
