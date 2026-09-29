# Real Physics Tire Wear / Reifenverschleiss audit

Audited package: `1.2.2.67` supplied by the user.

Status: **CANDIDATE_ABSORB BY LAYER — do not remove external mod yet**

## Functional inventory

The current system contains several separable products:

1. **wear state**
   - per wheel / track / running-gear persistence;
   - distance wear;
   - slip wear;
   - field-work/time wear;
   - load/force effects;
   - ground/weather factors;
   - AI/Courseplay/AutoDrive coverage.

2. **physical consequences**
   - wear-dependent traction;
   - round-tire structural/rolling-radius reduction;
   - AI cruise-speed mitigation;
   - tracked-vehicle max-speed penalties.

3. **visual wear**
   - round-tire tread/profile visual loss;
   - rubber/steel track profile wear;
   - custom shader parameters/material replacement;
   - synchronization between visual tire radius and physical radius.

4. **economy/workshop**
   - replacement pricing;
   - tire vs running-gear component replacement;
   - reference lifetime settings;
   - networked purchase event.

5. **startup/AI workaround**
   - electronic immobilizer used to stabilize initialization when AI/CP/AD bypass expected startup sequencing.

## What is attractive to RealismExtensions

### Wear state
Very attractive in concept. Tire wear is a persistent physical phenomenon and can become an authoritative input for:
- RC traction composition;
- terrain footprint/deformation;
- maintenance/economy;
- unified HUD.

A clean-room implementation could be simpler because the target stack already exposes better specialist state than a standalone universal mod must discover itself.

### Physical consequences
Traction should **not** be applied directly by Extensions if MR/Mud are active. Instead:
```text
Extensions TireWear state
        ↓
RealismCompatibility
        ↓
MR/Mud final traction / structural-radius composition
```

This removes the current late friction-owner collision.

### Workshop/economy
Potentially worth absorbing later because it gives persistent wear a complete gameplay loop. It is mostly logic/UI, not asset-bound.

## Main blocker: visuals

The package has a substantial custom visual pipeline:
- custom vehicle/track shader XML/GSL;
- material-holder I3Ds;
- texture-map copying/rebinding;
- custom shader parameters;
- multiple tracked-vehicle special cases;
- physical tire-radius synchronization to the visual model.

This is not a trivial icon/texture problem. It is a dedicated shader/material project.

The public author documentation also notes that special third-party vehicles may require their I3Ds, UV masks/mappings/shapes and XMLs to support correctly. That reinforces that visual compatibility is the expensive part.

## Governance

The supplied package does not contain a clear reusable-code license. Treat it as source evidence, not reusable source.

Public project history also discusses prior accidental inclusion of foreign files and subsequent recreation of shader files, which is another reason to keep our implementation clean-room and provenance explicit.

## Recommendation

Split the decision:
- **TireWearState:** strong future candidate to absorb.
- **RC traction/radius consequence:** integrate with that future state.
- **Workshop/economy:** candidate after state model.
- **VisualWear:** research project; keep Reifen external until a clean-room shader/material approach reaches acceptable parity.
- **Immobilizer:** do not automatically reproduce; first determine whether our own event/init architecture actually needs it.

Do not attempt a half-migration that runs our wear state and Reifen wear state simultaneously.
