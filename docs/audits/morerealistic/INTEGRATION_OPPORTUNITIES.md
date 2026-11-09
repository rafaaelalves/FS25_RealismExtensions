# MoreRealistic integration opportunities and boundaries

## Ownership baseline

### MR owns
- baseline drivetrain/transmission for MR vehicles;
- baseline tire/surface friction under the MR engine;
- rolling resistance;
- wheel load/support-width semantics;
- engine braking;
- implement draft force;
- PTO/mechanical process demand;
- mass/CoM behavior;
- converted equipment calibration.

### RC owns
Cross-mod translation/order/arbitration only:
- MR <-> Mud;
- MR <-> tire wear;
- MR <-> damage/mechanical system;
- MR <-> SoilCompaction throughput;
- MR <-> Dynamic PTO;
- future moisture/controller integrations when evidence requires them.

### RE owns
Missing persistent-world phenomena:
- physical heightfield rut creation;
- persistent terrain history;
- recovery/maintenance;
- future mass transport;
- contact-footprint abstraction where the engine/mod stack does not already provide persistent geometry.

RE should not become an alternate drivetrain/friction simulator.

## 1. MR + Mud

Existing RC MRMud work is correct in principle:
- MR = baseline friction/drivetrain/RR;
- Mud = local wetness, mud-specific sink/resistance/stuck/puncture;
- RC = composition.

New audit lesson:
- MR support width is useful physical provenance;
- Mud's private requested-sink fields must not be equated with physical terrain depth;
- future provider contracts should avoid exposing private implementation markers when normalized applied state is available.

## 2. MR + MoistureSystem + Mud

This is now a major future cross-audit.

MR exact source:
- globally wraps GIANTS ground wetness;
- imposes seasonal/night minimums;
- wheel friction and RR consume global weather wetness.

Mud:
- can provide persistent local wetness;
- also modifies global drying/wetting duration through SoilDrying.

MoistureSystem:
- provides localized/high-resolution moisture state.

An open upstream MR PR proposes direct per-wheel MoistureSystem sampling and independently fixes MR's night-damp arithmetic bug.

Integration questions:
1. Which system owns **weather climate baseline**?
2. Which owns **local soil moisture**?
3. Should MR friction/RR sample local moisture directly or through RC normalized state?
4. How should Mud local wetness and MoistureSystem local wetness coexist?
5. Can one provider expose a single source/provenance field so every consumer does not independently discover another mod?

Do not stack three moisture multipliers blindly.

## 3. MR + RE terrain deformation

MR already manipulates GIANTS terrain-displacement/work-area behavior to stop a rut-erasure/bounce loop.

RE must preserve that intention.

Recommended future contract:
- WorkContext identifies root + implement + physical work;
- MR ownership state says whether GIANTS wheel displacement has been suppressed for the implement;
- RE persistent writer is independently suppressed while the active work operation owns the same footprint;
- recovery executes from work/pass semantics rather than agricultural-state-change metrics.

## 4. MR + ContactFootprint

Useful MR inputs:
- `mrTotalWidth`;
- driven-wheel identity;
- tire type;
- crawler identity/track factor;
- wheel load;
- radius.

Do not copy MR's `mrTrackFx` as final crawler geometry.

A normalized ContactSupport structure could expose:
- base tire width;
- total support width;
- support count;
- type SINGLE/DUAL/TRIPLE/TRACK;
- load;
- structural radius;
- provenance.

## 5. MR + AI/controller systems

### GIANTS AI
MR changes AI speed/braking and keeps PTO demand visible for MR machines.

### AutoDrive
MR deliberately falls back to the previous/base central wheel-control function while AutoDrive is active, because AD's pulsed inputs interacted badly with MR heavy-vehicle control.

Global WheelPhysics remains MR.

Therefore AutoDrive behavior is a hybrid mode.

### Courseplay
Needs scenario parity testing because it may exercise GIANTS AI paths while MR control logic remains active.

### VCA / hand throttle
Current upstream has a reported VCA hand-throttle interoperability issue.

Future goal:
- expose/control **intent** through a stable motor-control contract rather than each controller patching internal motor variables.

## 6. MR + yield/process mods

MR globally changes selected default crop yields and separately models combine process demand from liters/sec.

Any mod changing yield/output later in the chain can desynchronize:
- final harvested liters;
- MR internal throughput;
- power requirement;
- speed limit.

RC's MRSoilHarvest demonstrates the correct approach:
- preserve the owner mod's exact yield result;
- correct only MR's downstream physical accounting;
- never reproduce the foreign formula.

This same pattern should be reused for future yield/weather/disease systems.

## 7. MR + mass/load mods

Because MR globally owns `Vehicle.updateMass` and spatial CoM recomposition, any mod that directly writes:
- component mass;
- component CoM;
- mounted-object mass reduction;
must be audited.

Preferred integration:
- contribute a named mass+CoM source into MR's mass model if possible;
- avoid alternating absolute `setMass`/`setCenterOfMass` ownership.

## 8. Optional owner-mod hotfixes

The user's target is a clean, coherent game stack, so narrow MR hotfixes are acceptable when worthwhile.

They must remain visibly exceptional:
- `MRHotfix_NightDampPrecedence`;
- `MRHotfix_PtoTurnOnPeak`;
- etc.

Every hotfix should carry:
- exact upstream version range;
- contract fingerprint;
- startup state ACTIVE / NOT_REQUIRED / UNSUPPORTED;
- deterministic harness;
- runtime test when physics-visible.

Do not let RC become a generic unofficial patch pack.

## 9. Suggested public/provider API direction

MR has many useful internal facts but few formal cross-mod contracts.

A future RC provider can normalize:
- MR engine present;
- converted vehicle flag;
- MR motor active;
- driven-wheel identity;
- support width;
- wheel load;
- current MR surface classification;
- baseline friction coefficient;
- dynamic friction scale;
- rolling-resistance factor;
- effective PTO ratio/domain;
- process-model identity;
- control mode/player/AI/controller provenance.

RE should depend on the normalized provider contract, not reach deeply into MR internals.
