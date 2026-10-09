# Realistic Harvesting 1.6.2.0 runtime test plan

Purpose:
promote the exact 1.6.2 source from static-approved to the user's current-stack
runtime baseline without turning this into a large artificial test campaign.

## Primary update smoke

Use:
- current RC main;
- current normal RE build;
- Realistic Harvesting 1.6.2.0;
- normal target stack.

Back up the save first.

### T1 — bootstrap/version
Confirm:
- RHM loads as 1.6.2.0;
- RC reports `RHarvest=1.6.2.0`;
- no new RHM/RC/RE/MR/RMS/Soil/Moisture/FarmKit error.

### T2 — inspect migrated target load
On an existing calibrated combine, record the actual target load shown in RHM.

Do not assume the update automatically changes a saved 88% calibration to the
new 80% default.

If comparing behavior against 1.6.0, normalize the setting first.

### T3 — normal grain harvest
Use an ordinary grain combine/header.

Observe:
- header detection;
- crop detection;
- throughput;
- engine/process load;
- target/recommended speed;
- actual working speed;
- physical tank growth;
- crop-loss indication.

Pass:
- stable controller;
- no unexpected 3.5 km/h floor lock;
- no runaway acceleration;
- no duplicate/lost crop;
- no obvious conflict with MR/RMS.

### T4 — chopper vs swath
If convenient:
1. harvest with straw swath active;
2. harvest with chopper/spreader active.

Expected:
- chopper state/power appears only in the appropriate mode;
- chopping can reduce equilibrium speed/increase RHM process demand;
- no second drivetrain/PTO solver appears.

### T5 — moisture sanity
With Moisture System active:
- note provider/crop moisture in dry/normal conditions;
- if possible compare morning/wet/rain context;
- verify RHM moisture does not jump to an implausible unrelated value.

Goal:
ensure object/provider moisture is being consumed before the fallback and that
combined process+loss effects are plausible.

Do not compare to Mud wheel/soil wetness as if they were the same state.

### T6 — slope/weed optional exercise
If the field naturally contains:
- a visible slope;
- live weeds;

observe whether the corresponding loss/load indicators react.

This is useful but not mandatory for version promotion.

### T7 — Courseplay
If Courseplay is part of normal play:
- run one short harvesting pass;
- observe actual speed;
- RHM recommended speed;
- process load/loss;
- cutter/turn-on state.

Pass:
- no controller fight;
- no stale motor speed cap after Courseplay stops/turns;
- no inability to resume manual control.

### T8 — Harvest History
Open the new Shift+J interface.

Verify:
- current trip updates;
- combine appears in fleet;
- field/crop identity is plausible;
- no GUI/input conflict.

Known static caveat:
historical loss percentage/reason attribution has an accounting defect. Do not
use exact displayed percentage as the physics promotion gate.

### T9 — save
Save normally.

Pass:
- no RHM XML/schema/setXMLBool error;
- `realisticHarvestingData.xml` is written;
- no save-time Lua error.

### T10 — reload
Reload the same save.

Confirm:
- combine calibration remains;
- target load remains what was saved;
- active/current history persists;
- RHM global settings persist;
- no duplicate trip/fleet state;
- no RHM error.

If T1-T10 pass, promote 1.6.2 for the user's single-player/trusted stack.

# Focused follow-up tests — not update blockers

## F1 — direct motor speed-limit coexistence
Only if a speed-cap anomaly appears.

Instrument/observe another owner that writes the motor-level speed cap while RHM
is active, then stop harvesting.

Question:
does RHM's `setSpeedLimit(math.huge)` release erase the other owner's cap?

If no anomaly is observed in normal MR/RMS/Courseplay operation, do not add RC
code.

## F2 — wide-header weed sampling performance
Large header + weedy field.

Measure frame time/CPU around active weed sampling.

Gate:
only investigate optimization if measurable.

## F3 — old 88% vs new 80% calibration
Controlled same field/machine/crop runs:
- target 88%;
- target 80%.

Compare:
- t/h;
- engine/process utilization;
- speed;
- loss.

Purpose:
understand the intentional new calibration, not detect compatibility.

## F4 — moisture provider semantics
Controlled case with known external object moisture and positional soil
moisture.

Confirm which branch RHM chooses and whether its fallback transformation is
appropriate.

Only design a provider clarification if the target stack produces a real
semantic mismatch.

## F5 — Harvest History accounting
Controlled known physical RHM loss.

Compare:
- gross liters before RHM subtraction;
- actual retained tank liters;
- RHM lost liters;
- displayed trip loss percentage;
- reason attribution.

Expected static defect:
history percentage understates the true RHM physical percentage and can assign
some physical lost volume to wear.

This should become an upstream bug report/fix, not RC compensation.

## F6 — FarmKit Straw Refeed
Only resume when that feature is actively used.

Question:
does re-fed straw/material add processing demand in RHM?

Current API has no external feed-flow injection contract.

Do not implement through private RHM fields.

# Dedicated-server gate

Do not infer dedicated parity from single-player.

Wait for upstream issue #67 or reproduce separately.

Minimum dedicated test:
- player-controlled grain combine;
- forage harvester;
- load/header/load-output telemetry;
- current target/recommended speed;
- client/server trip history;
- JIP;
- settings authority;
- save/reload.

Until then:
**single-player/trusted stack approved; dedicated server pending.**
