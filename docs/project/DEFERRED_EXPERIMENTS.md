# Deferred integration experiments

Updated: 2026-10-08

Purpose:
preserve the remaining **focused experiments** from the Mud 1.3.6 +
Reifenverschleiss 1.2.2.70 + RMS 0.11 audit line after the primary full-stack
smoke and migrated-save reload both passed.

These are **not blockers** for the currently accepted versions. They answer
specific ownership/model questions that may justify future RC/RE work.

## E1 — RMS drivetrain topology -> Reifen FORCE-WEAR magnitude

Exact pair:
- RMS 0.11.0.0;
- Reifenverschleiss 1.2.2.70.

Source-confirmed mismatch:
- RMS dynamically rebuilds the GIANTS differential graph for 2WD/4WD/AUTO;
- Reifen FORCE-WEAR derives and caches driven-wheel/torque shares from the
  GIANTS graph;
- neither side currently exposes/consumes a topology revision contract.

Test:
1. use a vehicle where 2WD/4WD/AUTO produces a real driven-wheel topology
   change;
2. record Reifen cached shares in 2WD;
3. switch to 4WD and AUTO without reloading the vehicle;
4. record effective RMS driven wheels and Reifen wear allocation;
5. compare with a fresh-load/reference state in each topology;
6. accumulate enough controlled FORCE-WEAR to determine whether stale shares
   produce a material wear error.

Decision gate:
- **negligible** -> document and leave unbridged;
- **material** -> design the narrowest possible topology revision/effective
  driven-share provider or cache invalidation boundary.

Do not add a broad RMS<->Reifen bridge before this magnitude test.

## E2 — Reifen structural radius under combined permanent + temporary effects

Exact stack:
- Reifen 1.2.2.70;
- Mud 1.3.6;
- current RC.

Controlled states:
- low/medium/high permanent Reifen wear;
- normal vs reduced pressure;
- Mud field sink;
- puncture/failure state where safely reproducible.

Capture:
- Reifen `getWheelWearRadius()`;
- Reifen `rvRoundPhysicalRadius`;
- Mud coordinated `__rvDesiredRadius`;
- pressure/sink desired radius channels;
- MRMud structural snapshot;
- ExtensionsStateProvider structural radius/source;
- final `physics.radius`.

Invariant:
```
permanent Reifen wear
        -> structural baseline

pressure / puncture / sink
        -> temporary consequence

physics.radius
        -> final actuator only
```

Fail condition:
a temporary deformation becomes the next permanent structural baseline, or
permanent tread wear is lost when a transient effect clears.

## E3 — Reifen puncture / Mud pressure authority

Goal:
prove whether the current pair has one coherent durable failure/pressure owner
across host/dedicated play.

Test:
- induce or safely force Reifen-driven puncture risk at controlled wear;
- observe server/host puncture decision;
- observe Mud pressure/radius consequence;
- repair and verify state clears once;
- join in progress after puncture;
- repeat on dedicated server if available.

Capture:
- puncture state;
- structural wear radius;
- pressure state;
- final grip/radius;
- network/JIP state.

Decision:
if puncture ownership remains fragmented, design a provider/constraint boundary
rather than a second puncture solver.

## E4 — Reifen wear provenance under Mud local wetness

Source state:
Reifen 1.2.2.70's wear accumulation still does not consume Mud
`FieldLocalWetness`.

Question:
does this create a material gameplay error worth integrating, or is the current
global/environmental wetness input sufficient once slip/contact consequences are
already represented?

Test equal-distance/equal-load/equal-speed runs where:
- GIANTS/global wetness is similar;
- Mud local physical wetness differs strongly.

Compare:
- Reifen wear delta;
- slip;
- effective traction;
- pressure/sink;
- any correlated penalties.

Important:
do not blindly multiply local wetness into wear. First determine whether doing so
would double-count the same physical cause already expressed through slip/sink.

## E5 — Mud local-wetness generation atomicity under load

Goal:
validate the static scheduler finding from Mud 1.3.6.

Test:
- create/update a sufficiently large wetness region that requires chunked work;
- sample cells while a generation is in progress;
- save during in-progress work;
- reload;
- measure frame time around generation/commit.

Expected:
- consumers see only committed generation N or N+1;
- no spatial half-generation is published;
- save persists the last coherent committed state;
- chunking avoids a large single-frame spike.

This is primarily an architecture/performance experiment, not a version blocker.

## E6 — Native RE PTO x RMS 0.11 focused causality

Owner:
continue in the dedicated PTO development line.

Important distinction:
- native RE PTO active;
- legacy `FS25_DynamicPTO_FFM` disabled;
- RC `RMSDynamicPTO` expected INACTIVE.

Test:
- at least two effective PTO modes/ratios;
- equal implement under continuous load;
- low-RPM vs high-RPM engagement;
- capture effective VehicleMotor PTO ratio;
- RMS native capacity/utilization;
- RMS 0.11 engagement-shock damage inputs;
- verify RE feedback/telemetry does not become a second RMS stress source.

This test closes native RE PTO development; it does not block the accepted
Mud/Reifen/RMS compatibility line.

## E7 — Safe outer-wrapper integrity diagnostic

Observed runtime:
FarmKit appends outside RC on `WheelPhysics.serverUpdate`, so MRMud's own
wrapper is no longer the top-level function pointer while its telemetry proves
the bridge remains active.

Optional experiment:
- capture chain identity at boot;
- verify the known outer FarmKit append;
- verify RC/Mud behavior before and after several vehicle create/delete cycles.

Goal:
decide whether the integrity diagnostic should distinguish:
- **wrapper absent/bypassed**;
- **known safe outer wrapper**.

No hook-order fight or runtime reinstallation should be added merely to silence
the diagnostic.

## Priority when experiments resume

1. **E1 RMS -> Reifen FORCE-WEAR magnitude** — strongest candidate to justify a
   new RC provider.
2. **E2/E3 radius + puncture/pressure ownership** — highest physical-state risk.
3. **E6 native RE PTO x RMS** — close in the PTO development line.
4. **E4 wetness -> wear** — integration opportunity only after causality test.
5. **E5 wetness scheduler atomicity** — architecture/performance validation.
6. **E7 outer-wrapper diagnostic** — low-risk diagnostics cleanup.

## Current accepted baseline

Already passed:
- Mud 1.3.6 + Reifen 1.2.2.70 + RMS 0.11 primary full-stack smoke;
- migrated-save reload;
- MudRMS 0.11 semantic function binding;
- Reifen/Mud API-v1 order stability;
- MRRMS live driven-wheel synchronization smoke.

Do not reopen these version decisions merely because the focused experiments
above are deferred.
