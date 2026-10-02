# TerraFarm audit — compatibility and integration opportunities with RC/RE

Updated: 2026-10-02
Audited source: `scfmod/FS25_TerraFarm` commit `b50e677cdef062d605ab188f8982ae1faa2789e7`.

This document is intentionally conservative. It separates opportunities from recommendations.

## 1. Current relationship

TerraFarm and RE are both persistent terrain writers, but they solve different primary problems:

- TerraFarm: explicit landscaping/earthmoving machine operations, materials, target areas and construction-style terrain control.
- RE: persistent consequence of vehicle/soil interaction, agricultural recovery and broader realism ownership composition.

They can coexist, but overlapping writes/history need explicit semantics.

## 2. Detection strategy

### Source finding

The official TerraFarm package expects technical mod name `FS25_0_TerraFarm`.

Its script environment exposes objects such as:
- `Machine`;
- `g_machineManager`;
- `g_landscapingManager`;
- `ModMessageType`;
- operation classes/state.

### Recommendation

If compatibility work begins:
- add explicit TerraFarm detection to RC's ModDetector;
- detect the active technical name rather than guessing from repo name;
- access TerraFarm only through its mod environment;
- version-gate the adapter using RC's existing VERIFIED/SOURCE_COMPATIBLE/CONTRACT policy.

Do not assume future TerraFarm versions preserve internals just because class names remain.

## 3. Prefer observation/adaptation over patching TerraFarm

### TerraFarm hook surface found

Global/engine hooks include:
- `Vehicle.load` overwritten for dynamic specialization injection;
- `ShopController.makeDisplayItem` overwritten;
- `GuiOverlay.loadOverlay` overwritten;
- `FSBaseMission.initTerrain` appended;
- `FSBaseMission.sendInitialClientState` appended;
- `SavegameController.onSaveComplete` appended;
- configured vehicle discharge methods may be overwritten.

### Recommendation

RC/RE should avoid wrapping the same TerraFarm internals unless necessary.

Prefer:
- TerraFarm's message-center events;
- `spec_machine` state;
- public functions injected on TerraFarm machines;
- physical heightfield reconciliation.

This reduces load-order sensitivity and ModMixer complexity.

## 4. Event-driven machine adapter

### Opportunity

TerraFarm's `MachineManager` publishes machine add/remove events.

A future RC TerraFarm adapter can:
1. subscribe after TerraFarm loads;
2. cache configured TerraFarm machines;
3. attach no new specialization;
4. expose normalized operation state to RE.

Candidate normalized state:
```text
source = TERRAFARM
machineType
inputMode / outputMode
active
available
workAreaContact
workArea width / nodes
input/output role
rootVehicle
```

### Benefit

No global vehicle scanning and no second `Vehicle.load` patch.

## 5. Terrain-writer ownership arbitration

### Problem

When a TerraFarm machine is actively smoothing/flattening/lowering/raising terrain, RE wheel rut writing can conflict with the deliberate landscaping operation.

### Opportunity

Extend `WorkOperationContext` / RecoveryAgent arbitration to recognize a TerraFarm operation.

Possible rule:
- when a TerraFarm machine is active, available and its work area is in physical contact, deliberate TerraFarm terrain operation owns its operation footprint;
- RE can suppress/reconcile conflicting persistent rut writes for the same combination/region during that operation;
- visual tire tracks and MR/Mud physics remain independent.

### Important

Do not globally disable RE around every TerraFarm-configured machine. Ownership should depend on actual active/contact state and operation footprint.

## 6. SpatialHistory compatibility

### Problem

TerraFarm can physically alter terrain without notifying RE SpatialHistory.

### Preferred solution

Implement RE's planned lazy physical history reconciliation:
- when an RE historical cell becomes relevant;
- compare physical relief with stored history;
- reconcile stale entries.

This solves TerraFarm, Construction landscaping and other external terrain writers at once.

### Avoid

Avoid making RE history correctness depend on patching `LandscapingBase:onDeformationCallback`. That would tightly couple RE to TerraFarm internals and still not solve other terrain editors.

## 7. Optional deformation-observer adapter

If future features need immediate TerraFarm attribution rather than lazy reconciliation, consider an **optional observer**, not core dependency.

Potential sources:
- Machine add/remove registry;
- machine mode and work-area active state;
- TerraFarm message center;
- possibly operation lifecycle only if TerraFarm publishes a stable contract in a future version.

Current source does not expose a generic public “terrain deformation completed in region X” event. Patching callbacks would therefore be a higher-risk integration.

## 8. Recovery/tool-profile mapping

### Opportunity

TerraFarm machine types/modes can optionally map to RE semantics:
- `ripper` / `excavatorRipper` -> deep disturbance/ripping profile;
- `leveler` -> grading/finish profile;
- `compactor` -> compacting/finish operation;
- `SMOOTH` / `FLATTEN` / `LOWER` modes -> operation intent.

### Caution

