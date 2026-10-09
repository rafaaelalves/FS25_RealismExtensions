# True AI Tracks functional-absorption assessment

Updated: 2026-10-04

Exact package audited:
- mod: `FS25_aiTracks` / True AI Tracks
- declared version: `2.2.0.1`
- author: KCHARRO
- ZIP SHA-256: `b04b46c08c3c84e0b32a73c3f90939dd572db8742cd18e29ac3c8b98c97c3fb4`
- package size: ~116 KB
- multiplayer declared: true
- source files:
  - `main.lua`
  - `scripts/aiGround.lua`
  - `scripts/aiTracks.lua`

Purpose: evaluate True AI Tracks as a functional-absorption candidate against the current RealismExtensions TerrainDeformation architecture.

## Executive decision

**FUNCTIONALLY REPLACE / ABSORB THE CAPABILITY, NOT THE IMPLEMENTATION.**

The physical-deformation half of True AI Tracks is already conceptually superseded by RE TerrainDeformation.

The remaining useful capability is narrower:

**AI and attached implements should retain the same native GIANTS visual tire-track behavior as player-controlled vehicles.**

That visual capability is not yet explicitly owned by RE and should be folded into the planned Persistent Visual Tracks / native TireTrack adapter rather than preserved as a separate stack mod.

## What True AI Tracks actually does

The mod has two independent functional halves.

### 1. AI/native visual tire tracks

`scripts/aiTracks.lua` overwrites:
- `AIImplement.getAllowTireTracks`;
- `AIJobVehicle.getAllowTireTracks`.

Both return `true`.

This is not a custom visual-track renderer. It simply removes GIANTS AI gating so the vanilla TireTrackSystem continues to create visual tire marks.

This is the most useful remaining capability for RE.

### 2. AI/native wheel displacement

`scripts/aiGround.lua` overwrites:
- `WheelPhysics.setDisplacementAllowed`;
- `WheelPhysics.setDisplacementCollisionEnabled`.

For anything classified as AI, it forces:
- displacement enabled;
- displacement collision enabled;
- `displacementScale = 1.2`.

It also periodically scans the mission vehicle list, recursively walks attached implements, and re-applies these wheel flags.

This is activation of GIANTS wheel displacement, not an independent terrain-response model.

## AI classification

The mod treats a vehicle as AI when any of these hold:
- `vehicle.isAI`;
- `spec_aiJobVehicle` exists;
- type name contains `AI`;
- Courseplay state `vehicle.cp` exists;
- AutoDrive state `vehicle.ad` exists;
- it is attached recursively to a vehicle that satisfies one of the above.

This is broad and pragmatic, but it conflates:
- "vehicle type can participate in AI";
- "AI currently controls the vehicle";
- "Courseplay/AutoDrive metadata exists".

RE does not need this classification for physical rut generation because its deformation law is not supposed to change between human and AI control.

## Exact 2.2.0.1 scan bug — source contradicts changelog

The audited ZIP declares `2.2.0.1` and its ModHub changelog says the old scan-unit bug was fixed.

However the exact `scripts/aiGround.lua` in SHA `b04b46c0...c97c3fb4` still contains:

```lua
lastCheckTime = lastCheckTime + (dt or 0.16)
if lastCheckTime < (SETTINGS.CHECK_INTERVAL / 1000) then return end
```

`CHECK_INTERVAL` is `150`.

FS25 update `dt` is milliseconds. Therefore the accumulator is milliseconds while the threshold is 0.15 seconds represented as a scalar.

At a normal frame, `dt` is already much larger than 0.15, so the mission-wide vehicle scan effectively passes every frame.

This is the same source shape documented in the earlier Talontownsend fix for 2.2.0.0.

Therefore, for this **exact uploaded 2.2.0.1 ZIP**, the claimed fix is not actually present.

Project evidence must prefer exact-source hash over changelog/version text.

## main.lua bootstrap quality

`main.lua` is largely stale/redundant relative to the two source files loaded directly by modDesc.

Important observations:
- modDesc already lists `main.lua`, `aiGround.lua`, and `aiTracks.lua` as extraSourceFiles;
- `main.lua` contains an additional custom `source()` loader;
- it creates/registers `AIVehicleTracks` twice;
- its internal version still says `1.0.0.0`;
- its calls to plain globals `aiGround` / `aiTracks` do not match `aiGround.lua`, which returns a local table rather than publishing that global;
- its secondary listeners are therefore mostly dead/bootstrap noise rather than the real physics owner.

This is not an architecture to reproduce.

## Why RE already supersedes the deformation half

RE attaches TerrainDeformation as a specialization to wheeled vehicle types, not only to player-controlled vehicles.

Its server update path processes each wheel through the same pipeline:
- normalized RC wheel/contact context;
- support width;
- structural radius;
- wheel load;
- tire pressure;
- local physical wetness;
- slip;
- observed sink;
- footprint;
- pressure/deformability response;
- spatial history;
- persistent TerrainDeformation write.

There is no intentional "AI physics multiplier".

That is preferable to True AI Tracks' fixed `1.2` AI displacementScale.

### Same physics for human and AI

RE's principle should remain:

**control source must not change the physical terrain law.**

A 10-ton tractor with the same tire/load/pressure/slip state should produce the same terrain response whether controlled by:
- player;
- GIANTS helper;
- Courseplay;
- AutoDrive.

AI should affect path/control state, not soil physics.

## Attached implements

True AI Tracks specifically evolved recursive implement traversal because its activation strategy scans an AI root vehicle and then tries to reach attached wheeled objects.

