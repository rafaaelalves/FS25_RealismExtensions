# MoreRealistic wheel, traction and mass model

## Wheel physics ownership

MR globally replaces major WheelPhysics behavior.

Important effects include:
- MR tire/ground friction tables;
- dynamic friction scaling from slip/load/surface;
- explicit rolling resistance;
- pressure/contact-support proxy;
- driven-wheel metadata;
- wheel mass estimation;
- wheel-shape rotational inertia;
- force-point relocation;
- brake/engine-brake force distribution;
- advanced spring support.

This is why Mud/Reifen/RE integrations must treat MR as the baseline wheel owner.

## Tire/support geometry

### `mrTotalWidth`

MR starts support width at the base tire width and adds the width of additional wheels.

This means dual/triple configurations are semantically represented as wider support rather than merely cosmetic wheels.

This is the source fact behind RC's MR+Mud dual support-width composition.

### Tracks/crawlers

MR assigns a default `mrTrackFx=3` for crawler tire types and uses it as an effective contact-area multiplier.

This is useful as a gameplay proxy, but not a geometric track footprint.

RE should therefore:
- consume MR crawler identity/support intent where useful;
- still construct a grouped crawler footprint from `spec_crawlers.crawlers`;
- not treat three pseudo-wheel contacts as the final physical representation.

## Ground-pressure proxy

`WheelPhysics.mrGetPressureFx(width, radius, load)` uses:

`contactPatch = width * radius * 0.53`

and approximately returns bar-equivalent pressure from wheel load/contact area.

This is not a tire carcass/contact-patch model, but it creates a coherent scalar connecting:
- support width;
- radius/track factor;
- wheel load;
- soft-ground rolling resistance.

RE pressure/contact-area work should not silently duplicate this formula. RC's normalized state can expose MR state/hints while RE keeps its own terrain-deformation model explicit.

## Rolling resistance

MR adds terrain-, wetness-, pressure- and load-sensitive rolling resistance.

Important semantics:
- soft field differs from firmer harvest-ready field;
- wetness amplifies soft-ground response;
- driven wheels receive reduced soft-ground RR;
- multi-axle trailers can use an inline-axle factor to approximate following wheels running in already-packed tracks;
- non-driven wheels receive reduced RR at nearly zero speed to avoid static lock-like behavior.

### Confirmed endpoint discontinuity

At exact `wetness == 0` and `wetness == 1`, `mrGetRrFx` calls dry/wet helpers without the `isDrivenWheel` argument.

At intermediate wetness the argument is passed.

Consequently the intended driven-wheel reductions:
- dry: 0.9x;
- wet: 0.75x;
are absent exactly at the endpoints.

Status: **CONFIRMED_STATIC** in the exact 0.26.08.03 source. Runtime magnitude pending.

## Dynamic friction

MR computes a dynamic friction scale from:
- driven/non-driven state;
- smoothed slip;
- surface class/subclass;
- steering angle;
- support geometry;
- tire load;
- snow/contact context.

The code explicitly acknowledges that friction is used as a gameplay/engine compensation because the GIANTS physics model cannot reproduce all desired real-world behavior directly.

This matters for RE: MR grip factors are **effective vehicle-dynamics controls**, not direct measurements of soil shear strength.

## Global wheel behavior on non-converted equipment

Several WheelPhysics replacements are not gated by `mrIsMrVehicle`.

Examples include:
- wheel mass estimation;
- rotation damping;
- tire friction;
- RR;
- wheel-shape creation;
- force-point placement;
- tire-load sampling.

Therefore unconverted third-party vehicles/equipment can still be physically affected by MR.

## Random wheel damping

During wheel XML load, exact 0.26.08.03 applies:

`rotationDamping = (0.5 + math.random()) * rotationDamping`

That gives approximately 50%-150% of the XML value.

The value is later especially visible when wheels have no ground contact.

Risks:
- nondeterministic behavior between loads;
- global Lua RNG sequence consumption;
- possible server/client divergence in locally computed non-authoritative state;
- harder controlled testing.

Recommendation: runtime/profiling first. If variation is desirable, deterministic per-wheel variation would be easier to reproduce than shared RNG.

## Wheel mass and rotational inertia

MR distinguishes:
- wheel assembly mass contributing to vehicle mass/CoM;
- wheel-shape mass used to approximate rotational inertia.

