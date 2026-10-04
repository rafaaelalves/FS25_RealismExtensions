# Runtime protocol — tracks / VMT assimilation checkpoint

Updated: 2026-10-04
Branch: `feat/terrain-recovery`

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
- `drift=0`;
- signature sampling remains bounded after the initial contract samples while call counters continue increasing.

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
- leave one loaded wheel stationary long enough to cross the contact refresh interval and confirm it remains protected;
- no visible terrain raise/jump under that loaded wheel;
- stationary contact refresh must not create/deepen a persistent rut by itself;
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


---

## Runtime result — 2026-10-04 session

Build:
- branch at test time: `feat/assimilation-tracks-vmt`
- commit: `54c00c10b3232c569275139d63afa71a7ef86013`

### Session A — PARTIAL PASS / CAPTURE REMAINS GATED

Observed across the session:
- adapter installed;
- integrity remained true;
- `addTrackPoint`: 65,622 calls by shutdown;
- `cutTrack`: 3,972 calls;
- observed max args: `0/15/1`;
- observer errors: 0;
- pointer drift: 0.

Important failure/gap:
- `createTrack=0` for the entire observed session.

Interpretation:
- the 15-argument point boundary and 1-argument cut boundary are strongly runtime-confirmed;
- the 2-argument create boundary was **not** observed;
- likely lifecycle issue: native tracks may be created before the mission-instance adapter is installed.

Do not enable VisualTrackCapture yet.

Before capture:
1. prove/observe createTrack at an earlier lifecycle point, **or**
2. design a trustworthy bootstrap for already-existing native tracks with width/atlas metadata.

Do not lazily invent width/atlas from point events.

### Session F — FAILED: guard is over-broad

Final relevant counters:
- coverage: 14,552;
- stamp skips: 874;
- loaded-contact queries: 13,678;
- loaded-contact blocked: 13,409;
- recovery brushes enqueued: 269.

Therefore ~98% of post-stamp recovery candidates were vetoed by the loaded-contact guard.

The current rule blocks an entire 2 m smooth brush whenever any recent loaded contact overlaps its circle.

This is too conservative for a working tractor/cultivator combination.

Also, "do not consume the stamp and retry next callback" is insufficient because the implement can move beyond the patch before the loaded wheel clears it.

Required redesign:
- preserve safety;
- introduce deferred recovery or equivalent eventual-completion semantics;
- distinguish current-combination vs foreign contacts where useful;
- do not simply disable the safety invariant.

### VisualTrackCapture was not tested

The current Config intentionally keeps:
`VisualTrackCapture=false`.

No VisualTrackCapture runtime diagnostics were emitted in this session.

This test validates only:
- adapter integrity/performance boundary;
- point/cut signatures;
- contact-registry/recovery-guard runtime behavior.

### Shutdown error

One shutdown script error originates from `FS25_manualAttach` DetectionHandler delete path, not from RE tracks/recovery.


---

## Runtime result — 2026-10-04 early-bootstrap validation

Tested artifact:
- branch: `feat/terrain-recovery`;
- commit: `22f016365a053033e40fc6512656eb53549c8712`;
- run: `37201970938`.

Stack evidence:
- RC reported `AITracks=-`; True AI Tracks was not active in the tested save.
- user visually observed that the GIANTS NPC/helper did **not** leave native visual tire marks.

### Session A — PASS

Early `TireTracks:onPreLoad` bootstrap succeeded.

Observed:
- bootstrap installation log appeared during vehicle loading;
- `createTrack=30`;
- `addTrackPoint` exceeded 66k calls;
- `cutTrack` exceeded 14k calls during the main observed period;
- `maxArgs=2/15/1`;
- `observerErrors=0`;
- `drift=0`;
- `bootstrapPreLoad=7`;
- `bootstrapInstalls=1`.

Conclusion:
- the early mission-instance bootstrap solves the missing-create lifecycle gap;
- official runtime contract is now confirmed at 2/15/1 in the target stack;
- VisualTrackCapture gate is satisfied.

### Session C — physical helper ownership appears healthy

With True AI Tracks inactive, RE TerrainDeformation continued to produce wheel contexts and rut-writer activity while the tested combination was operating.

This supports the existing conclusion that physical terrain deformation is controller-neutral and does not require True AI Tracks.

This is not yet the complete helper/Courseplay/AutoDrive parity matrix.

### AI visual gap — CONFIRMED

The user's NPC/helper produced no native visual tire marks with True AI Tracks inactive.

This is the expected vanilla gap and closes the prerequisite for implementing the RE AI visual policy.

The pre-runtime plan intentionally had **not** implemented that policy before the native contract was proven.

Post-test action:
- implement `AIVisualTrackPolicy`;
- remove only the GIANTS AI-active suppression;
- preserve lower/native `getAllowTireTracks` restrictions such as distance and segment quality;
- enable VisualTrackCapture for the next combined runtime session.

The missing NPC marks in this build are therefore **not** evidence that an already-implemented RE AI policy failed; that phase had remained gated on purpose.
