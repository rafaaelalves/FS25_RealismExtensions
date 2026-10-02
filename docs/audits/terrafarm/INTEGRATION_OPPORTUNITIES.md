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


## 18. Stack-wide capability evaluation model

TerraFarm should not be evaluated only as "TerraFarm vs RE" or "TerraFarm vs RC".

The target realism stack is intentionally fluid. A mod may enter, leave, remain external, be partially composed through RC, or eventually be functionally absorbed by RE depending on:
- implementation quality;
- ownership conflicts;
- API/extension surface;
- runtime stability;
- asset burden;
- maintenance burden;
- multiplayer support;
- performance architecture;
- user-facing coherence;
- whether a clean-room replacement provides enough benefit to justify ownership.

### Preferred project destinations

Today there are two preferred project roles:

**RealismCompatibility (RC)**
Use when the desired capability already exists in one or more external mods and the real problem is:
- conflicting ownership;
- lost hook/semantic path;
- duplicated writes;
- translating authoritative state from one owner into another owner's formulas;
- suppressing overlapping fallback behavior;
- version/contract adaptation;
- maintaining a coherent stack without reimplementing the phenomenon.

**RealismExtensions (RE)**
Use when:
- no external owner provides the desired capability;
- the external implementation is monolithic and cannot expose the needed sub-capability cleanly;
- RC would need brittle/private hooks to recover the behavior;
- multiple fragmented implementations are better replaced by one coherent clean-room capability;
- persistent/world-level state belongs naturally in RE;
- functional absorption materially reduces conflicts or enables better authoritative inputs.

A third project is not ruled out, but should require a genuinely different ownership/lifecycle/deployment boundary rather than being created for organizational convenience.

### Consequence for TerraFarm

Each TerraFarm capability should be classified independently:

```text
KEEP EXTERNAL
    TerraFarm remains owner; RC only observes if necessary.

COMPOSE THROUGH RC
    TerraFarm remains owner, but authoritative state/ownership must be coordinated with the rest of the stack.

OPTIONAL RE CONSUMER/ADAPTER
    RE consumes TerraFarm geometry/state/events while keeping its own capability owner.

CANDIDATE ABSORB INTO RE
    Reimplement the behavior independently if there is a concrete architectural/gameplay benefit.

DO NOT ADOPT
    Capability is outside the desired realism model or introduces more burden than value.
```

Do not decide at mod granularity if capability granularity gives a better result.

## 19. Stack-wide TerraFarm interaction matrix

The following is the current source-derived/provisional view. "No direct conflict found" means only that the audited TerraFarm source does not touch the relevant owner surfaces; runtime validation is still required for the full stack.

### MoreRealistic (MR)

**Observed TerraFarm behavior**
- no motor torque/load/PTO/friction ownership found in audited TerraFarm source;
- TerraFarm primarily owns deliberate terrain landscaping and its machine/work-area state.

**Relationship**
- largely orthogonal mechanically;
- indirect interaction occurs because TerraFarm changes physical terrain geometry that MR-driven vehicles later traverse.

**Potential RC role**
- none required for drivetrain ownership from current evidence;
- if TerraFarm machines later gain physics/load semantics, re-audit before composing.

**Potential RE role**
- consume changed heightfield physically through normal terrain queries/history reconciliation.

**Current disposition**
KEEP both; no MR↔TerraFarm bridge justified today.

### MudSystemPhysics

**Observed domains**
- Mud owns local wetness, sink, resistance, stuck and wheel-ground terramechanics.
- TerraFarm owns explicit excavation/grading/smoothing/material terrain operations.

**Relationship**
- no source-level direct friction/sink ownership collision found;
- TerraFarm can radically alter the geometry on which Mud subsequently operates.

**Opportunity**
- future TerraFarm machine operations could optionally consume RC-normalized wetness/material context for operation quality, but only if TerraFarm exposes/needs such semantics.
- RE natural/recovery systems should continue consuming Mud state independently; TerraFarm must not become a replacement soil-wetness source.

**Current disposition**
KEEP specialist separation. RC bridge not currently required.

### Reifenverschleiss / tire wear

