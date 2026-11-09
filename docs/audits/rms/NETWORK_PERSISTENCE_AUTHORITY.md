# RMS networking, persistence and authority — pass 1

Baseline: RMS `0.10.0.0`.

## Server ownership

Persistent mechanical simulation is principally server-authoritative. Client presentation and input are synchronized into server decisions rather than each peer independently running the whole wear simulation.

That is the correct baseline for:
- random breakdowns;
- service results;
- wear/condition;
- thermal/electrical persistent state;
- physical fluid transactions;
- drivetrain state.

## Incremental stream architecture

RMS allocates one GIANTS dirty flag and layers 11 semantic bit groups over it:
```text
1     STATE
2     SERVICE_CONTEXT
4     TELEMETRY
8     THERMAL
16    ELECTRICAL
32    FIELDCARE
64    WEAR
128   BREAKDOWNS
256   SERVICE_PROGRESS
512   TUTORIAL_DATA
1024  DRIVETRAIN
```

`SYNC_GROUP_ALL = 2047`.

For each joined connection, RMS keeps a pending bit mask. A domain-specific comparison function raises only the groups whose data changed materially.

Examples of network noise suppression include epsilon thresholds for:
- operating time;
- fuel usage;
- dynamic load/slip;
- thermal values;
- battery values;
- system condition/stress;
- service progress.

This is a strong design pattern for a state-rich FS25 simulation.

## Initial stream

On join, RMS sends a complete vehicle snapshot. In addition to the incremental domains it sends:
- the complete maintenance history as `UInt16 count + serialized entries`;
- exhaust wet-stacking/deposit state.

The maintenance history is also saved persistently and each entry contains a substantial condition snapshot.

## Maintenance log scaling

`addEntryToMaintenanceLog()` assigns monotonically increasing IDs and appends entries. No source-level pruning/cap was found.

Every initial join serializes all entries for every RMS vehicle.

This is not a short-save bug, but it is an unbounded long-save/fleet scaling surface. A future upstream improvement could:
- retain full save history but page/lazy-load UI/network history;
- cap normal join history and request older pages on demand;
- compact old snapshots;
- introduce a configurable archival limit.

## Per-connection pending masks

`rmsPendingByConnection` is initialized as a normal Lua table and populated when a connection receives the initial vehicle stream.

`raiseRMSDirty()` iterates all keys and ORs the requested group bits into each mask.

No source-level disconnect cleanup or weak-key mode was found in pass 1.

Classification: STRONG_CANDIDATE lifecycle/memory issue. GIANTS connection lifetime semantics should be runtime-checked before calling it a demonstrated leak.

Straightforward defensive options:
- weak-key table (`__mode='k'`) if safe for GIANTS connection objects;
- explicit connection-removal cleanup;
- periodic pruning against live server connections.

## Client-to-server event review

### Good authority examples

`RMS_ServiceRequestEvent`:
- resolves the user/farm from the connection;
- requires the requesting farm to own the vehicle;
- validates current state and service type;
- validates workshop hours;
- delegates to a server transaction that checks stock and money.

`RMS_DrivetrainEvent`:
- rejects server-origin direction;
- requires `vehicle:getOwnerConnection() == connection` before applying state.

`RMS_SettingsSyncEvent` and `RMS_ConsoleCommandEvent`:
- require a server-resolved master user.

`RMS_FluidTransferRequestEvent`:
- builds requester context from the connection;
- validates ownership of source and target;
- validates player/container/vehicle distance;
- validates motor/transfer/circuit state.

`RMS_HandToolSyncEvent` / jumper cables:
- validate that the requesting connection maps to the player actually carrying the tool before server action.

### Authority gaps

`RMS_ReinitializeVehiclesEvent`:
- UI is normally restricted to server/master users;
- server event handler itself does not repeat the master-user check;
- any client able to construct/send the event can request `reinitializeAllVehicles()`.

This is a confirmed missing server-side authorization check.

`RMS_StartButtonEvent`:
- validates that the vehicle is synchronized and has RMS;
- writes start-button state and can call `RMS_Preheat.requestStart()` on server;
- does not verify the sending connection controls/owns that vehicle.

This is a confirmed authority gap even if ordinary UI only sends it from the controlled machine.

`RMS_EffectSyncEvent`:
- allows three start-related effect IDs from client to server;
- applies their status/timer payload before rebroadcast;
- does not validate that the sender controls the target vehicle;
- does not validate a strict allowed transition graph.

This is another confirmed trust-boundary weakness. It is especially relevant because RMS otherwise follows a strong server-authoritative model.

`RMS_FieldInspectionEvent` maps the connection to a player but accepts the carried vehicle reference without an event-level distance/ownership check. The called state method only records the player/timer. This is lower severity than the start/reinitialize paths and should be reviewed together with the interaction trigger before patching.

## Workshop transaction integrity

`RMS_FluidWorkshop.tryStartService()` is a positive reference implementation:
1. validates server/state/workshop;
2. discovers selling point;
3. computes fluid requirements;
4. allocates owned stock or dealer purchase;
5. verifies available farm money;
6. begins container transactions;
7. initializes service;
8. checks that post-init requirements equal reserved requirements;
9. consumes exact liters;
10. rolls back partial consumption on failure;
11. commits containers;
12. charges the farm.

This is the kind of transaction boundary RE should emulate if it later owns any persistent economy/resource workflow.

## Persistence

RMS persists a broad vehicle-local model including:
- condition/service/system state;
- stress and breakdowns;
- service lifecycle/progress;
- real operating time;
- engine/transmission thermal;
- battery/electrical state;
- radiator/air-filter/lubrication;
- physical fluid levels, compatibility and leak debt;
- drivetrain state;
- PTO wear/engagement information;
- maintenance history;
- effect-related persistent data such as exhaust deposit.

Schema registration includes legacy `AdvancedDamageSystem` keys and migration paths.

This is a strong lifecycle pattern: migration is explicit rather than relying on ad-hoc runtime detection of old fields.

## Release packaging governance

The audited game ZIP contains source headers stating GPL v3-or-later and `See LICENSE`, but no `LICENSE` or `NOTICE` file was found inside that ZIP.

The official repository does contain both files and documents fork provenance.

Classification: packaging/provenance cleanup candidate, not a simulation defect.

# RMS 0.11 authority delta

## New battery charger is server-authoritative by design

The charger request path derives requester identity from the network connection
and validates:
- requester farm;
- charger ownership;
- spectator state;
- player proximity;
- player vehicle state;
- target/mode validity.

Live charger measurements are published from the server after the one
authoritative battery integration.

This is a positive contrast with older RMS request surfaces that still trust
client-selected vehicle targets more than they should.

## Vehicle exclusion improves authorization semantics

The exclusion event now routes client requests through
`getCanSetUserExclusion(..., connection)` before server mutation.

This is a positive owner-side hardening and requires no RC patch.

## Settings remain authoritative

The current settings sync path still validates master-user authority before
applying client-proposed server settings.

The 0.11 settings reduction does not weaken that ownership boundary.

## Old authority findings not superseded

The improved new events do not automatically close:
- RMS-01 fleet reinitialize;
- RMS-02 start button;
- RMS-03 start-effect sync.

Those older event implementations remain materially unchanged and must be
evaluated independently.
