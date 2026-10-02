# Roadmap

Updated: 2026-10-02

The roadmap is capability-driven, not version-date driven.

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

Current progression:
1. normalized MR/Mud/RC wheel-ground state;
2. tire/load/support-width footprint;
3. distance/cadence-invariant persistent rutting;
4. wetness/slip/plasticity response;
5. persistent history/persistence;
6. physical terrain recovery by soil-working implements;
7. implement operation ordering;
8. native crawler/track footprint;
9. SoilMassTransport calibration/mass conservation;
10. GIANTS AI/Courseplay parity;
11. underbody/high-centering interaction research;
12. assess retirement/remaining ownership of True AI Tracks.

Current immediate gate: v22 TerrainRecovery runtime validation.

## Architecture refinement

After v22 mechanism validation, extract reusable boundaries inspired by runtime lessons and the TerraFarm audit:
- WorkDetector;
- WorkFootprint;
- TerrainOperation;
- HistoryReconciliation;
- diagnostics/causality context.

Do not perform a large refactor before the current runtime hypothesis is validated.

## Later capability candidates

- crop/vegetation interaction;
- surface contamination;
- richer terrain/furrow interaction;
- RMS-facing drivetrain decision enrichment;
- CTIS/tire-pressure capability;
- visual-effect consolidation;
- unified state-driven HUD.

Candidates require their own ownership/audit/test gates before implementation.
