# Realistic Brakes — network, persistence and authority audit

Updated: 2026-10-06  
Exact baseline: 1.3.0.0

## Main vehicle persistence

Per vehicle RB saves:
- exhaust-brake state;
- exhaust level;
- exhaust forced-off state;
- brake temperature;
- permanent brake damage;
- parking-brake state / related stable state as applicable.

The source also registers trailer pressure separately under:
`rbTrailerAir#presion`.

Stable physical state is therefore persisted rather than rebuilt blindly.

## Main initial stream

RB main specialization has a real full initial stream.

It sends:
- exhaust active;
- exhaust level;
- exhaust forced-off;
- quantized brake temperature;
- parking-hold exceeded;
- quantized permanent brake damage;
- parking brake on/off.

Positive:
- joining clients do not have to wait for the first ordinary dirty update;
- compact temperature/damage representation.

## Main update stream

One dirty flag currently groups:
- brake temperature;
- parking-hold exceeded;
- permanent brake damage.

Dirty is raised after meaningful changes such as temperature delta > 2 C and discrete parking transition.

This is efficient enough for the current small state.

If the system grows, follow the RMS precedent:
```text
THERMAL
PARKING
CONDITION
PNEUMATIC
```
as separate semantic groups.

Do not make every change resend unrelated domains.

---

## Park event authority gap

`RBParkEvent` carries:
- target vehicle;
- requested boolean.

On server receipt it invokes `rbSetParkBrake` and rebroadcasts.

Missing server checks include:
- sender controls target;
- sender belongs to target farm / has permission;
- target is in a legal state for that action.

The normal UI may only generate legitimate requests, but event security must not depend on UI behavior.

Target:
```text
client sends intent
server resolves connection -> controlled vehicle
server validates transition
server applies accepted state
server broadcasts accepted result
```

Prefer not to let client choose an arbitrary target object where the server can derive it.

---

## Exhaust event authority gap

`RBStateEvent` carries:
- target vehicle;
- active;
- level;
- forcedOff.

Server accepts and rebroadcasts without proving controller ownership.

The server should also own/validate:
- allowed level;
- whether vehicle has exhaust brake;
- authoritative simulation setting/mode.

Do not trust a client-provided "level 3" because the client menu allowed it.

---

## Local settings vs multiplayer simulation

RBSettings is stored in:
`modSettings/FS25_RealisticBrakes_config.xml`.

It mixes:

### Local preference
- HUD visible;
- HUD layout/calibration.

### Simulation-affecting settings
- exhaust automatic/manual mode;
- default exhaust level;
- fade heating scale;
- trailer-air enabled.

No server/save settings synchronization was found.

Potential divergence:
- server heat model uses server-local fadeScale;
- client HUD/options can display another preference;
- trailer-air physics can exist on server while a client locally thinks it is disabled, or vice versa;
- engine-brake behavior is computed on both server/client and consults local config.

Target architecture:
```text
LocalPreferences
    HUD/layout/key presentation

SimulationConfig
    server/save authoritative
    replicated
    versioned

DevCalibration
    explicit development-only tuning
```

This is the same lesson found in RDS and should become shared RE infrastructure.

---

## Trailer pressure persistence

Trailer pressure is saved server-side:
`rbTrailerAir#presion`.

Positive:
- detached trailer can retain its tank state across save.

But no dedicated:
- initial stream;
- update stream;
- event
for trailer pressure exists.

Connected clients infer pressure from truck RDS pressure because the current algorithm equalizes immediately.

This is an implementation shortcut tied to the current model.

A future finite-flow model requires explicit trailer state replication.

---

## Hose state authority

RB reads GIANTS ConnectionHoses state.

This is good:
- connection authority/network behavior remains in the base/connector owner;
- RB does not invent a separate network boolean.

However, any future player action that opens/closes a pneumatic valve or requests transfer must be server validated.

Connector state is evidence; it is not permission for a client to mutate pressure.

---

## Save/load ordering

Main thermal/parking state has explicit stream/persistence.

Future low-air/spring safety adds a stronger requirement:

```text
restore reservoir
 -> derive spring demand
 -> install final brake effect
 -> allow ordinary physics wake
```

Do not restore spring state one frame after vehicle motion becomes possible.

This is especially important for:
- trailers on slopes;
- low-pressure trucks;
- join in progress.

---

## Trailer pair identity

Future truck/trailer pneumatic transfer should not persist direct object references.

Persist:
- each reservoir only.

At runtime derive:
- attachment topology;
- supply/service hose connection;
- active transfer pair.

On:
- detach;
- sell;
- delete;
- reset;
- second save in same process

invalidate transient pair state.

This follows the lifecycle lesson from RMS external-power relationships.

---

## Brake damage persistence/service

RB's permanent brake damage is persisted.

That is good.

Its repair trigger, however, is a generic drop in base vehicle damage.

This creates an authority/domain mismatch under RMS.

Future service should be:
- a server-authoritative brake-specific transaction; or
- owned by RMS mechanical service if a brake subsystem API is introduced.

Do not let each peer decide repair from local observations.

---

## Stochastic behavior

RB thermal/damage model is deterministic from input state; there is no equivalent local random catch roll like RDS.

Positive:
- easier server authority;
- no divergent random result.

If future brake failures become probabilistic, use server-side continuous-time/hazard logic consistent with RMS lessons.

---

## Network precision

Current:
- temperature: 8 bits across 0..800 C (~3.14 C step);
- damage: 8 bits across 0..1.

For presentation this is adequate.

If future physical fade needs more accurate remote state:
- clients generally only need display/effect state;
- final authoritative brake physics remains server-side;
- do not increase network precision merely to make UI interpolation exact.

---

## Connection cleanup / global lifetime

No dedicated per-connection pending table like RMS exists, so there is no analogous obvious connection-key retention issue.

Global console/UI hooks are mod-lifetime singletons.

Per-vehicle audio samples are cleaned in `onDelete`.

Future native implementation should still test:
- save A -> menu -> save B;
- vehicle delete/sell/reset;
- controller handoff;
- trailer detach/delete.

---

## Authority checklist before stack adoption

1. park event controller validation;
2. exhaust event controller validation;
3. authoritative SimulationConfig;
4. full trailer pressure initial/update state if finite transfer is added;
5. server-derived pneumatic transfer quantity;
6. server-derived brake service/failure transactions;
7. correct safe-load ordering for spring brakes.

Until then multiplayer support may work in normal cooperative play, but the trust boundaries are weaker than the preferred RE/RMS model.
