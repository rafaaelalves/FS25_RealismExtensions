# Gameplay blocker: SHALLOW_DISC repair stagnates and seeder gets stuck

Source: user gameplay report plus uploaded `log(20261012-104905).txt`, `ModMixer(20261012-104905).log`.
Runtime RE `feat/terrain-pto-integration-2026-10-09@3e3554a`, RC `main@ad7461f`; NOT changes in this branch.

## Acceptance: FAIL

User visually observed continuous, deep harvester ruts; the first cultivator pass reduced their depth but successive passes scarcely improved the field. Attempting to sow led to immobilization and further excavation; S780 helped tow Fiat and active Avatar. This is a practical failure of the harvest–cultivate–seed cycle, not merely numeric calibration. User mentioned a separate possible seeder incompatibility. The log cannot assign cause of immobilization to RE alone (MR, Mud, implement/attachment specs, and already damaged ground all participate). An active towed seeder is not proof of planting while towed.

## Observations

- RE restored 12,258 spatial history cells. Savegame2 successfully saved 12,103 at 07:43:06 and 12,503 at 07:48:40 (Game saved successfully at 07:48:43). Unlike prior no-save sessions, damage may now be persisted; preserve the existing save and pristine backup separately.
- 4,109 physically worked SHALLOW_DISC area callbacks; 22 completed TerrainPass IDs (not 22 full identical-rut passes); 997 changed and 3,112 repeat GIANTS work areas. Those changed/repeat counters are not direct physical repair success.
- TARGET scheduled 21,553, applied 3,734; noOp 2,607, improved 965, worsened 115, stalled 1,142, completed 270. Writer zeroProbe 2,615, raised 1,010, lowered 109, failedJobs 0. Roughly 70% of commands were no-op by controller and a similar fraction had no measured center movement. `SHALLOW_DISC` max target amount=0.85 and maxStructuralPulses=4 by current profile.
- Only 419 logical RE history cells were reduced, sum of 5.230m of logical debt across applications (NOT a measurement of total unique crater recovery). `maxAbs=0.8073->0.7918m` and `patchMaxResidual=0.854m` are reference-plane relative; NOT proven 80cm-high physical ruts.
- Rut accepts climbed from 1,410 at ~07:39–07:42 to 3,279 by 07:48, with no additional recovery TARGET. Entire-session writer owners: Fiat 180-90 DT=2,275; MR Avatar 12.25 SD=440; S780=348; MR 980=216. The specific tow and seeding contact times/coordinates are not separately identified.
- Soil response writes: FIELD_SOFT=2,973 / 3,279 accepts, which is why soft disturbed field dominates. Samples show wetness 1.00 at 07:26, 0.25 at 07:40, and 0.76 with longitudinal slip 1.0 at the end: local wetness is NOT spatially uniform. Instantaneous Mud sink peaked at 0.360m and RE modeled rut cap at 0.180m; do not conflate these metrics or attribute the peaks to the same contact.
- TerrainPerf recovery=4,109 avg 0.4511ms total 1,853.4ms. Can optimize separately, but gameplay correctness first.
- ModMixer hook chain 59 targets, unknown 0, healthy. New FS25_SeedSelect HUD resource load errors concatenate the SeedSelect directory with absolute paths for Estancia Sao Carlos fill-type PNGs; these icon errors do not establish drivetrain/hitch failure. Newly present ManualConnectorSystem and attachImplementsManually ZIPs in the folder are not evidence that they were loaded.

## Current engineering gates

1. R1 fixed-reference vs native TARGET: record same-center actual pre/post heights, unchanged center, command target, reference drift and queue drift. Existing PR #42 proves reference bias for parallel/wide ruts and natural curvature in synthetic tests.
2. Geolocated RE rut writes by vehicle/root under actual wetness, slip, wheel pressure/load, historical depth and commanded delta. Match to recovery x/z in a subsequent controlled dataset.
3. Diagnose why repeats do not help: legitimate SHALLOW_DISC depth capability vs premature history debt clearing, cooldown, event order, centered TARGET brush unable to move and reference contamination. No blind escalation of amount/pulses: previous additive RAISE caused massive mounds.
4. Test possible double sink: Mud effective radius shrink plus physical RE heightmap lowering at the same contact can potentially amplify mobility loss. This is still a hypothesis, not a confirmed bug. Preserve Mud/MR ownership.
5. Future sowing work-area proof: actual planting while towed and towing/traction physics remain undetermined from available counters.

## Implemented on this branch

Read-only RecoveryTargetOutcome classifier, 12 bounded TerrainTargetSample traces, periodic TerrainTargetOutcome counters and up to 18 geolocated TerrainRutSample traces (three per writer). No change to writer physics, bearing, R1 decisions, tool profile, PTO or production main. CI harness classifies fixed-target progress, unchanged center, reference drift and queue drift. A green CI does NOT validate in-game behavior.

## Safe workflow

Retain backups; do not continue the destructive save merely to generate logs. Disabling RE terrain stops *future* writing, not existing modified heightmap. Validate a correction only on a duplicate save after offline tests and code review.