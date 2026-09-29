# Roadmap

The roadmap is intentionally capability-driven, not version-date driven.

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
