# Tillage recovery capability study

Status: **R7 implementation basis / runtime tuning pending**

## 1. Scope

Terrain recovery is no longer modeled as one generic `recoveryPower`.

The physical functions must remain separate:

1. **surface regrade** — ability to move loose/tilled surface soil enough to close RE-owned wheel ruts and approach the current local terrain plane;
2. **surface finish** — ability to crumble clods, level small positive/negative relief and prepare a smooth seedbed;
3. **deep compaction relief** — ability to fracture/loosen a compacted layer below the surface.

R7 uses only the first dimension to parameterize the proven bounded TARGET recovery. The other dimensions are stored now so later soil-compaction and finishing/berm work can reuse the same semantic tool classification instead of inventing a second taxonomy.

## 2. Agronomic evidence

Primary reference: University of Minnesota Extension, “Tillage implements — purpose and ideal use”
https://extension.umn.edu/natural-resources/conservation/agricultural-soil-and-water/tillage-implements-purpose-and-ideal-use

The Extension explicitly includes removing surface compaction and rutting among the purposes of tillage and documents materially different soil actions:

- moldboard plow: about 8–12 in (0.20–0.30 m), full inversion, most aggressive; normally followed by one or two secondary passes with field cultivator/tandem disk to smooth the soil and pulverize large clods;
- disk ripper: about 12–16 in (0.30–0.40 m), deep primary tillage; also normally needs secondary tillage for seedbed finish;
- in-line subsoiler/ripper/paraplow: about 15–20 in (0.38–0.50 m), narrow deep slots, intended to fracture deep compaction while incorporating little residue and leaving most of the surface intact;
- disk: about 5–8 in (0.13–0.20 m), aggressive mixing/lifting and clod reduction;
- tandem disk: about 2–4 in (0.05–0.10 m), less aggressive secondary tillage commonly used for a smooth seedbed;
- field cultivator: common secondary tillage that pulverizes smaller clods.

A second UMN reference reports field-cultivator cover-crop termination at about 3–4 in:
https://extension.umn.edu/agriculture/crop-production/cover-crops/spring-management-of-cover-crops

Power-harrow reference: LEMKEN Zirkon
https://lemken.com/en-en/agricultural-machines/soil-cultivation/seedbed-preparation/power-harrows

LEMKEN describes intensive mixing/crumbling to roughly 15 cm and explicitly frames the machine as seedbed preparation. Their seedbed-preparation material lists levelling, breaking clods and maintaining a consistent working depth as core tasks:
https://lemken.com/en-en/agricultural-machines/soil-cultivation/seedbed-preparation

## 3. FS25 semantic evidence

GIANTS FS25 Cultivator specialization exposes semantic state that is more reliable than model names:

- `spec_cultivator.useDeepMode == true` routes through cultivator-area logic;
- `useDeepMode == false` routes through disc-harrow-area logic;
- `spec_cultivator.isSubsoiler` additionally invokes subsoiler-area logic;
- `spec_cultivator.isPowerHarrow` is an engine-level semantic marker.

Source:
https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=652&version=engine

Plow is a distinct specialization/work-area operation and is therefore integrated through `processPlowArea`, not disguised as a cultivator.

PlowPacker is a useful special case: GIANTS requires both Plow and Cultivator and implements its own `processCultivatorArea`; R7 detects `spec_plowPacker` before the more generic classes.

Source:
https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=777&version=script

## 4. External-mod precedent

`Realistic-Farming/FS25_SoilFertilizer` independently separates subsoiler action from plow action in its compaction model. Its current constants give deep subsoiling a much larger compaction-relief role than plowing and explicitly note that the subsoiler’s real work occurs deep while surface “changed area” can be small.

This is used only as architectural corroboration. RE does **not** copy its numeric values.

Sources:
- https://github.com/Realistic-Farming/FS25_SoilFertilizer/blob/main/src/config/Constants.lua
- https://github.com/Realistic-Farming/FS25_SoilFertilizer/blob/main/CHANGELOG.md

## 5. Capability model

`TillageRecoveryProfiles.lua` defines:

- `nominalWorkingDepthM` — documented agronomic classification scale;
- `surfaceRegrade01` — semantic surface-rut reconstruction capability;
- `surfaceFinish01` — semantic future smoothing/seedbed capability;
- `deepCompactionRelief01` — semantic future deep-soil capability;
- TARGET-controller parameters used by the current geometric recovery.

Initial profiles:

| Profile | Nominal depth | Regrade | Finish | Deep relief | R7 intent |
|---|---:|---:|---:|---:|---|
| CULTIVATOR | 0.10 m | 0.70 | 0.75 | 0.25 | exact R6 baseline |
| SHALLOW_DISC | 0.08 m | 0.65 | 0.90 | 0.12 | broad shallow finishing/regrade |
| POWER_HARROW | 0.10 m | 0.55 | 1.00 | 0.08 | strongest finish, restrained structural fill |
| SUBSOILER | 0.45 m | 0.35 | 0.20 | 1.00 | deep fracture, deliberately weak surface grading |
| PLOW | 0.25 m | 0.90 | 0.35 | 0.45 | strong soil displacement, rough finish |
| PLOW_PACKER | 0.25 m | 0.90 | 0.70 | 0.45 | plow displacement plus improved levelling/reconsolidation |

These 0..1 values are **not measured physical coefficients**. They encode the evidence-supported ordering/function. Runtime TARGET constants are conservative game mappings that must be validated independently.

## 6. Initial TARGET mapping

CULTIVATOR remains bit-for-bit the proven R6 controller:
- radius 0.40 m;
- probe 1.25 m;
- amount 0.75 → max 1.00;
- strength 0.35;
- hardness 0.20;
- max 6 pulses;
- spacing factor 2.10;
- 12 candidate centers/work-area callback.

Other profiles change footprint, intensity, softness, retry depth and candidate density conservatively. They do not alter target-plane safety, SpatialHistory authorization, loaded-contact guard, patch verification or global closed-loop serialization.

## 7. Deliberately deferred

### Roller / packer as standalone finishing tool

A roller/packer should primarily own reconsolidation, crumbling and finish. It should not gain strong deep-rut TARGET authority simply because it can leave a visually level seedbed. That work belongs to a later finish/reconsolidation stage, likely with positive-berm ownership and controlled SMOOTH/TARGET semantics.

### Deep compaction

`deepCompactionRelief01` does not currently edit terrain height. It is reserved for the future compaction/soil-state layer. This prevents the subsoiler from becoming an unrealistic surface grader merely because it works deepest.

### Chisel / modded specialized implements

GIANTS' base Cultivator flags do not fully describe every real-world geometry (for example every chisel configuration). R7 therefore has a safe generic CULTIVATOR fallback. A future compatibility/metadata override may select a more specific profile for a known tool without hard-coding model names into the core resolver.

## 8. Runtime gates

Before tuning profile values broadly:

1. R6 cultivator parity must remain exact.
2. Runtime must report the intended profile in `TerrainRecoveryTools`.
3. Plow must execute through its own work-area path.
4. No profile may bypass causal SpatialHistory ownership or target-plane tolerance.
5. Compare fresh, similarly sized ruts with one pass of each available implement.
6. Observe target jobs, patch convergence, residual reduction and visible finish.
7. Tune game parameters only after profile detection and qualitative hierarchy are proven.

The research-supported hierarchy is the constraint; exact per-profile TARGET parameters remain experimental.
