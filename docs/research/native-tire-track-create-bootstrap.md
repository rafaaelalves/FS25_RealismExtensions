# Native TireTrack createTrack bootstrap plan

Updated: 2026-10-04
Status: **DOCUMENTED — IMPLEMENT NEXT, CAPTURE STILL OFF**

## Runtime evidence

Tested build:
- branch: `feat/assimilation-tracks-vmt`
- commit: `54c00c10b3232c569275139d63afa71a7ef86013`

Observed by shutdown:
- `addTrackPoint=65622`;
- `cutTrack=3972`;
- `createTrack=0`;
- `maxArgs=0/15/1`;
- `observerErrors=0`;
- `drift=0`;
- adapter integrity remained healthy.

`VisualTrackCapture=false`, so the normalized journal/chunk runtime was intentionally not exercised.

## Source/lifecycle evidence

Official FS25 `TireTracks` specialization shows:

1. `TireTracks:onPreLoad()` assigns:
   `spec.tireTrackSystem = g_currentMission.tireTrackSystem`.

2. `TireTracks:addTireTrackNode(...)` later calls:
   `spec.tireTrackSystem:createTrack(width, tireTrackAtlasIndex)`.

Therefore the current Core `loadMap()` installation point is too late for at least the already-loaded vehicle tracks seen in the runtime test.

## Preferred design

Install the **mission-instance NativeTireTrackAdapter** on the first `TireTracks:onPreLoad` opportunity, before any `addTireTrackNode` creates native tracks.

This does **not** mean making RE the global TireTrackSystem owner.

Architecture:

```
mod Lua/source initialization
        |
        +-- install one lightweight TireTracks.onPreLoad bootstrap
                |
                v
first vehicle TireTracks:onPreLoad
                |
                +-- g_currentMission.tireTrackSystem must exist
                |
                +-- adapter.installFromMission()
                |
                v
original TireTracks:onPreLoad
                |
                v
later addTireTrackNode()
                |
                +-- native createTrack(width, atlas)
                +-- RE probe observes create
```

The bootstrap is only a lifecycle trigger.

The actual observed methods remain instance-scoped:
- `createTrack`;
- `addTrackPoint`;
- `cutTrack`.

## Bootstrap requirements

- preserve the complete existing `TireTracks.onPreLoad` chain;
- never bypass another specialization owner;
- install only when probe or capture is enabled;
- be idempotent across many vehicle `onPreLoad` calls;
- fail closed if `g_currentMission.tireTrackSystem` is not yet available;
- keep the existing Core retry as fallback;
- on mission teardown, uninstall only the mission-instance adapter;
- the bootstrap itself may remain process-global so a second mission can install the new mission instance;
- no VisualTrackCapture activation in the first bootstrap test.

## Why not bootstrap missing tracks from addTrackPoint

Do not infer missing `width` or atlas/tread identity from point events.

A lazy synthetic create would make persistence look functional while silently losing native identity.

If early observation still misses createTrack, inspect the native system's existing-track metadata before considering a bootstrap-by-enumeration strategy.

## Next runtime gate

First test after implementation keeps:

`VisualTrackCapture=false`.

Success requires:
- `createTrack > 0`;
- observed max args becomes `2/15/1`;
- `point > 0`;
- `cut > 0` where applicable;
- `observerErrors=0`;
- `drift=0`;
- vanilla player tracks remain visually unchanged;
- no stacked wrappers after save reload / second mission.

Only after that result do we enable `VisualTrackCapture=true` for the normalized journal/chunk test.

## External source

GIANTS FS25 scripting documentation:
- TireTracks `onPreLoad` binds `g_currentMission.tireTrackSystem`;
- TireTracks `addTireTrackNode` calls `createTrack(width, tireTrackAtlasIndex)`.

This plan is a lifecycle integration design, not source copying.
