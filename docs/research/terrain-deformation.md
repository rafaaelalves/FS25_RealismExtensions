# Terrain deformation research

Status: research, no active gameplay implementation.

## Problem

The RC0200 target stack can produce convincing physical loss of traction, sink and stuck behavior through MR + Mud, but FarmKit's custom geometric rut deformation is suppressed because its public Ground Physics toggle couples ruts to a competing sink/ground core.

Observed runtime symptom:
- wheels visibly spin and sink;
- vehicle/trailer can become stuck;
- no corresponding custom rut/deformation is produced by FarmKit.

## Goal

Create terrain deformation as a **consequence** of authoritative physics.

## Inputs to validate

- grounded/contact position;
- longitudinal slip;
- lateral slip/scrub;
- effective wheel load or a defensible proxy;
- tire width / contact footprint;
- local Mud wetness;
- Mud sink depth;
- ground/surface type;
- freeze/thaw state;
- vehicle/implement/AI control state.

## Outputs

Only terrain/visual state owned by this module:
- rut depth;
- rut width;
- longitudinal excavation/shear;
- lateral scrub;
- optional track visual metadata.

It must not write MR/Mud friction, motor load, brake force, sink radius or speed caps.

## Desired behavior

- low slip on firm/dry soil: shallow/mostly cosmetic tracks;
- high slip + wet/soft soil: deeper excavation;
- repeated passes: diminishing accumulation with a hard physical/visual bound;
- wider footprint: wider and generally less-deep rut for equal load;
- narrow/heavily loaded tire: greater pressure effect;
- lateral slip: sideways scrub rather than identical longitudinal rut;
- frozen soil: strongly reduced deformation;
- thawed/wet soil: increased susceptibility;
- AI/Courseplay/player: same model, no duplicate AI-only physics.

## True AI Tracks

Treat True AI Tracks as a functional-overlap candidate. Before replacement:
- audit exact 2.2.0.1 implementation;
- determine which GIANTS deformation calls it restores;
- identify AI/implement coverage;
- measure update cadence and persistence;
- reproduce equivalent or better behavior through this common engine.

## Performance budget

Research must establish:
- maximum brush/deformation operations per frame;
- temporal throttling per wheel;
- minimum movement/slip thresholds;
- spatial deduplication/merge behavior;
- maximum active tracked wheels;
- cleanup/persistence semantics.

No prototype graduates to default-on until a long-session profile shows bounded cost.