Do not assume TerraFarm's machine type implies an agricultural `TerrainRecoveryProfile`. This mapping should be explicit and optional.

## 9. External profile/configuration precedent

### Source finding

Other mods can ship `machineConfigurations.xml` to add TerraFarm behavior to their equipment without TerraFarm hardcoding every mod.

### RE opportunity

Adopt a similar extension mechanism for future:
- `TerrainRecoveryProfile`;
- `ContactFootprint` overrides;
- crawler grouping corrections;
- implement work-footprint metadata.

A compatibility pack could register profiles for third-party equipment without modifying RE core.

Suggested principles:
- configuration registry loaded after active mods are known;
- exact vehicle XML path or stable semantic match;
- validation and diagnostics for missing files/profiles;
- no runtime code execution from profile files.

## 10. TerraFarm landscaping areas and RE maintenance zones

### Opportunity

TerraFarm path/polygon areas are persistent and multiplayer-synchronized. They could optionally seed:
- target corridors;
- target heights/planes;
- public road maintenance geometry;
- construction exclusion/priority areas.

### Caution

Do not infer ownership from TerraFarm's area name/icon/color alone.

Possible future explicit adapter options:
- RE configuration maps selected TerraFarm area unique IDs to RE zone policy;
- naming/tag convention only if user explicitly enables it;
- a future upstream TerraFarm metadata extension if collaboration becomes possible.

## 11. Map resources and SoilMassTransport

### Opportunity

TerraFarm's map resource layer can identify material classes such as dirt/stone and provide yield.

Potential use:
- optional material classification for mass transport/excavation;
- distinguish rock-like areas from soft soil when no specialist source is better.

### Caution

TerraFarm resource yield is an earthmoving/mining gameplay value, not ground-bearing strength, wetness or compaction.

Do not replace Mud/RC soil state with TerraFarm resource state.

## 12. AI navigation updates

### Source finding

TerraFarm marks modified regions dirty in GIANTS AI after successful heightfield changes.

### RE gap/opportunity

RE currently has no equivalent AI-area dirty path.

Before implementing large:
- municipal maintenance;
- target grading;
- autonomous field/world recovery;
- large SoilMassTransport deposition;

add a bounded modified-region accumulator and invalidate AI navigation after successful physical writes.

For tiny rut brushes, evaluate whether dirtying every write is necessary; coalescing/budgeting may be required.

## 13. Multiplayer compatibility

### Source finding

TerraFarm:
- performs terrain operations server-side;
- streams machine state;
- uses discrete events for settings/areas;
- sends explicit initial client state.

### RE recommendation

Any direct TerraFarm adapter should run ownership decisions server-side.

Clients should not independently decide whether TerraFarm and RE operations overlap.

## 14. Load-order sensitivity

### Source finding

TerraFarm explicitly warns if its mod technical name is not `FS25_0_TerraFarm`, because other mods may depend on its specialization name.

It also overwrites `Vehicle.load`.

### Recommendation

Do not create an RE dependency requiring TerraFarm to load before/after RE.

RC should discover TerraFarm after active mods/environments exist and fail closed when its expected runtime contract is unavailable.

## 15. InteractiveControl precedent

### Source finding

When `FS25_interactiveControl` is present, TerraFarm detects it and registers optional functions through the external mod's API rather than patching it.

### RE lesson

This is a good model for cooperative compatibility:
- detect capability;
- call documented/extensible API;
- no ownership takeover;
- no dependency when absent.

Where an upstream mod offers a real extension API, prefer it over hooks.

## 16. Recommended compatibility tiers

### Tier 0 — coexistence only
- detect TerraFarm for diagnostics;
- no behavior changes;
- rely on lazy physical history reconciliation.

### Tier 1 — ownership awareness
- event-driven machine registry;
- normalized TerraFarm active-operation context;
- suppress conflicting RE terrain writes only inside active operation footprint.

### Tier 2 — semantic integration
- optional mapping from TerraFarm machine types/modes to RE Recovery/Work profiles;
- optional area-to-maintenance-zone adapter;
- optional resource-layer material hints.

### Tier 3 — shared contracts/upstream collaboration
Only if stable APIs emerge:
- direct deformation-completion events;
- shared region/change attribution;
- explicit extension metadata for maintenance/recovery semantics.

RE should not jump directly to Tier 3 by patching internal callback methods.

## 17. Proposed audit-driven tests before any integration

1. Load TerraFarm + current RE with no adapter; record ModMixer hook chains.
2. Verify whether an active TerraFarm SMOOTH/FLATTEN operation conflicts with RE wheel rut writes.
3. Manually modify a region with TerraFarm and test lazy SpatialHistory reconciliation.
4. Verify TerraFarm machine add/remove messages can be consumed through its environment without patching.
5. Test server/client visibility of `spec_machine` state in multiplayer.
6. Verify operation footprint/nodes are stable enough for read-only ownership arbitration.
7. Measure AI pathing after large RE terrain edits before deciding AI-dirty policy.
