# Roadmap

The roadmap is intentionally capability-driven, not version-date driven.

## Current priority and state (2026-10-13, after PTO V1.6)

**PTO V1.5/V1.6 is integrated in `main`**, with a tested subset of real implements and RC/MR/RMS compatibility; `TerrainDeformation=false` remains the safe mainline default. The PTO label **V1.6** names a functional milestone, not the FS25 mod's `modDesc` version (`0.0.1.0`).

**Next most urgent gameplay risk:** make RE's experimental terrain ruts recoverable by real cultivation/tillage without immediate reseeding collapse. Experimental [PR #44](https://github.com/rafaaelalves/FS25_RealismExtensions/pull/44) addresses reference contamination, but repeated native GIANTS TARGET no-ops and field acceptance remain release blockers. Never merge these experimental terrain branches just because PTO is integrated or CI passed.

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
