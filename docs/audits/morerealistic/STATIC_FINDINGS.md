# MoreRealistic static findings ledger

Evidence labels:
- **CONFIRMED_STATIC** — source logic itself proves the condition/path.
- **STRONG_CANDIDATE** — source strongly indicates a defect but engine lifecycle/runtime behavior is still needed.
- **DESIGN_RISK** — potentially undesirable architecture/semantics, not inherently a defect.
- **RUNTIME_PENDING** — question intentionally reserved for controlled game testing.

Exact baseline: MoreRealistic 0.26.08.03, SHA-256 `4646b8c01dd9157d452e66022fdc5323e812e2f287b23bbee657f05f5386b4bb`.

## F-01 Night damp arithmetic precedence

Status: **CONFIRMED_STATIC**

Comment says damp should take two hours to rise/fall.

Exact expressions apply multiplication to `dampStart`/`hour` rather than elapsed time:
- `hour - dampStart * 0.05`
- `dampStop - hour * 0.05`

Expected shape is equivalent to:
- `(hour - dampStart) * 0.05`
- `(dampStop - hour) * 0.05`

Current upstream has an open PR that independently identifies this exact issue.

Classification: owner-mod fix / optional explicitly gated hotfix; also relevant to MR-MoistureSystem integration.

## F-02 PTO turn-on peak impossible condition

Status: **CONFIRMED_STATIC**

`ignoreTurnOnPeak == nil and ignoreTurnOnPeak == false` is impossible.

The configured turn-on peak multiplier is therefore unreachable through that condition.

Classification: owner-mod fix / optional hotfix.

## F-03 Hydrostatic flag read from VehicleMotor instead of Vehicle

Status: **CONFIRMED_STATIC**

`VehicleMotor.mrUpdate` checks `self.mrTransmissionIsHydrostatic`.

The flag is loaded on `vehicle.mrTransmissionIsHydrostatic`.

Classification: owner-mod fix candidate.

## F-04 Hydrostatic engine-braking default load order

Status: **STRONG_CANDIDATE**

`Motorized.mrLoadMotor` chooses ordinary vs hydrostatic engine-brake factor using `self.mrTransmissionIsHydrostatic`.

`Vehicle.mrLoad` assigns that field only after the base vehicle load has returned.

Potential result: hydrostatic vehicles without explicit `mrEngineBrakingFx` can receive the ordinary default.

Needs a load-lifecycle harness/runtime capture before patch.

## F-05 Driven-wheel RR endpoint discontinuity

Status: **CONFIRMED_STATIC**

At exact wetness 0 and 1, `mrGetRrFx` omits `isDrivenWheel` when calling the dry/wet helper.

At intermediate wetness it passes the flag.

The driven-wheel RR reduction therefore disappears at exact endpoints.

Classification: owner-mod numerical bug / optional hotfix.

## F-06 Global random wheel damping

Status: **DESIGN_RISK**

Every WheelPhysics load applies roughly 50%-150% random scaling to rotation damping.

Risks:
- nondeterministic A/B tests;
- global RNG coupling;
- possibly different local values across peers;
- difficult replay/debugging.

Potential improvement: deterministic variation or fixed calibrated damping.

## F-07 Fixed-per-call smoothing coefficients

Status: **RUNTIME_PENDING**

Multiple hot paths use fixed exponential coefficients without `dt` normalization.

Potentially cadence-sensitive examples:
- dynamic friction;
- RR;
- load/speed smoothing;
- fuel-use smoothing;
- CVT target;
- PTO decay.

Need controlled cadence/FPS test before declaring behavior wrong.

## F-08 Direct global `Vehicle.getName` replacement

Status: **DESIGN_RISK**

MR directly reassigns `Vehicle.getName` instead of composing through Utils.

Potential load-order conflict with any other naming/configuration mod.

## F-09 Exact-version console teardown mismatch

Status: **CONFIRMED_STATIC** for 0.26.08.03

Adds:
- `mrVehicleMorePower`

Deletes:
- `mrConsoleCommandVehicleMorePower`

The command name does not match.

This path may already differ upstream; gate any fix to the exact affected contract.

## F-10 Direct PF method replacement

Status: **DESIGN_RISK**

`FIX_PF.lua` directly replaces selected Precision Farming linkage functions.

Risks:
- PF source/load-order changes;
- another compatibility mod owning the same function;
- no explicit version contract.

No RC patch unless a real collision is observed.

## F-11 Store combination input mutation

Status: **DESIGN_RISK**

`StoreManager.mrGetItemsByCombinationData` rewrites fields on the provided `combinationData` table in place and does not restore them.

Potential impact depends on caller reuse semantics.

Harness/source-call-site review pending.

## F-12 DynamicMount CoM path marked untested

Status: **RUNTIME_PENDING**

The exact source labels `DynamicMountAttacher.mrGetAdditionalComponentMass` as `TODO = NOT TESTED`.

This is relevant because MR's variable-CoM framework otherwise depends on mass-contributor correctness.

## F-13 External surface classification is narrow

Status: **DESIGN_RISK**

Off-field classification relies partly on a small set of exact surface-sound names:
- dirt;
- grass;
- gravel;
- sand;
- leaves;
- asphalt.

Fallback ground-depth/road logic helps, but custom maps can still produce semantic mismatch.

Potential improvement: declarative surface-profile registry.

## F-14 Work-area/terrain-displacement ownership overlap

Status: **CONFIRMED_STATIC**, not a bug

MR deliberately suppresses:
- stationary ground-contact work-area processing for configured MR tools;
- GIANTS wheel displacement for selected lowered implement wheels.

This must be preserved when RE persistent terrain writers are active.

Classification: integration ownership constraint.

## F-15 Global engine effects extend beyond converted vehicles

