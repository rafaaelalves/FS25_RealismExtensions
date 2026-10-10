# PTO V1.5 — read-only inspection + conservative gear-family contract

Date: 2026-10-09. Reconciles prior PTO HUD/AI work, standalone inspector and sprayer incident. Scope: RE PTO only. No changes to terrain, RC, MR, RMS.

**Problem:** RE interpreted any `spec_powerConsumer.ptoRpm` value as an external 540/1000 gearbox family. MR sets the AEON5200/Vantage4300 load value to 500; other sprayers report 340/400. Genuine mechanic PTO may be present even when the nominal family is not encoded in that field; conversely non-PTO draft tools may have a power consumer.

**Implemented:**
1. Actual `inputPowerTakeOffs` or independently evidenced implement profile is required for PTO consumer identification; raw `ptoRpm` alone is not enough. Game-model exceptions can be added only after source evidence.
2. `requiredShaftRpm` retains raw unique demand (legacy API), `requiredGearboxFamilyRpm` exposes the nominal family only if all attached PTO consumers are resolved to one family. Native 540/1000 values with mechanical input are conservative **inferred** families, not OEM certainty. Other RPM values remain unknown. Conflicting raw demands alone do **not** prove incompatible physical gears.
3. `gearCompatibility=COMPATIBLE|INCOMPATIBLE|UNKNOWN`; `mismatch=true` only for positively incompatible nominal family or conflicting evidenced families. A connected PTO implement with unknown family appears as a `?` after nominal mode, not a red false alert. This is **not a guarantee of safe operation**.
4. AI changes gear only with resolved `requiredGearboxFamilyRpm`; no guessing 500→540. Existing engaged shaft interlock, manual mode and saved operator preference stay as before.
5. `rePTOInspect` logs one on-demand snapshot including root state, input PTO count, raw / live consumer RPM, MR governor floors and connected implements. No per-frame telemetry, no new global drivetrain hooks and no new physics.
6. HUD adds live `≈RPM` kinematic estimate and event-only worker logs (prior V1.5), plus unknown indicator.

**Test fixtures:** sprayers 340/400/500, non-PTO generic draft consumer, conflicting 540+1000 gears, 750/900/1300/1400 (no rounding), guarded cyclic graphs, AI safety/mode restore, HUD unknown and normalized RPM, console snapshot. CI builds the ZIP. In-game investigation remains observational; this patch does **not claim** to resolve any remaining mechanical sprayer turn-on issue or baler governor difference.

**Risks:** A mod with no populated native PTO input table and no explicit profile can be under-classified. Inspect actual inputs for each unusual machine before adding a model-specific profile; the user-visible physical PTO shaft is evidence but may not correspond to the runtime specialization. Do not map all 500 values to 540 or infer 1000 via nearest neighbor. No automatic work penalties or simulated spraying behavior are introduced here.

After CI, one brief inspector capture before and after starting a baler will distinguish RE consumer ownership from MR's additional PTO minimum RPM. Unlike continuous telemetry, this can be performed later without redundant save/load tests.