TerraFarm does not appear to own tread wear, wheel radius or tire friction.

Indirectly, TerraFarm equipment still uses normal vehicle wheels and therefore Reifen/MR/Mud physics may apply to the carrier vehicle.

**Current disposition**
No TerraFarm-specific RC bridge justified.

### SoilCompaction

This is a more interesting semantic interaction.

SoilCompaction owns persistent agronomic compaction and tillage relief.
TerraFarm can physically lower/raise/smooth terrain but does not appear to update SoilCompaction's compaction map.

Therefore a TerraFarm operation can visually/physically reshape soil while agronomic compaction remains unchanged.

This is not automatically a bug:
- grading a surface is not equivalent to removing subsoil compaction;
- excavation may physically remove/redeposit soil without SoilCompaction understanding that process.

**Future integration questions**
- Should a TerraFarm ripper operation count as tillage relief in SoilCompaction?
- Should a compactor machine add SoilCompaction state?
- Should excavation/replacement reset, translate or preserve cell compaction?
- Can this be expressed through SoilCompaction public/existing work-operation contracts rather than copied formulas?

**Likely project destination**
RC if SoilCompaction exposes enough semantic entry points.
RE only if a broader unified soil-volume/history model eventually owns the missing physical consequence.

This is a high-value future audit item.

### RMS / ADS branch

TerraFarm does not currently appear to inject mechanical load, PTO load, wear, thermal or failure state.

But TerraFarm machines represent physically demanding operations such as ripping/excavating/compacting.

That means the current stack may visually perform heavy earthmoving without RMS necessarily seeing a corresponding mechanical work demand beyond normal vehicle movement/hydraulics.

**Opportunity**
Audit whether TerraFarm-native machines already generate GIANTS power/hydraulic/PTO demand through their vehicle definitions.

If not, a future integration could expose operation effort/load to RMS/MR through existing owner contracts.

**Project destination**
RC if this is translation into existing MR/RMS load mechanisms.
Do not put a second engine-load model in RE.

### Dynamic PTO / WorkMode

No direct TerraFarm PTO semantics were found in the audited core.

Most TerraFarm equipment appears landscaping/hydraulic rather than PTO-centric, but individual configured machines may still use native power consumers.

**Opportunity**
No generic TerraFarm↔DynamicPTO bridge should be invented.
Evaluate only concrete equipment where the machine definition actually uses PTO.

WorkMode may already provide hydraulic/work RPM behavior for some TerraFarm-capable vehicles; this is a runtime interaction worth testing if the equipment needs raised working RPM.

### FarmKit

This is the largest terrain-domain overlap in the current ecosystem.

FarmKit historically provided:
- custom player slip/scrub terrain ruts;
- furrow/crop/effects systems;
- other bundled realism features.

RC's conservative FarmKit profile already suppresses overlapping FarmKit ground-core behavior where MR/Mud/Reifen/True AI Tracks own the same domain, and RE now owns player persistent geometric ruts/recovery.

TerraFarm adds another deliberate TerrainDeformation writer.

**Stack implication**
Terrain ownership now has at least three conceptual sources:
- RE: persistent consequence of vehicle/soil interaction and recovery;
- TerraFarm: explicit landscaping/earthmoving operation;
- FarmKit: residual unique terrain/crop systems such as furrow interaction, with its custom rut core already suppressed in the target profile.

**RC opportunity**
A single terrain-write ownership model may be preferable to pairwise "FarmKit vs TerraFarm", "RE vs TerraFarm", etc.

Candidate capability ownership states:
- passive wheel consequence;
- agricultural work recovery;
- deliberate landscaping;
- furrow/crop interaction;
- AI/native-style deformation;
- world/public maintenance.

RC should coordinate only where two external/current owners write the same phenomenon.

### True AI Tracks

True AI Tracks restores native-style deformation for AI and implement wheels.

TerraFarm is not an AI-rut replacement. Its machine operations are explicit landscaping behavior.

Potential overlap occurs only when:
- an AI-controlled TerraFarm machine is physically driving/working;
- True AI Tracks deforms wheels/implement wheels;
- TerraFarm simultaneously reshapes the operation footprint.

