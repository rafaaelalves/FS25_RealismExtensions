# TerraFarm audit — machine lifecycle and work detection

Updated: 2026-10-02
Audited source: `scfmod/FS25_TerraFarm` commit `b50e677cdef062d605ab188f8982ae1faa2789e7`.

This document supplements the main TerraFarm audit. It records source behavior separately from RE/RC design inferences.

## 1. Machine registration model

### Source finding

TerraFarm supports two machine-integration paths:

1. A vehicle mod explicitly includes the `FS25_0_TerraFarm.machine` specialization as the last specialization.
2. TerraFarm loads external `machineConfigurations.xml` registries and dynamically injects its `Machine` specialization into matching already-loaded vehicle instances.

External configuration files can live in another active mod at:
- `/machineConfigurations.xml`
- `/xml/machineConfigurations.xml`

Entries map a vehicle XML path to a TerraFarm machine configuration XML.

For external configurations, TerraFarm overwrites `Vehicle.load`, calls the previous/super load first, then:
- resolves a matching configuration;
- clones the vehicle's specialization tables so the type definition is not mutated;
- inserts the Machine specialization;
- installs Machine functions;
- manually registers Machine event listeners.

The official package expects the mod name/filename `FS25_0_TerraFarm`; TerraFarm warns when the technical mod name differs because external mods may refer to that specialization name.

### RE/RC lesson

The **configuration registry** is a strong precedent. The **runtime specialization injection** is not automatically a pattern RE should copy.

For future RE tool/contact profiles, prefer an optional external registry such as:
- tool recovery profile configuration;
- contact-footprint overrides;
- crawler/contact metadata corrections.

That allows equipment mods or compatibility packs to provide semantics without hard-coding model names in RE.

Avoid injecting a new RE specialization into arbitrary vehicle instances unless there is a clear need. TerraFarm's solution is powerful but touches the global `Vehicle.load` chain and manually mutates per-instance specialization tables.

## 2. Machine type abstraction

### Source finding

TerraFarm defines semantic machine types:
- `compactor`
- `discharger`
- `excavatorRipper`
- `excavatorShovel`
- `leveler`
- `ripper`
- `shovel`
- `trencher`

Each type declares capabilities such as:
- input support;
- discharge/output support;
- fill unit use;
- leveler/shovel integration;
- driving-direction requirements.

A machine configuration then selects supported input/output modes independently:
- `RAISE`
- `LOWER`
- `SMOOTH`
- `FLATTEN`
- `PAINT`
- `MATERIAL`

### RE/RC lesson

This is a useful example of separating:
- **machine family/capability**
from
- **current operation mode**.

Future `TerrainRecoveryProfile` should follow the same conceptual separation:
- tool family describes physical capability;
- active work operation describes what is happening now.

If TerraFarm compatibility is enabled later, `spec_machine.machineTypeId` and current `inputMode/outputMode` are useful semantic signals, but TerraFarm's categories should not become RE's universal ontology.

## 3. Activation chain

### Source finding

TerraFarm separates activation prerequisites from actual ground contact.

`getCanActivateMachine()` checks:
- global TerraFarm enabled state;
- per-machine enabled state;
- player landscaping permission;
- powered state when configured;
- turned-on state when configured.

`getIsAvailable()` further requires:
- machine active;
- a non-material input mode;
- capacity available when relevant;
- configured driving direction.

Only then does server `onUpdate()` use the work area's physical-contact state and cadence to perform terrain input.

### RE/RC lesson

This reinforces an explicit `WorkDetector`/context model with reasoned state rather than one boolean derived from an outcome.

Useful future diagnostic reasons include:
- disabled;
- not active;
- powered/turned-off;
- no valid work direction;
- no terrain contact;
- operation cadence not due;
- capacity/material constraint;
- ownership arbitration.

Do not equate TerraFarm's `getIsAvailable()` with agricultural work state: it includes TerraFarm-specific permission/capacity semantics.

## 4. Work-area contact model

### Source finding

`MachineWorkArea` builds transform nodes across configured width.

Defaults:
- node density starts at 0.5 m in code;
- XML density is clamped to 0.25..4 m;
- width is clamped to 0.1..16 m.

For tools wider than ~1.5 m, node count is approximately `round(width / density) + 1`.

Every active update:
- each node's world position is sampled;
- terrain height is sampled under the node;
- node is active when terrain Y >= node Y;
- the work area is considered active when at least one node is active.

Output/deposition uses a separate output node.

### RE/RC lesson

Strong precedent for `TerrainWorkFootprint`:
- represent a wide tool with multiple spatial samples;
- separate input/work coverage from output/deposition position;
- keep contact detection distinct from terrain operation.

Do not copy the exact `terrainY >= nodeY` test universally. Agricultural GIANTS work areas already expose stronger operation semantics for many tools, and crawler/wheel contacts need different contact contracts.

## 5. Cadence

### Source finding

Machine input deformation is explicitly rate-limited:
- `spec.updateInterval = 50` ms;
- work-area/contact state may update every frame;
- input TerrainDeformation is submitted only when the interval expires and at least one work-area node is active.

### RE/RC lesson

The transferable idea is **explicit cadence ownership**, not the 50 ms constant.

RE should keep:
- fast state/contact observation;
- separately budgeted physical writes;
- pass-based recovery dose where pass semantics are stronger than wall-clock cadence.

## 6. Driving direction

### Source finding

Machine state can require:
- forwards;
- backwards;
- both;
- or unrestricted behavior.

Attached machines can resolve driving direction from the root vehicle.

### RE/RC opportunity

Future tool profiles may need direction semantics:
- grader/blade operating direction;
- ripper direction;
- tool orientation relative to rut direction.

TerraFarm demonstrates that direction belongs in machine operation context, not in the TerrainWriter.

## 7. Active-machine registry

### Source finding

`MachineManager` maintains a collection of TerraFarm machine vehicles and publishes:
- `MACHINE_ADD`
- `MACHINE_REMOVE`
- active-machine changes

through TerraFarm's message types.

### Integration opportunity

If RC/RE gains an optional TerraFarm adapter, use the TerraFarm environment's manager/message types to maintain an event-driven set of TerraFarm machines.

Prefer this over:
- scanning every vehicle every frame;
- wrapping `Vehicle.load` again;
- trying to rediscover configured machines by XML path.

This is one of the cleanest direct integration surfaces found in the audit.

## 8. Collision handling

### Source finding

TerraFarm machine configuration can nominate collision nodes. When a machine is active, those nodes can be scaled to zero; they are restored when inactive.

### RE caution

Do not copy this behavior into general RE work detection/terrain physics. It is TerraFarm-specific machinery behavior and can materially change collision semantics.

If diagnosing odd physical interactions with TerraFarm equipment, however, remember that an active TerraFarm machine may intentionally alter its configured collision nodes.
