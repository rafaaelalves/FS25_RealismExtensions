# PTO V1.7 — Phase A: read-only shaft connection evidence and implement telemetry

Date: 2026-10-14. Scope: **RealismExtensions PTO only**, staged feature branch `feat/pto-v1-7-connection-evidence`. The V1.6 `main` remains unchanged pending this PR's review. This is **not** a new power/torque, hookup, clutch, or failure simulation.

## Problem and verified engine semantics

RE V1.6 `Resolver.hasInputPowerTakeOff` established that an implement declared a native input shaft, but declaration alone cannot tell whether it is currently connected. Before V1.7, `rePTOInspect` counted `connectedInput` merely by `input.connectedVehicle ~= nil`, which could be a partial or stale reference.

The FS25 `PowerTakeOffs.lua` script (inspected from [FS25 Lua API mirror](https://github.com/MyGameSteamOfficial/fs25-lua-api/blob/main/vehicles/specializations/PowerTakeOffs.lua), `attachPowerTakeOff`, `detachPowerTakeOff`, and `onUpdateInterpolation`) establishes reciprocal pointers:
- On attachment: `output.connectedInput = input`, `output.connectedVehicle = attachableObject`, `input.connectedVehicle = self`, `input.connectedOutput = output`.
- On detach, both ends are cleared.
- For rendering, `input.connectedOutput.isActive` can track the implement's **active animation**, not a measured transfer of torque.

The [official GIANTS PowerTakeOffs implementation for FS22](https://gdn.giants-software.com/documentation_scripting_fs22.php?category=48&class=534&version=script) shows the same reciprocal structure. The mirror is not an OEM FS25 v1.24 runtime proof, and custom mods including Manual Attach may use a different lifecycle. **Unknown must remain an explicit possible outcome**.

## Implemented now (safe read-only stage)

New public resolver helper: `RealismExtensionsPTOResolver.getInputConnectionEvidence(implement)`:

| Result | Conservative meaning |
| --- | --- |
| `NO_INPUT` | Native input list explicitly exists and is empty |
| `DECLARED_UNLINKED` | One or more native input entries exist and *all* have no connection pointers |
| `LINKED` | Every listed input provides a `connectedVehicle` + `connectedOutput` and that output reciprocally identifies the same input and the examined implement |
| `MIXED` | Some inputs LINKED and others unlinked; no ambiguous input |
| `UNKNOWN` | Missing or malformed input list; incomplete pointers; stale reciprocal links; third-party connection lifecycle not proven |

Also returns counts `declared`, `linked`, `unlinked` and `uncertain`. The helper computes evidence from *current* native fields each time it is called; **no stale cache, no per-frame polling**.

`rePTOInspect` retains legacy `inputPto` and `connectedInput` for log comparisons, while appending **`ptoLink`, `verifiedLinks`, `unlinkedInputs`, `uncertainLinks`** to TOOL lines. In addition it exposes source MR fields when present:

- `mrBalerTonsPerHour` → `tool.mrBalerLastTonsPerHour`;
- `mrBalerSpeedLimit` → `tool.mrBalerSpeedLimit`;
- `mrFeedingActive` → `tool.spec_woodCrusher.mrFeedingActive`;
- `mrFeedingWaiting` → `tool.spec_woodCrusher.mrWaitingForFillLevel`;
- `mrCrusherPowerWanted` → `tool.spec_woodCrusher.mrCrushingPowerWanted`.

These are **reads, not overrides**: can help verify the MR Heizohack feed cutoff at normalized `mrPtoRpmRatio=0.78`, and future actual baler throughput tests. A non-MR implement shows `-` for missing values, not zero.

## Deliberate scope exclusions

- **Do not** start rejecting PTO mode changes because link evidence is UNKNOWN, LINKED, or DECLARED_UNLINKED. The production interlock still uses the *live* RE `isPtoEngaged` model (same as V1.6), and MR/RMS still own physics.
- **Do not** rename the existing `connectedInput` field; although weaker, it is part of earlier log conventions.
- **Do not** equate LINKED with shaft rotation, load transfer or unbroken/connected Manual Attach lifecycle under every mod version.
- **Do not** cache engagement or alter the profile selector, AI, savegame schema, multiplayer packets, HUD rendering, motor hooks, or RC bridge.
- **Do not** merge experimental terrain recovery or broaden multi-output PTO behavior yet.

## Tests and acceptance

`tests/pto_resolver_harness.lua`: empty/missing inputs, declared-but-unlinked, partial linked, verified reciprocal linked, wrong output reference, connection mutation without attach callback, mixed sets, broken native method/spec fallback; evidence remains separate from `isPtoEngaged`.

`tests/pto_inspection_harness.lua`: legacy connectedInput preserved, new fields change when the reciprocal connection toggles, missing MR optional values print `-`, and source-native baler/woodcrusher counters are visible in on-demand logs.

**Next runtime test after CI, when convenient:** one `rePTOInspect` for a shafted implement with a connected cardan and (if possible) a second after using Manual Attach to disconnect it. Check `ptoLink`, `connectedInput`, `turnedOn`, `activePto` separately; if Manual Attach changes a different state, record `UNKNOWN` rather than retrofitting engine hooks speculatively. No need for multiplayer.

**Follow-on V1.7 work:** profile hardware/ratio provenance, scoped profile matching cache **only after measuring repeated calls**, and distinct multi-output relations. Those changes are *not* in this PR. Research issues [#50](https://github.com/rafaaelalves/FS25_RealismExtensions/issues/50) (infrastructure/optimization) and [#48](https://github.com/rafaaelalves/FS25_RealismExtensions/issues/48) (implement response).

## Evidence status

CI tests validate code using simulated GIANTS objects. Even with a passing CI, this is not proof of a Manual Attach in-game linkage signal. No physical load, speed or routing claim changes until that observation.
