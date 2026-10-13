# Field validation — Berthoud Vantage 4300 and Horsch Avatar 12.25 SD (2026-10-13)

Status: **runtime observations confirmed; real implement-output semantics unresolved**. No physics/control implementation change authorized yet.
Build under test: RE `feat/pto-v1-6-drive-evidence@cad0c62d496f27155d0e738876b84b38dc1aa597`, GitHub Actions `38393575680`; RC `main@ad7461fb7777691f6f64e2327753417c95b6177b`. FS25 1.24.0.0, MoreRealistic 0.26.10.08, RMS 0.11.0.0. RE TerrainDeformation **disabled**, so this session is a PTO test, not terrain validation.

Uploaded runtime evidence: `log(20261013-122823).txt` and `ModMixer(20261013-122823).log`. Relevant exact `rePTOInspect` timestamps below, with game-local timestamp.

## Berthoud Vantage 4300: native mechanical PTO really identified

At 09:18:41, Vantage attached but OFF, tractor selected 1000:
- `inputPto=1 connectedInput=1`; `driveEvidence=NATIVE_PTO_INPUT`, `hasConsumer=true`, `engaged=false`.
- MR XML raw `ptoRpm=500`, `powerMinKW=12 powerMaxKW=12`; operating load 0.
- RE `gearCompatibility=UNKNOWN` and `nominalFamily=-`; neutral `?` after the selected mode is **correct**, not a red fault. The raw load/governor RPM is **not** an independently verified 540/1000 nominal mechanical gearbox.

At 09:19:56, active sprayer, AI on, selected 1000:
- `effectiveRatio=2.3`, reported motor RPM 2083.43, MR cached drive `mrPtoCurrentRPM=978.31`, `mrPtoRpmRatio=1.9566`.
- `mrLoadKW=12`, `mrTorqueKNm=0.11713`, `consumePower=true activePto=true`.

At 09:20:27, active sprayer, AI on, selected 540:
- `effectiveRatio=4`, reported motor RPM 2083.43, MR cached drive `mrPtoCurrentRPM=562.53`, `mrPtoRpmRatio=1.12505`.
- `mrLoadKW=12`, `mrTorqueKNm=0.20371`, `consumePower=true activePto=true`.

**Interpretation**: this is not a fake selector. The mechanical ratio and the MR-reported drive speed change substantially. The shaft-side torque changes inversely with RPM to deliver the same modeled **12 kW**, fully consistent with `P=T*omega`. The users reports spraying works/performs similarly in both selections. Static MoreRealistic `MoreRealistic/data/overriding/vehicles/berthoud/vantage4300.xml` sets `ptoRpm=500`, `neededMaxPtoPower=12`; actual loaded native minimum is **also 12**, so MR's generic `mrUpdatePtoPower` has no variable min-to-max load to respond to RPM. `MR_Sprayer.lua` affects application usage based on working speed / configured spray speed and **does not directly use `mrPtoCurrentRpmRatio`**. This explains a plausible absence of gameplay response without claiming that actual liquid flow/output was quantitatively measured (it was not).

**Timing limitation**: the `MOTOR engineRPM` one-time getter (2083) is not numerically consistent with directly multiplying cached `mrPtoCurrentRPM` by RE `effectiveRatio` (both imply approximately 2250). MR updates its last-consumer RPM on its own schedule, whereas the inspector samples different motor variables at command invocation. Do not claim the recorded drive RPM is a direct instantaneous physical sensor or infer a new motor bug until synchronous sampling verifies the provenance. The direction and magnitude of the gear change are nevertheless clear.

AI emitted `decision=blocked-unknown` for both 1000 (09:19:38) and 540 (09:20:20): conservative no-automatic-shift policy behaved as designed, **not** a failure to spray. Vehicle operated while `ai=true` and `engaged=true`.

RC is active: `MR+RE PTO ACTIVE`, `RMS+RE PTO ACTIVE`; end-of-run aggregate counters were nonzero (`MRPTO.effectiveRatioScopes=30224`, `mrPtoRpmRatioScopes=14657`, `motorizedUpdateScopes=15218`, `RMSPTO.effectiveRatioCapacityScopes=7236`). These are session-level counters, **not** per-BERTHOUD causal attribution. Dynamic PTO mod appears on the game mod scanner but `DynamicPTO=-` and Dynamic bridges are inactive; not a competing active PTO owner in this run.

