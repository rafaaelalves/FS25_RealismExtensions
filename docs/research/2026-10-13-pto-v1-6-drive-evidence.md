# RE PTO V1.6 (incremental) — observed mechanical input vs load-only power
Date: 2026-10-13
Branch: `feat/pto-v1-6-drive-evidence` based on PTO V1.5 draft PR #39 at `8acedcd01e73367d475ede61ed7d0dcbe60d606f`.
Status: experimental / read-only diagnostic and HUD improvement, not a complete V1.6 simulation.

## Motivation
Horsch Avatar 12.25 SD with MR 0.26.10.08 declares generic `powerConsumer.ptoRpm=340`, `neededMaxPtoPower=22` for fan and electric distribution, but neither value establishes a 540/1000 mechanical shaft. Previous V1.5 correctly prevented a fabricated PTO-family mismatch, yet the HUD displayed the selected gearbox without identifying a non-mechanical declared power consumer.

## Behavior
`Resolver.collectRequirements` now reports attachment evidence without creating an additional mechanical owner:
- `NATIVE_PTO_INPUT`: at least one attached implement exposes an actual native input PTO array. This **does not confirm actual linkage** or rotation; use `rePTOInspect` to check `connectedInput` separately.
- `PROFILED_PTO`: independently curated implement PTO profile, but no native input was observed.
- `POWER_CONSUMER_NO_INPUT`: at least one attached implement declares non-zero powerConsumer demand/RPM, but no native PTO input or curated shaft-driven profile is found. This is **not proof that equipment physically lacks a cardan**, only absence of such evidence in the observed game APIs.
- `NO_PTO_INPUT_DETECTED`: attached tools exist, but neither native shaft nor declared generic PowerConsumer was identified.
- `NO_ATTACHMENT`: an empty attachment list was observed.
- `UNKNOWN`: root attachment data unavailable; never interpret missing API as no implement.

Additional read-only owner state:
`driveEvidenceStatus`, `attachedImplementCount`, `nativeInputImplementCount`, `profiledImplementCount`, `unlinkedPowerConsumerCount`. These fields are optional additions; all existing API fields and RC ratio contracts remain unchanged.

HUD keeps displaying the tractor's **selected** 540/1000 mechanical gearbox. Only when a non-physical `POWER_CONSUMER_NO_INPUT` exists and PTO is not engaged, a compact neutral second line `PWR?` appears (default `ptoHud.showUnlinkedPowerHint=true`). It means *power declared, no cardan input proved*; it is not a running power meter and never turns the icon orange. `PWR?` is not shown with a mechanical PTO input or an actual estimated running shaft RPM. Disabling the hint leaves the V1.5 presentation unchanged.

`Resolver.isPtoEngaged` now requires shaft evidence **before** believing a generic `getIsPowerTakeOffActive=true`. This prevents a shaftless seeder that exposes a generic active PowerConsumer from visually behaving as a turning PTO shaft. Actual shaft-driven implement control is unchanged, including the turned-on fallback for modded PTO implements.

The `rePTOInspect` ROOT record includes the drive evidence and each category count; tool lines still expose native `inputPto`, `connectedInput`, raw MR power and `mrLoadKW`.

## Boundaries

NO new engine hooks, fuel/torque demand, cutting/sowing rate, AI gear changes, saved fields or multiplayer wire fields. The resolver walks existing attachment trees at onLoad/postLoad/attach/detach/manual refresh; not each frame. The HUD reads cached public-state evidence; per-frame native PTO engagement detection existed already. Existing V1.5 diagnostics and RC MR/RMS owner semantics remain intact. Terrain untouched.

Observed/declared `neededMaxPtoPower` is a **limit**, not proof that full kW was drawn during gameplay. Only an in-game `rePTOInspect` sample off/on can test real MR consumption. Absence of the input specialization may mask a visible shaft in an unusual mod; evidence stays explicitly uncertain.

## Test coverage
- Horsch 340 RPM / 22 kW generic consumer, real native input 540 mower, mixed attachment, no attached implement, absent API.
- Even if Horsch reports generic `getIsPowerTakeOffActive=true`, RE does not report mechanically engaged. A native-input mower continues to engage.
- Control exposes evidence without changing manual 540/1000 mismatch or AI modes.
- HUD shows neutral `PWR?` only for load-only state; configurable OFF; no false red/orange state. The tooltip isn't interactive; further UX work is deferred.
- Inspector ROOT reports evidence, no new polling.

## Remaining gates
1. CI test+packaging must pass for exact new head.
2. One normal-save Horsch sample with `rePTOInspect` before/while sowing; see `mrLoadKW`, `inputPto`, `connectedInput`, and changed HUD. No repeated long regression required.
3. Baler and chipper diagnostic comparison remains a separate V1.6/V2 physics/output study. Do not claim these modes physically regulate throughput until confirmed.
4. Dedicated multiplayer authority and server-side event permission checks are a separate high-priority review before public-server release, not patched speculatively here.
5. Keep the PTO V1.5 parent PR #39 draft pending runtime smoke; isolate this V1.6 branch for development.

## Dynamic PTO reference
The supplied updated Dynamic PTO archive still identifies as 1.1.3.0 despite changed UI/network scripts. `PTODetector.lua` and `PTODynamics.lua` are unchanged in normalized member comparison. RE adopts *neither* global synthetic motor grunt nor unsupported universal under/over-speed warning thresholds.
