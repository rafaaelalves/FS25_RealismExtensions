# ADR 0006 — Absorb RDS by capability, not as one mechanical owner

Status: proposed
Date: 2026-10-05

## Context

Realistic Diesel Start provides valuable manual ignition/glow/start interaction and a unique compressed-air system, but its supplied 1.2 implementation also owns engine temperature, cold torque, generic damage, lights/electronics and start failure state that overlap RMS/ADS/MR.

The exact supplied RDS 1.4.0.0 source now proves direct ADS composition, optional Diesel Fuel System capability calls and a public pressure boundary for Realistic Brakes. These confirm that startup is composed from orthogonal capabilities rather than one isolated mechanical owner.

## Proposed decision

Functionally replace RDS inside RealismExtensions through separate capabilities:

1. RE owns `EngineStartControl`: staged ignition/preheat/crank interaction and diesel/profile semantics.
2. Mechanical start state is composed by capability facet: thermal, electrical/starter, glow, fuel, interlock and final motor-start ownership may come from different providers.
3. RE owns a redesigned `PneumaticBrakeSystem` because no current target-stack specialist owns compressed-air supply state.
4. Final drivetrain/brake-force effects remain with active physics owners and are composed through RC only when required.
5. Start/glow/air presentation joins the shared RE HUD/settings surface.
6. External RDS active disables native RE equivalents during migration; no dual ownership. Historical RC RDSADS remains fail-closed for RDS 1.4 because upstream changed the ADS ownership contract.

## Explicit non-goals

Do not absorb:
- RDS direct `motor.torqueScale` cold derate;
- duplicate engine thermal model when RMS/ADS owns it;
- generic cold-driving/start damage when a mechanical specialist exists;
- broad independent electrical/light ownership;
- source/assets from RDS without explicit license permission.

## Status gate

This ADR remains **proposed** until:
- current audit is reviewed;
- RDS 1.4 exact source is inspected if obtainable;
- the first implementation phase boundary is accepted.

Audit: `docs/audits/rds/README.md`.


## Exact 1.4 evidence

The source review closes the earlier changelog-only uncertainty.

Positive upstream patterns to retain conceptually:
- wait for the actual motor transition before declaring RUNNING;
- optional capability methods for fuel/start state;
- per-vehicle capability ownership;
- conservative default-key migration;
- UI-scale invalidation rather than per-frame geometry rebuild;
- narrow external pneumatic API.

Reasons the proposed absorption remains justified:
- private ADS state coupling;
- local stochastic start authority;
- non-diesel eligibility gap;
- duplicate temperature/torque/damage ownership;
- weak pressure-only pneumatic model;
- fragmented HUD/settings and lifecycle debt.
