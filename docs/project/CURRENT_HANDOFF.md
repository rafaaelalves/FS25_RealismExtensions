# Current development handoff

Updated: 2026-09-30

## Active work

- Branch: `feat/terrain-distance-response-v7`
- Purpose: remove low-speed/update-cadence excavation bias and collect explicit dual/twin footprint evidence.
- v6 remains the baseline integrated in `main`; TerrainDeformation is not complete yet.
- This v7 branch is a runtime-test branch, so TerrainDeformation and verbose diagnostics are intentionally enabled here only.

## New runtime evidence from 2026-09-30 log

- True AI Tracks 2.2.0.1 was loaded in the supplied session, so that run cannot prove RE parity with AI/implement deformation.
- John Deere S700/S780 asset load shows `dual002.i3d`.
- Mud restored tire pressure at 2.40 bar in that session.
- RE remained stable during the longer run: 4,083 accepted brushes, 574 native jobs, 0 failed jobs, and terrain history grew from 12,483 to 16,155 persisted cells.
- RC reuse remained healthy: 10,956 contexts, 10,956 slip snapshot hits, 0 direct slip reads, and 10,956 speed/wheel-speed hint hits.

## v7 model change

The v6 response could deepen the same history cell more simply because a slow vehicle generated more 250 ms samples over the same ground.

v7 changes progression from sample-driven recursion to cumulative physical exposure:
- normal rolling exposure comes from vehicle travel distance relative to contact-patch length;
- longitudinal excavation exposure comes from newly accumulated relative longitudinal displacement;
- lateral scrub exposure comes from newly accumulated lateral displacement;
- the terrain cell stores cumulative `deformationExposure`;
- rut target is reconstructed from total exposure + current capacity instead of applying another pseudo-pass each sample.

A harness now compares equal 2 m traversals at 2 km/h and 12 km/h, plus a finer 50 ms subdivision. Equivalent physical travel must converge within 0.5 mm.

Stationary wheelspin remains supported because relative wheel/soil displacement still grows when body speed is near zero.

## Dual/twin diagnostics added

The runtime log now reports:
- base tire width;
- total support width;
- support/base width ratio;
- wheel load;
- contact area;
- min/max ground pressure;
- tire inflation pressure;
- count of contexts with wide support geometry.

Do not add a hard-coded dual multiplier yet. Exact SoilCompaction source notes that FS may represent a dual set as one wider wheel contact; RE first needs runtime evidence of how MR/Mud expose the S700's load/width/pressure combination.

## Next runtime test

1. Use the same S700/S780 with duals.
2. Compare controlled straight driving over similar wet field ground at:
   - ~2-3 km/h with low slip;
   - ~10-12 km/h with similarly low slip.
3. Then deliberately induce wheelspin at low vehicle speed.
4. Keep tire pressure unchanged for the speed comparison; record whether it is 2.40 bar.
5. For a second comparison, if convenient, repeat one pass at Mud's lower field pressure.
6. True AI Tracks may remain installed for this specific low-speed/dual test, but a later dedicated AI parity test must run with it disabled.

Expected v7 result:
- controlled low-speed travel must no longer dig more merely because it is slow;
- true wheelspin must still excavate progressively;
- diagnostics must reveal whether dual support width is actually reaching RE and what ground pressure the current stack computes.

## Additional runtime findings from the S780 field test

The user lowered Mud tire pressure from 2.40 bar to the automatic field target near 1.00 bar and was able to recover the S780 from the original rut. During the later re-stuck period:
- local wetness observed by RC was commonly ~0.32-0.54, not near 1.0 saturation;
- wide support reached RE (max support width 1.30 m, ratio up to 2.0);
- contact area reached ~0.62 m2 and minimum calculated ground pressure ~110 kPa;
- MRMud telemetry showed applied radius deltas typically around 0.07-0.13 m rather than the previous raw ~0.30 m sink interpretation;
- perma-stuck remained false and drag ratio stayed low while vehicle speed fell to fractions of km/h.

