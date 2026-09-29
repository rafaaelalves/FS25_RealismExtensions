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

## Later candidates

- persistent surface contamination / dirt;
- furrow interaction;
- visual-effect consolidation;
- unified state-driven HUD.

These are candidates, not promises. Every module must justify ownership and maintenance cost.
