# Terrain evolution plan

Updated: 2026-10-02

Status: canonical terrain-algorithm plan for the next TerrainDeformation / TerrainRecovery development phase.

**Integrated stabilization plan (2026-10-08):** [STABILIZATION_ROADMAP_2026-10-08.md](STABILIZATION_ROADMAP_2026-10-08.md). This also tracks wide/narrow/dual/triple/track contact coverage, difficulty-balance hypotheses and recovery-winch audit gates. No new difficulty coefficient has been approved.

This document starts from the first runtime-validated TerrainRecovery baseline. The goal is no longer to prove that recovery can work; the goal is to evolve it into a coherent soil-interaction system without losing monotonic convergence, ownership boundaries or observability.

## Baseline that must be preserved

Validated in runtime on commit `94a10476e45b8fc4ebf14f7a25e6cd7440c92509`:
- repeated physical cultivator work continues recovery even when `realArea=0`;
- persistent RE rut generation is suppressed while the soil-working operation is physically active;
- machine-style TerrainDeformation SMOOTH converges usefully instead of progressively damaging the field;
- Koralin 9-840 and MR Mach Till 412 both entered the same recovery pipeline successfully;
- stable active-work windows repeatedly reached `rutAccepted=0` with implement/root writer window delta `(+0)`;
- recovery still needs calibration and richer physical semantics.

Any future feature must retain regression coverage for this baseline.

---

# Phase A — make recovery measurable in physical passes

## A1. TerrainPassTracker

### Problem
Current recovery eligibility still includes a time-based stamp cooldown. A slowly moving implement can keep a location under the tool longer than a faster one, so the amount of smoothing can still depend partly on update/cooldown timing rather than on the number of physical passes.

### Goal
Make a physical work pass a first-class domain event.

Concept:
```text
implement begins a continuous physical work pass
        -> passId N
cells/work-footprint samples touched by pass N
        -> one controlled recovery dose for pass N
implement stops/lifts/leaves continuous operation
        -> pass N ends
next physical pass
        -> passId N+1
```

### Responsibilities
- detect pass start/end from WorkContext physical state;
- assign monotonically increasing runtime `passId`;
- measure pass distance, duration, mean/min/max speed;
- expose per-pass cell/footprint eligibility;
- prevent frame rate and short cooldown timing from changing nominal dose;
- remain server-authoritative.

### Must not own
- smoothing strength;
- implement-type capability;
- terrain-writing API;
- wheel traction/sink physics.

### Acceptance
- same implement + same path + materially different frame rate yields equivalent pass dose;
- reasonable speed variation does not multiply recovery simply because the tool stays over a cell longer;
- second/third physical passes remain independently eligible.

---

## A2. RecoveryPassSummary

### Problem
Five-second TerrainWindow telemetry solved causal debugging, but calibration is naturally expressed in passes, not arbitrary time windows.

### Goal
Emit one causal summary per completed physical pass.

Candidate fields:
```text
RecoveryPass #N
implement/root
controlMode
distance / duration / avgSpeed
workArea width/depth
firstWork / repeatWork
coverage samples
smooth brushes / callbacks
roughness improved / worsened / neutral
roughness before/after distribution
history reconciled
rutBlocked
rutAcceptedWhileActive
writer counts while active
```

### Hard invariant
`rutAcceptedWhileActive == 0` for the protected tractor + active soil-working combination.

A non-zero value is a direct bug signal and should not require inference from a five-second mixed window.

### Acceptance
- pass summaries reconcile with cumulative telemetry;
- writer attribution is explicit for active work;
- tests cover first pass, repeated pass and transition/lifted cases.

---

# Phase B — improve the physical recovery metric

## B1. Slope-aware local roughness

### Problem
Simple local relief can confuse legitimate terrain grade/slope with surface roughness.

### Goal
Fit a local reference plane and measure height residuals relative to that plane.

Concept:
```text
local terrain ~= horizontal world plane
local reference: y = ax + bz + c
roughness = residual structure around that local grade
```

This should distinguish:
- natural field slope: not roughness;
- rut/depression: roughness;
- berm/ridge: roughness;
- isolated hole: roughness.

### Initial use
Measurement only. Do not immediately change TerrainDeformation behavior when this metric lands.

### Acceptance
- a smooth sloped test surface reports low roughness;
- an equivalent slope with a rut reports materially higher roughness;
- before/after recovery metrics remain directionally stable.

---

