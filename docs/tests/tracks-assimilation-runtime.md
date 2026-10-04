# Runtime protocol — tracks / VMT assimilation checkpoint

Updated: 2026-10-04
Branch: `feat/assimilation-tracks-vmt`

Purpose: validate the first assimilation implementation without allowing external test mods to contaminate RE physical calibration.

## Build / stack

Use the current GitHub Actions artifact from this branch.

Normal specialist stack may remain active:
- MoreRealistic;
- current audited MudSystemPhysics;
- RMS / Reifen / Soil as normally selected;
- current RC branch appropriate to the save.

For the controlled sessions below:
- **Visual Mud Tracks: OFF**
- **Persistent Tracks: OFF**
- **True AI Tracks: OFF unless a session explicitly says ON**

Reason: all three can alter or observe the exact capabilities being validated.

## Session A — native TireTrack contract probe

External three audit mods: all OFF.

Drive a normal wheeled tractor on terrain where vanilla tire tracks are visible.

Expected RE log:
```
TireTrackProbe | installed=true integrity=true ...
```

After enough movement:
- `create > 0`;
- `point > 0`;
- `cut` may increase when leaving valid contact/visual range;
- `maxArgs=2/15/1` after create/point/cut have all occurred;
- `observerErrors=0`;
- `drift=0`.

The exact point signature should correspond to FS25 TireTracks:
```
trackId,
x,y,z,
ux,uy,uz,
r,g,b,
dirtAmount,
groundDepth,
tireDirection,
onTerrain,
colorBlendWithTerrain
```

### Fail closed

If point args are not 15:
- do not enable VisualTrackCapture;
- retain the probe;
- record the observed signature/types;
- update the adapter normalization only after source/runtime reconciliation.

If `integrity=false` or `drift>0`:
- identify which stack mod owns the later pointer;
- do not reassert blindly.

## Session B — player physical baseline

True AI Tracks remains OFF.

Create several controlled passes over deformable soil:
- ordinary rolling;
- modest longitudinal slip;
- steering/lateral scrub;
- stationary wheelspin if practical.

Verify:
- one RE physical deformation path;
- no VMT/True-AI native-displacement calibration contamination;
- existing TerrainDeformation telemetry remains plausible;
- no new error from LoadedContactRegistry.

This session is regression proof, not final soil calibration.

## Session C — GIANTS helper physical ownership

True AI Tracks: **OFF**.

Use the same tractor/field area with a GIANTS helper.

Goal: prove RE physical deformation does not depend on True AI Tracks.

Look for:
- RE vehicle/wheel updates continue;
- provider contexts accepted;
- `rutWriter` / `brushesAccepted` attributable to the AI-controlled machine;
- comparable physical response for comparable load/wetness/slip state.

Expected visual result at this checkpoint:
- native AI tire marks may still be absent because RE has not enabled AI visual-track policy yet.

That absence is acceptable and proves the remaining visual gap cleanly.

## Session D — AI visual comparison only

True AI Tracks: **ON**.

Do **not** use this session to calibrate physical rut depth because True AI Tracks also forces vanilla displacement.

Goal:
- visually confirm native AI tire marks return;
- confirm `TireTrackProbe point>0` while AI is active;
- verify the same 2/15/1 native signatures.

Then turn True AI Tracks OFF again.

This gives the exact visual behavior RE must later replace without adopting its physical path.

## Session E — wheeled implement physical coverage

True AI Tracks: OFF.

Use:
1. tractor + one wheeled implement;
2. if available, nested wheeled attachment.

Verify:
- implement wheels generate their own RE contexts/ruts where physically eligible;
- no root-vehicle recursive scanner is required;
- no duplicate brush path from tractor ownership.

Repeat with GIANTS helper if practical.

Courseplay/AutoDrive are a later extension of this matrix after native helper is proven.

## Session F — loaded-wheel recovery guard

Place or operate a loaded wheeled vehicle so one of its recent wheel contacts overlaps an area being smoothed by TerrainRecovery.

Expected log:
```
TerrainRecoveryContactGuard | queries=... blocked=... maxBlockingLoadN=...
```

Success:
- `blocked > 0` in the overlap case;
- no visible terrain raise/jump under that loaded wheel;
- after the wheel moves and the tool continues/repeats the area, recovery becomes eligible again;
- no permanent recovery hole caused by consuming a blocked stamp.

Control:
- normal recovery away from loaded contacts remains unchanged.

## Session G — sink handoff observation

Use current Mud on a wet/deformable area and generate:
- mild sink;
- deeper sink;
- repeated passes until RE persistent rut history grows.

Expected log:
```
TerrainSinkHandoffProbe |
  observed=...
  historyRepresented=...
  residual=...
  maxRepresented=...
  maxResidual=...
```

Interpretation:
- `observed` = instantaneous Mud sink reported through RC;
- `historyRepresented` = conservative overlap with RE logical rut history;
- `residual` = observed sink not represented by that history proxy.

This **does not** prove actual geometry handoff.

Decision gate:
- only design an explicit Mud↔RE sink representation API if runtime demonstrates meaningful double-representation or jump as terrain rut grows;
- otherwise leave Mud instantaneous sink and RE persistent terrain independent.

## Session H — adapter lifecycle

During a normal full-stack launch inspect:
- `TireTrackProbe integrity=true`;
- `drift=0`;
- no observer errors.

Return to menu and load another save in the same game process.

Verify:
- adapter uninstalls/reinstalls cleanly;
- counters reset as expected;
- no stacked wrappers;
- native tire tracks still function.

## Evidence to retain

For each session keep:
- complete `log.txt`;
- ModMixer log if used;
- exact RE/RC build SHA;
- exact Mud/Reifen/RMS versions;
- note which of the three audited mods were enabled;
- screenshots only where geometry/visual distinction matters.

## Gates after this protocol

### Enable normalized VisualTrackCapture only if
- native point signature is confirmed;
- adapter integrity is healthy;
- observer errors are zero.

### Implement AI visual policy only if
- Session C proves physical AI replacement with True AI Tracks OFF;
- Session D proves the remaining user-visible difference is native tire-track gating.

### Begin savegame persistence only after
- journal capture is runtime-confirmed;
- simplification preserves visual shape/tread state;
- chunk store statistics stay bounded.

### Remove True AI Tracks from target stack only after
- AI physical matrix passes;
- RE AI visual policy is active and preserves native visual limits.

### Do not add Persistent Tracks to target stack if
- RE journal/chunk/persistence path reaches equivalent or better behavior.

### Do not add VMT to target stack
Its selected lessons are being integrated independently; its overlapping simulation domains remain rejected.
