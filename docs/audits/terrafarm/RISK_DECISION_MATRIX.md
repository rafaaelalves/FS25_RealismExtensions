# TerraFarm audit — risk and decision matrix

Updated: 2026-10-02
Audited source: `scfmod/FS25_TerraFarm` commit `b50e677cdef062d605ab188f8982ae1faa2789e7`.

| Surface / concept | Learn/copy concept | Optional read-only integration | Patch/wrap directly | Notes |
|---|---|---|---|---|
| Machine type vs operation mode | YES | YES | NO | Strong precedent for RecoveryProfile vs TerrainOperation. |
| Work-area nodes across width | YES | YES | NO | Useful for WorkFootprint; do not assume exact node-contact rule fits agriculture. |
| 50 ms cadence | CONCEPT ONLY | n/a | NO | Explicit cadence ownership is useful; constant is TerraFarm policy. |
| Input SMOOTH constants | RESEARCH ONLY | n/a | NO | Gameplay config, not soil constants. |
| TerrainDeformation constraints | YES | n/a | NO | Operation-specific profiles are valuable. |
| Preview-before-apply grading | YES | n/a | NO | Good for target grading/deposition when preview metric is relevant. |
| Physical displaced volume accounting | YES | n/a | NO | High-value SoilMassTransport precedent. |
| AI `setAreaDirty` after large writes | YES | n/a | NO | RE gap for future large operations. |
| External machine-config registry | YES | POSSIBLY | NO | Good precedent for RE profile packs. |
| Dynamic Machine specialization injection | LEARN ONLY | NO | AVOID | Overwrites Vehicle.load and mutates instance specializations. |
| MachineManager MACHINE_ADD/REMOVE | n/a | YES | NO | Clean event-driven adapter opportunity. |
| `spec_machine` active/mode/workArea | n/a | YES | NO | Candidate ownership-awareness contract, version-gated. |
| Landscaping area register/update/delete | YES | YES | NO | Useful optional geometry cache. |
| Path/polygon target geometry | YES | YES | NO | Do not infer RE ownership/zone semantics automatically. |
| Map resource InfoLayer | CONCEPT | OPTIONAL | NO | Material hint only; not soil mechanics. |
| Landscaping callbacks | LEARN | MAYBE | AVOID | No stable generic completion event currently; patching callbacks is brittle. |
| Visual tire tracks | LEARN | MAYBE | NO | Separate from physical heightfield; MP caveat upstream. |
| Savegame/network event architecture | YES | OPTIONAL | NO | Good precedent for explicit initial sync. |
| InteractiveControl API integration style | YES | n/a | NO | Prefer cooperative APIs over hooks. |

## Primary compatibility risks

### R1 — duplicate terrain ownership
TerraFarm and RE can both write the same heightfield region.

Mitigation:
- detect actual operation state;
- arbitrate ownership at operation-footprint level;
- preserve MR/Mud physics and visual systems independently;
- reconcile SpatialHistory physically after external writes.

### R2 — hook/load-order complexity
TerraFarm overwrites `Vehicle.load` and other UI/shop surfaces.

Mitigation:
- do not add another TerraFarm-specific Vehicle.load wrapper;
- use environment/events after mods load;
- inspect ModMixer chains before shipping an adapter.

### R3 — internal API drift
Useful TerraFarm objects/events are currently implementation surfaces, not a formal stable public API contract.

Mitigation:
- exact version detection;
- source audit on updates;
- fail closed;
- RC version-compatibility policy.

### R4 — history desynchronization
External terrain writes can invalidate RE SpatialHistory.

Mitigation:
- lazy physical reconciliation as generic core behavior;
- optional immediate attribution only as optimization.

### R5 — visual/physical mismatch in multiplayer
Heightfield can be correct while tire-track decals remain visually stale on clients.

Mitigation:
- document domains separately;
- do not use decal disappearance as proof of physical recovery;
- only add visual-track integration if a reliable synchronized API exists.

### R6 — semantics mismatch
TerraFarm earthmoving machine types/material layers do not equal agricultural soil profiles.

Mitigation:
- explicit mapping;
- never infer ground bearing strength from TerraFarm yield/fill type;
- continue using MR/Mud/RC specialist state for soil-wheel physics.

### R7 — licensing/copying
TerraFarm's repository license is CC BY-NC-ND 4.0.

Mitigation:
- independent implementation;
- no vendoring/adapted TerraFarm source;
- behavioral/source audit only;
- runtime integration through contracts/events.
