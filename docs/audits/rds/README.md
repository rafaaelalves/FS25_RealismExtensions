# Realistic Diesel Start deep audit / functional-absorption study

Updated: 2026-10-05

Source-audited baseline: user-supplied `FS25_RealisticDieselStart 1.2.0.0`, SHA-256 `e22816e712ef6a48c8f0210209f9983a7c4da3bc55a6267a7fbaad5c5f6bacbd`.

Current public release found during the audit: `1.4.0.0`, published 2026-10-04. No public GitHub repository or 1.4 source archive was found, so 1.3/1.4 notes are changelog evidence only.

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
RE EngineStartControl -> StartMechanicalProvider (RMS / ADS / fallback)
                     -> shared RE HUD

RE PneumaticBrakeSystem -> RC composition only where external physics owners require it
```

The supplied 1.2 source audit is complete. Current-upstream source comparison remains open until a 1.4 ZIP/source becomes available.

Companion documents in this directory cover static findings, absorption architecture, pneumatic physics, upstream 1.4 notes and runtime gates.
