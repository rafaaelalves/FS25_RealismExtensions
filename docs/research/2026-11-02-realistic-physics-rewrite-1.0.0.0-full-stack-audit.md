# Realistic Physics rewritten 1.0.0.0 — exact ZIP vs 1.20.2.0, MR/Mud/Reifen/RMS/HSS/RE full-stack audit

**Audit date:** 2026-11-02 (America/Sao_Paulo). **Exact source:** user-uploaded `FS25_RealisticPhysics (1).zip`, author Rónai Márk (RMark), manifest `version=1.0.0.0`, `descVersion=114`. **SHA256:** `9d10db754bb69c23f26ad2133d69a3d3addf5eb8b3104ee27c968f937e17adff`, **326,750 bytes**, 19 files. ZIP CRC PASS; **13/13 Lua loadfile syntax PASS**, **1/1 XML strict parse PASS**; manifest declares exactly those 13 source files. 4 OGG samples, one existing icon DDS. **No live FS25, gameplay/save, multiplayer or frame-time test was executed.**

**Baseline:** previous exact user ZIP `FS25_RealisticPhysics.zip`, manifest `1.20.2.0`, SHA256 `04e19cf8ad0310eda538f72ad09cb2d1b0ea52f19a0d1f5b3246979f1b74fc72`, 128,774 bytes, 170 files incl. 168 Lua. See [full old source audit](2026-10-23-realistic-physics-1.20.2.0-full-stack-audit.md). **This is not a version-number regression to an older release**: current author description explicitly calls it a **new rewritten mod with the same internal name** and warns to delete the old one. Public [Nov 2 v1.0 listing](https://www.farmingsimulator19mods.com/fs25-realistic-physics-v1-0-0-0-2/) lists selectable truck leaf/air and trailer leaf/rigid/air/hydraulic suspensions and rudimentary towing changes. The user's exact ZIP, not an unauthenticated mirror asset, is the binary evidence. **No author-published SHA found** to independently attest user ZIP to its upstream download; the modDesc and code match the claimed feature generation.

**Exact-file delta:** 170 old → 19 new. Only common files are `modDesc.xml` (changed) and `icon.dds` (byte-identical). **17 added paths, 168 removed, one shared changed, one shared unchanged.** All 167 former category/type profile Lua files and the old `RealisticSuspension.lua` disappear; there is **no comparable file-to-file algorithm diff** for the rewrite. 13 new domain scripts and four sound assets replace their architecture.

**Decision:** **substantial positive new capability evidence** (shop-selected physical trailer/truck suspensions, load-responsive spring & damper, center-of-mass/hitch balancing, unified live tuning). Still **do not install unmodified in the user's full MR + Mud + Reifen + RMS + HSS/RC + RE production stack**. New **default 0.72 global grip multiplier**, alternate wet/surface/lateral-slip model, global friction hooks, unleased suspension/CoM wheel writes, and an obsolete HSS compatibility fingerprint give concrete *source-level ownership conflicts*. **Worth a focused standalone A/B** on a cloned save with clear, mutually exclusive suspension owners, rather than dismissal. **Future RE research candidates:** `TrailerLoadDistribution`/`CargoCenterOfMass` and an explicitly single-owner `TrailerSuspensionCapability`, not wholesale traction/soil physics.

## 1. What the new 13-file code really implements

| New domain | Actual mechanism, not just mod description |
| --- | --- |
| `RealisticPhysics.lua` | Central vehicle classification, per-vehicle ticker/load-handler composition, `WheelPhysics.loadFromXML` wrapper; `core.forcePointRatio=0.9` assigned to **all wheels** by default. Mass-aware damper with `c = 2 ζ sqrt(k*m_per_wheel)` floor (`ζMin=0.20`) bounded by original damper and calibration caps, including load-dependent trailer damping. |
| `RealisticPhysicsMachines.lua` | Separate front/rear axle physical parameters for motorized tractors, harvesters, loaders, forestry equipment. Three tractor mass bands ≤6t, 6–11t, >11t; base spring and rest load scale with empty mass, optional tire deformation band, rigid wheel hub, and front axle joint tuning. Many profile entries default to zero = *keep factory*, so not every declared class implies a calibrated physical change. |
| `RealisticPhysicsHydro.lua` | Recognition of selected tractor front hydraulic leveling and axle/kneeling state; edits wheel physical spring/damper/rest position, and hooks `WheelVisual.update` for tire/axle rendering offsets. |
| `RealisticPhysicsTruck.lua` | Per-front/rear truck spring/damper re-planning: leaf vs air rear vs air both, balancing and kneeling with engine start/stop; air-ride trailer counterpart, OGG sounds and console controls. Uses actual `p.spring`, `p.deltaYOriginal`, `p.suspTravel` and visual offsets rather than only cosmetics. |
| `RealisticPhysicsTrailerSusp.lua` | Per-trailer leaf/rigid/hydraulic/air model; physical spring, four dampers and body-height compensation; hydraulic and air systems adapt stiffness to cargo load with bounded exponential response; rigid axle option maps movement to tire deformation when parameters support it; source calls native wheel update/rebuild. |
| `RealisticPhysicsShop.lua` | Registers one ordinary GIANTS vehicle configuration type `rsSuspension`, using `ConfigurationUtil.getConfigurationsFromXML` wrapper. Trailer choices: leaf/rigid/hydraulic/air; truck choices: leaf/airRear/airBoth (default airRear). **All listed option prices = 0**. Stores selection via standard vehicle configurations, conceptually benefiting vanilla persistence/MP, but actual shop visibility/service reconfiguration/synchronization remain **FS25-UNVERIFIED**. This does not implement inventory/storage/reuse of removed parts. |
| `RealisticPhysicsTrailer.lua` + `RealisticPhysicsCog.lua` | Measure longitudinal component center-of-mass vs axle/hitch moment arms, target approximate **8% hitch share for drawbar trailer** and **20% for semitrailer** (category dependent); shift CoM longitudinally in bounded increments, and raise effective CoM as cargo fill/mass increases (max rise **0.8m**). Shared `comSetOffset(vehicle,node,key,...)` composes independent `balance` and `lift` requests as deltas. These affect native physical COM and may alter towing/stability, but do **not** impose a real manufacturer towing capacity or drawbar rating. |
| `RealisticPhysicsGrip.lua` | **New independent traction solver** atop GIANTS native wheel tire table: default `scale=0.72`, road/hard/field/soft class, load-sensitive `ratio^-0.1` from tire suspension compression, tire width × radius area, wheel wetness, optional lateral stiffness reduction, exempt crawler/chains/spikes. Recomputes wheel multipliers every ~100 ms and wraps both `WheelPhysics.updateFriction` and `updateTireFriction`. Does not query Mud's local wetness provider; reads the `groundWetness` passed by native wheel friction callback. |
| `RealisticPhysicsHop.lua` | Retains synthetic sinusoidal wheel hop, ground class and load weighting, friction oscillation and optional vertical `addForce`. New default amplitude **0.80** (old audit 0.98), `fadeSpeed=1.8m/s = 6.48 km/h`, wheel frequency scaled by radius. This is not calibrated measured tire stick-slip. |
| `RealisticPhysicsLive.lua`/`Settings.lua` | Consolidates all knobs in one Lua config and `rsGet`/`rsSet`/`rsSettings` live console commands; live reconfiguration is **local state mutation**, no dedicated server-authoritative multiplayer settings/event contract shown. Valuable source provenance and observability model, not independently suitable for untrusted MP. |
| `RealisticPhysicsAxle.lua` | Optionally changes moving visualization node of rigid/pendular trailer axle according to measured suspension; separate visual actuator; hardware binding and geometry need per-vehicle proof. |

**What it does not do:** no direct `TerrainDeformation`, `setTerrainHeightAtWorldPos`, soil hardness/penetration-force/dryness profile, native `PowerConsumer` draft override, RMS part wear registration, or independent PTO shaft/gearbox torque model. The claimed stronger towing result is an *emergent consequence* of CoM/balance/grip/suspension, not a source-proven maximum admissible mass rule. Never infer dry-hard implement resistance or a direct solution for RE ruts merely from the mod name.

## 2. Critical full-stack findings, with evidence tier

### RP100-01 HIGH — generic extra traction owner directly overlaps MR/Mud/Reifen/RC

The source enables `grip.enabled=true`, `scale=0.72` for practically all motorized vehicles unless explicit factory-name exclusion. For a nominal wheel with no other multipliers it requests **72% of the preexisting frictionScale** even on dry road; hard-ground `ground.mult.hard=0.88` would yield nominal **0.6336** before load/wet/tire-size factors. Wet terrain further scales native wet tire tables through `wet.loss[...]` **in addition** to MR + Mud's current local wetness, wheel load, contact/resistance and Reifen tread-wear composition. The code also scales `p.maxLatStiffness`, a second native wheel field, with no RC single-owner or provenance handshake.

One of RP's own two wrappers additionally applies `rsHopMul` to the same temporary `frictionScale` field. In a deterministic Lua mock, the default dry-road grip multiplier **0.72** multiplied by a fully mobilized **0.20** hop multiplier gives only **0.144 of native frictionScale** before any external MR/Mud/Reifen factors. This is the *limiting-model configuration*, not measured frequency in FS25 gameplay; the most extreme wheel hop requires high sustained slip and hard ground. **Even so, these are new conflicting active physical writes**, whereas the old 1.20.2.0 audit showed wheel-hop effects but not this broad independent load/wet/tire-grip policy.

**Do not add a generic RC "fix" that counteracts 0.72 with another multiplicative 1/0.72**: result would depend on hook order, tool and contact. Instead keep canonical MR/Mud/Reifen ownership or evaluate RP alone as an alternative physical configuration.

### RP100-02 HIGH — friction wrappers swallow super return and leave transient fields dirty on exception (Lua mock reproduced)

`RealisticPhysicsGrip.lua` wraps `WheelPhysics.updateTireFriction`, temporarily assigns `self.frictionScale` and `self.maxLatStiffness`, invokes `superFunc(self,...)` and restores, **but does not return downstream values** or protect the restore with protected-call/finally. `RealisticPhysicsHop.lua` adds a second, nested wrapper for the same hook, also without returning downstream results or exception-safe restoration.

Exact-source harness:
- downstream callback returns sentinel **123**; wrapped call returns **nil**, while inside callback frictionScale=**0.72** and lateral stiffness=**60** vs 100 base;
- downstream throws in the staged callback: error propagates and leaves `frictionScale=0.72` / `maxLatStiffness=60` rather than restoring to 1 / 100.
- composed Grip+Hop with `0.72×0.20` sends **0.144** to the downstream callback and again discards its return.

**Source-executed Lua failure semantics, not a proven GIANTS real-game crash.** Some native consumers may ignore return values, but nil return is a contract risk. Restoration omission on another mod's error can leak state into subsequent physics updates; never copy the pattern into RC/RE.

### RP100-03 HIGH — HSS 2.0.3.1's newly introduced Realistic Physics adapter is now incompatible with the rewritten fingerprint

The earlier **HSS 2.0.3.1** [full source audit in PR #72](https://github.com/rafaaelalves/FS25_RealismExtensions/pull/72) establishes that its `realisticPhysicsCompat` looks specifically for `wheel.physics.stOrig` created by *old* RealisticPhysics 1.20.2.0. That field is **absent in all 13 rewritten scripts**; the new RP instead uses `rsDamper0`, `rsTV`, `rsT`, `rsTS` and active-wheel coefficients. Thus HSS's source-specific damper/`forcePointRatio` restore **cannot use the old marker and is not evidence of compatibility with this 1.0 rewrite**. Meanwhile HSS owns `setSuspensionMultipliers` while RP independently mutates `p.spring`, `p.deltaYOriginal`, dampers, travel, visual offsets and COM. The **new engine suspension overlap is stronger than before**, not eliminated by the old HSS patch.

**Direct source fingerprint mismatch** and shared physical writers confirmed; actual game crash, double spring force, damping jitters or order of vehicle physics rebuild not observed. No full-stack RP+HSS activation advised; **test as alternatives**, not mutually complementary mods by default. Flag this in HSS PR #72 before anyone treats the earlier compatibility announcement as current.

### RP100-04 MEDIUM/HIGH — default `core.forcePointRatio=0.9` is global

`RealisticPhysics.onWheelLoaded` assigns that single value to **every eligible WheelPhysics instance**, not merely target tractors/trailers; profile detection and spring tuning may preserve stock but force point ratio remains broadly modified. That can change wheel reaction forces, tipping, contact load and RE terrain load/shear input even on an unrelated implement. It also interacts with HSS's prior assumed pressure/contact baseline. A per-vehicle/axle opt-in capability and actual stock baseline are preferable.

### RP100-05 MEDIUM — COM and hitch model are useful but can be physically wrong on unusual trailers

`measureBalance` approximates trailer share from weight-averaged axle position, hitch node and component center-of-mass. It chooses the **heaviest component** as the node to shift and caps the shift at 1.2m with a gradual ramp; it excludes trailers with more than two rigidbody components, and can fail gracefully when node transforms unavailable. The target percentages are generic defaults (8% drawbar, 20% semitrailer); actual manufacturer, hitch design, load position, balance and axle pressures are not directly calibrated. A level loader/platform or tanker with multiple fill units may need additional constraints. This is **positive experimental architecture for load balance**, not an automatic mechanical proof that a 5t tractor can never tow 30t.

### RP100-06 MEDIUM — menu persistence and authority unverified

`rsSuspension` GIANTS config is created at shop-item parse time, with default truck `airRear` and trailer `leaf`, **no price difference**. The source assumes ordinary GIANTS vehicle configuration save/service carries changes, but has no own vehicle state event or per-install schema. Test whether it appears for actual modded truck/trailer, persists through buy/sale/reload, and is consistent on dedicated server/late join. Runtime `rsSet` and tuning values are not synchronized via custom events; a local setting change is not a server physical change. No untrusted MP certification from `multiplayer supported=true`.

### RP100-07 MEDIUM — native wheel rebuild/suspension lifecycle performance

Multiple modules set `p.isPositionDirty` / `p.isFrictionDirty`, call `p.updateBase`, and periodically rescale spring/damper/travel/height based on mass changes or leveling/air kneeling. Central tickers guard same-frame repeat and separate server/attached passes, but all connected implements can be revisited on active vehicles. There is no recorded game benchmark, no explicit cross-mod lease for previous MR/HSS wheel settings, and restoring only RP's initial value may overwrite changed external values if another mod adjusts after capture. RE's geometry/rut model would see altered actual wheel loads/contact, so **do not calibrate RE rut depth on such a changing physical stack**.

### RP100-08 LOW/MEDIUM — external features not supported by new source

The new grip ground class is a native surface-type/wetness heuristic, **not local soil-strength or penetration**; no new dry-only draft/erosion response. The trailer shop configuration provides a selectable vehicle property, **not an inventory of reusable suspension components/parts stored in a garage**. This distinction matters to the user's long-term interchangeable tractor parts concept.

## 3. Positive isolated source tests and consistency checks

1. Exact new/old ZIP CRC PASS, new 13/13 Lua parse, XML parse PASS; manifest's loaded script paths all present. 17 new/168 removed/one changed modDesc; icon byte-identical. **Rewritten architecture**, no exhaustive line-diff equivalence claim.
2. A small `texlua` harness executes the **actual new** `RealisticPhysicsGrip.lua` and `RealisticPhysicsHop.lua` with GIANTS-shaped `WheelPhysics` callbacks, proving RP100-02 and the 0.72×0.20 numeric product without touching game files. This is not a real vehicle tractive-force measurement.
3. The same harness executes `RealisticPhysicsCog.lua` `comSetOffset` with a mocked engine CoM: balance request moves z by -0.3m, cargo lift moves y by +0.2m **without overwriting z**; releasing balance resets only z and retains lift y. This is **genuine positive composition of two CoM subcontrollers**. If another mod controls native `setCenterOfMass` concurrently, there is still no independent owner contract.
4. The new full ZIP contains **zero** `stOrig` references; the HSS source-specific compatibility adapter expects it. This is static mismatch, not FS25 runtime proof.
5. No observed in-game bumper/air pressure, load equilibrium, traction, animation, acceleration limits, persistence, HSS coexistence or MP; source confidence must not be promoted to gameplay VERIFIED.

## 4. Domain ownership crosswalk

| Target owner | New RP overlapping resource | Recommendation |
| --- | --- | --- |
| **MR 0.26.10.08** | Normalized tire traction/engine load, vehicle wheel friction and possibly suspension; RP changes `WheelPhysics.updateTireFriction` and lat stiffness globally. | **Do not combine out of the box**; MR remains effective traction/torque owner. Pairwise A/B only if author wants alternative feel. |
| **Mud 1.3.9 + RC MRMud/MRMudDraft** | Mud local wetness, sink/resistance, pressure; RP only knows GIANTS groundWetness and native ground type and multiplies grip again. | Do not add new Mud torque/traction corrections. Distinguish dry-soil strength from native wet tire classes. |
| **Reifen 1.2.2.70 + MRTireWear** | Worn tire grip and rolling contact; RP tire friction scale and lat stiffness wrappers overlap, and uses width/radius to scale again. | Direct composition risk; no RC version gate/bridge without a monitored ordering/contract. |
| **RMS 0.13.0.1** | Chassis, drivetrain fault and hydraulics wear respond to physical wheel-load distribution; RP CO​M, hitch loads and spring adjustment change input. | RMS remains wear owner; game A/B required before concluding mechanical damage benefits. No RMS function patched by RP source. |
| **HSS 2.0.3.1** | Same spring/damper/position physical actuator and old `stOrig` fingerprint no longer present. | **Previously audited adapter no longer proven applicable; avoid combining**. HSS and RP are alternatives for baseline suspension research, not add-ons to stack simultaneously. |
| **RE PTO** | No independent PTO rpm/shaft/wear update. Loading trailers can indirectly increase motor resistance due to GIANTS. | No PTO code or governor changes. |
| **RE Terrain V3** | No heightmap writer; wheel-load changes indirectly affect rut generation and clipping/force baselines. | Keep RE terrain experiments on stable underlying wheel physics, no new terrain writer or speculative collision. |
| **AI/Courseplay/MP** | Some server-side tickers iterate attached equipment, mode/CoM settings dynamically; shop configs rely on GIANTS persistence. | Test one player→worker→park, shop/reload and untrusted/late-join independently. |
| **RE future parts/garage concept** | Shop suspension selection is one vehicle configuration, without physical inventory/trade-in reuse. | Learn shop integration patterns, not claim complete SnowRunner-style retained parts. |

## 5. What is worth advancing into the RE roadmap?

**Highest-value narrow candidate: `TrailerLoadDistribution` / `CargoCenterOfMass`.** A small **read-only diagnostics-first** feature would measure/estimate trailer axle share, tongue/hitch share, cargo fill/mass and dynamic center of mass, with source/provenance and safe "unknown" status. Only after confirming GIANTS+MR/RMS do not already cover the deficiency should an authorized actuator apply a **bounded COM correction**, scoped to verified trailer configurations, without replacing the native reaction forces elsewhere. The new RP's `comSetOffset` is a strong *design precedent* for composing two independent internal COM demands, but must be reimplemented clean-room and extended with foreign owner handback.

**Second valuable candidate: `SuspensionConfiguration` / `TruckAirSuspension` / `TrailerSuspension`.** A per-vehicle hardware/capability profile and user configuration through GIANTS shop/service interface is more credible than a global profile for all vehicles. Compare **HSS 2.0.3.1 standalone versus RP 1.0 standalone** before selecting an external provider to keep or replacing either in RE. Never invent a second active spring/damper engine while MR or HSS own the same wheel. If selecting a clean-room RE module, model rigid axle as axle joint plus actual tire deformation, load-based stiffness, and true observable ride height.

**Third candidate: transparent traction telemetry without competing friction writes.** Wheel load ratio, apparent tire compression, measured wetness provenance, contact type, current native grip and observed slip can improve diagnostics and tuning. **Do not absorb RP's blanket 0.72 multiplier, extra wet reduction or 0.8 hop friction pulse as production MR+Mud+Reifen dynamics.** The user specifically seeks greater realism, not simply visibly easier wheelspin.

**Still unresolved:** dry/firm soil penetration and implement draft should be researched in existing MR/SoilCompaction + RC MRMudDraft and RE terrain boundaries; the rewritten RP adds no authoritative soil-strength model.

## 6. Focused experiments, not an infinite test plan

On an **isolated disposable save**, **replace** old RP ZIP rather than loading both generations. Start with vanilla vehicle physics and new RP alone, **without HSS**, one ordinary tractor with one drawbar trailer and one semitrailer/truck if available:

1. **Suspension selection:** choose leaf/air/hydro/rigid in shop and/or service; verify a real vehicle's spring/damp/travel, ride height under empty/loaded, air kneel with motor off/detached, sound and no unstable wheel rebuild. Save/reload twice, unload and re-enter. Capture `rsSusp` / `rsTruck` / `rsTSusp` outputs where applicable.
2. **Load/hitch:** compare equal cargo/trailer before/after `rsBalance` and `rsCog`: observed front/rear hitch balance, axle load distribution, CoM vertical position, cornering/tipping at safe speed, dynamics of attached cargo and possible load migration. Avoid a standard "5t vs 30t" conclusion without quantified tractive effort and hitch rating.
3. **Traction sanity:** measure native friction/lat stiffness with `rsGrip off` vs `on`, hard road/grass/dry and wet field, one wheelspin pulse. If ~0.72 independent of already applied MR/Mud/Reifen, that is evidence of duplicate ownership and enough reason to leave grip disabled in a research profile.
4. **Only if standalone works:** introduce **MR only**, separately compare suspension and wheel grip; then try HSS as **alternative** (not concurrently). Reintroduce Mud/Reifen/RMS individually only if a concrete gap remains.
5. **RE terrain:** do not change working rut/recovery baseline; if testing later, compare the same field and wheel with RP OFF/ON only after establishing stable physical loads. No source proof the new RP fixes geometric clipping or writer overcuts.
6. **MP:** do not promote shop/console/network status before owner permissions, hot-change sync, save/reload and JIP evidence.

**Source audit only.** No RC or RE code, version gate, specialist physics, branch merge, user build or third-party source/asset redistribution. Any future RE feature needs independent copyright-compliant implementation, owner approval, measured gameplay advantage and bounded scope.