Wheel dimensions can replace base wheel mass estimates, and additional dual/triple wheels add extra assembly mass.

Wheel shape creation uses approximately twice the wheel mass to model greater rotational inertia.

This is a valuable separation. RC/RE should not collapse both meanings into one scalar.

## Vehicle mass and center of mass

MR globally replaces `Vehicle.updateMass` and removes the vanilla max-mass clamp.

It maintains component default mass/CoM plus additional contributors:
- FillUnit;
- TensionBelts;
- DynamicMountAttacher;
- wheel mass;
- object-change/additional-mass configuration.

Contributor CoMs are combined by weighted mass.

Physical CoM movement is rate-limited rather than teleported to the new target.

Positive lesson:
> variable load should carry spatial mass distribution, not merely increase total vehicle mass.

### Audit watchpoints

- DynamicMountAttacher's CoM path is explicitly marked `TODO = NOT TESTED` upstream in the exact source.
- MR's legacy ObjectChange mass system comments that GIANTS now has an equivalent and should eventually be removed/migrated.
- mods that directly own component mass/CoM can collide semantically even when their hooks chain.

## Terrain displacement interaction

MR explicitly addresses the GIANTS wheel-rut/work-area feedback loop.

For configured implement wheels:
- when lowered, MR can disable wheel terrain displacement;
- when raised, it restores it.

Separately, MR can suppress ground-contact work-area processing while an MR implement is nearly stationary.

This is directly relevant to RE v22:
- MR suppresses GIANTS transient terrain displacement for selected implement wheels;
- RE suppresses RE's persistent rut writer while the active cultivation combination is physically working.

These should remain complementary, not fight one another.

## RE lessons

1. Treat support width as a first-class contact property.
2. Keep crawler identity separate from crawler geometry.
3. Separate effective traction coefficients from soil constitutive properties.
4. Preserve the distinction between transient wheel/suspension response and persistent terrain deformation.
5. Avoid writing persistent ruts through a work area another owner is actively flattening.
6. Future ContactFootprint should be able to explain provenance: base tire, dual/triple support, crawler group, implement wheel.


## Second-pass finding: rolling-resistance base state can become stale

Status: **CONFIRMED_STATIC**.

`WheelPhysics.mrUpdateFriction` recomputes `mrTireGroundRollingResistanceCoeff` only inside the branch where the newly computed friction coefficient differs numerically from `tireGroundFrictionCoeff`.

The shipped table contains a concrete counterexample:
- tire type: `CHAINS`;
- surface: `GROUND_SOFT_TERRAIN`;
- dry friction: `0.76`;
- wet friction: `0.76`;
- dry RR: `0.030`;
- wet RR: `0.060`.

A dry->wet transition can therefore require a 2x RR change while friction remains 0.76, so the RR refresh guard is false and the previous base RR can survive.

The clean architectural fix is to invalidate/update RR from the state inputs that actually own RR (surface/subtype/wetness/tire type), not use friction-coefficient change as its proxy.

## Second-pass findings: center-of-mass invalidation

### Same-mass spatial redistribution

Status: **CONFIRMED_STATIC limitation**.

`Vehicle.mrUpdateMass` recalculates the target center of mass only inside the same >~20 kg mass-delta block used to decide whether to call `setMass`.

However contributors such as FillUnit can change their weighted spatial CoM without materially changing total component mass. A multi-compartment vehicle can therefore redistribute approximately the same mass from one location to another while the target CoM remains stale.

The physical-mass update threshold is reasonable; target-CoM invalidation should be a separate condition.

### Additional mass without explicit CoM

Status: **STRONG_CANDIDATE / model limitation**.

The target-CoM denominator uses `mrDefaultMass + totalAddMassWithCOM`, not total physical component mass.

At least two contributor paths can add physical mass without necessarily adding the same mass to the positioned-CoM table:
- TensionBelts separately adds `objectData.objectMass - 0.01`;
- DynamicMountAttacher adds object mass even when no coordinate node can be resolved.

If positioned and unpositioned additional masses coexist, the target can be biased toward the explicitly located contributors because unpositioned mass affects physical mass but not the weighted CoM denominator.

Runtime/harness evidence should determine how often GIANTS actually produces this mixed state.
