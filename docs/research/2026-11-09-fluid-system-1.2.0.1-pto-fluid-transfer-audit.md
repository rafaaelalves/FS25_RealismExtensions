# Fluid System 1.2.0.1 — first source audit, adoption decision and RE PTO / MR / Mud / RMS stack compatibility

**Audit date:** 2026-11-09 (Brazil). **Goal:** decide whether user should add the new Fluid System mod to their deep-realism FS25 stack, and document source-backed compatibility / possible RC or RE work.

**Exact user ZIP:** `FS25_FluidSystem.zip`, **AgrarMods / Agrar Kandelin**, `modDesc.xml` **1.2.0.1** (`descVersion=115`), **20,760,013 bytes**, SHA-256 **`0206fbda2b72d75be5a27495a1812163eec07eebd2c5e835c3775787b98dd0c9`**; 155 files, ZIP CRC **PASS**, **72/72 Lua syntax PASS**, **19/19 XML strict parse PASS** and **14/14 .i3d scene XML parse PASS**. These are *format/syntax* checks, not game or asset-shape lifecycle validation. No FS25 runtime, actual vehicle, save/reload, FPS, dedicated MP or third-party mod combination tested.

**Provenance caveat:** public [AgrarNord KingMods Fluid System page](https://www.kingmods.net/en/fs25/mods/83990/fluid-system) and [v1.2 public changelog](https://farmingsimulator25mods.com/fluid-system-v1-2/) document 1.2.0.0; **no independent publisher ZIP hash or public release listing for the exact 1.2.0.1 was established**. User ZIP manifest/README include *1.2.0.1: recognizing slurry storage in animal buildings*. Treat user ZIP as primary code evidence, not a verified mirror-to-author byte identity. GPL-3.0-or-later is declared for **Lua source**, with a full GPL text in README; model/audio/texture asset grants must not be inferred automatically.

## 1. What the mod actually is

**Not RMS-like engine oil, coolant, gearbox oil or internal hydraulic circuit maintenance.** It models **external, operator-controlled liquid transfer logistics**: physical 8-inch 3m and 5m hoses and steel intake, connecting ends and extensions, manual and remote valves, two 540-rpm rotary lobe PTO pumps, a Wienhoff funnel/docking station and a manual slide-valve storage placeable. Supports water, slurry, digestate and explicitly configured other GIANTS fill types; finite source/target storage, purchased-fill economy boundary, flow, pump modes, pressure/pipe ratings, booster primary route sharing, reversibility, tank selection and persistence.

Seven bundled store items, independent vehicle/placeable/pipe specializations, own GUI and native help bindings. Existing base machine compatibility list includes several **Kotte FRC/FRC55/FRC65/TSA/PQ 32000**, Zunhammer ULT 18/24, Farmtech Supercis 800, Fliegl PFW 18000, Annaburger AW 22.27, Kaweco Profi II and **Vredo DLC** models. Some integrated existing vehicles change vanilla fill/discharge pathways; *installing does not add a fluid socket automatically to every modded tanker*. The new **Tank Setup** editor allows defining vehicle/connector parts, with admin-level authoring controls. The major source value for the user is realistic hose operations/pumping procedure, not extra ruts or another weather system.

## 2. Positive physical and architecture findings

### FS1201-01 POSITIVE — native PTO request instead of a third global governor

- `VehicleFluidConnectors.registerOverwrittenFunctions` registers **per-vehicle specialization** wrappers for `getPtoRpm`, `getDoConsumePtoPower`, and `getIsPowerTakeOffActive` only on vehicle types exposing the appropriate GIANTS `PowerConsumer` / `PowerTakeOffs` specializations. `getPtoRpm` is `max(native, FluidPumpDriveUtil.getVehiclePtoRequest)`, so a running pump independently requests its `ptoRpm * selectedSpeedFactor` without turning on all native `TurnOnVehicle` tools.
- `FluidPumpDriveUtil.getActualPtoRpm` derives achieved shaft RPM from measured motor RPM / `motor:getPtoMotorRpmRatio()`, and `getEffectiveSpeedFactor` uses actual PTO RPM where available to compute flow and sound speed. It retains a selected-speed fallback where the motor/ratio API cannot be read: **source usability, not proof of actual shaft speed**. `raiseActive` and scoped interpolation support parked/unused PTO output visual/sound continuation.
- Native included pumps declare `<powerConsumer ptoRpm="540" neededMinPtoPower="35" neededMaxPtoPower="50"/>`, while Fluid System defines `100 L/s (6,000 L/min)`, maximum 3 bar output, 0.8 bar suction and **45 kW nominal**. Therefore GIANTS has a native PTO powerConsumer channel; **not true to claim 'no engine load whatsoever'.** But the separate `FluidPumpModel.getPowerDemandKw` is consumed by `FluidSystemTelemetryProvider` and **not fed into a dynamically recomputed native shaft torque/power load**. Hose head, route flow and pressure do not directly become a measured variable engine torque. This is the main **future** low-risk integration opportunity for RE PTO and RC after actual runtime.
- The RE's native PTO / RC RMSPTO/MRPTO remains **the selected authoritative gear/shaft/RPM owner**. Fluid System should supply an actual equipment demand and let the native owner meet it, rather than another `VehicleMotor.getRequiredMotorRpmRange` hook. This is preferable in principle to MapFlood's unconditional +500rpm/+0.5kNm governor and several external governor mods. **Do not add a speculative RC bridge yet**: real `PowerConsumer.getTotalConsumedPtoTorque` and RE consumer-activation detection are runtime acceptance gates.

### FS1201-02 POSITIVE — conserved fluid transfer / pressure-aware route validation

- `FluidTransferEngine.commit` removes liquid from a finite source, deposits the target's accepted portion and attempts source rollback if target is full. Unlimited native water and native buying-station paths have distinct semantics; paid source uses native purchase path rather than inventing free stock. `commitWithSpill` divides removed liters between accepted target and a real outflow ledger.
- `FluidPumpModel` supports rotary-lobe, centrifugal, vacuum, generic modes with exponent profiles (centrifugal Q∝RPM, head∝RPM², nominal power∝RPM³); models priming, caps and a boost flow limit, not an exact Navier–Stokes solver. `RouteValidator`, `PipeTypeRegistry`, `ConnectorRegistry` reject incorrect connector fit, unopened valves and over-pressure/vacuum. Hose network and effects have explicit bounded capacities.
- The exact code's `FluidControlAccess` checks connection's farm permission and whether an input is from a nearby outside operator or the current vehicle; structural setup requests are admin + owner-authorized. These are substantially stronger source-level checks than the previously audited Etrigo/MapFlood pump event paths. **Still no public dedicated MP security guarantee**, especially for all custom network actions.

### FS1201-03 POSITIVE — mod-friendly diagnostics and GUI, real external capability model

- `FluidSystemTelemetryProvider` publishes pump speed, demanded kW, available drive factor, requested/observed PTO RPM, flow, route pressure/vacuum, spill and endpoint identity. Dashboard offers source→pump→destination connections, user-configured hardware positions, manually operated valves and visible input help; noteworthy **UI/UX precedent for RE PTO**, where the user has asked for better visual polish.
- The extension point is **XML and vehicle type specializations**, including an admin-authored setup editor; little reason for the RC to introspect unstable private tables if a future public API is requested.
- Source license says **GPL-3.0-or-later for Lua**, with redistribution obligations; do not wholesale import author code or assets into RC/RE. Learn independent UI/owner patterns or coordinate upstream.

## 3. Important source-level risks and unproven behaviors

### FS1201-04 HIGH for the user's ongoing RE tests — modifies vanilla equipment paths

`VehicleFluidConnectors.prerequisitesPresent` and `PlaceableFluidConnectors.prerequisitesPresent` return **true**, and `TypeManager.validateTypes` installs these specializations **on all compatible vehicle and placeable types**. On load, unconfigured vehicles mostly get empty Fluid System instances, but this is not a zero-scope plugin: it registers handlers and conditional wrappers around `Dischargeable`, `PowerConsumer`, `PowerTakeOffs`, `Washable`, `getFillLevelInformation`, `PlayerInputComponent` and construction/shop callbacks.

For selected base vehicles, integration tables explicitly set `disableVanillaFill=true` and/or `disableVanillaDischarge=true` to require using Fluid System hoses and valves. `FluidSystemSettings.DEFAULT_LEGACY_VANILLA_INTEROP=false`; enabling the mod may **change normal R-action filling/discharging in a production save before the user owns its hardware**. This is an intended gameplay restriction / compatibility concern, not an observed bug. Check Kotte, Zunhammer, other favorite tankers and manure buildings in a cloned save before promoting.

### FS1201-05 HIGH for crop/soil integration — real spill-to-field effect

`FluidGroundSpillSync` defaults `nativeSpreadingEnabled=true`. `FluidGroundSpillSpreading.deposit` accumulates real lost `LIQUIDMANURE`/`DIGESTATE` over **1m×1m** cells, checks the full cell is field, then calls **`FSDensityMapUtil.updateSprayArea(...)`** when dose reaches one native spray pass. Pending fractions are persisted in `fluidSystemGroundSpills.xml`; ground visuals max 64 patches and 6m radius, and client snapshots are separately managed. Soil *nitrogen for Precision Farming is explicitly deferred*. **Disabling 'Spill effects on the ground' hides visuals only; it does NOT stop fluid loss or native crop-soil fertilizer edits.** For clean RE terrain/RH/PF baseline, disable host setting **Allow fluid spills** (default true), not just the visuals; check whether direct outputs and existing spills persist after the toggle. This is a **native field-density writer**, not a terrain heightmap or Mud 1.4 puddle reservoir.

**Isolated actual-source test:** a mocked 5L LIQUIDMANURE spill centered inside a single all-field 1m² cell, with native spray-type dosage set to 1L/s, **issued exactly one `updateSprayArea`**. This proves source control flow, **not** agronomic balance or actual PF/RH results. Beware existing fertilizer spreader/Precision Farming duplication if a user attempts to represent the same lost volume twice.

### FS1201-06 MEDIUM — pump hydrodynamics are useful approximations, not verified power hydraulic realism

The included pump's 45kW nominal and 100L/s/3bar parameters appear in XML and telemetry; `getPowerDemandKw` is **not called from a native torque/engine load hook**. Existing GIANTS `PowerConsumer` config provides a nominal load, but there is no source-proven dynamic `P = Δp × Q / η` feeding shaft torque, nor verified fluid viscosity/pressure drop for each 3/5m hose. Nominal pump-speed/pressure exponents and pressure ratings are operationally meaningful but not manufacturer calibration.

Because Fluid System requests PTO RPM itself, test whether RE's **manual hand throttle** and **road/worker modes** properly expose real shaft RPM while the pump keeps running after dismount. Do not make RE override its PTO governor globally just to force this one implement to work. A measured failure may warrant a **capability handshake**: `getPtoRpm`, `getDoConsumePtoPower` and observed load/ratio should be first evidence.

### FS1201-07 MEDIUM — Mud 1.4 puddles, RutFlow, MapFlood not interchangeable water sources

`NaturalWaterSource.lua` checks **native `CollisionFlag.WATER` via up to four async raycasts per update**, caching submerged samples. This works for genuine lakes/rivers/native collision water but **does not consume Mud `LocalPuddleSystem` basin depth or volume**. Earlier exact Mud 1.4 audit showed its *visual puddles have no WATER collision*; RutFlow displays primarily non-authoritative client-local water and lacks Mud wetness provider. **Do not promise to pump a Mud-generated puddle** or a RutFlow water sheet as a real finite intake. MapFlood creates some WATER colliders but adds a conflicting independent water volume model and pump PTO hooks; don't enable MapFlood merely to make its water accessible to Fluid System. A future specific, consented native-water-source adapter would need server-side conserved basin volume and provider API, **not** treating an overlay as unlimited natural water.

### FS1201-08 MEDIUM — native save and scene workload untested

The mod writes persistent extra state (vehicle/pipe connections, valve positions, per-save ground spill XML and staged native fertilizer doses), uses scene models with hoses/joints, connection placement, interaction point searches, GIANTS XML/save/stream and runtime snapshot events. Some loaded vehicle and placeable types receive extra specializations, and GUI/scan work can be broad in a large mod stack. No actual load time, frame-time, resource leaks, full save-reload, realistic pipe collisions or MP late-join measurement yet.

## 4. Actual-source test results (minimal mocked GIANTS context, no gameplay)

Ran `texlua --luaonly` on extracted **unchanged** source modules:
- `FluidPumpDriveUtil` with root tractor: motor 1800rpm and PTO ratio 1800/540 → **540 shaft RPM, 100L/s, reported 45kW**. Motor 900rpm at same ratio → **270 shaft RPM, 50L/s, reported 22.5kW**. Motor OFF → zero flow. Pump stopped → PTO request 0. None of this simulates actual engine *load* or selected PTO gearbox.
- `FluidTransferEngine.commit` with 100L source, 25L target capacity, 70L requested → **25L delivered, 45L rolled back, 75L remain**. `commitWithSpill` 80L source, 40L target cap, 60L transfer +10L prescribed spill → **40L delivered, 30L spilled, 70L removed**, conservation PASS.
- `FluidGroundSpill` accepts LIQUIDMANURE spill and refuses WATER-only graphical slurry patch. `FluidGroundSpillSpreading.deposit` with matching native spray stubs emitted one real native field write after 5L.
- `FluidControlAccess.connectionCanAccessOwner` rejects a simulated *farm 3 client* controlling a farm 4 vehicle; accepts farm 3 and server. This is source-level behavior, not a penetration test of all game events or the rest of GIANTS permission checks.

All checks PASS after adapting mocked adapter callback to the mod's published dot-call interface. No errors attributable to the shipped source.

## 5. Main-stack and RC/RE decision

| System | Owner or effect | Recommendation |
| --- | --- | --- |
| **RE PTO** | Selected PTO gear, effective RPM, player/worker and unattended state. Fluid System provides pump load/input request through per-vehicle `getPtoRpm` + nominal GIANTS `PowerConsumer`. | **Promising compatible design**, controlled A/B required; no code change now. |
| **RC MRPTO / RMSPTO / MR / RMS** | RC adapts native RE PTO ratios/engine load; RMS owns mechanical wear and may grease implement cardans in 1.0 beta. Fluid System owns pump process. | No same-function global governor; observe any over/under-consumption and duplicate wear, not immediately absorb. |
| **Mud 1.4** | Soil wetness, physical puddles, traction/ruts indirect. Fluid System's spilled slurry/digestate updates native fertilizer density; no independent water catchment. | Can plausibly coexist with Mud hydrology **without duplicate water simulation**, but new field writes/PF require a test. Keep spill permission OFF initially. |
| **RH / PF / SoilCompaction** | Harvest and agronomic soil/crop state; Fluid System can native-fertilize from actual spilled nutrient liquids. | A/B crop stages/fertilizer and field writer order; avoid counting intentional broadcast/spreading twice. |
| **RutFlow / MapFlood** | Prior recommendation keeps both OFF in main stack due Mud water ownership. | Do not reactivate either for Fluid System water intake; only native CollisionFlag.WATER sources are supported. |
| **Base-game tankers/barns** | Some standard fill/discharge hotkeys deliberately suppressed for Fluid System hardware. | Clone-save installation trial and test configured vs unconfigured equipment. |
| **Multiplayer** | Farm-access checks, server authority, structural admin gate and streamed hose state. | Positive source signals, but **MP not verified**; do not promise dedicated server readiness. |

**Verdict: YES as an optional controlled-trial candidate, with medium-to-high usefulness for the user's desired manual realism/logistics. No urgent need to install into the current RE terrain-development main save.** Stronger case if the player regularly hauls/spreads slurry, digestate or tanked water. Not a reason to switch RMS or create a new engine-fluid simulator. Its clean **external-process owner** and graphical hardware editor are valuable references, including for future roadwork/mining fluids.

**Minimal acceptance (one cloned save):** (1) existing tanker standard vanilla controls and source tanks with mod ON/OFF; (2) GIANTS 540 PTO pump + 3m hose + storage → tank transfer, start/stop, reversed flow, one valve closed, confirm source decrease matches target increase; (3) RE PTO ROAD/manual/worker/dismount + observed actual 540 RPM and real tractor fuel/load with pump start/stop; (4) spill permission OFF, repeat ON only in disposable cultivated area, confirm native fertilizer delta and PF interaction; (5) save/reload tank, hose and coupling state; (6) log errors, RC modules and performance before any permanent adoption. **No requirement to repeat entire terrain test cycle** for this external fluid module.

**Repository action:** documentation-only RE source audit, no RC/RE functional changes, build, merge, compatibility whitelist or downstream asset copy. A narrow RC PTO pump-demand bridge is only worth implementing after a reproduced actual-load or RPM arbitration discrepancy.