This is analogous to the RE cultivator problem:
the tool operation may need to own/overwrite some wheel-generated geometry while active.

**Future decision**
Once RE reaches AI/implement parity and True AI Tracks is reconsidered, include TerraFarm AI-machine scenarios in the retirement/coexistence test matrix.

### MoistureSystem

MoistureSystem owns agronomic/material moisture.
TerraFarm owns fill/material earthmoving and map resource types.

Potential future opportunity:
- excavated/deposited materials could eventually carry material moisture;
- soil/material removed by TerraFarm could interact with MoistureSystem's pile/material state.

No such integration is established in the current audited code.

This is a candidate ecosystem integration, but it is outside current terrain-recovery scope.

### RealisticHarvesting

No direct TerraFarm overlap found.

Indirect overlap may arise only if landscaping affects fields/crops/density state. TerraFarm can clear field/deco/weed/stone states during terrain modification, but it is not a harvest-processing owner.

No RC bridge justified from current evidence.

### RealPhysics LoadSpill / Loose Load

TerraFarm has material excavation/deposition into fill units and terrain.
LoadSpill/Loose Load own material escaping from vehicles and/or discharge dynamics.

Potential overlap:
- TerraFarm output/discharge machinery may use fill units/discharge nodes that a load-spill mod also observes;
- TerraFarm modifies discharge behavior for some configured machines.

This deserves equipment-specific testing because TerraFarm can overwrite configured discharge methods.

**Likely RC role**
Ownership arbitration only if the same discharge/material-transfer path is modified by both.
Do not generalize a bridge without a concrete collision.

### soundExpansionMP / visual effects

No direct TerraFarm sound-extension integration was found.

TerraFarm has its own machine effects and UI; soundExpansionMP owns operational/MP sound patches.
Likely coexistence, but configured earthmoving equipment should be smoke-tested for duplicated tool sounds.

### Courseplay / AutoDrive / GIANTS AI

No named Courseplay/AutoDrive integration was found in audited TerraFarm source.

TerraFarm machine terrain input is driven by machine state/contact on the server, not by direct player input. Therefore it may naturally work under AI if the machine is activated and the required state remains valid.

Questions for runtime validation:
- does GIANTS AI activate/retain TerraFarm machine state correctly?
- can Courseplay control a TerraFarm machine without fighting input/activation?
- does AutoDrive transport leave TerraFarm inactive as expected?
- do large TerraFarm heightfield edits invalidate AI navigation promptly?

The last point is partly handled by TerraFarm's own `aiSystem:setAreaDirty` after successful deformation.

## 20. Capability absorption perspective

TerraFarm should not be assumed permanent merely because current integration looks clean.

Potential long-term RE absorption candidates include:
- generic target-plane grading;
- path/corridor maintenance;
- public/municipal terrain maintenance;
- selected soil-work recovery operations;
- terrain-operation profiles and area geometry.

Reasons to leave TerraFarm external for the foreseeable future:
- rich machine ecosystem and maintained equipment configs;
- UI/editor/HUD;
- material/fill-unit earthmoving workflow;
- assets and effects;
- multiplayer state/events;
- landscaping-area editor;
- dedicated author/community maintenance burden.

This is exactly the kind of capability set where external ownership can remain preferable even if RE could technically reproduce it.

Absorption should be justified by a concrete integration or realism benefit, not by theoretical ability to implement it.

## 21. Stack evolution rule

The current stack is a working ownership graph, not a permanent dependency list.

When evaluating any newly discovered mod:
1. decompose it into capabilities;
2. identify existing owners in RC/RE/external stack;
3. classify each capability as keep/compose/absorb/reject;
4. estimate asset and maintenance cost;
5. prefer external specialist ownership when quality is high and integration is clean;
6. prefer RC when composition solves the problem without new simulation ownership;
7. prefer RE when the capability is missing or cannot be recovered cleanly through compatibility;
8. revisit decisions when upstream mods improve, regress, expose APIs, disappear, or become costly to maintain.

TerraFarm is now documented under this same rule.
