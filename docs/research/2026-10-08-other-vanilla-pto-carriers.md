# Official non-tractor drivables: mechanical PTO scope review (2026-10-08)

## Decision and evidence hierarchy

This is a targeted follow-up after cataloguing 75 shop entries in Small, Medium and Large Tractors. **The FS25 base game has two additional official PTO-relevant drivable families outside those shelves:** Pfanzelt Pm Trac III (Forestry Tractor) and Merlo MF44.9CS-170-CVTRONIC (Telehandlers). Both have source-backed real *external rear mechanical output PTOs* but must have an actual native GIANTS `outputPowerTakeOffs` entry in the active game configuration before the RE PTO system exposes gearing.

- Official FS25 roster: [All Equipment](https://farmingsimulator.wiki.gg/wiki/All_Equipment/Farming_Simulator_25) and [Forestry](https://farmingsimulator.wiki.gg/wiki/Forestry/Farming_Simulator_25), [Telehandlers](https://farmingsimulator.wiki.gg/wiki/Merlo_MF44.9CS-170-CVTRONIC).
- Evidence 1 = manufacturer or engineering specification documenting the actual physical PTO speed(s).
- Evidence 2 = actual running vehicle's GIANTS output hardware. **Neither the shop category, 3-point hitch, hydraulic lines nor internal motor load establishes a PTO shaft.**
- Evidence 3 (currently unavailable here) = direct inspection of official installed FS25 vehicle XML and exact output-to-rear attacher mapping. CI harness is not a replacement for that evidence.

## Added candidate profiles

| In-game category / vehicle | Real external PTO | Runtime default | Source | Critical limitation |
|---|---|---|---|---|
| Forestry > Pfanzelt Pm Trac III | Current *standard* rear 540E/750/1000; *alternative* rear 1000E/1000/1450; front PTO a separate optional 1000 drive | **540E, 1000** only if GIANTS output exists | [Pfanzelt official Pm Trac III](https://www.pfanzelt.com/en/forestry-tractors/pmtrac/) | 750/1450 are *distinct shaft speeds* outside the current four-mode system; an [older model brochure](https://grapak.com/en/product/multipurpose-tractor-pfanzelt-pm-trac) lists 540/540E/1000/1000E, but we must not mix factory generations/packages |
| Telehandlers > Merlo MF44.9CS-170-CVTRONIC | Rear mechanical, electrohydraulic clutch, selectable **540/1000** | **540, 1000** only if GIANTS output exists | [Merlo archive/technical specifications](https://www.merlo.de/teleskoplader/multifarmer/mf-44-9/) and [Merlo original brochure](https://storage.googleapis.com/merlo-storage/38af6c2f-6fdd-479f-a37b-a99a115cc5af) | Rear 3-point hitch alone is insufficient; actual FS25 output PTO may differ from real equipment |

Runtime profiles use `verifiedOutputCarrier` and are discoverable by model-specific display/name/path tokens only. They each expose immutable `catalogGroup` provenance and `requiresOutputPto=true`, sharing the already-tested capability resolver used on Large Tractors. No new per-frame resolver or periodic polling. No RC bridge changes.

The Pm Trac is not guaranteed to have rear PTO just because the real manufacturer offers one; FS25's [forestry tractor](https://farmingsimulator.wiki.gg/wiki/Pfanzelt_Pm_Trac_III) features integrated crane, winch and blade. The Merlo has an in-game rear three-point hitch, but the [in-game listing](https://farmingsimulator.wiki.gg/wiki/Merlo_MF44.9CS-170-CVTRONIC) does not independently establish a rear output shaft. If the exact FS25 vehicle lacks `outputPowerTakeOffs`, these profile entries deliberately remain **inactive**.

## Reviewed and deliberately excluded from the generic agricultural PTO selector

| Official drivable family / category | Disposition | Reason |
|---|---|---|
| **NEXAT carrier vehicle** (NEXAT DLC) | **Separate research / no 540/1000 profile** | Modular carrier distributes power to proprietary crop-processing modules, not proven to expose a selectable conventional rear agricultural 540/1000 spline. [GIANTS NEXAT description](https://www.farming-simulator.com/dlc-detail.php?dlc_id=fs25nexat); [system architecture](https://www.nexat.de/produkte/) |
| **Prinoth Leitwolf Agripower** (Miscellaneous) | Exclude pending independent rear mechanical PTO hardware proof | Self-propelled silage leveler. A third-party mod adds rear 3-point linkage, but that is not vanilla proof of PTO. [Category](https://farmingsimulator.wiki.gg/wiki/Miscellaneous_Drivables/Farming_Simulator_25); [non-vanilla modification](https://www.farming-simulator.com/mod.php?mod_id=311955) |
| **Ropa NawaRo-Maus** | Exclude | Self-propelled biomass pickup/conveyor: internal powered systems do not imply a separately selectable output PTO |
| **JCB World's Fastest Tractor** | Exclude | Racing/prototype demonstration vehicle; no source confirming normal rear 540/1000 work PTO |
| **Heizomat Heizotruck V2** (Agro Trucks) | Exclude pending proof | Integrated chipper/vehicle auxiliary power is not automatically a tractor-standard implement PTO |
| **Conventional telehandlers** (JCB 541-70, Kramer KT557, Manitou MLT, Fendt Cargo, Sennebogen 340G, Schäffer, Merlo EW) | Exclude | Loader boom hydraulics are not independent selectable 540/1000 output; **Merlo Multifarmer is the deliberate exception** |
| **Self-propelled combines, forage and root crop harvesters, swathers, grape/olive harvesters** | Exclude generic PTO speed control | Their internal header/rotor/hydrostatic drive may need *independent* power-demand simulation but not an operator-rear-PTO gearbox selector |
| **Self-propelled mixers, chippers, pumps, sprayers and loaders** | Exclude generic selector | Internal attachment motor drive does not demonstrate a separate 540/1000 selectable tractor PTO shaft |
| **Road trucks, hooklift/forestry/agro trucks, cars, motorcycles, quads** | Exclude generic selector | Truck gearbox PTO/hydraulic ancillary outputs are technically real but distinct from agricultural independent mechanical shaft. Need a separate truck-PTO model if later required |
| **Forwarders, tree harvesters, skidders, heavy log loaders** | Exclude generic selector | Work hydraulics and crane/timber processing do not mean an external 540/1000 PTO output |
| **Other ModHub vehicles, including GIANTS-authored downloadable mods** | Out of official base/DLC scope here | External downloadable mods are not part of the user's requested vanilla inventory; they can be audited separately as expansion candidates |

## Design notes and future upgrades

- *No invented package modes.* Pm Trac 750/1450 and Lindner 750/1400, Fendt 1300 require **new nominal-shaft-RPM mode identifiers**, savegame/stream migration, UI labels and MR/RMS generic-ratio consumers. They are not economy 540E/1000E.
- Merlo and Pm Trac become natural prototypes for later **individually installed output PTO gearboxes**, with a factory package + upgrade package stored per *vehicle instance*. Do not automatically grant hardware merely from physical support documented in a brochure.
- Optional front shaft is a distinct package/position; output proof currently checks *existence of some output*, not its exact front/rear direction. The honest follow-up is to inspect native output `attacherJointIndices` and the exact FS25 XML configuration, not guess position based on the machine name. Guard stays fail-closed on no-output configuration.
- Maintains current `PTOControl.prerequisitesPresent` (Motorized + Drivable + AttacherJoints), so only vehicles with needed specializations can receive operator controls. No new callbacks/timers. [GIANTS PowerTakeOffs API reference](https://gdn.giants-software.com/documentation_scripting_fs22.php?category=48&class=534&version=script).
- Diagnostic boundary: sources establish **real rear PTO support**; automated tests establish **our modeled behavior** for simulated inputs. They do **not** prove those two optional outputs are installed on the user's specific game vehicles. This remains a compact runtime/FS25 XML validation task when those specific machines are used.

## Automated regression acceptance

`tests/pto_resolver_harness.lua`: two models × (name matching, exact file tokens) × both physical output states and generic specialization-only case; checks mode count, mode forbiddance and category provenance. Also verifies names of NEXAT, Prinoth, Ropa, other loaders and already-covered Fendt 728 do not spuriously resolve to these PTO profiles.

### Pfanzelt installed-package uncertainty

The proposed 540E/1000 RE profile is a **projection of the current documented standard Pm Trac III package into our supported 4-mode engine**, not an assertion that every factory version has both gears. The optional Pfanzelt rear gearbox changes the economy gear family (1000E, 1000, 1450). If the FS25 unit uses the optional package, 540E must be withheld and the installed `ptoPackageId` must distinguish it. A populated GIANTS output proves **a shaft is present**, but not the shaft's gear package. This limitation remains documented for later XML validation / factory-package architecture; do not advertise full physical accuracy yet.
