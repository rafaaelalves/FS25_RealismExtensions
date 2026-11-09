# TerraFarm audit — multiplayer, persistence, areas and map resources

Updated: 2026-10-02
Audited source: `scfmod/FS25_TerraFarm` commit `b50e677cdef062d605ab188f8982ae1faa2789e7`.

## 1. Server-authoritative terrain behavior

### Source finding

Machine terrain input executes on server state. Client-side update work is largely UI/debug/effects.

Machine state is sent through:
- initial vehicle stream;
- discrete state events;
- dirty update stream for work-effect state.

### RE lesson

This aligns with RE's server-owned TerrainWriter.

Future pass tracking, autonomous recovery and TerraFarm compatibility should remain server-authoritative. Clients need only synchronized state/UI that is not already represented by the replicated terrain itself.

## 2. Machine-state persistence

### Source finding

Per-machine savegame state includes:
- enabled/resources enabled;
- input/output mode;
- selected input/output landscaping area;
- selected fill type;
- terrain layers;
- MachineState properties such as brush radius/strength/hardness, ratios, effects, cleanup options, direction policy, grading options and collision behavior.

The vehicle specialization persists this under the vehicle savegame entry.

### RE lesson

Separate:
- per-machine/tool configuration;
- global module settings;
- world/persistent terrain history.

Do not place all state into one monolithic RE save file.

## 3. Global settings vs user settings

### Source finding

TerraFarm separates:
- savegame/global gameplay settings (`terraFarmSettings.xml`);
- per-client/user UI/debug settings (`userSettings.xml`).

### RE lesson

Useful precedent for future RE:
- simulation policy belongs to savegame/server state;
- diagnostic/UI preferences can remain local-user state.

## 4. Landscaping areas are persistent world objects

### Source finding

TerraFarm defines persistent, networked landscaping areas:
- polygon areas with target height;
- path/corridor areas with width and 3D control points.

Common area metadata includes:
- unique ID;
- name;
- restrict-area flag;
- icon/color;
- optional forced fill type;
- optional forced input/output terrain layers.

Areas are saved to `terraFarmAreas.xml`, loaded after terrain initialization and synchronized to joining clients.

Area registration/update/delete use explicit events and message-center notifications.

Current serialization allocates 6 bits for area count and point count, giving a design ceiling around 63 items/points.

### RE integration opportunity

TerraFarm's area system could optionally provide geometric **target corridors/polygons** to RE in future, especially for:
- municipal/public maintenance corridors;
- target-grade maintenance;
- excluded/controlled construction regions.

However, TerraFarm areas do **not** currently encode RE ownership semantics such as PUBLIC_MAINTAINED, NPC_FIELD or PLAYER_PROPERTY.

Therefore:
- do not auto-interpret all TerraFarm areas as RE maintenance zones;
- require explicit opt-in/convention/adapter metadata if this integration is added;
- retain RE's own ownership-zone contract.

## 5. Path areas as target grade precedent

### Source finding

A TerraFarm path area:
- stores 3D points and width;
- finds the nearest path segment;
- can reject positions outside half-width;
- computes a target height and slope plane from neighboring path points;
- returns min/max height constraints around endpoints/interior.

### RE opportunity

This is a strong precedent for future:
- road-corridor maintenance;
- grader target-plane recovery;
- municipal path restoration;
- slope-aware recovery targets.

RE should reuse the mathematical concept, not depend on TerraFarm's class unless an optional adapter is explicitly enabled.

## 6. Polygon areas as target surface precedent

### Source finding

Polygon areas define:
- an inside/outside test;
- a fixed target Y;
- optional restriction to the polygon.

### RE opportunity

Useful precedent for:
- yards/pads/public maintenance zones;
- explicit construction target surfaces;
- flat-area restoration.

Again, geometry is useful; ownership semantics are absent.

## 7. Area events as optional integration surface

### Source finding

TerraFarm exposes message types/events for:
- area register;
- area update;
- area delete;
- initial area synchronization.

### Integration opportunity

A future optional TerraFarm adapter could subscribe to TerraFarm's own message-center events via its mod environment and maintain cached area geometry without polling.

This is cleaner than wrapping TerraFarm area methods.

## 8. Map resource extension

### Source finding

TerraFarm can read a map-defined InfoLayer (`mapGroundResources`) that maps world positions to:
- fill type;
- input/output paint layer;
- yield multiplier.

It is intended for mining/earthmoving material identity.

### RE/RC caution

Do not treat TerraFarm resource layers as authoritative soil mechanical properties.

Potential optional uses:
- material-class hint for future SoilMassTransport;
- differentiate rock/stone/dirt handling when no stronger specialist source exists;
- public/construction terrain presentation.

Mud/RC remains the preferred source for wheel-soil wetness/terramechanics.

## 9. Save lifecycle

### Source finding

TerraFarm appends `SavegameController.onSaveComplete` to persist:
- global TerraFarm settings;
- landscaping areas.

### Compatibility note

This is a relatively low-risk append hook, but it is still part of TerraFarm's hook surface. RE/RC should not assume save completion is untouched by other mods.

## 10. Initial client synchronization

### Source finding

TerraFarm appends `FSBaseMission.sendInitialClientState` and sends:
- global settings/materials;
- map resources state;
- landscaping areas;
- waterplanes.

### RE lesson

For future autonomous-recovery zones or profile registries in multiplayer, define explicit initial-state synchronization rather than relying on late local discovery.