RE's specialization model is cleaner:
- every eligible wheeled vehicle type receives TerrainDeformation;
- wheeled implements can therefore own/process their own wheel contacts directly;
- duplicate prevention belongs naturally to per-wheel/per-object state rather than one mission scanner.

Runtime smoke is still required for:
- GIANTS helper with wheeled implement;
- Courseplay;
- AutoDrive;
- nested wheeled attachments.

But no special AI-only deformation architecture is justified.

## What RE still does not absorb

### Native visual tire-track enablement for AI

Current TerrainDeformation is physical terrain ownership.

It does not currently replace:
- `AIImplement.getAllowTireTracks`;
- `AIJobVehicle.getAllowTireTracks`.

Therefore removing True AI Tracks today can still remove **native visual AI tire marks**, even though RE continues to make physical ruts.

This is the principal remaining absorption task.

### Recommended ownership

Do not add a tiny one-off `AITracks` module that only returns true.

Instead put this in the planned native visual-track boundary identified by the Persistent Tracks audit:

```
NativeTireTrackAdapter
    |- normal player native tracks
    |- AI/native gating policy
    |- Persistent Visual Track journal
    |- replay/streaming adapter
```

That gives one owner for GIANTS TireTrackSystem behavior.

## Companion CRAWLERS and NEXAT reveal scope limitations

KCHARRO publishes separate:
- True AI Tracks: CRAWLERS;
- True AI Tracks: NEXAT.

That means the base mod is not a universal footprint/deformation solution for all mobility types.

RE should not recreate a family of vehicle-specific enablement patches.

Current RE behavior:
- ordinary wheeled support is modeled;
- dual/twin support is being normalized through RC;
- crawler footprint currently fails closed intentionally because a crawler requires grouped track geometry/load rather than pretending it is a wide tire.

That is the better long-term architecture.

A future crawler model should represent:
- track contact length/width;
- bogie/roller load concentration;
- track slip/shear;
- effective support pressure.

It should then work identically for player and AI.

## What to learn from True AI Tracks

### Useful

1. **AI visual-track gating is a real separate capability.**
   Physical deformation alone does not guarantee native tire-track visuals.

2. **Wheeled attached implements need explicit runtime coverage.**
   Even if RE's specialization architecture should handle them naturally, this deserves a regression test.

3. **Courseplay and AutoDrive must be tested as control owners.**
   Do not assume GIANTS helper behavior covers third-party controllers.

4. **Exact source beats changelog.**
   The uploaded 2.2.0.1 package demonstrates why source/hash evidence matters.

### Do not copy

1. mission-wide recurring vehicle scans;
2. recursive root-to-implement traversal as the core physical ownership model;
3. AI-only `1.2` deformation multiplier;
4. direct global WheelPhysics method replacement for a capability RE already owns;
5. ad-hoc `vehicle.cp` / `vehicle.ad` presence as the physical model;
6. redundant custom source/bootstrap loader.

## Performance comparison

True AI Tracks' deformation side performs a full `g_currentMission.vehicles` scan and recursive implement/wheel processing on its periodic update.

In the exact uploaded source, the intended 150 ms throttle is broken and the scan is effectively eligible every frame.

RE avoids mission-wide rediscovery:
- specialization is injected at type level;
- wheel state belongs to each loaded wheeled object;
- cheap activity gating happens before expensive provider/model work;
- writer work is separately budgeted.

RE is structurally better suited to large fleets.

## Multiplayer

True AI Tracks declares MP support, but its core behavior is primarily:
- local/global method overrides;
- normal GIANTS wheel-displacement state;
- native tire-track gating.

It does not implement a custom persistent terrain networking protocol.

RE's physical terrain writer remains server-authoritative.

For native visual tracks, the future adapter must determine which GIANTS TireTrackSystem outputs are already client/local/network-managed before adding any custom replication.

Persistent visual history is a different problem and should use the spatial-interest architecture proposed in the Persistent Tracks assessment.

## Licensing

The inspected package contains no explicit reusable source license.

Treat this as clean-room functional analysis.

The functionality is small enough that source copying is unnecessary:
- visual AI gating is conceptually trivial;
- RE physical deformation already has an independent implementation.

## Absorption status

### Physical AI/implement terrain deformation
**ALREADY FUNCTIONALLY REPLACED by RE architecture**, pending targeted runtime validation.

### Native visual AI tire tracks
**CANDIDATE_ABSORB — small missing capability.**

### Crawler/NEXAT deformation
**DO NOT COPY SPECIAL CASES.**
Implement generalized mobility/footprint models when RE supports those categories.

## Runtime closure tests

Before removing True AI Tracks from the target stack, verify:

1. player tractor creates RE physical rut;
2. GIANTS helper on same tractor creates comparable RE rut under equivalent state;
3. wheeled attached implement creates its own RE rut under helper control;
4. nested wheeled attachment;
5. Courseplay-controlled vehicle;
6. AutoDrive-controlled vehicle;
7. AI visual tire tracks after NativeTireTrackAdapter enables them;
8. player visual tire tracks unchanged;
9. Persistent Visual Tracks journal captures AI-created native tracks too;
10. no duplicate physical deformation from player/AI-specific paths;
11. crawler remains explicitly unsupported/fail-closed until grouped-track model exists.

## Final recommendation

True AI Tracks should not remain a long-term stack dependency.

Its physical behavior is narrower and less physically informed than the current RE TerrainDeformation pipeline.

The only distinct feature worth preserving is native AI tire-track visualization, and that belongs naturally inside the same GIANTS TireTrack adapter that will support persistent visual tracks.

Once that adapter is implemented and the AI/implement runtime matrix passes:

**True AI Tracks can be removed from the stack as fully functionally replaced.**
