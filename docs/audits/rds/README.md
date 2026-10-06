# Realistic Diesel Start deep audit / functional-absorption study

Updated: 2026-10-05

## Exact source baselines

Previous supplied baseline:
- `FS25_RealisticDieselStart 1.2.0.0`
- SHA-256: `e22816e712ef6a48c8f0210209f9983a7c4da3bc55a6267a7fbaad5c5f6bacbd`

Current supplied/upstream baseline:
- `FS25_RealisticDieselStart 1.4.0.0`
- SHA-256: `a2a983c7754bc4fb3dffc04839fb16cf844c72d7664ae78cfcd70fcf3c15721c`
- exact-source diff completed against 1.2;
- no public GitHub repository/license file was found in or for the supplied release.

The 1.4 archive is now the canonical source baseline for this audit.

## Recommendation

**FUNCTIONALLY ABSORB, BUT SPLIT BY CAPABILITY.**

Absorb into RE:
- manual ignition/contact/crank interaction;
- diesel eligibility and glow/preheat orchestration;
- compressed-air supply/brake state, redesigned rather than copied;
- shared RE HUD presentation.

Do not duplicate specialist mechanical ownership:
- RMS/ADS remain preferred engine-temperature, battery, starter and failure owners;
- MR/RMS retain drivetrain/torque ownership;
- RE should not port RDS direct `motor.torqueScale` or generic damage writes.

Proposed shape:

```text
RE EngineStartControl
    -> StartCapabilityResolver
       -> authoritative channels (thermal/electrical/final motor)
       -> contributor sets (fuel/interlocks/blocks)
       -> GIANTS/profile fallback when no external owner
    -> shared RE HUD

RE PneumaticBrakeSystem
    -> PneumaticStorageBackend (native AIR or RE-owned; P0 decides)
    -> BrakeDemand
    -> RC/final brake-owner composition where required
```

## What the 1.4 source changed in the recommendation

The new source strengthens rather than weakens the absorption case.

Useful upstream patterns to retain conceptually:
- final start state is confirmed from actual motor transition instead of assuming `startMotor()` succeeded;
- optional integration through capability methods;
- conservative keybind migration that preserves user custom bindings;
- UI-scale subscription and speedometer-relative HUD anchoring;
- per-vehicle HUD coexistence based on whether ADS actually owns that vehicle;
- narrow pneumatic read/write API for another mod.

Important remaining reasons to redesign:
- ADS integration still mutates private ADS state;
- start failure randomness is still local rather than server-owned;
- broad motorized eligibility and the input dead band remain;
- duplicate RDS temperature/torque/damage ownership remains;
- pneumatic held-pedal consumption remains physically weak;
- air initial stream is still absent;
- lifecycle/dead-code defects are visible in the much larger HUD implementation.

## Audit status

- 1.2 static/source phase: **CLOSED**
- exact 1.2 -> 1.4 source diff: **CLOSED**
- 1.4 static/source review: **CLOSED**
- cross-audit against prior RE/RC audits: **CLOSED**
- final transversal architecture/optimization pass: **CLOSED**
- runtime phase: **pending**
- Realistic Brakes 1.3 exact-source audit: **CLOSED**; trailer implementation remains deferred by design/runtime gates
- native RE implementation: **DEFERRED — not started on this research branch**

The research package is intentionally frozen at a "ready to resume" point.
When implementation resumes, start from `FUTURE_IMPLEMENTATION_BLUEPRINT.md`
instead of repeating a broad RDS audit.

## Companion documents

- `STATIC_FINDINGS.md` — baseline findings plus 1.4 status matrix.
- `SOURCE_DIFF_1_2_TO_1_4.md` — exact update audit and new source findings.
- `ABSORPTION_ARCHITECTURE.md` — proposed RE modules/provider boundary.
- `PNEUMATIC_MODEL.md` — compressed-air physics redesign.
- `DESIGN_LESSONS.md` — reusable ideas for future RE/RC systems and optimization.
- `PERFORMANCE_AND_LIFECYCLE.md` — cadence, caching and lifecycle opportunities.
- `START_MODEL.md` — canonical readiness/outcome/provenance model.
- `NATIVE_AIR_BACKEND.md` — native GIANTS AIR vs RE-owned storage decision.
- `MECHANICAL_OWNER_COEXISTENCE.md` — RMS/ADS authority modes.
- `CROSS_AUDIT_INTEGRATION_MATRIX.md` — final cross-stack ownership/integration ledger.
- `REALISTIC_BRAKES_PREAUDIT.md` — exact-source closure of the former trailer/general-brake gate.
- `../realistic-brakes/README.md` — dedicated Realistic Brakes 1.3 audit.
- `FUTURE_IMPLEMENTATION_BLUEPRINT.md` — canonical return handoff and implementation sequence.
- `RUNTIME_TEST_PLAN.md` — future implementation/runtime gates.
- `UPSTREAM_1_4_NOTES.md` — historical pre-source notes; superseded by the exact source diff.
