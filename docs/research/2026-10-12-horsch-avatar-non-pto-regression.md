# 2026-10-12 incident: false red PTO warning on HORSCH Avatar 12.25 SD

Status: reproduced from user game log + MR XML; V1.5 classification already fixes its *proven* false positive. Regression fixtures added on this branch; runtime validation pending. **Do not conflate with the active experimental terrain branch.**

## Evidence
- User FS25 game log, 2026-10-12, run started 07:23; Fiat **180-90 DT** towing **HORSCH Avatar 12.25 SD**, MR replacement identified at shutdown as `MoreRealistic/data/overriding/vehicles/horsch/avatar1225.xml`.
- Game used RE `feat/terrain-pto-integration-2026-10-09@3e3554a43d1c3c6b3305d609a799d8ffb48a7ca4` and RC `main@ad7461fb7777691f6f64e2327753417c95b6177b`, **not V1.5 RE**. RC `MR+RE PTO` and `RMS+RE PTO` bridges active.
- At 07:42:49.586 RE logged `PTO requirements | vehicle=180-90 DT consumers=1 known=1 unknown=0 required=340 conflict=false source=POWER_CONSUMER_PTO_RPM profile=-`.
- At 07:43:48.757, 07:43:49.387 and 07:44:04.876, operator mode switches 540/1000 continued to report `required=340 mismatch=true`. This establishes a **misleading UI requirement**, not a measured gear or a proven turn-on block.
- MR source at `quadural/MoreRealistic_FS25@b38d5667e073505255cd7ce170ab568616a91221`, `MoreRealistic/data/overriding/vehicles/horsch/avatar1225.xml`, sets `vehicle.powerConsumer#ptoRpm=340` and `neededMaxPtoPower=22`; XML comment explains *air turbine (seeds + ferti) + electric distribution*. These are modelled power/governor demands, not a nominal mechanical tractor gearbox family. User reports no visible cardan. Runtime `inputPowerTakeOffs` of the actual in-game variant was not captured, so **do not claim the absence of a native input as an independently measured fact**.
- Mechanical traction is separate: MR overrides seed-drill mass, tyre and draft settings. The concurrent experimental terrain log observed wetness ~0.76, full-slip samples, deep ruts, and independent recoverability issues. The PTO mismatch alone **cannot** explain a vehicle's lack of traction.

## Contract under test
1. A seeder with `spec_powerConsumer.ptoRpm=340`, `neededMaxPtoPower=22`, **no native input PTO**, and **no exact verified PTO profile** is **not** an RE mechanical PTO consumer. Neither 540 nor 1000 gets a false-red mismatch or an AI gear change. MR's load remains untouched.
2. If a genuine physical input PTO exists at runtime, 340 is still *raw load demand*, and **nominal family must remain UNKNOWN** without independent evidence. Show uncertainty, never red incompatibility or 340->540 guess. This case is covered by the generic and sprayer fixtures, not newly assumed about this model.
3. A second, genuine 540/1000 shaft implement connected alongside the non-PTO seeder must remain detectable; ignoring the seeder must not discard other attached machine requirements.
4. The V1.5 `rePTOInspect` command can establish native runtime input count later. No repeated older save/load acceptance tests.

## Regression added
- `tests/pto_resolver_harness.lua`: explicit Fiat/Avatar source-identity fixture + 340rpm/22kW, absence of shaft declaration, and mixed-attachment negative coverage.
- `tests/pto_control_harness.lua`: both physical selector modes remain neutral; worker doesn't shift. No production logic changes needed because PR #39 already enforces physical shaft evidence.
- No modifications to MR, RC, RMS or terrain; PTO V1.5 remains draft until targeted in-game smoke.

## Related log observations (not a PTO patch)
- Missing SeedSelect HUD PNGs for several custom fruit fill types under Estancia Sao Carlos are separately actionable.
- `FS25_CBI6800CT.WoodGrinder` repeats specialization registrations.
- `FS25_manualAttach` throws nil argument in `DetectionHandler.delete` during map shutdown.
- ModMixer reports multiple runtime hook chains; its offline scanner includes a dataset timestamp of 2026-06-01 and should not be mistaken for causal proof of the seeder PTO warning.
