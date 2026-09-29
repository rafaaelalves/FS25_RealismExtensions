# ADR 0004 — Specialist ownership is provisional, not permanent

Status: accepted  
Date: 2026-09-29

## Context

The project started from a conservative rule: mature specialists such as MoreRealistic, MudSystemPhysics, RMS, Reifenverschleiss, SoilCompaction and RealisticHarvesting should remain authoritative owners rather than being casually duplicated inside RealismExtensions.

That remains the correct default because replacing mature systems has real implementation, validation and maintenance cost.

However, "external owner" must not become an architectural prohibition.

The capability audits already show cases where a clean-room replacement can provide a materially better system:
- True AI Tracks can be absorbed into one TerrainDeformation pipeline with less polling and stronger shared state;
- Dynamic PTO can remove substantial translation/compatibility machinery;
- Reifen can be reconsidered by layer;
- loose-material behavior can be unified more coherently than two overlapping external owners.

The same evaluation must remain possible for MR, Mud, RMS and other deep specialists.

## Decision

Every current external owner is **provisional by capability**.

RealismExtensions may clean-room reimplement and replace even a mature specialist capability when evidence shows that centralizing it creates sufficient benefit.

No specialist receives permanent "do not replace" status merely because it is mature or currently authoritative.

## Replacement bar

The bar is deliberately higher for deep specialists.

A proposed replacement should demonstrate one or more substantial gains:

- materially lower runtime cost or bounded work architecture;
- cleaner ownership with fewer global hooks/writes;
- removal of major compatibility bridges;
- a higher-quality authoritative state model;
- materially better physics or simulation fidelity;
- coherent player/AI/implement behavior impossible to achieve through integration;
- simpler persistence/network state with equal or better behavior;
- maintainability gains large enough to justify owning the full subsystem.

Minor code-style improvements or mod-count reduction are not enough.

## Migration rule

Replacement is staged:

1. audit the existing specialist by capability;
2. define normalized provider semantics independent of that implementation;
3. prototype the replacement behind the same contract;
4. compare behavior, performance, persistence and multiplayer;
5. switch ownership only after parity or deliberate behavioral improvement is demonstrated;
6. remove now-redundant RC bridges after the new owner is validated.

This is one reason the StateContract/provider boundary is important: TerrainDeformation and other consumers should not care whether wetness/load/slip comes from Mud/MR today or a future native RE physics owner.

## Current implication

For the first TerrainDeformation milestone:
- MR remains drivetrain/slip owner;
- Mud remains physical wetness/sink/load/ground-state owner;
- Reifen + RC remain structural tire-wear owner.

Those are implementation choices for the current milestone, not permanent project boundaries.
