# Native PTO V1 — final in-game acceptance (2026-10-09)

## Proven already; avoid repeated redundant tests

- Real RE and RC PTO build identities, MoreRealistic 0.26.10.08 and RMS 0.11, bridges ACTIVE.
- 512 Vario with VariPack detects 540 shaft speed; 6R 155 with Heizohack HM10-500 detects 1000.
- Engaged interlock, mode mismatch, 6R ROAD engine idle and manual +100 RPM commands.
- Detailed MRPTO `rcTelemetry MRPTO detailed`: 273 causality samples, physical engine RPM, kinematic shaft RPM, consumed PTO torque, applied power, motor load, fuel. Kinematic shaft RPM is not an independent measured shaft sensor.

## Unverified release gates

1. **Terrain-off safety of final paired build:** With this RE PTO candidate confirm startup `TerrainDeformation=disabled`, PTO controller active, RC MR+RE PTO/RMS+RE PTO ACTIVE. No `realismExtensionsTerrainDeformation` specialization on wheeled vehicles and no RE terrain writer jobs. The Lua harness guarantees only registration/config behavior, not GIANTS runtime.
2. **AI actual powered operation:** With one engaged implement (e.g. 6R+Heizohack 1000 or 512 Vario+VariPack 540), start GIANTS AI or Courseplay where supported. Verify useful engine RPM without manually setting hand throttle and no governor fight. Distinguish implement classification from genuinely engaged PTO operations; if worker cannot operate that class, record NOT TESTABLE and use another tool rather than claim PASS.
3. **Persistent operator settings:** On backup save set a nondefault supported PTO mode and hand throttle (not ROAD), save, reload and verify both independently restored, no save XML errors and no unexpected state changes on AI/manual return.
4. **Exit and return:** With hand throttle set, exit the vehicle and re-enter; verify intended unattended state with no unexpected RPM command or mode reset.
5. **Fallback:** Without RC (or MR) verify RE's native GIANTS path does not crash and baseline operation remains sane; with RC but RE native PTO disabled, verify bridge stays inert. Separate compatibility gate; do not modify the production save.
6. **HUD:** Confirm icon, selected family and warnings on the expected 1080p UI, not merely HUD attachment message.

## Performance and control

- Enable detailed `rcTelemetry MRPTO detailed` only for *one short targeted session*, then restore summary. Detailed logs must not remain permanently active.
- Record paired artifacts/build identities, tractor/implement, activation, operator setting, AI state and approximate test interval.
- If any gate fails, stop release and fix its narrow cause. The terrain-recovery experimental branch and PR #36 are deliberately excluded.

## Scope after V1

A kinematic shaft-speed estimate does **not** prove under-RPM productive yield, clutch slip, physical stalling or speed-scaled animations. These require model-specific audits and isolated V1.5/V2 work, not a universal multiplier.