## B2. Roughness distributions

Track at least robust pass-level values such as:
- median/P50;
- P90 or P95;
- maximum bounded outlier;
- fraction of samples above recovery threshold.

Purpose: distinguish “most of the field is fixed but one hole remains” from “the whole strip is moderately rough.”

---

## B3. Target roughness / convergence floor

### Problem
Unlimited smoothing conceptually tends toward mathematical flatness. Agricultural tools should converge toward a tool-appropriate surface condition, not an infinitely smooth plane.

### Goal
Each recovery profile defines a target residual roughness range.

Behavior:
```text
roughness >> target -> meaningful recovery
roughness near target -> reduced recovery
roughness <= target -> no TerrainDeformation job
```

### Benefits
- natural diminishing returns;
- fewer neutral jobs;
- prevents needless repeated smoothing;
- creates a physical distinction between tool categories.

### Acceptance
Repeated passes converge toward a stable floor rather than continuing to alter already-acceptable terrain.

---

## B4. Severity-adaptive recovery

### Goal
Recovery dose responds to measured defect severity while remaining bounded.

A severe rut may justify a stronger operation than a nearly finished surface, but the adaptation must preserve monotonic convergence and avoid overshoot.

Do not implement this as a global “strength multiplier” before slope-aware roughness and target roughness exist.

---

# Phase C — separate work geometry from recovery policy

## C1. TerrainWorkFootprint

### Problem
Coverage construction currently lives inside TerrainRecovery.

### Goal
A reusable component converts WorkContext geometry into physical coverage samples/nodes.

Input:
- workArea geometry;
- tool dimensions;
- direction;
- optional profile requirements.

Output:
- coverage nodes/strips;
- local coordinates;
- width/depth occupancy;
- sampling density.

This follows the architectural lesson from TerraFarm: machine state, work-area geometry and terrain operation should be separate layers.

### Acceptance
Koralin and Mach Till coverage remains equivalent to current validated behavior before tool-specific policy is introduced.

---

## C2. TerrainRecoveryProfile

### Goal
Describe what a soil-working tool is physically capable of doing, independently of its exact model name.

Candidate properties:
- surface repair capability;
- deep-rut repair capability;
- finish quality / target roughness;
- recovery dose bounds;
- useful working-depth class;
- direction sensitivity;
- moisture sensitivity.

Candidate families:
- cultivator;
- disc harrow / high-speed disc;
- subsoiler / ripper;
- plow;
- roller;
- future specialized grading/leveling tools.

The first implementation should prefer specialization/work-area semantics and explicit configuration over hard-coded individual vehicle names.

### Important
Koralin and Mach Till currently use the same generic recovery policy. Their observed runtime differences should be treated as baseline geometry/terrain-condition effects until profiles deliberately model a physical distinction.

---

## C3. Operation direction vs rut direction — later calibration

SpatialHistory can eventually retain dominant rut/shear direction.

Recovery may then distinguish:
- parallel work;
- oblique work;
- transverse work.

This is a later feature, not a prerequisite for PassTracker/Profile architecture.

---

## C4. Moisture-conditioned recovery — later calibration

Consume Mud/RC local soil state; do not create a competing wetness model.

Possible behavior:
- excessively wet/plastic soil -> poor geometric repair / smearing-like limitation;
- suitable moisture -> efficient recovery;
- very hard/dry conditions -> different bounded effectiveness.

RE owns the persistent geometric consequence only. Agronomic compaction penalties remain with the specialist owner.

---

# Phase D — contact-footprint model for wheels and tracks

The current ordinary-wheel model is not sufficient for all vehicle contact systems.

## D1. ContactFootprint abstraction

Create one contact representation consumed by TerrainDeformation rather than assuming every contact is a conventional pneumatic wheel.

Candidate source types:
- `SINGLE_TIRE`;
- `DUAL_TIRE` / twin;
- `WIDE_FLOTATION_TIRE`;
- `IMPLEMENT_WHEEL`;
- `CRAWLER` / native track;
- future grouped/bogie contact if required.

Common normalized outputs should include:
- source type;
- center/contact frame;
- support width;
- effective contact length;
- contact area;
- load;
- effective ground pressure;
- orientation;
- longitudinal/lateral extent.

---

## D2. Conventional single pneumatic tires

Preserve the validated pressure/load/support-width model for normal wheel contexts.

Regression requirement: existing ordinary-wheel rut behavior must not materially change simply because ContactFootprint was extracted.

