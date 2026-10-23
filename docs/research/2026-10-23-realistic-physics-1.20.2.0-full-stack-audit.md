# Realistic Physics 1.20.2.0 — exact ZIP, dry/firm-ground claim, wheel hop and RC/RE stack audit

**Audit date:** 2026-10-23. **Source:** exact supplied `FS25_RealisticPhysics.zip` (not a repository clone or guessed version). **Intent:** learn and selectively design for RE, not assume adoption. **Final decision:** **RESEARCH-ONLY / DO NOT INSTALL IN PRIMARY STACK / DO NOT ABSORB AS-IS.** No RC or RE physics code modifications; no runtime/game-save testing. Separate earlier HSS 1.1.0.0 adoption decision remains test-external-first, narrow RC handoff if an actual conflict, no premature HSS code port.

## 0. Identity and integrity

- Package `modDesc.xml`: **Realistic Physics 1.20.2.0**, author **Rónai Márk**, `descVersion=114`, `multiplayer supported=true`. The author expressly forbids redistribution/modification without written permission; no independent LICENSE granting source re-use.
- **Exact ZIP SHA-256:** `04e19cf8ad0310eda538f72ad09cb2d1b0ea52f19a0d1f5b3246979f1b74fc72`; **128,774 bytes**, **170 files**: `scripts/RealisticSuspension.lua` plus **29 category profiles**, **138 vehicle-type profiles**, `modDesc.xml`, `icon.dds`. Total **168 Lua files**, 1 XML, 1 DDS.
- Full CRC PASS, XML strict parse PASS, `168/168` Lua sources included in modDesc's `extraSourceFiles` and verified with `texlua --luaonly` / `loadfile`; no extra declared Lua missing, no duplicate paths.
- Public third-party listing [LS Portal Realistic Physics beta](https://ls-portal.eu/realistic-physics/) and [fs25.net, 2026-10-22](https://fs25.net/realistic-physics-v-beta/) describe category/type suspension and slip-induced hopping more pronounced on hard ground. These pages are not verified bytewise official downloads and **do not attest v1.20.2.0 exact SHA**; the **ZIP modDesc is authoritative** for source version. User's file is not internally a dry-soil simulation, regardless of expectations inferred from its promotional text.

## 1. Ground/dry soil: actual source vs what the user wants

**It does NOT compute soil dryness, drying cycles, penetration resistance, compaction, the extra draft of a plow in very dry soils, field cultivator penetration, water balance or persisted terrain deformation.** There is no native moisture/SoilCompaction/Mud state reader, no soil-history writer, no `setTerrainHeight*` or `TerrainDeformation` API, no density-map soil-moisture update. Its `getGroundClass(p)` serves **only as a multiplier to wheel-hop intensity**, not a strength model:
- If `p.isOnField==true` or `p.densityType>=2` where `isOnField` is absent: class **`field`**, factor **0.1**, irrespective of dry/moist/wet soil.
- Otherwise classify `tireGroundFrictionCoeff>=1.1` as **road** = 1.0, `>=0.8` as **hard** = 0.6, smaller as **soft** = 0.0. When those signals are missing it defaults to **road**, not UNKNOWN.
- Same cultivated land cannot transition from “dry-hard” to “wet-mud” in this model unless external engine classification changes; there is **no dry hard soil pressure/penetration physics**. `tireGroundFrictionCoeff` is a tire/terrain *friction coefficient*, not a unique soil classification — MR, Mud, Reifen and RC already adjust tire physics. A driven-wheel friction change could thus alter the label “road vs hard” without any material transition.
- **What actually merits future RE/RC source research**: dry-soil penetration / shear strength **as a separate phenomenon** in the *existing* MR/Soil/Mud draft ownership, not another traction multiplier. Soil strength increases on drying in many soils ([South Dakota State Extension](https://extension.sdstate.edu/soil-penetration-resistance-soil-health-indicator), [Penn State Extension](https://extension.psu.edu/diagnosing-soil-compaction-using-a-penetrometer-soil-compaction-tester)). Very wet cohesive/adhesive soil can also increase *tillage draft* while reducing penetration resistance: one simplistic `hardness = 1 - wetness` mapping is unsuitable. See [USDA ARS “Soil Moisture Effects on Energy Requirements…”](https://www.ars.usda.gov/ARSUserFiles/60100500/csr/ResearchPubs/raper/raper_04g.pdf).
- **Ownership proposal, not a patch:** inspect MR's existing dry draft, SoilCompaction's measured/agronomic compaction and RC `MRMudDraft` interfaces and actual native `PowerConsumer` work depth; decide whether any high-dryness resistance is unowned. If it is, prefer an independent **dry-strength `SoilCondition` observation/parameter** feeding the *canonical* MR draft (possibly through a narrow versioned RC bridge), with local wetness/source trust and precise implement eligibility. Do not double-adjust motor torque, hydraulic limits or wheel friction in RE.

## 2. Actual source behavior: suspension and wheel hop

### 2.1 Load-time per-wheel suspension profiles

`WheelPhysics.loadFromXML` is globally wrapped via `Utils.overwrittenFunction`; it first delegates to `superFunc` and, after a successful load, stores initial `forcePointRatio`, `suspTravel`, `deltaY`, spring, 4 damper parameters and transRatio/restLoad; it applies **vehicle type first, then store category**.

**The profile volume is misleading:** all **167** category/type profile heads set `forcePointRatio = 0.9`, **161/167 set `damper = 1`**, the other 6 leave it nil; **all 167** leave base `spring`, `suspTravel`, `initialCompression`, `springMult`, `damperMult`, `restLoad`, `restLoadMult` unset. Only **three category profiles** (`TRACTORSS`, `TRACTORSM`, `TRACTORSL`) assign rear `suspTravel = 0.10`; no source profile uses `front`, `suspended` or `rigid` numeric overrides. Most claimed machine individuality is **a configuration architecture capable of it, but not populated with distinct current values**.

When damper 1 is configured, the code replaces the four native damping components using factors 1, 0.7, 0.9 and 0.18 (0.9 × 0.2), rather than scaling original damper; it can alter true loaded vehicle behavior substantially and conflict with specific vehicle XML and HSS spring/damping owner. `forcePointRatio=0.9` on essentially every wheel is broad and not model-specific. The three rear tractor travel=0.10 changes physical wheel travel while attempting to preserve original `deltaY/suspTravel` proportion; not proof every model has matching rear suspension geometry.

The mod offers console tools `rsStock`, `rsCategory`, `rsList`, `rsListAll`, `rsSet`, `rsShow`, `rsApply` and `rsApply hard` to inspect current/vanilla settings and reapply. `rsApply hard` calls `WheelPhysics.removeFromPhysics` / `addToPhysics` for every selected wheel; use only on disposable save and avoid during active towing/suspended loads. No persistently saved user profile edits or versioned config XML are supplied.

### 2.2 Wheel hop (oscillating friction + vertical force)

`RealisticSuspension.updateHop`, appended to `Wheels.onUpdate` (or `onUpdateTick` fallback), runs for server-side motorized vehicles with wheels. It reads:
- wheel axle angular speed (wheelShape when possible, fallback `getRotation(driveNode/repr)`), physical wheel radius, and `vehicle.lastSpeedReal * 1000` (m/s);
- wheel slip speed = `abs(axleRadPerSec) * radius - abs(vehicleSpeed)`; min +1.0 m/s slip threshold, full intensity at +7.0 m/s; a 0.5 m/s minimum wheel speed;
- engine `actualLoadPercentage`/`smoothedLoadPercentage` or throttle; attachment-mass ratio and a 0.2 maximum damping from weighted tow mass; individual ground multipliers above;
- time phase `2π * 2.5 Hz`, amplitude **0.98**, smoothing `min(1,dt * 0.01)`; `p.rsHopMul` drives periodic friction loss and `addForce` applies alternating vertical load at wheel nodes if native function and mass available.

**Critical numeric caveat:**
- `fadeSpeed = 1.8 m/s` means the hop amplitude reaches zero at **6.48 km/h**, even though an inline Hungarian comment says roughly **22 km/h**. This is a calculation from the actual code, not an in-game speed measurement.
- When the modulation state reaches intensity 1 and `sin(phase)=1`, requested multiplier `1 - 0.98 * 1 = 0.02`, but the `updateTireFriction` hook clamps to `max(0.05,mul)`: **frictionScale can be temporarily reduced by up to 95% per callback**. This is an artificial grip oscillation layered over MR healthy friction + Reifen degradation, NOT a measured soil contact-stick-slip force.
- `kick=11.5` contributes an alternating mass-proportional force; the source calls `addForce(wheel.node, ..., mass * kick * state * sin / wheelCount, ...)`. GIANTS's wheel/body mass unit and correct rigidbody target are not demonstrated here. Do **not** label the visible bounce physically calibrated; test wheel joint target and tractor/implement topology.
- `updateTireFriction` wrapper writes `self.frictionScale` temporarily and restores afterward, but **does not return** `superFunc`'s return value and **is not exception-safe** if a downstream hook errors. Since `MRMud` and `MRTireWear` compose the same method, load order may alter private baseline and post-hook output; any true integration needs an actual observed conflict test.
- `getGroundClass` defaults to road on missing coefficients, and field strength factor 0.1 even in dry soils; the `densityType>=2` heuristic is not a trusted universal field surface map. Wheel angular rotation fallback and opposite/wheel-turn speeds can produce false slip under steering or for nonstandard wheel hierarchy, so test manually before trusting the effect.
- The `Wheels` update wrapper is server-gated, but **the mod has no dedicated network events** for hop state or console configuration. Its `multiplayer supported=true` manifest cannot certify visual/physics uniformity or client authority.

### 2.3 Source robustness and CPU budget

The only executable logic is the main 34 KB script and its 167 parameter-table files; the build is broad in file count but not broad in independent physical simulation. Hook ownership is global across vehicle types, not per wheel opt-in. `onWheelLoaded` handles errors via `pcall`; `updateHop` uses `pcall` with a one-time logged error, potentially **silently disabling observability for subsequent failures** without a safe force reset; no dedicated uninstallation and no leased spring/damping ownership. `rsApply` can trigger wheel physics rebuild with no guaranteed foreign-mod state preservation.

A success log from `modDesc` or Lua parse proves *loading*, not that MR pressure/spring/radius snapshot correctly composes with HSS, Reifen, Mud and RMS across save/vehicle update/physics reconstruction.

## 3. Exact target-stack collision matrix

| Target owner | Realistic Physics effect | Evidence-tier decision |
| --- | --- | --- |
| **MR 0.26.10.08** | Temporary override of `frictionScale` inside `WheelPhysics.updateTireFriction`, another load-time spring/damper writer; `getMotorLoad` may read MR synthetic load | **Direct shared hook/writer**; do not enable blind, preserve MR actual traction. |
| **Mud 1.3.7** | Classifier reads **already composed** friction coefficient, not true dry soil; hop forces modify wheel contact load and sinking, implicitly changing Mud response | Unmodelled interaction; no extra mud/dry owner; **no RC generic bridge**. |
| **Reifen 1.2.2.70 / MRTireWear** | Oscillating `frictionScale` can be applied before/after relative Reifen worn-grip factor; `rsApply` rebuild may lose structural radius / pressure if not preserved | Direct order concern, untested. Avoid competing wear/damage owner. |
| **RMS 0.12** | Body/engine wear and differential behavior indirectly affected by artificial grip/wheel hop; dynamic physics rebuild | No direct new RMS engine model, but no evidence RMS suspension/tire rebuild is safe with whole-stack. |
| **HSS 1.1** | HSS is a **runtime spring/damper/height controller** and intercepts wheel `setSuspensionMultipliers`; RP pre-sets base damper/force/travel and can later reapply/rebuild. | **Separate contenders for suspension authority**. Do not run HSS and RP simultaneously in first test. Prefer HSS as external capability if game tests justify it; do not import RP presets into HSS/RE without measured value. |
| **RC 0.2.0.9** | `MRMud` and `MRTireWear` both compose WheelPhysics methods. No present RC RealisticPhysics bridge or risk rule; `rcHooks` reports identity only. | RC code unchanged, package version unchanged. Keep issue/test evidence, not a speculative wrapper that cancels mod behavior. |
| **SoilCompaction** | No compaction/yield/soil-strength writer; any hop changes driven contact load, not persisted agronomic compaction | No integration. |
| **RE Terrain V3 / TerraFarm** | No actual heightmap writer; wheel force may indirectly influence RE wheel-load/rut decisions once terrain enabled | No code port; RE remains sole native rut geometry owner. |
| **RE native PTO V1.6** | Engine “load” used only to scale cosmetic/mechanical hop; not physical PTO shaft torque/ratio | No PTO changes. |
| **Courseplay, AI, trailers and mod vehicles** | Server-side `Wheels` hook may act on AI motorized vehicles; profile load hook touches trailers and implements, `getAttachedMassRatio` traverses attachments | No observed integration proof. Avoid main save with untested whole-mod interactions. |

## 4. Specific opportunity: two *different* research tracks

### A. Dry, hard ground and implement workability (user's goal — NOT implemented by this mod)

1. **First audit existing owners**: native terrain density/crop status, Mud local wetness, SoilCompaction type/soil density or stress state, MR draft calculation, RC `MRMudDraft` and RE TerrainResponseModel. Avoid inventing second environmental moisture variable.
2. **Separate mechanisms**: (i) traction and mobility (MR+Mud+Reifen), (ii) implement **draft force vs moisture, depth, soil texture, adhesion, pre-compaction** (MR/Soil + possible narrow bridge), (iii) physical rut depth and work pass recovery (RE), (iv) optional vegetation/growth consequences (future environmental owner). A dry field might have hard cohesive clods, while dry loose sand may have poor support; this is not one friction coefficient.
3. **Propose a read-only, source-labeled `SoilStrengthContext` only if data available**: moisture regime, prior compaction, treatment history, soil type and supported depth, with measured/estimated/unknown confidence. Feed canonical MR/Soil implement demand by a specific audited owner interface **without overwriting motor load or wheel friction in RE**.
4. **Controlled tests:** the *same physical plow/cultivator/subsoiler*, same soil class/previous compaction, humidity dry↔intermediate↔very wet, two depths, native motor torque and actual kN draft if available. Distinguish slip limitation vs power requirement, and ensure actual field deformation/recovery still happens under RE V3. Do not add “all dry fields are sticky/hard” or an arbitrary global penalty.

### B. Real wheel hop and suspension dynamics (mod's real value, but overlap)

If desired after HSS A/B, consider a **read-only wheel-hop detector** as an optional diagnostic using actual wheel angular speed, vehicle velocity, wheel force, surface contact, and root-body vertical acceleration. First test if GIANTS+HSS+MR already produce hop at an equivalent controlled slip; if they do, no new physics. If absent and desirable, design a *single physical suspension controller* that owns the chassis excitation and respects original spring/damper, not an unrelated sinusoid that reduces healthy tire friction up to 95%. This would be a future RE behavior only after an explicit decision that HSS is external or replaced.

### C. Config system lesson

The 167 profile files do demonstrate a **scalable opt-in parameter declaration style**, not real unique machines tuning today. Prefer RE-specific sparse data profiles keyed to known capability, physical chassis/axle properties and versioned defaults; avoid 167 nearly-identical files that falsely signal calibrated vehicle support. Their vanilla-value console `rsStock` is a useful *observability pattern*, not reusable source code.

## 5. Minimal isolated research tests if still curious

No primary-save adoption advised. On a disposable backup:
1. **Vanilla+RealisticPhysics only:** `rsStock` on small/large tractor and trailer, compare original/current per wheel, observe hard road wheel-spin vs cultivated field; check actual fading above **6.48 km/h**, while original comment incorrectly quotes 22.
2. **MR+RealisticPhysics only:** same tractor and surface, log `updateTireFriction` wrapper ordering, nonzero wheel hop and actual driving; ensure no disappearance of MR baseline friction or erroneous 95% repeated traction losses.
3. **Do NOT combine HSS in early tests.** HSS and RP both own suspension behavior, with no joint owner contract; comparing source-hopping vs HSS real wheel load response separately is enough for a research decision.
4. **After that only if worthwhile:** add Mud/Reifen and compare wheel sink/worn radius, dual tire and steering wheel slip, Courseplay active, two save/reloads, frame-time/hitch body alignment. An all-mod smoke with no exception would not certify correct physics.
5. **MP:** manifest claims supported, but absence of hop-specific authority events or settings sync means dedicated client behavior remains unverified.

**No RC bridge, no RE simulation code, no new ZIP/build, and no change in RE Terrain/PTO production toggles.** This audit is docs-only by design; RE GitHub Actions excludes docs-only changes. See HSS [1.1 source review](2026-10-23-hydraulic-suspension-system-1.1.0.0-audit.md) for external-first recommendation and narrow RC bridge conditions.
