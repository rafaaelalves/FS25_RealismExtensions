# Roadmap

Updated: 2026-10-02

The roadmap is capability-driven, not version-date driven.

Canonical next-phase terrain plan:
`docs/project/TERRAIN_EVOLUTION_PLAN.md`.

## Engineering process (applies to every capability)

- source/API research;
- explicit ownership boundary;
- hypothesis + acceptance/rejection criteria;
- harness coverage;
- high-observability first runtime;
- physical + causal validation;
- calibration only after mechanism is proven;
- stabilization telemetry and regression scenarios;
- periodic high-observability revalidation after major dependency/game changes.

See `docs/DEVELOPMENT_PROCESS.md`.

## Terrain deformation / soil interaction — active

Validated foundation now includes:
1. normalized MR/Mud/RC wheel-ground state;
2. conventional tire/load/support-width footprint;
3. distance/cadence-invariant persistent rutting;
4. wetness/slip/plasticity response;
5. persistent SpatialHistory/savegame state;
6. physically working TerrainRecovery with repeated-pass support;
7. active-work persistent-rut suppression;
8. successful runtime validation with more than one cultivator-family implement.

## Next implementation sequence

1. TerrainPassTracker.
2. RecoveryPassSummary + `rutAcceptedWhileActive == 0` invariant.
3. slope-aware roughness and pass-level roughness distributions.
4. target roughness / convergence floor.
5. severity-adaptive recovery.
6. TerrainWorkFootprint extraction.
7. TerrainRecoveryProfile.
8. tool-family recovery profiles; later moisture/direction modifiers.
9. ContactFootprint abstraction.
10. conventional single / dual / wide / implement-wheel normalization.
11. native GIANTS crawler/track footprint.
12. PLAYER / GIANTS_AI / COURSEPLAY parity validation.
13. True AI Tracks (`FS25_aiTracks`) source/runtime audit and retire/coexist/bridge ownership decision.
14. RecoveryAgent / ownership-zone contract.
15. NPC/other-farmer field recovery.
16. natural-relaxation scheduler.
17. public/municipal maintenance scheduler.
18. lazy physical reconciliation of SpatialHistory after external terrain edits.
19. SoilMassTransport redesign with measured mass realization.
20. underbody/high-centering and later terrain-interaction research.

See `TERRAIN_EVOLUTION_PLAN.md` for dependencies, acceptance criteria and ownership boundaries.

## Key policy

Do not reimplement the above as one large terrain-physics rewrite.

Each step must preserve the current validated recovery baseline, add causal telemetry/harnesses first where practical, and change one physical assumption at a time.