Status: **CONFIRMED_STATIC**, architectural

WheelPhysics, mass/CoM, drag/downforce, weather and default data changes extend beyond `mrIsMrVehicle`.

Compatibility detection based only on conversion identity is incomplete.

## F-16 Changelog is not a reliable feature-presence contract

Status: **CONFIRMED_STATIC provenance issue**

The exact ZIP's changelog contains entries extending beyond the declared package version/date.

Audit policy:
- source code + modDesc + source hash determine behavior;
- changelog is historical/contextual evidence only.

## Hotfix policy

If RC ever carries an owner-mod fix:
1. put it in an explicitly named hotfix module;
2. document exact affected versions/contracts;
3. verify the faulty source shape is still present;
4. fail closed if the shape differs;
5. detect an upstream-corrected shape and report `NOT REQUIRED`;
6. never hide the fix inside an unrelated MR integration module.


## F-17 Rolling resistance refresh coupled to friction change

Status: **CONFIRMED_STATIC**

`WheelPhysics.mrUpdateFriction` updates `mrTireGroundRollingResistanceCoeff` only when the numeric friction coefficient changed.

The bundled tire table proves those two states are not equivalent. For `CHAINS` on `GROUND_SOFT_TERRAIN`:
- dry friction = 0.76;
- wet friction = 0.76;
- dry rolling resistance = 0.030;
- wet rolling resistance = 0.060.

Therefore a wetness transition can require a 2x RR change while the friction equality guard suppresses the RR refresh.

Classification: owner-mod physics bug / optional hotfix candidate.

## F-18 PowerConsumer draft guard aborts unrelated PTO bookkeeping

Status: **CONFIRMED_STATIC**

`PowerConsumer.mrOnUpdate` returns from the whole function if:
- force-node velocity is unavailable; or
- a configured `maxGroundDistance` is exceeded.

Those returns happen before the shared tail that decrements `turnOnPeakPowerTimer` and updates PTO power.

Several converted headers configure `maxGroundDistance` together with PTO/maxForce data, so the affected shape is used by shipped assets.

Classification: owner-mod control-flow bug / optional hotfix candidate.

## F-19 Variable CoM invalidation is tied to mass delta

Status: **CONFIRMED_STATIC LIMITATION**

`Vehicle.mrUpdateMass` recalculates the target CoM only while processing a component whose total mass changed by more than ~20 kg.

But positioned mass contributors can change their weighted location without changing total mass. Same-mass transfer between compartments can therefore leave physical CoM stale.

Classification: model/lifecycle limitation; fix should separate mass invalidation from CoM invalidation.

## F-20 Positioned and unpositioned additional mass can diverge

Status: **STRONG_CANDIDATE**

The target CoM denominator uses `mrDefaultMass + totalAddMassWithCOM`, not the final physical component mass.

Some contributor paths can add mass without guaranteeing a corresponding positioned-CoM entry:
- TensionBelts `objectData.objectMass`;
- DynamicMountAttacher when an object's CoM node cannot be resolved.

If these coexist with positioned contributors, target CoM can be biased.

Classification: model edge case; harness/runtime incidence pending.

## F-21 WoodCrusher queue can lose accepted-vs-requested delta

Status: **CONFIRMED_STATIC**

MR subtracts `volumeToDeliver` from `mrWaitingFillLevel` before calling `addFillUnitFillLevel`, and discards the returned applied delta.

If the destination fill unit accepts less than requested, the unaccepted difference has already been removed from MR's queue.

Classification: owner-mod material-conservation bug. Correct pattern is to reduce the queue by the actual applied delta.

## F-22 CNH ballast path comparison typo

Status: **CONFIRMED_STATIC**

`commonKey` already ends with `/`, but the CNH comparison appends `/cnh/weight001.i3d`, producing a double slash.

The intended special-case 0.6 t ballast mapping therefore does not match the normal path form.

Classification: owner-mod data/path bug; trivial exact-shape hotfix if runtime relevance is confirmed.

## F-23 Duplicate EVO 290 override catalog entry

Status: **CONFIRMED_STATIC, benign data duplication**

The exact override database lists `data/vehicles/grimme/evo290/evo290.xml` twice, both mapping to the same MR target.

Because the loader indexes by source filename, the later entry overwrites the same value.

No behavioral defect is established, but it is catalogue noise worth cleaning.

## F-24 Tire-table loader fails partially

Status: **DESIGN_RISK / version-drift robustness**

Unknown tire/surface names or missing values cause local `break` behavior during table loading after earlier global tire entries may already have been overwritten.

A future engine/table drift can therefore leave MR with partially replaced global tire tables instead of atomically retaining the old state.

Classification: robustness improvement; not a current-data failure.

## F-25 Duplicate wrapper helper names hide earlier implementation identity

Status: **DESIGN_RISK**, not a behavior bug by itself.

Some MR files intentionally install multiple wrappers using the same helper symbol before redefining that symbol:
- `WheelPhysics.mrUpdateBase`;
- `FillUnit.mrLoadFillUnitFromXML`;
- `Baler.mrSetIsUnloadingBale`.

The installed wrapper chain retains the earlier function object, so behavior is not automatically lost. But the Lua global symbol points only to the newest helper afterward, making introspection, pointer-integrity diagnostics and compatibility tooling harder.

This can explain pointer drift without implying a broken chain.

## F-26 Drivetrain/control ownership is broader than converted-vehicle identity

Status: **CONFIRMED_STATIC architectural correction**

Many `VehicleMotor` methods and `WheelsUtil.updateWheelsPhysics` are globally overwritten.

`mrIsMrVehicle` mainly changes calibration/metadata branches; it does not delimit MR drivetrain participation.

Compatibility code must not use `mrIsMrVehicle` as a generic "MR motor absent/present" switch.
