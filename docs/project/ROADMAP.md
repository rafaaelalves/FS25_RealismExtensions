# Roadmap

The roadmap is intentionally capability-driven, not version-date driven.

## Current priority and state (2026-10-13, after PTO V1.6)

**PTO V1.5/V1.6 is integrated in `main`**, with a tested subset of real implements and RC/MR/RMS compatibility; `TerrainDeformation=false` remains the safe mainline default. The PTO label **V1.6** names a functional milestone, not the FS25 mod's `modDesc` version (`0.0.1.0`).

**Next most urgent gameplay risk:** make RE's experimental terrain ruts recoverable by real cultivation/tillage without immediate reseeding collapse. Experimental [PR #44](https://github.com/rafaaelalves/FS25_RealismExtensions/pull/44) addresses reference contamination, but repeated native GIANTS TARGET no-ops and field acceptance remain release blockers. Never merge these experimental terrain branches just because PTO is integrated or CI passed.

**Focused PTO-only development after V1.6:** [source-backed engineering roadmap](../research/2026-10-13-pto-post-v1-6-focused-roadmap.md) and [V1.7 model/performance investigation #50](https://github.com/rafaaelalves/FS25_RealismExtensions/issues/50). This thread is independent of terrain recovery and does not add implementation physics by default.

**Next PTO research milestone ([issue #48](https://github.com/rafaaelalves/FS25_RealismExtensions/issues/48); V2 not implemented):** find one *measurable, absent* implement-specific shaft-RPM/throughput consequence without duplicating MoreRealistic baler capacity/load or wood-crusher feed gates. Start with upstream source matrix, provider ownership and on-demand instrumentation; only then test an isolated behavior. The user cannot plan an MP session: [issue #46](https://github.com/rafaaelalves/FS25_RealismExtensions/issues/46) remains deferred. The HM10 post-merge normalized RPM is confirmed in game; actual log-feeding crossover still [RC issue #26](https://github.com/rafaaelalves/FS25_RealismCompatibility/issues/26).

**Additional independent exploration:** interchangeable rodados/dual-wheel sets and weights with reusable stored inventory; vehicle workshop/motor/gearbox configuration constrained by real MR/RMS ownership; RHM+WA clogging and CropInteraction; FarmKit bridges and surface contamination; mining/roadwork stack as external owners rather than cloning.

**Maintained detailed work order:** [Post-PTO V1.6 roadmap review](2026-10-13-POST-PTO-V16-ROADMAP-REVIEW.md). Earlier version-based sections below are long-term candidate streams; they are **not** evidence that all listed capabilities were built.


## 0.0.x — Foundation and research

- establish repository/CI/contracts;
- audit candidate mods;
- define normalized RC→Extensions state;
- research GIANTS terrain deformation and runtime budgets;
- build diagnostics/harnesses.

## 0.1.x — Terrain deformation prototype

Goal: produce believable geometric consequences from authoritative wheel/ground state without changing traction or sink physics.

Progression:
1. player tractor, one supported terrain, longitudinal slip;
2. tire-width/load-aware rut geometry;
3. local wetness and freeze/thaw response;
4. lateral scrub;
5. repeated-pass accumulation with bounded depth;
6. implement wheels;
7. GIANTS AI and Courseplay;
8. assess removal of True AI Tracks from the stack.

## 0.2.x — Crop/vegetation interaction candidate

Research before commitment:
- speed/load/footprint damage;
- wetness sensitivity;
- steering/lateral scrub;
- off-field grass/meadow interaction;
- possible functional absorption of CropDestructionAnywhere.

## 0.3.x — Surface contamination candidate

Research target:
- replace RealDirtColor's current-target color model with persistent per-wheel/body material contamination;
- use Mud/RC authoritative contact state where available;
- preserve GIANTS Washable dirt amount as a separate quantity;
- save/network persistent contamination;
- retain existing `dirtColor` shaders as the first presentation backend.

## Drivetrain improvement research

Parallel research, not a separate physics owner:
- enrich RMS AUTO/lock decision semantics using the audited Realistic 4x4 requirements;
- pursue an RMS public/provider boundary rather than another `updateDifferential` writer;
- keep CTIS/tyre pressure as a separate future capability.

## Later candidates

- richer surface contamination visuals beyond `dirtColor`;
- furrow interaction;
- visual-effect consolidation;
- unified state-driven HUD.

These are candidates, not promises. Every module must justify ownership and maintenance cost.


## Supporting research (after current terrain recovery blocker) — TTD 3.7 source lessons

- [x] Source study completed: TTD 1.0.3.7 `FS25_TTD_v3_7_BETA.zip` is a **reference specimen, not an RE/RC dependency**. Its wheel-radius and slip/grip/engine writers overlap Mud/MR/Reifen/RMS. It does not provide pre-rut heightmap restoration.
- [ ] **P1, alongside V3 recovery tests:** introduce adverse reference-estimator fixtures (natural slope, curvature, TerraFarm pits, fresh RE rut, old-save unknown anchors, native heightmap vertex unit and tracked wheelspin). This is a testing extension of current reconstruction V3, not a new mechanic.
- [ ] **P1, only if needed after auditing existing state interfaces:** define read-only per-wheel SurfaceContext, provenance/epoch/units, meaningful enter/exit hysteresis for field/road/natural/object; consume Mud wetness and MR/RC slip, never write their physics.
- [ ] **P2 parked:** per-vehicle *RE-owned* calibration/test-lab profiles with server validation, stable vehicle IDs and reset, after geometry model is validated in-game.
- [ ] **P3 parked:** tractor/trailer measurable hitch/drawbar force and wheelshape displacement comparison. TTD scalar trailer slip is not an actual force; don't introduce a new engine load writer.

[TTD research memo](../research/2026-10-18-ttd-v3.7-terrain-response-lessons.md). Existing RE PTO V1.6/terrain defaults and normative [ownership](OWNERSHIP.md) unchanged.


## Supporting research — DynamicDrive Pro terrain-write safety (2026-10-18)

- [x] Source inspect exact DynamicDrive Pro 1.0.1.0 ZIP `bf7fff1f1167dcf6c28a877da08ae1a2a8c3e5382407e0b4cde64457f632c52f`; it *attempts* native world-height writes and absolute post-height replay but contains nil scoped wheel hook, uninitialized `trackCells`, undefined `finalSink` and unused/unregistered modules. **No runtime adoption or RE port**.
- [ ] **P0 during V3 safety work:** add constructor/history/hook reachability tests, vertex actor ownership, native brush/height API existence checks, per-vertex max depression, repeated stationary-wheel callback frame-rate invariance, and mixed TerraFarm/RE save-reload identity tests.
- [ ] **P1 optional:** read-only per-wheel surface/tyre category metadata using Mud/RC/RE authoritative providers; no direct friction or torque write.
- [ ] **P2 parked:** measurable load-transfer and hitch/brake/roll comparison, not arbitrary rootNode roll angle or synthetic torque division.

[DDP terrain safety memo](../research/2026-10-18-dynamicdrivepro-terrain-writer-safety-lessons.md). Existing RE terrain production toggle remains OFF and V3 actuator/provenance evidence is not upgraded by this audit.


## Supporting research — AutoSwitch 1.0.0.58 wheel exchange / RMS AUTO (2026-10-18)
- [x] Audit exact `FS25_AutoSwitch.zip` SHA256 `ee20772aeddde5c567d99f004f9282541b7d50a634c7146fc21ac7cf38ce3c25`. Mixed RC-like global arbiter/physics controller requires TTD+DDP; no source support for adding to active MR/Mud/Reifen/RMS stack.
- [ ] **P1 after current Terrain V3 acceptance:** refine previously parked interchangeable-parts vision with a safe wheel-set inventory/transaction model (actual stored front/rear wheels, wear/pressure, 15-minute service step per tire, cancel/rollback and stable vehicle identity). Study native GIANTS reconfiguration before adopting vehicle-XML reload workaround; no external assets.
- [ ] **P1 parallel source research, not implementation:** review RMS 0.12's public differential/park command authority and Realistic 4x4 audit for AUTO recommendation when axle slip > threshold; support manual/AI takeover, steering safety and fail-closed unknown drivetrain.
- [ ] **P2:** off-field grass/crop trampling and re-sowing semantics through native GIANTS density map, respecting SoilCompaction and FarmKit; distinct from terrain geometry.
- [ ] **P3:** tire track **visual** save/replay and unbraked trailer mud drag as isolated measurement tasks, not presumed physics gaps.

[AutoSwitch RE research memo](../research/2026-10-18-autoswitch-decision-policy-and-wheel-racks.md). Current RE PTO V1.6, RC per-bridge arbitration and `TerrainDeformation=false` in main remain unchanged.


## Source research — Hydraulic Suspension System 1.1.0.0 (2026-10-23)

- [x] Source-audited uploaded HSS 1.1.0.0 (`0c014805e1dc8dd981f7f2d6c34903578a90daa0b1b94db4120d7a335381cf59`) against archived 1.0.0.0 (`b338a28d13cadfe8b00949c7d0461079a04f6ee29a5afdd6fc79c3567038d40e`): +2, modified 41, removed 0; CRC/XML/Lua syntax pass.
- [x] Evaluate physical front/rear/pendular suspension, dynamic WORK/ROAD damping, frontloader Ride Control and cab visuals; no heightmap writer or replacement grip simulator.
- [x] Identify non-composing MR/HSS per-wheel spring/damper claim, parked/AI ownership persistence, client-to-server permission/clamp omission, 7→12 config reset, new `loaderOff` schema question and forced wheel rebuild performance gate.
- [ ] **After current RE Terrain V3 recovery milestone or as a separately authorized independent research sprint:** controlled singleplayer A/B HSS 1.1 vs vanilla/MR/RMS/Mud/Reifen on supported tractor, small tractor, Fastrac and frontloader. Verify owner release across driver→AI→park and double save/reload.
- [ ] **If measurable unique capability confirmed:** design a distinct opt-in `SuspensionControl` subsystem (not a broad RC physics replacement) with vehicle-profile provenance, safe exclusive spring/damper lease/release, server authority, visual axle and arm/cab effects separated; preserve RE native PTO and existing MR/Mud/Reifen/RMS ownership.
- [ ] No MP promotion without server validation of controller/ownership and clamped height requests; do not import third-party code/sounds without applicable permissions.

[HSS exact-source research](../research/2026-10-23-hydraulic-suspension-system-1.1.0.0-audit.md). **Docs only; no RE behavior or package version changed.**


## External source research — Realistic Physics 1.20.2.0 (2026-10-23)

- [x] Source audit exact `FS25_RealisticPhysics.zip` SHA-256 `04e19cf8ad0310eda538f72ad09cb2d1b0ea52f19a0d1f5b3246979f1b74fc72`: 170 entries (168 Lua, 1 XML, 1 DDS), CRC/XML/Lua parse PASS. 167 tables are mainly uniform (`forcePointRatio=0.9` in all, `damper=1` in 161, 3 rear tractor travel `0.10`), not 167 physically unique machine models.
- [x] Identify **not a soil dryness/hardpan/implement-draft mod**: the `road/hard/field/soft` labels merely scale wheelspin-induced grip oscillation and vertical force; no moisture read, compaction, historical strength or heightmap writer. `fadeSpeed=1.8 m/s` is 6.48 km/h despite comment claiming ~22; `updateTireFriction` temporary multiplier can clamp at 0.05 × baseline, conflicting with MR/Mud/Reifen.
- [x] Distinguish HSS ownership from RP: HSS is a full dynamic suspension/ride-control capability worth separate external-first test; RP broad rewrites spring/damping baselines and adds synthetic wheel hop. Do not initially co-install HSS/RP; no RC hook patch or RE implementation justified.
- [ ] **P1 as an independent research milestone, after Terrain V3 recovery or explicit re-prioritization:** audit actual MR/SoilCompaction/Mud/RC `MRMudDraft` mechanics for **dry/very-dry soil implement workability**, separate soft-wet adhesion, optimal soil and dry penetration strength. Measure native implement depth, draft and wheel-slip limitations; only then design a narrow owner-composed soil-strength provider if missing.
- [ ] **P2 parked:** after HSS A/B, inspect real wheel hop/chassis vertical acceleration and decide whether GIANTS/HSS suspension already covers it, rather than add a sinusoidal grip loss or second friction writer.
- [ ] **P2 data quality:** adopt concept of `rsStock` vanilla-vs-current per-wheel diagnostic only with RE-specific capability profiles and no copied third-party code.

[Realistic Physics exact-source audit](../research/2026-10-23-realistic-physics-1.20.2.0-full-stack-audit.md). **RE/RC runtime and modDesc versions unchanged; docs-only — do not generate build artifacts.**
