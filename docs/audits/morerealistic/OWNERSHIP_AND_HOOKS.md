# MoreRealistic ownership and hook architecture

## 1. MR is an engine mod first, conversion pack second

The exact 0.26.08.03 package installs roughly 140 GIANTS function hooks, overwhelmingly `Utils.overwrittenFunction` hooks.

Central replacement surfaces include:
- `VehicleMotor`;
- `WheelPhysics`;
- `WheelsUtil`;
- `Motorized`;
- `Vehicle`;
- `PowerConsumer`;
- `StoreManager`;
- work-area and implement specializations;
- AI/control helpers;
- fill/fruit managers.

Several critical MR functions deliberately do not call `superFunc`. In those paths MR is the final algorithm owner, not merely a modifier around vanilla.

This creates the central compatibility rule:

> A third-party wrapper can remain structurally present in the Lua chain and still lose its semantics if MR later enters an alternate/custom path that bypasses the wrapped vanilla function.

MRADS is a proven example: ADS wrapped vanilla transmission functions, but MR's custom transmission path bypassed some of them.

## 2. Scope matrix

### Global engine scope

These changes can affect vehicles that are not explicitly MR converted:

- `WheelPhysics.new/loadFromXML/postUpdate/updateTireFriction/updatePhysics/updateFriction/updateBase/getTireLoad/serverUpdate`;
- tire friction and rolling-resistance tables loaded into GIANTS tire types;
- wheel mass estimation from dimensions;
- wheel-shape rotational-inertia mass;
- wheel force-point placement;
- dynamic friction and rolling resistance;
- `Vehicle.updateMass` replacement and component CoM framework;
- aerodynamic drag/downforce in `Vehicle.updateVehicleSpeed`;
- default fill-type density/selected price overrides;
- default fruit-type yield/process-factor overrides;
- seasonal/night `Weather.getGroundWetness` floor;
- several light/dashboard/AI/base-game behavior changes;
- filename/store/PF remapping needed for converted assets.

### Global drivetrain/control scope

Second-pass correction: MR's drivetrain/control ownership is broader than converted vehicles.

The package globally overwrites many `VehicleMotor` methods, including direction changes, gear shifting, min/max ratio, motor update, speed limit, start-in-gear behavior, target-gear application, gear groups, clutch/torque helpers and motor-run checks. `WheelsUtil.updateWheelsPhysics` is also globally overwritten.

`VehicleMotor.new` only uses `mrIsMrVehicle` for some calibration differences; the MR motor/control path itself still participates on non-converted vehicles.

### MR-converted metadata/calibration scope

The `vehicle.MR` marker remains important for:
- richer MR transmission/hydrostatic/CVT metadata;
- converted engine/transmission calibration;
- custom implement work-area stationary gating;
- MR-specific combine/baler/mower/etc process models;
- converted-vehicle XML tuning;
- selected suspension and implement parameters.

Therefore `mrIsMrVehicle` should be interpreted as **converted/calibrated by MR**, not as **MR physics present**.

### Capability-gated scope

Some systems activate based on available specialization or metadata rather than a simple MR flag:
- FillUnit mass/CoM;
- TensionBelts added mass;
- DynamicMountAttacher added mass;
- Dashboard value behavior;
- wheel advanced spring parameters;
- implement-specific XML values;
- trailer/attachment state.

## 3. Converted asset catalog

The exact package contains a large `data/overriding` catalog and an `overridingDatabase.xml` mapping vanilla/DLC XMLs to MR copies.

The architecture:
1. StoreManager sees a base/DLC item.
2. MR substitutes a converted XML when a mapping exists.
3. the vehicle loads in the MR environment/configuration;
4. save serialization temporarily restores the genuine source filename;
5. MR restores the runtime converted filename after the base save routine.

This is a thoughtful persistence strategy: disabling MR should not automatically orphan the saved vehicle by leaving a private converted XML path in `vehicles.xml`.

### Risks

- correctness depends on stable vanilla/DLC filenames and package layout;
- DLC/environment handling requires special cases;
- store combination records are mutated in place when remapping filenames;
- temporary `vehicle.configFileName` mutation around save is not exception-safe;
- PF linkage requires separate filename translation.

## 4. Precision Farming patch style

`FIX_PF.lua` directly replaces three PF linkage functions so original PF vehicle filenames can resolve MR-overridden XMLs.

This is useful functionality but a fragile integration surface:
- direct assignment rather than composable wrapper;
- depends on the PF global being available at source-load time;
- no explicit PF version/shape gate;
- another mod replacing the same method has ordinary load-order ownership.

If this path ever causes a real stack problem, it is a strong RC candidate because the behavior is genuinely cross-mod filename translation.

## 5. Global direct assignment

The exact source directly assigns `Vehicle.getName = function(self) ... end` rather than using `Utils.overwrittenFunction`.

Functionally it adds configuration-sensitive naming and MR labeling behavior. Architecturally it is a load-order risk because it discards whichever implementation was present at assignment time.

Recommendation:
- do not patch speculatively;
- include `Vehicle.getName` in ModMixer ownership/watch lists;
- if a real collision occurs, prefer a narrow composable adapter.

## 6. Lifecycle/persistence/networking

MR's physics mostly rides on native server-authoritative vehicle state rather than defining a large custom network protocol.

The exact package has explicit custom update-stream state mainly for its reworked WoodCrusher.

Important persistence patterns:
- genuine filename serialization for overridden vehicles;
- custom runtime physics values usually recomputed rather than persisted;
- fill/fruit defaults are loaded from MR data each session.

Exact 0.26.08.03 contains a console-command teardown mismatch:
- adds `mrVehicleMorePower`;
- removes `mrConsoleCommandVehicleMorePower`.

This is an individual-mod lifecycle defect, not a compatibility bridge.

## 7. Compatibility implication for RC

RC should classify MR participation by **owned surface**, not merely by `mrIsMrVehicle`.

Examples:
- friction composition: MR participates globally;
- drivetrain/control composition: MR's VehicleMotor/WheelsUtil overrides are global; richer branch behavior can additionally depend on converted-vehicle metadata;
- mass/CoM: MR participates globally;
- combine throughput: only when MR combine metadata/model is active;
- PF overridden-filename mapping: only converted assets.

A future shared provider should expose facts such as:
- `mrEnginePresent`;
- `mrVehicleConverted`;
- `mrMotorActive`;
- `mrGlobalMotorControlActive`;
- `mrConvertedCalibrationActive`;
- `mrWheelPhysicsActive`;
- `mrProcessModel`;
rather than one ambiguous boolean.