This makes a chassis/terrain high-centering hypothesis plausible: the wheel/radius model may still have traction available while the undeformed terrain between wheel tracks contacts the vehicle body.

Do not assume a dual must be represented as two separate RE contacts yet. The exact SoilCompaction source records an in-game precedent where FS exposes a dual/twin set as one wider physics contact. We need authoritative spacing/visual geometry before splitting that footprint.

## Diagnostics added after that finding

- RE now measures the terrain height at the midpoint between left/right wheel contacts on each axle and compares it with the plane interpolated between both wheel-track heights.
- Runtime telemetry reports max central crest and counts above 5/10/15 cm.
- The diagnostic is slope-invariant in the harness: a planar cross-slope produces zero crest while a true 12 cm center ridge is reported as 12 cm.
- RC MRRMS now emits per-vehicle drivetrain state: primary/engageable wheel indices, active 4WD state and MR-driven wheel indices/count. This avoids interpreting the old global lastDrivenWheelCount gauge as if it necessarily belonged to the S780.

## Completion blockers after v7

- validate that the v7 distance-based response behaves correctly in runtime;
- determine whether central terrain crest/high-centering is the dominant cause of the remaining S780 stalls;
- verify S780 rear-wheel-assist/4WD reaches MR wheel ownership correctly;
- validate dual/twin behavior without inventing unsupported split-contact geometry;
- design soft-ground underbody/belly interaction only after high-centering is measured;
- implement grouped crawler/track support;
- validate player + GIANTS AI + Courseplay + wheeled implements with True AI Tracks disabled;
- resolve native AI tire-track permission ownership;
- complete external-source crosswalk before declaring TerrainDeformation finished.


## v9 experimental SoilMassTransport

Branch: `feat/terrain-mass-transport-v9`

This is a TerrainDeformation feature, not a separate gameplay module.

Purpose:
- replace pure height removal with partial surface-mass redistribution;
- use GIANTS callback `displacedVolume` as the mass budget;
- create positive terrain berms only after a successful lowering callback;
- keep the untransported fraction as compaction/sub-surface rearrangement;
- preserve v7 distance/cadence-invariant rut response.

Current v9 behavior:
- moving wheel samples carry travel direction, wetness, deformability and slip into the writer;
- lowering jobs remain the authoritative rut operation;
- successful callbacks allocate the actual displaced volume across contributing brushes;
- `SoilMassTransportModel` computes a bounded transport fraction from wetness, deformability and longitudinal slip;
- transported volume is split into left/right lateral berms perpendicular to travel;
- lateral slip can bias which berm receives more material;
- berms are queued as separate positive TerrainDeformation jobs;
- raise jobs never generate further transport, preventing recursion;
- coalescing remains enabled only when transport direction/state are compatible.

Mass-balance telemetry:
`SoilMassTransport runtime | source=... targetTransport=... raised=... realization=... compaction=... balanceError=... berms=... raiseJobs=... rejects=...`

Interpretation:
- `source`: real lowering volume reported by GIANTS for brushes eligible for transport;
- `targetTransport`: fraction of source volume assigned to surface berms;
- `raised`: real positive volume reported by GIANTS for berm jobs;
- `realization = raised / targetTransport`;
- `compaction`: source volume intentionally not returned to the surface;
- `balanceError = raised - targetTransport`.

The first runtime goal is calibration/shape validation, not acceptance:
1. verify berms appear on both sides of moving wheel ruts;
2. ensure berms do not create unstable walls or obvious terrain inflation;
3. measure realization ratio and mass-balance error;
4. compare dry/firm vs wet/plastic soil;
5. compare low-slip rolling vs wheelspin;
6. verify performance/job counts remain acceptable;
7. only then decide whether to extend toward rearward shear, relaxation and implement-driven field repair.

Do not merge v9 until runtime evidence shows both geometry and mass balance are plausible.


## v9.0 runtime result and v9.1 retune

The first mass-transport runtime proved the architecture works but rejected the initial calibration.

