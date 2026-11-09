# Handoff: experimental terrain R1 on current PTO V1.6 main

2026-10-13. Working branch: `integration/terrain-r1-main-pto-v16-2026-10-13`.

## Provenance and policy

- Original production main: `5c6d51cbddab7ffe9ddde1289b7f80e88b18ecd3` (PTO V1.6).
- Experimental terrain parent: `3c97b724ef940af46e2e424f7825a2a8d4b6f76a` (PR #44, including PR #43 diagnostics, PR #38 terrain).
- Actual two-parent merge commit: `ab253dfb2b31515e47e7aeb6c109d9a4e301b7f5`, with main as first parent, terrain as second.
- Integration is on this experimental branch ONLY. Production main and old experiments/PRs were not modified.
- Future terrain development should branch from this integrated branch, rather than the stale October 9 terrain branch.

## Merge conflict resolution

Both histories changed only two overlapping paths: `modDesc.xml` and `scripts/Config.lua`.

- `modDesc.xml` retains every experimental terrain/track/R1 declaration and adds production main's `scripts/pto/PTOInspection.lua` source registration. PTO bindings remain unchanged.
- `scripts/Config.lua` retains the experimental terrain setup and telemetry, and adopts main PTO's `ptoWorkerEvents`, estimated shaft RPM and power hint HUD settings.
- Git trees were compared by blob SHA: all 149 terrain-exclusive changed paths match PR #44's source; 10 selected main PTO implementation/test paths match the current main exactly. Unchanged main files are preserved.
- Local workflow `build.yml` allows integration branches to run CI; this workflow modification was not made on main.

## Runtime modules and limitations

- TerrainDeformation, TerrainRecovery, TerrainPlasticYield, TerrainMaintenance, reference V2, native tracks and bounded diagnostics stay enabled experimentally. SoilMassTransport stays disabled.
- No changes to soil yield, wetness, Mud sink transfer, tractor traction, TARGET pulse strength or tillage capability were introduced by this integration.
- PR #40 recovery history broadphase performance optimization is NOT included. PR #42 research is NOT merged. PR #43 instrumentation and #44 reference V2 are inherited through the second parent.
- Reference V2 synthetically recognizes ~11.9cm instead of ~6.7cm for a constructed 12cm paired rut; it is not a gameplay-verified full repair. Native TARGET no-op problem may remain.
- Extreme wetness/hail and an undersized tractor plus giant seeder are NOT justification by themselves to weaken terrain physics; preserve the user's challenging realism goals.

## RC and PTO pairing

- Previous user's RC tested: `ad7461fb7777691f6f64e2327753417c95b6177b`.
- RC main now: `e55dd9e141c7b536b63da799677c02d14c8a3efc`, with source changes to `scripts/pto/PTOState.lua`, and regression tests. This is the more appropriate matching RC release for the updated RE PTO V1.6.
- PTO V1.6 includes estimated shaft RPM HUD, on-demand `rePTOInspect`, command authorization and neutral treatment of shaftless powered implements. Live multiplayer is not validated. Avoid simultaneous external Dynamic PTO authority.
- RE and RC still ship as distinct ZIPs, never overwrite RC with the RE package.

## Acceptance and next work

1. Confirm complete GitHub Actions harness/ZIP build for the integration branch.
2. Smoke test the generated ZIP and appropriate RC build on a COPY of the save, not valuable original; verify PTO UI + `rePTOInspect` and terrain R1 work-area callback. Record matching BuildInfo SHAs.
3. Continue the pre-existing R1 test: same damaged harvester lane, one/two/three cultivation passes, native heightmap profile and physical improvement, then seeder passability.
4. If native TARGET no-op persists, develop a separate safer native-actuator fix. Keep SoilMassTransport and broadphase independent, and preserve the updated main PTO behavior.

**Status:** code merged on experimental integration branch; runtime field validation still required. No merge to production main.