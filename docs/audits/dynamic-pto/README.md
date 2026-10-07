# Dynamic PTO audit

Audited package: `FS25_DynamicPTO_FFM` version `1.1.2.0` supplied by the user.

Status: **CANDIDATE_ABSORB — strong**

## Why this candidate is different

RealismCompatibility already needs dedicated Dynamic PTO integrations:
- profile state;
- MR ratio translation;
- RMS PTO-capacity/utilization composition.

The external mod also owns a large UI/input/settings surface. Replacing it clean-room can remove compatibility complexity and UI fragmentation while preserving the useful concept.

## Functional inventory

The package implements:
- 540 / 540E / 1000 / 1000E families;
- auto selection from implement requirements;
- front/rear PTO selection;
- live PTO RPM from engine RPM and PTO ratio;
- per-tractor mode availability;
- implement XML + heuristic/catalog detection;
- saved PTO state;
- MP synchronization;
- hand throttle;
- road RPM;
- warnings/popups;
- settings integration;
- compact/expanded HUD;
- dynamic implement-output scaling;
- power-consumer scaling;
- baler overload/stall behavior;
- engine-grunt behavior.

It exposes **11 input actions** in `modDesc.xml`, which contributes materially to the current control/UI clutter.

## Asset burden

Not significant for a clean-room replacement:
- the packaged runtime panel/white textures are tiny;
- UI can be built from standard FS25 primitives and original icons;
- the large image payload is primarily the mod icon.

## Architecture concerns worth improving

### 1. Detection
The mod combines:
- native PowerConsumer data;
- XML scanning;
- filename/category heuristics;
- a large static equipment/category catalog.

A replacement should use an evidence hierarchy:
1. explicit implement metadata/API;
2. trustworthy native PowerConsumer values;
3. curated profile database with exact identifiers;
4. category heuristic only as a fail-soft presentation hint, not silent physical truth.

### 2. Physics ownership
The current dynamics layer can change implement speed limits and `neededPtoPower`, add engine-grunt/stall semantics, and apply hand throttle through engine-RPM writes.

For the target stack this should be decomposed:
- PTO module owns PTO mode, gearing/demand and user intent;
- MR owns engine/drivetrain response;
- RMS owns mechanical capacity/condition;
- RHM owns harvest processing;
- RC performs cross-owner composition where specialist APIs are needed.

### 3. Operational status
The user already observed a mismatch where the Dynamic PTO HUD called an RPM state acceptable while the attached Heizomat still would not operate.

A replacement should compute separate states:
- selected PTO mode;
- actual physical PTO RPM;
- implement requested RPM;
- implement operational threshold;
- available PTO power/capacity;
- reason not operational.

The HUD should never reduce those to one misleading generic green/red threshold.

### 4. UX
Prefer context-sensitive controls:
- one primary PTO control/menu;
- optional direct bindings, not eleven mandatory concepts;
- no separate redundant weather/slip-style dashboard;
- unified Extensions HUD later.

## Proposed replacement boundary

Potential module name: `PTOSystem`.

It should publish normalized state, e.g.:
```lua
{
  selectedMode = "1000",
  actualPtoRpm = 925,
  requestedPtoRpm = 1000,
  operationalMinRpm = 930,
  requestedPowerKw = 82,
  availablePowerKw = 95,
  activeEnd = "rear",
  engaged = true,
  status = "UNDER_SPEED"
}
```

MR/RMS-specific translation remains outside the module's private implementation boundary, preferably through RC.

## Recommendation

Proceed to design, but do **not** remove Dynamic PTO from the gameplay stack yet. Build a parity matrix first and replace only after:
- mode/ratio behavior is validated;
- MR + RMS composition matches or improves RC0183;
- attached implement detection is at least as reliable;
- save/MP semantics are understood;
- UX solves the current status contradiction.


## RMS 0.11.0.0 cross-audit follow-up

RMS 0.11 keeps `RMS_Utils.getPtoNativeCapacityData(vehicle,totalTorque)`
text-identical to 0.10, so the existing RMSDynamicPTO ratio scope remains
source-compatible.

0.11 adds a new consumer of the same helper:
`RMS_Utils.getPtoEngagementDamage()` uses the returned utilization/size to
scale high-RPM PTO engagement shock.

This expands the effect of the existing bridge in a physically coherent way:
the selected Dynamic PTO gearing should affect both continuous reflected PTO
load and engagement-shock sizing.

No new bridge is required.

Runtime follow-up:
- compare low/high engine-RPM engagement;
- test at least two effective PTO ratios;
- verify Dynamic PTO `gruntLoadExtra` remains excluded from RMS stress.