Observed in the 2026-10-01 S780 test:
- berms were visually far too aggressive, especially toward vehicle center;
- early realization ratios reached 16-17x;
- later realization stabilized around 7-8x;
- at source=16.841 m3, targetTransport=5.814 m3, GIANTS reported raised=48.054 m3 (realization=8.26);
- the test commonly ran near local wetness ~0.35-0.51 with 1.00 bar tire pressure;
- therefore the first linear wetness transport curve moved far too much surface soil for merely damp/trafficable conditions.

v9.1 changes:
- transport is now strongly nonlinear with a plastic-wetness threshold;
- around ~0.50 wetness + low slip, surface transport is intended to remain around 0.5-1% and compaction dominates;
- truly wet/plastic soil + severe slip can ramp toward a hard 18% surface-transport ceiling;
- additive raise height is calibrated by 0.10 based on the measured runtime over-realization;
- microscopic berms are no longer rounded upward to the minimum terrain brush; their mass is folded into compaction instead;
- the berm facing vehicle center is resolved geometrically from vehicle root/contact position, not from wheel-side assumptions;
- inner berm share is capped near 18% of transported mass and its per-operation raise height is capped at 1 mm;
- outer berms may reach 3 mm per operation in severe conditions.

Next runtime acceptance criteria:
1. ordinary 0.35-0.55 wetness should show rutting/compaction with little or no obvious berm;
2. inner berms must not create a center ridge capable of interfering with the vehicle;
3. realization should move much closer to 1.0 and must no longer sit at 7-17x;
4. severe wetness + wheelspin should still produce visible lateral displacement;
5. job/brush growth must remain manageable.


## v10 experimental plasticity response

Branch: `feat/terrain-plasticity-response-v10`

Purpose:
- decouple instantaneous Mud sink from persistent RE rut geometry;
- preserve Mud authority over mobility while letting RE decide how much sink becomes permanent plastic terrain deformation;
- stop treating every transient wheel-radius sink peak as an immediate permanent heightfield lower bound.

Runtime motivation:
- v9.1 S780 test often operated around local wetness ~0.35-0.57 at 1.00 bar;
- the RE static/slip capacities peaked around ~0.05 m while `modelRut/modelCap` reached ~0.138 m;
- this happened because `observedSinkM` from Mud was included directly in `rutCapacityM=max(static, slip, observedSink)`;
- the same session began with ~49,294 restored history cells, so existing field geometry is heavily contaminated by earlier experimental versions.

v10 model:
- `observedSinkDepthM` remains the authoritative instantaneous Mud consequence;
- `sinkPlasticTransfer01` is computed from a nonlinear wet-plasticity curve plus slip activation;
- `persistentSinkDepthM = observedSinkDepthM * sinkPlasticTransfer01`;
- only `persistentSinkDepthM`, static rut capacity and slip rut capacity participate in persistent geometry;
- around moderate wetness (~0.50) and low slip, transient sink transfer is deliberately small;
- near very wet/plastic conditions, and especially with severe slip, transfer rises strongly but remains bounded below 100%;
- existing rut history is never automatically healed.

Diagnostic line:
`TerrainPlasticity sample | wet=... slip=... instantSink=... transfer=... persistentSink=... staticCap=... slipCap=... rut=... maxInstant=... maxPersistent=... maxTransfer=...`

Mass-accounting correction:
- source-volume shares rejected by SoilMassTransport are now counted as compaction/sub-surface rearrangement;
- the harness requires `source = targetTransport + compaction` before positive raise realization is considered.

Runtime test requirement:
- use a previously undeformed area or a clean backup; the current field contains ~49k persisted experimental cells and earlier heightmap edits cannot be safely reconstructed;
- compare moderate damp/trafficable soil against substantially wetter soil;
- keep tire pressure appropriate for field work;
- verify moderate wetness can show instantaneous sink/resistance without converting the full sink into a permanent rut;
- verify genuinely wet + high-slip conditions still produce deeper persistent deformation.

Do not merge v10 until this separation is validated in runtime.
