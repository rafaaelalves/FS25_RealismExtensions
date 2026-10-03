# Reifenverschleiss integration opportunities

## Ownership baseline

### Reifen should own
- persistent tire/track/roller wear state;
- wear accumulation curves;
- wear-dependent visual tread state;
- permanent structural tread-radius loss;
- replacement/service price policy.

### MR should own
- healthy/base tire-ground friction;
- dynamic traction/load response;
- rolling resistance;
- baseline drivetrain behavior.

### Mud should own
- local soil wetness/mud state;
- transient sink/pressure radius;
- mud resistance/stuck behavior;
- mud visual dirt state before Reifen's wear cap.

### RMS should own
- selected drivetrain/2WD/4WD state;
- mechanical failures/wear in its domain.

### RC should own
translation/arbitration only when those owners overlap.

### RE should own
persistent terrain geometry/history/recovery, not tire wear.

## 1. Common WheelEligibility contract

Mud TirePressure and Reifen tire wear independently suffer from the same semantic question:
"Does this GIANTS WheelPhysics object represent a pneumatic tire?"

Reifen currently treats almost every non-crawler wheel as a tire wear object.
Mud currently injects tire pressure broadly by Wheels specialization.

A normalized shared classifier is justified:

```
WheelEligibility {
    class = PNEUMATIC | SOLID | CRAWLER_MEMBER | ROLLER | HELPER | UNKNOWN
    confidence
    source
}
```

Priority:
1. explicit mod/vehicle metadata;
2. GIANTS structural/visual tire metadata;
3. conservative heuristics;
4. UNKNOWN preserves owner-mod behavior unless explicitly configured.

This can be an RC provider/utility without making RC own wear or pressure formulas.

## 2. Reifen + MR friction

Already implemented correctly in MRTireWear:
- observe Reifen wear state/curve;
- convert it to a relative non-boosting degradation;
- apply after MR's healthy composed friction;
- suppress Reifen's absolute final ownership.

Do not reproduce Reifen's wear accumulation formula.

## 3. Reifen + Mud radius

Existing ownership should remain:
- Reifen worn radius = structural baseline;
- Mud pressure/sink radius = transient response.

Prefer explicit named state (`rvRoundPhysicalRadius`) over guessing from whichever radius field happens to be smallest/largest.

## 4. Reifen + Mud local wetness

New integration opportunity.

Reifen currently reads global GIANTS wetness.
Mud owns local persistent wetness.

A bridge can scope Reifen's own ground/wear query so:
- Reifen formulas remain owner code;
- wetness input is replaced with normalized local wetness when available;
- fallback remains vanilla/global.

This is analogous to the already successful MudRMS pattern.

Before implementation, cross-audit against MoistureSystem is required so local wetness has one explicit provenance rather than Mud and MoistureSystem both being multiplied/overwritten independently.

## 5. Reifen FORCE-WEAR + RMS/MR drivetrain state

This audit reopens the earlier "no RMSTireWear bridge needed" conclusion for one narrow new reason.

Reifen FORCE-WEAR:
- determines traction wheels from GIANTS differential topology;
- caches differential wheel torque shares.

MRRMS:
- dynamically toggles MR `mrIsDriven` wheel flags for RMS 2WD/4WD/AUTO;
- does not rebuild the GIANTS differential graph.

Potential mismatch:
a front axle currently disengaged by RMS can still receive Reifen longitudinal force wear.

Preferred solution if runtime confirms:
- provide current effective driven-wheel eligibility/share to Reifen's FORCE channel only;
- do not make RMS own tire wear;
- invalidate/update Reifen share cache only on drivetrain state changes.

This would be a genuine RC integration.

## 6. Reifen + MR/RMS speed/brake ownership

EWFS/roller systems write:
- brake force;
- max forward speed;
- cruise speed;
- acceleration/torque gates.

These can collide with mechanical failure or drivetrain control mods.

RC should not patch unless a real overlap appears, but ModMixer/audit should watch:
- `Motorized.startMotor/stopMotor`;
- `WheelsUtil.updateWheelsPhysics/updateWheelPhysics`;
- `setVehicleProps`;
- `setWheelShapeProps`;
- `AIVehicleUtil.drive*`;
- `motor.maxForwardSpeed`;
- `motor.brakeForce`.

Long term, EWFS should become optional/separable rather than forcing compatibility bridges for a feature ancillary to wear.

## 7. Reifen + RE ContactFootprint

Useful Reifen facts:
- first-class crawler grouping;
- rubber/steel classification;
- member wheel sets;
- side/signature;
- roller classification.

RE should learn from grouping architecture but not depend on Reifen internals for core terrain physics.

If a normalized RC/RE provider already exposes crawler grouping, Reifen and RE could both consume the same structural classification independently.

## 8. Workshop / maintenance integration

RMS or future maintenance systems may also own service UX/economy.

Do not merge all maintenance just because both have a workshop.

Only integrate if:
- one service operation should logically replace/reset both states;
- UI double-entry is materially confusing;
- price/state authority is clearly defined.

Native repaint should not silently be treated as running-gear maintenance.

## 9. Hotfix policy

Potential owner-mod fixes are acceptable only as explicit exceptions:
- `ReifenHotfix_RuntimeDeletionGuard`;
- `ReifenHotfix_WorkshopMpAuthority`;
- `ReifenHotfix_DefaultLifetime`;
- etc.

Each must:
- exact/version/contract gate;
- source-shape verify;
- report ACTIVE / NOT_REQUIRED / UNSUPPORTED;
- fail closed on unknown upstream;
- have a harness;
- avoid hiding inside MRTireWear/MRMud integration.

## 10. Provider state worth exposing

A future normalized state can expose without transferring ownership:
- eligible running-gear kind;
- current wear 0..1;
- per-channel wear if diagnostics require it;
- worn structural radius;
- crawler rubber/steel classification;
- roller wear;
- effective driven-wheel provenance;
- wetness provenance used by wear;
- wear owner/version/confidence.

RE should normally need only structural radius/running-gear identity, not Reifen's full wear internals.