---

## D3. Dual/twin wheels

Duals must not be treated accidentally as one giant tire or two unrelated contacts that double-count load/deformation.

Research/implementation goals:
- identify dual group membership from game/MR wheel configuration;
- aggregate or distribute load consistently;
- preserve physical gap/combined support width where useful;
- avoid duplicate persistent rut volume;
- compare single vs dual ground-pressure consequence under equal axle load.

---

## D4. Wide/flotation tires

Ensure wide support width, pressure and load produce plausible broad/shallow persistent geometry without relying on arbitrary width caps intended for ordinary tires.

---

## D5. Implement/support/transport wheels

Distinguish implement wheels from tractor propulsion wheels where semantics matter.

Important ordering problem:
- wheel contact before soil-working elements may be repaired/overwritten by the operation;
- wheel contact after the working elements may legitimately leave a post-work shallow track/compaction signature.

Do not globally disable implement-wheel deformation.

WorkOperationContext / WorkFootprint should eventually expose enough relative geometry to classify wheel position/order.

---

# Phase E — native crawler / track support

## E1. First-class GIANTS crawler model

Do not model native crawler assemblies as ordinary wheels.

Use `spec_crawlers.crawlers` as the first-class entity.

Available native structure includes:
- crawler grouping;
- constituent wheels;
- `trackWidth`;
- left/right identity;
- linked front/back wheel references/nodes;
- geometry from which effective contact length can be derived.

### Crawler footprint
For each crawler unit:
- group constituent wheels once;
- aggregate grounded load;
- derive track center/orientation;
- use actual `trackWidth`;
- derive effective ground-contact length from linked wheel geometry;
- area ~= trackWidth * effective contact length;
- pressure = aggregate load / effective contact area;
- produce an elongated strip/capsule footprint, not independent circular tire brushes.

Quadtrac-style machines should therefore produce four track patches, not a set of pseudo-tires.

### Critical guard
Constituent wheels mapped to a crawler must not also be processed independently by the ordinary-wheel path.

### Acceptance
- no generic `Wheel shape not found for getContactPoint` path is required for native crawler deformation;
- crawler telemetry identifies sourceType=CRAWLER;
- contact area/pressure are physically plausible relative to conventional tires;
- equal-machine test demonstrates broader/shallow geometry instead of giant-tire artifacts.

---

# Phase F — player, GIANTS AI, Courseplay and True AI Tracks

## F1. Driver-agnostic terrain physics

Terrain deformation/recovery must depend on physical machine state, not on who controls it.

Record explicit control mode:
- `PLAYER`;
- `GIANTS_AI`;
- `COURSEPLAY`;
- other supported controllers if relevant.

Acceptance scenario:
same machine + same implement + similar path/speed/soil -> comparable persistent result regardless of control mode.

---

## F2. External True AI Tracks / FS25_aiTracks audit and ownership decision

Background:
- True AI Tracks was an early precedent for applying track/deformation behavior to AI and implement wheels.
- The user intentionally disabled it during earlier RE isolation tests to determine how much of its role RE could absorb.
- Presence in the mods directory is not evidence that it is active in a given save.
- RE should not require True AI Tracks for native crawler support or AI parity.

Audit questions:
1. What does current `FS25_aiTracks` still own?
   - visual tire tracks?
   - terrain/ground writes?
   - AI-specific wheel processing?
   - implement-wheel processing?
   - crawler behavior?
2. Which responsibilities are already superseded by RE?
3. Can remaining useful visual behavior coexist without duplicate physical deformation?
4. Should RC detect/suppress overlapping writes?
5. Can the external mod be retired entirely in the target stack once RE reaches parity?

Possible outcomes:
- **retire**: RE fully supersedes the needed behavior;
- **coexist**: keep only non-overlapping visual behavior;
- **bridge/suppress overlap**: RC coordinates explicit ownership;
- **retain**: if it owns a valuable phenomenon RE deliberately does not implement.

No outcome should be assumed before source/runtime audit.

---

# Phase G — autonomous / world recovery without direct player action

Terrain recovery must not depend on the player personally driving over every damaged location.

This is separate from control-mode parity. PLAYER/GIANTS_AI/COURSEPLAY parity answers *who controls an active machine*. Autonomous/world recovery answers *how the world evolves when the player is not performing the repair at all*.

## G1. RecoveryAgent / RecoveryCause contract

