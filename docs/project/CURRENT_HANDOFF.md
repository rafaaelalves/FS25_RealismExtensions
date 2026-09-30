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

## Completion blockers after v7

- validate dual/twin behavior from runtime evidence;
- implement grouped crawler/track support;
- validate player + GIANTS AI + Courseplay + wheeled implements with True AI Tracks disabled;
- resolve native AI tire-track permission ownership;
- complete external-source crosswalk before declaring TerrainDeformation finished.
