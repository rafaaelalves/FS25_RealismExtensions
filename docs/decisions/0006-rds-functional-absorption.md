# ADR 0006 — Absorb RDS by capability, not as one mechanical owner

Status: proposed
Date: 2026-10-05

## Context

Realistic Diesel Start provides valuable manual ignition/glow/start interaction and a unique compressed-air system, but its supplied 1.2 implementation also owns engine temperature, cold torque, generic damage, lights/electronics and start failure state that overlap RMS/ADS/MR.

The current public RDS line is 1.4.0.0 and reports direct ADS compatibility plus trailer-air integration with Realistic Brakes, reinforcing that these are cross-owner capabilities rather than one isolated feature.

## Proposed decision

Functionally replace RDS inside RealismExtensions through separate capabilities:

1. RE owns `EngineStartControl`: staged ignition/preheat/crank interaction and diesel/profile semantics.
2. Mechanical start state is provided by RMS, ADS or a minimal standalone fallback.
3. RE owns a redesigned `PneumaticBrakeSystem` because no current target-stack specialist owns compressed-air supply state.
4. Final drivetrain/brake-force effects remain with active physics owners and are composed through RC only when required.
5. Start/glow/air presentation joins the shared RE HUD/settings surface.
6. External RDS active disables native RE equivalents during migration; no dual ownership.

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