Every non-wheel recovery action should identify its cause:

- `PLAYER_WORK`;
- `NPC_FARM_WORK`;
- `NATURAL_RELAXATION`;
- `PUBLIC_MAINTENANCE`;
- `EXTERNAL_TERRAIN_EDIT`;
- future scripted/world event if justified.

The physical TerrainOperation layer may be shared, but policy, target roughness, cadence and eligible zones differ by cause.

Telemetry/history should preserve recovery cause so a changed field can be explained later.

---

## G2. Natural relaxation / environmental recovery

### Goal
Allow some terrain defects to soften gradually without an explicit machine pass.

This must be conservative. Natural processes should not magically erase deep vehicle ruts overnight.

Candidate inputs:
- elapsed game time;
- local wetness/moisture history from specialist state where available;
- freeze/thaw if a reliable source exists;
- precipitation/weather exposure;
- surface/soil class;
- defect severity;
- whether the cell is actively trafficked.

Candidate behavior:
- tiny/shallow irregularities relax faster;
- deep compacted ruts relax very slowly or require mechanical work;
- repeated wet/dry or freeze/thaw cycles may increase relaxation if evidence supports it;
- hard/public surfaces should not use the agricultural natural-relaxation model.

### Architecture
Prefer a sparse scheduled process over continuous per-cell updates:
- SpatialHistory marks cells eligible for future natural relaxation;
- a bounded scheduler visits a small budget of eligible cells;
- physical state is rechecked before writing;
- recovery is applied incrementally and attributed to `NATURAL_RELAXATION`.

### Persistence / offline time
Store stable timestamps/state needed to evaluate elapsed in-game time after save/load. Do not simulate every missed frame while the save was closed.

### Acceptance
- shallow damage visibly softens over meaningful in-game time;
- severe damage remains until enough time or proper work occurs;
- no frame-rate dependence;
- bounded CPU cost independent of total historical map size.

---

## G3. NPC / other-farmer agricultural recovery

### Goal
Fields not owned/worked directly by the player should not remain permanently scarred merely because RE only observes the player.

Possible data sources:
- GIANTS NPC/contract field-work state;
- actual AI-controlled machines when spawned/working;
- field state transitions when GIANTS simulates work without a fully physical machine;
- future integration with NPC gameplay mods if present.

### Preferred hierarchy
1. If a real AI/NPC vehicle is physically working the field, use the normal WorkContext/PassTracker/RecoveryProfile pipeline.
2. If GIANTS advances an NPC field state abstractly without a physical machine, use a bounded **abstract field recovery event** based on the agricultural operation that occurred.
3. Never invent detailed wheel tracks for an NPC machine that was never physically simulated.

### Policy
- work only inside the relevant field/property;
- use tool/operation family where known;
- target the same recovery profile semantics as equivalent player work;
- avoid instant whole-field flattening;
- preserve severe anomalies that the simulated operation should not plausibly fix.

### Acceptance
NPC-owned fields can recover from persistent RE damage across normal world simulation without player intervention.

---

## G4. Public / municipal maintenance

### Goal
Public infrastructure should not accumulate permanent damage forever simply because no player-owned implement repairs it.

Candidate zones:
- public roads/road shoulders if terrain deformation is allowed there;
- municipal dirt/gravel access paths;
- public yards/communal areas;
- map-defined service areas;
- other non-field public terrain explicitly classified as maintainable.

### Policy model
Create a `MaintenanceZone` / ownership mask:
- PRIVATE_FIELD;
- PLAYER_PROPERTY;
- NPC_FIELD;
- PUBLIC_MAINTAINED;
- NATURAL_UNMAINTAINED;
- EXCLUDED.

Public maintenance should be periodic/event-driven, not constant smoothing under the player.

Possible behavior:
- small public-road defects repaired on a schedule;
- severe damage takes longer or waits for a maintenance cycle;
- maintenance has its own target roughness/profile;
- public maintenance must never spill into adjacent private fields.

### Municipality simulation options
Start abstract:
- scheduled maintenance event + bounded terrain operation.

Later, optionally:
- visible service vehicle / grader behavior if a suitable system exists.

The abstract version should come first; visible municipal AI is a presentation/gameplay feature, not a prerequisite for correct world persistence.

---

## G5. Recovery scheduler and spatial budget

Autonomous recovery needs a world-level scheduler that is deliberately different from per-frame vehicle processing.

