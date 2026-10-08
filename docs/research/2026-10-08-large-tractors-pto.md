# Large Tractors — PTO research and implementation ledger (FS25 1.24)

Date: 2026-10-08. Scope: all **26 entries** in the official FS25 Large Tractors shop, including Plains & Prairies, Highlands Fishing and the Black Edition. Inventory cross-check: https://farmingsimulator.wiki.gg/wiki/Tractors/Farming_Simulator_25 . This covers the official store, **not third-party tractor mods**.

Of 26 entries, **25 have evidence-backed family mode definitions; 1 stays pending (Big Roy)**. These are not 25 confirmed installed PTO hardware sets. The implementation requires actual native GIANTS outputPowerTakeOffs on the vehicle before advertising any large tractor PTO gearbox. It is intentionally conservative, particularly for optional/conditional tractor PTOs.

**Terminology:** `540E` is the 540 rpm shaft at economy engine speed; `1000E` analogously. All ratios describe *rear* PTO; front PTO is separate. A documented optional real-world package is not the same thing as equipped hardware in FS25.

| FS25 Large tractor | Evidence-backed default/candidate rear gears | Manufacturer/technical source | Uncertainty or variant | 
|---|---|---|---|
| New Holland T8000 | 1000 | [Technical reference](https://www.tractordata.com/farm-tractors/006/3/2/6323-new-holland-t8050.html) | 540/1000 optional |
| Versatile 976 | 1000 | [Technical reference](https://www.tractordata.com/farm-tractors/001/3/6/1361-versatile-976.html) | only with PowerShift |
| Ford 976 Versatile | 1000 | [Technical reference](https://www.tractordata.com/farm-tractors/010/1/4/10148-ford-976.html) | same PowerShift-only limitation |
| Versatile 1156 | 1000 | [Technical reference](https://www.tractordata.com/farm-tractors/001/3/6/1363-versatile-1156.html) | historical rear PTO |
| Ford 1156 Versatile | 1000 | [Technical reference](https://www.tractordata.com/farm-tractors/001/3/6/1363-versatile-1156.html) | Ford-badged counterpart; game output must exist |
| Versatile 1080 Big Roy | PENDING | [Technical reference](https://tractordata.com/farm-tractors/001/3/6/1367-versatile-1080.html) | prototype; no verified PTO shaft, no mode unlocked |
| JCB Fastrac 8000 iCON | 540E/1000 | [Technical reference](https://www.jcb.com/globalassets/digizuite/53520-29846-fastrac-4000-8000-series-e-spec-fr-fr-issue-1-lr/) | not the 4000's four-speed PTO |
| Valtra S Series | 540E@1577 /1000@1882 | [Technical reference](https://www.valtra.com/content/dam/Brands/Valtra/en/Products/Brochures/2023/Valtra-S6-brochure-en-2023-screen.pdf) | 1000E@1605 is alternative factory pack |
| Massey Ferguson MF 9S | 540E/1000 | [Technical reference](https://www.masseyferguson.com/en_gb/product/tractors/mf-9s.html) | 1000/1000E alternative factory pack |
| Versatile MFWD | 1000 | [Technical reference](https://www.versatile-ag.com/na/pages/product_mfwd.php) | 540/1000 optionally on smaller engine versions |
| New Holland T8 GENESIS | 1000 | [Technical reference](https://assets.cnhindustrial.com/nhag/nar/en-us/assets/pdf/agricultural-tractors/t8-plm-spec-sheet-us-en.pdf) | other shaft options vary by model |
| John Deere 7R | 1000 | [Technical reference](https://www.deere.com/assets/pdfs/region-1/products/tractors/7R_Brochure.pdf) | manual 540/1000 and 540E/1000/1000E options not silently added |
| John Deere 8R | 1000 (8R 250 verified @1995) | [Technical reference](https://www.deere.com/en-us/products-and-solutions/tractors/row-crop-4wd-tractors/8r-250-tractor-odexmvjx) | 540/1000 or 1000/1000E options |
| Fendt 900 Vario | 540E/1000 | [Technical reference](https://www.fendt.com/nl/geneva-assets/article/126276/700249-fendt900vario-2101-td-en.pdf) | 1000/1000E alternative |
| Case IH Magnum AFS Connect | 1000@1803 | [Technical reference](https://www.caseih.com/en-gb/europe/products/tractors/magnum-afs-connect/magnum) | 540/1000 optional |
| Fendt 1000 Vario | 1000/1000E | [Technical reference](https://api.fendt.com/techdata/BR/pt/1161054/Fendt%201000%20Vario%20Gen3) | PTO itself optional; real 1300 outside current model |
| John Deere 8RT | 1000 (engine RPM not cross-inferred) | [Technical reference](https://www.deere.com/assets/pdfs/region-4/industries/government-and-military-sales/contracts/price-pages/agricultural/A2_6000-8000_20210203.pdf) | family 1995 engine target should be calibrated |
| Fendt 1100 Vario MT | 1000/1000E | [Technical reference](https://api.fendt.com/techdata/GB/en/1152877/Fendt-1100-Vario-MT) | PTO optional; 1300 option depends trim |
| John Deere 9R (440–640) | 1000 | [Technical reference](https://www.deere.ca/en/tractors/4wd-track-tractors/9r-590/) | optional PTO fit |
| John Deere 8RX | 1000 (8RX 340 verified @1995) | [Technical reference](https://www.deere.com/en/tractors/row-crop-tractors/row-crop-8-family/8rx-340-tractor/) | 540/1000 or 1000/1000E optional |
| Versatile DeltaTrack | 1000 | [Technical reference](https://www.versatile-ag.com/NA/pages/product_dt.php) | optional output; do not infer from category |
| John Deere 9RX (490–640) | 1000 | [Technical reference](https://www.deere.ca/en/tractors/4wd-track-tractors/9rx-590/) | independent rear shaft |
| CLAAS XERION 12 | 1000@1500 | [Technical reference](https://www.claas.com/caas/v1/media/1328946/data/738cb304d52f63b9be6f3d4eb853b7c9) | rear output hardware verified in game |
| Case IH Steiger Series | 1000 | [Technical reference](https://online.flippingbook.com/view/341953633) | no 540; confirm physical PTO |
| Case IH Steiger 715-785 Black | 1000 | [Technical reference](https://online.flippingbook.com/view/341953633) | same mechanical family, distinct shop entry |
| John Deere 9RX (710–830) | 1000 | [Technical reference](https://www.deere.com/en-us/products-and-solutions/tractors/row-crop-4wd-tractors/9rx-830-tractor-otkymfjx) | no 540; high-hp variant |

## Runtime protection introduced with the catalog

`Profiles.LARGE_CATALOG` records all 26 identities, `Profiles.PENDING_LARGE` explicitly holds the unique Versatile 1080 prototype. Profiles for the other 25 are authored through `largeTractor(...)` with `requiresOutputPto = true`, unlike pre-existing medium and legacy profiles.

`PTOResolver.vehicleHasOutputPto` now confirms real GIANTS `getOutputPowerTakeOffs()` (or populated `spec_powerTakeOffs` outputs) on *those* profiles. `resolveCapability` fails closed with `PROFILE_OUTPUT_UNVERIFIED` and **no modes** if no such output is installed. This prevents the prior potential false positive where the mere presence of a high-horsepower tractor profile allowed PTO registration. The same model with actual PTO hardware retains its real researched modes. When a real optional gearbox exists but FS25 does not expose which package was selected, we expose the conservative shared or base mode set, never the union of mutually exclusive factory packages.

**Load-order limitation:** this is a conservative snapshot at vehicle onLoad. If third-party modifications create output PTO connectors only after that point, the system should later adopt explicit event-based re-resolution for that tractor. We intentionally do not add per-frame retries or speculative front-to-rear PTO resolution now.

### Known engineering limits / future upgrades

1. Current engine model supports only 540 / 540E / 1000 / 1000E. Fendt 1000/1100 1300 RPM physical PTO and alternative 900 RPM modes are documented real machines but **not implemented**, and must not be rounded to the 1000 family. Represent these as deferred modes requiring an extended typed mechanical ratio model and appropriate UI/network/save migration.
2. Published engine RPMs are used only when sourced for the gearbox. Other gears still rely on `PTOModel.resolveMotorRatio` generic extrapolation; these **remain approximate** and require validation against motor/transmission options.
3. A model-level family mode set can differ from the equipment actually factory-fitted. Before future PTO upgrades, introduce fitted `ptoPackageId` separately from model, a capability revision, server-authoritative workshop transaction, persistent hardware schema and migration. No upgrade/gameplay implemented here.
4. An output may have front/rear locations. Current GIANTS guard confirms any native output, **not its direction**. Future implementation must verify output position and shaft type before selecting a rear gearbox; do not interpret a front-only connection as proof of rear PTO.
5. Never treat an absent rear shaft as a fault or automatically grant the 540 baseline for these larger machines. A prototype or haulage-focused articulated tractor may properly have no PTO.

### Verification matrix

`tests/pto_resolver_harness.lua` verifies 25 Large-Tractor profile identities, their supported and forbidden modes, actual output present vs absent, 26/26 inventory coverage, Big Roy fail-closed, selected family engine ratios, and high-risk overlaps: 7R vs 8R vs 8RX vs 9R vs 9RX; Steiger Black Edition vs base; Ford vs Versatile 976.

Next physical integration samples should prioritize:
- PTO present and absent on a model with optional output (9R/DeltaTrack/Versatile 976).
- Valtra S, Fendt 900 and MF9S (exclusive gearbox options).
- CLAAS XERION 12 @ 1500 engine RPM and 1,000 shaft RPM.
- 8R/8RX selected 1,000 governor under MR+RMS load.
- Case Magnum 1000, PTO under AI and manual operation.
- Confirm there are **no frame-hot re-detections**; bridge caches per vehicle+revision.
- 1300 RPM model migration is explicitly deferred.

### Evidence-scope correction

- John Deere 7R's `1950` target is published in an older 7R brochure but not specific to every 2020 FS25 7R. Generic 7R retains 1000 gear without this exact nominal engine ratio.
- John Deere 8RT engine RPM must not borrow 8R data without a tracked-tractor drivetrain spec.
- John Deere 8R 250 and 8RX 340 use their own manufacturer-verified 1000@1995 values; other models in these families only claim the standard 1000 PTO gear. The tests distinguish the submodels.
