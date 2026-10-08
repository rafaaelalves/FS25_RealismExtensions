# Research: PTO medium tractor catalog and future upgrade architecture (2026-10-08)

## Scope and completeness

FS25 1.24 medium tractors (vanilla + official DLC) follow the 24-family list on [FS25 tractors category](https://farmingsimulator.wiki.gg/wiki/Tractors/Farming_Simulator_25). The runtime profile registry now has coverage for **22 evidence-backed families**, and explicitly records **2 still pending** (Unimog U1800-2400 and U527-535). The pending models retain the pre-existing conservative native fallback; no unsourced PTO mode is asserted. Fiat 180-90 is retained separately as a mod/legacy profile, and John Deere 6R 155 keeps its specific ratio profile.

"Coverage" means model/family accounted for, not every historical engine/transmission/market trim individually certified. Source evidence and factory-option limitations are attached to runtime profiles as metadata; only `modes` affect gameplay.

## Manufacturer / engineering evidence ledger

| FS25 medium family | Available **default** rear modes in code | Evidence / caveat |
|---|---|---|
| AGCO White 8010 | 1000; 8510 gets 540/1000 | [TractorData 8510](https://www.tractordata.com/farm-tractors/002/3/8/2384-agco-white-8510.html), [8610](https://www.tractordata.com/farm-tractors/002/3/8/2385-agco-white-8610.html), [8710](https://www.tractordata.com/farm-tractors/002/3/8/2386-agco-white-8710.html); series variants differ |
| Case IH Puma AFS Connect | 1000 | [Case IH AFS Puma specification](https://assets.cnhindustrial.com/caseih/NAFTA/NAFTAASSETS/Products/Tractors/AFS-Connect-Puma/AFS_Puma_Spec_Sheet_CIH23020701_pages%20%281%29.pdf); incompatible optional 540/1000, 540E/1000 and 1000/1000E packages |
| Challenger MT600 | 540/1000 | [MT635 technical](https://www.tractordata.com/farm-tractors/003/8/2/3827-challenger-mt635.html); separate MT635 exact ratio from generic MT600 capability |
| DEUTZ-FAHR AgroStar 8.31 | 1000 | [TractorData](https://www.tractordata.com/farm-tractors/002/1/2/2122-deutz-fahr-831.html) |
| DEUTZ-FAHR 6230 TTV | 540E/1000/1000E | [DEUTZ official Series 6](https://www.deutz-fahr.com/en-ea/tractors/series-6) |
| DEUTZ-FAHR Series 7 TTV HD | 540E/1000/1000E | [DEUTZ official 7250 TTV](https://www.deutz-fahr.com/en-eu/tractors/7250-ttv-warrior) |
| DEUTZ-FAHR Series 8 8280 | 540E/1000/1000E | [DEUTZ brochure](https://www.deutz-fahr.com/media/308.8517.7.4-1_Serie_8_Stage_V_PT.pdf) |
| Fendt 700 Gen7 | 540/540E/1000/1000E | [Original Gen7 Fendt data](https://www.fendt.com/int/geneva-assets/article/150214/905890-fendt700variogen7-2201-td-en-web-v2.pdf): rear engine RPM 1618/1283/1649/1308; this is **Gen7**, not Gen7.1 |
| Fiat 160-90 DT | 540/1000 | [DLG independent test](https://pruefberichte.dlg.org/filestorage/FIAT_160-90_Nr976_1985-englisch.pdf): 1950/2074 engine RPM |
| JCB Fastrac 4000 iCON | 540/540E/1000/1000E | [JCB technical specification](https://www.jcb.com/globalassets/digizuite/53520-29846-fastrac-4000-8000-series-e-spec-fr-fr-issue-1-lr/) |
| John Deere 6R 145–185 | 540/540E/1000 | [John Deere 6R 145](https://www.deere.ca/en/tractors/row-crop-tractors/row-crop-6-family/6145r-tractor/); exact engine RPM restricted to the 145 and existing 155 entry, other variants omit ratios |
| John Deere 6R 230–250 | 540E/1000/1000E | [John Deere 6R 250](https://www.deere.ca/en/tractors/utility-tractors/6-family-utility-tractors/6250r/); 540/540E/1000 alternative factory pack, not mixed |
| Kubota M8 | 540/540E/1000/1000E | [Kubota official catalog](https://www.kubotausa.com/docs/default-source/brochure-sheets/2024-full-product-line-brochure.pdf) |
| Massey Ferguson 7S | 540/1000 | [MF 7S options](https://www.masseyferguson.com/en/product/tractors/mf-7s.html) and [brochure with distinct Dyna-6/Dyna-VT gearing](https://www.masseyferguson.com/content/dam/public/masseyfergusonglobal/markets/en_au/assets/product-brochures/tractors/mf-7s/240622_MF_7S_Brochure.pdf) |
| McCormick X8 VT-Drive | 540E/1000/1000E | [McCormick X8 brochure](https://www.mccormick.it/wp-content/uploads/2024/02/X8-2024-Brochure-_02.02.2024-1.pdf) |
| MB-trac 1100–1500 | 540/1000 | [MB-trac spec](https://www.tractorbook.de/traktoren/mercedes-benz/mb-trac-1100-1300-1500-1976-1987/technische-daten/) |
| MB-trac 1300–1800 Turbo | 540/1000 | [TractorData 1800](https://www.tractordata.com/farm-tractors/002/9/4/2947-mercedes-benz-trac-1800.html) |
| Unimog U1800–2400 | PENDING | No sufficient proof of **installed** rear PTO package on the specific official DLC model |
| Unimog U527–535 | PENDING | Same; optional/implement drive must be identified separately |
| New Holland T7 LWB PLMI | 540/540E/1000/1000E | [New Holland T7.260 technical](https://www.berchtold.com/equipment/new-equipment/new-holland/new-holland-ag/tractors-and-telehandlers/T7-with-PLM-Intelligence/T7-260/) 1931/1598/1912/1583 engine RPM |
| STEYR Absolut CVT | 540/540E/1000/1000E | [STEYR engineering data](https://www.steyr.ro/en/agricultural/2/absolut-cvt); optional two-speed PTO packages differ |
| Valtra T | 540/1000 | [Valtra T5 brochure](https://www.valtra.com/content/dam/Brands/Valtra/en/Products/Brochures/2021/Valtra-t5-series-tractor-brochure-en-screen-2021.pdf) 1890/1897 engine RPM; 540E optional |
| Versatile Nemesis | 540E/1000/1000E common; 175–210 adds 540 | [Official Nemesis specification](https://www.versatile-ag.com/NA/downloads/brochure/Versatile-Brochure-Nemesis.pdf) |
| Zetor Crystal HD | 540/540E/1000/1000E | [Official Zetor technical](https://www.zetor.com/zetor-crystal-technical-parameters) |

## Important modeling limitations

1. **Factory variants are not upgrades.** Real units may have mutually exclusive rear PTO gear packs installed at manufacture. Current FS25 identity seldom exposes those choices. Registry defaults to documented common or conservative mode subsets; no "union of all optional speeds".
2. **Nominal engine RPM is model/gearbox-specific.** Exact published rpm is used where available (Fendt 700, Fiat, Deere variants, NH T7, STEYR, Valtra T). When only speeds are documented, `Model.resolveMotorRatio` estimates based on `motor.maxRpm` and 0.78 economy factor. This remains a physics approximation requiring calibration against FS25's actual engine specs.
3. **Front PTO is a different installed hardware axis** (shaft and drive ratio) from rear PTO, despite often sharing a nominal 1000 rpm. Do not enable front capability based on rear brochures.
4. **Stable identity is not the vehicle's horsepower.** Tokens intentionally identify documented models; mismatch in an aftermarket mod may require explicit mapping or native fallback.
5. **Series aliases must not override a more specific model**. Model-specific entries precede families; tests cover Fendt, Deere, Versatile and AGCO.
6. **Catalog incomplete at transmission/config variation level**. A future audit should read exact FS25 motor/transmission option selected when available before trusting rare mode claims.

## Future: PTO upgrades (DESIGN ONLY, NO CURRENT GAMEPLAY)

The upgrade is a distinct component installed on a **vehicle instance**, not on a model family. Separate these four concepts:

- **`tractorModelId`**: evidence/catalog vehicle identity and immutable architecture limits.
- **`factoryPtoPackageId`**: baseline installed as shipped; selected from actual FS25 factory configuration if exposed.
- **`installedPtoPackageId`**: resulting upgrade/retrofit part set (rear PTO ratio pack, front PTO module, shaft/spline connector). Must be purchased and installed later, with cost, duration, compatibility and physical constraints.
- **`operatorState`**: selected speed and hand-throttle setting; current runtime fields, saved independently of hardware.

Future resolution: `resolveCapability(vehicle, installedPackage?) -> available rear/front speed set + ratios + limits + provenance` and a capability revision. A purchase changes hardware and increments capability revision; it does **not** automatically select PTO gearing or activate attached implements. Physical feasibility prevents adding a 1000E pack to a tractor with unsuitable driveline, PTO shaft, clutch or rated torque.

Install/remove/reconfigure protocol (future): authoritative server transaction, vehicle stopped, PTO disengaged, valid workshop location, wallet/cost accounting, durable savegame state, deterministic network sync, migration for old saves, opt-in UI. Reject an upgrade that would strand a currently engaged PTO implement. Factory package/upgrade persistence must be independent from operator `mode` and `handThrottlePercent`.

**Critical migration**: old saves currently persist only `mode` and `handThrottlePercent`. Introducing packages must default old tractors to their evidenced factory state, never retroactively grant missing PTO speeds. If current selected mode becomes unavailable, migrate to a valid safe selection while preserving the operator throttle without faking hardware.

Implementation seam to preserve today: public API `RealismExtensionsPTO.getVehicleState`, `PTOResolver.resolveCapability`, stable mode IDs, and RC's `vehicle+revision+canonicalPtoRpm` cache. Future installed package lookup should occur on load/retrofit events, not per-frame.

## Performance and test gates

- One capability resolution on load or a real attachment/hardware change; no frame-by-frame catalog scanning.
- Keep existing PR smoke requirements. Profile expansion changes power-to-shaft ratio and available PTO positions, so *unit tests alone are not a guarantee of correct in-game gearing for every model*. Future runtime spot checks should include 540-only, 1000-only, 3-speed, 4-speed and optioned tractor with PTO load.
- Never merge unrelated terrain or RC physics changes as part of a PTO catalog addition.

## Evidence handling correction

- Fiat 180-90 uses its own [Fiat model source](https://www.tractordata.com/farm-tractors/002/0/2/2021-fiat-180-90.html), not a borrowed 160-90 source.
- Challenger MT635 engine RPM 1991/2091 is specific to that variant; MT645–MT665 have modes but no borrowed numerical targets.
- John Deere 6R 145 engine RPM values are specific to that model; 165/175/185 modes do not borrow the 145 nominal ratio. The 155 retains its existing profile.
- Manufacturer manuals for the Unimog [U2400](https://www.camion4x4.com/fiche_tech/u2400) and [modern Unimog](https://special.mercedes-benz-trucks.com/en/the-unimog-implement-carrier/general/start.html) confirm optional mechanical PTO installations, but not which rear PTO configuration is fitted in the FS25 DLC. Therefore both remain unresolved rather than falsely unlocked.