Candidate responsibilities:
- maintain sparse priority queues of recoverable historical cells/regions;
- choose eligible work by recovery cause and zone;
- enforce per-tick/per-minute physical TerrainDeformation budgets;
- avoid touching cells near an active player operation if that creates conflicts;
- coalesce nearby maintenance work;
- save only stable scheduling state when necessary.

Priority can consider:
- age of damage;
- severity;
- ownership/zone;
- scheduled field operation;
- public maintenance cycle;
- natural-relaxation eligibility.

### Hard requirement
World recovery cost must scale with **active/eligible damaged regions**, not map area.

---

## G6. World recovery observability

Add aggregate/pass/event telemetry such as:
```text
WorldRecovery |
cause=NATURAL_RELAXATION
regions=...
cells=...
jobs=...
improved=...
worsened=...
skippedActive=...
budgetUsed=...
```

and:
```text
MaintenanceEvent |
zone=PUBLIC_MAINTAINED
reason=scheduled
roughnessBefore=...
roughnessAfter=...
```

This is essential because autonomous recovery may happen outside the player's camera.

---

## G7. Recovery ownership safety rules

- do not let autonomous systems silently undo an active player-created experiment/worksite immediately;
- do not apply public maintenance inside private/NPC fields unless the zone explicitly overlaps by map design;
- do not use natural relaxation to replace proper agricultural repair for severe damage;
- do not let multiple recovery agents process the same region simultaneously without arbitration;
- physical callbacks remain authoritative before SpatialHistory reconciliation.

---

# Phase H — external terrain edits and persistent history


## G1. Lazy physical history reconciliation

### Problem
Construction landscaping, TerraFarm or another terrain writer can modify the physical heightfield without updating RE SpatialHistory.

Possible stale state:
```text
SpatialHistory: rut depth = 8 cm
physical terrain: already manually smoothed
```

### Goal
When a historical cell becomes relevant again, compare stored state with current physical relief and reconcile stale history lazily.

Avoid a full-map scan.

### Acceptance
Manually repaired terrain does not retain phantom historical damage that distorts later recovery decisions.

---

# Phase I — SoilMassTransport redesign

Status: disabled.

Do not re-enable the old fixed-calibration berm implementation merely because recovery now works.

If resumed, redesign around measured volume and a mass ledger:

```text
LOWER physical callback
        -> observed removed/displaced volume
        -> split compacted vs transportable fraction
        -> local transport reservoir
        -> bounded RAISE targets
        -> RAISE callback actual/target
        -> adaptive realization feedback
```

Goals:
- approximately conserved transportable mass;
- no 2x over-realization;
- no central artificial ridge;
- recovery remains stable with transport enabled.

If this cannot be made robust, leave it disabled permanently. Correct recovery has priority over visible berms.

---

# Phase J — later terrain interaction research

Only after the above is stable:
- event-triggered underbody/high-centering diagnostics;
- possible chassis/underbody soil interaction;
- richer furrow/plow geometry;
- automatic/world maintenance policies;
- visual consolidation;
- crop/vegetation interaction.

Underbody deformation must not be inferred from current wheel writers; it requires its own physical contract.

---

# Recommended implementation order

1. `TerrainPassTracker`
2. `RecoveryPassSummary` + `rutAcceptedWhileActive` invariant
3. slope-aware roughness + pass-level roughness distributions
4. target roughness / convergence floor
5. severity-adaptive recovery
6. `TerrainWorkFootprint`
7. `TerrainRecoveryProfile`
8. tool-family profiles and later moisture/direction modifiers
9. `ContactFootprint` abstraction
10. single/dual/wide/implement wheel normalization
11. native `CRAWLER` footprint
12. PLAYER / GIANTS_AI / COURSEPLAY parity validation
13. True AI Tracks audit + retire/coexist/bridge decision
14. RecoveryAgent / ownership-zone contract
15. NPC/other-farmer field recovery
16. natural-relaxation scheduler
17. public/municipal maintenance scheduler
18. lazy SpatialHistory physical reconciliation
19. SoilMassTransport redesign
20. underbody/high-centering and later interaction research

## Development rule for this sequence

Do not land all items as one physics rewrite.

For each step:
- preserve the current validated recovery baseline;
- add harnesses first where possible;
- add causal telemetry before runtime calibration;
- change one physical assumption at a time;
- record runtime evidence in CURRENT_HANDOFF;
- keep branch history capability-focused rather than creating one branch per experimental version.