### Model-specific OEM evidence research (NOT blanket in-game profile)

A documented real 2022 Berthoud Vantage 43-46, 4300 L, includes **540 PTO** and PTO-driven pump:
https://www.rbauction.fr/pdp/2022-berthoud-vantage-43-46-28-m-s-a-pulverisateur-traine-pulverisateur-%C3%A0-tirette/14416491

A Vantage E.C.TRONIC manual that covers the 43-46 family discusses **540 rpm PTO**, and indicates hydraulic pump drive can be an option:
https://www.manualslib.com/manual/3872363/Berthoud-Vantage-E-C-Tronic-55-60.html

This is compelling evidence for a **540-driven configuration** in the model family, but does not prove the precise FS25 in-game 4300 XML variant, its fitted pump, or the lack of alternative factory configurations. Do not automatically promote the `500` load to nominal 540 or enforce shutdown for 1000 until the variant is mapped accurately. Candidate for curated `PTOProfiles` if exact model evidence/variant is established.

## Horsch Avatar: auxiliary MR power load without native mechanical PTO

At 09:25:20 and 09:25:48, attached/off:
- `driveEvidence=POWER_CONSUMER_NO_INPUT`, `inputPto=0 connectedInput=0`, `hasConsumer=false`, `engaged=false`.
- `rawConsumerRPM=340`; loaded MR `powerMinKW=20 powerMaxKW=22`; `mrLoadKW=0`, `consumePower=false`.

At 09:26:07 and 09:26:54, attached/on without actual crop being newly sown:
- Still `hasConsumer=false engaged=false` in RE, correctly avoiding false mechanical shaft activation.
- The **GIANTS/MR generic** `activePto=true`, `consumePower=true` refer to the internal power-consumer state, not independently to a connected physical shaft.
- `mrLoadKW=20` at both inspector snapshots even as tractor motor speed changes ~2023 -> ~1145 rpm; modeled torque 0.37755 -> 0.66085 kNm (increases when speed falls).
- **This confirms MR calculates non-zero accessory load even without a native connected PTO input.** It does not alone demonstrate actual engine power delivery via independent dyno measurement or prove the real machine's hydraulic/electrical supply path. RE should not duplicate 20–22 kW or synthesize a PTO shaft.
- The fact that active load stayed at 20 kW is consistent with loaded minimum; because no actual sowing occurred, evidence about load increasing to 22 kW under material placement remains unresolved.

The log validates the V1.6 read-only classifier and false-engagement safeguard in normal save for these two implements. The user did not report screenshot of `PWR?`, so the exact HUD appearance remains to be confirmed independently; logging proves the needed state exists, not that every render path displayed it.

## No new RE physics patch yet

1. Keep RE V1.6 experimental build `cad0c62d` for current PTO investigation; do not replace with an old V1.5 or merge draft PRs on runtime observation alone.
2. Additional output physics cannot be justified merely because changing PTO gear leaves sprayer gameplay similar. First audit actual FS25 `Sprayer` liquid-discharge and nozzle/rate controllers plus exact in-game variant; measure output quantity/area or flow under a controlled scenario, distinguishing regulation compensation and genuine pump shortage. If a gap exists, design optional, evidence-based operational envelope; never blanket 85%/112% or universal n^3 fan/pump law.
3. For the Vantage model family, verify native FS25 equipment configuration and manufacturer drive before curated `gearboxFamilyRpm=540` or selective warnings. Avoid generalizing all Vantage and alternative drive options.
4. Optionally improve diagnosis to log both synchronous instantaneous engine/nonclamped RPM and MR cached RPM with sampling ages, only if a concrete mismatch remains and adds value.
5. Keep the Berthoud/Horsch test and existing harness cases as regression fixtures. No repeat of the current operating tests is required.
6. Finish multiplayer validation (per-user vehicle authority), baler/chipper, and UI tests later on separate work tracks. None of the observed shutdown errors is a proven PTO failure.

## Other unrelated log issues

`FS25_manualAttach/src/core/DetectionHandler.lua:65` invokes `delete(nil)` on session shutdown (existing issue). `FS25_CBI6800CT.WoodGrinder` duplicates vehicle-type specializations at load, and Dynamic PTO's installed inactive archive has duplicate translation entries. The ModMixer conflict scan includes baseline global conflicts without proof of new PTO regression. Keep these in general mod optimization audits, outside the PTO branch.
