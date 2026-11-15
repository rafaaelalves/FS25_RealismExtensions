# Wheel Pallet 1.0.0.1 — source audit and Reifen compatibility decision

Date: 2026-11-15. Exact user ZIP: FS25_WheelPallet.zip, author Guner348, SHA256 342c0cebf0e1a159ca9b65999b9b7222744914be9ec62db611bd6b0111e23122, 110861 bytes. ZIP CRC PASS; 11 files (5 Lua, 4 XML, 2 DDS). 5/5 Lua syntax PASS and 4/4 XML parse. Copyright declarations in Lua say Guner348 all rights reserved, no source reuse license found. Multiplayer supported="true" in modDesc is metadata, not evidence of compatibility.

## Finding 1 — UYT is optional for the core swap

The exact modDesc describes 50keda Use Up Your Tyres as recommended, without an XML dependency. WheelPalletUtil.getTyreWearMod checks g_modIsLoaded.FS25_useYourTyres, then accesses FS25_useYourTyres.UseYourTyres; if absent it simply returns nil. Shop and basic wheel-changing paths continue to work. Public catalogs frequently label it Required, but the author's executable code only requires it to preserve and visualize its specific UYT wear state. Official UYT v1.1.0.0 introduces its own physically degrading wheel and tire replacement model, unrelated to Reifen's existing owner.

## Finding 2 — the full original vehicle is replaced

WheelPallet.performWheelSwap switches the GIANTS wheel configuration to generate vehicle:getReloadXML, restores old configuration on the original, removes original physics, removes the unique ID from VehicleSystem, asynchronously loads a replacement through vehicleSystem:loadFromXMLFile, transfers wheel dirt/mud/UYT travelled values and deletes the former vehicle if load succeeds. On error it attempts to delete partially created instances, re-add original physics and restore its unique ID. The operation is not a pure mesh/part change and source inspection cannot establish crash atomicity or cross-mod save data preservation. Swap prerequisites check model and farm match, no attached implements, driver out, stationary, complete side-positioned pallet set within 3.5m. Existing wheel configurations only; no creation of a brand-new manufacturer wheel option.

This resembles the prior AutoSwitch wheel-rack audit: both reuse full-vehicle reload and expose other mod references and specialized vehicle state to reload lifecycle risks. Current Reifen 1.2.2.70 inherited a prior deleted-vehicle lifecycle concern; RC's September audit of earlier Reifen documented 11760 stale GIANTS wheel/node calls after deletion of a different vehicle. This is a meaningful risk for Wheel Pallet, NOT an in-game reproduction of the same error. RMS wear/service, RE PTO, MR and Courseplay/AutoDrive state and leases also require validation. The latest Wheel Pallet has multiplayer support metadata, not a verified server-authoritative atomic transaction.

## Finding 3 — Reifen wear is not transferred

WheelPalletUtil.getWheelDirt snapshots dirt, mud and ONLY wheel.uytTravelledDist or 0. The reverse helper sets dirt/mud, and restores uytTravelledDist plus its UYT save cache only if UYT is installed. Pallet persistent fields and WheelPalletStateEvent contain vehicle ID/config/slot, dirt, mud and UYT travelled; never Reifen rvRoundPhysicalWear, rvRoundPhysicalRadius, Reifen public compatibility API-v1, Mud pressure or puncture state. A pallet tracks its own rain/wash wetness but vehicle tire wetness is not transferred in the wheel swap helpers.

An original-source mocked Lua test demonstrated: without UYT, shops/dirt helpers remain callable, mud and dirt transfer, and a wheel with Reifen wear 0.6 and physical radius 0.71 produces travelled=0 in the pallet. With only dummy UYT registered, travelled transfers, Reifen stays unchanged. This is a verified adapter omission, NOT proof the GIANTS vehicle reload always loses existing owner savegame entries. Reifen has a different wear unit/curve; mapping its wear percentage to UYT distance would be incorrect and could duplicate grip/radius ownership.

## Finding 4 — multiplayer request authorization needs review

WheelPalletSwapEvent:run verifies the message is coming from a client and pallet/vehicle node references are present, then calls performWheelSwap. getWheelPalletStatus validates the pallet farm equals vehicle farm but does not inspect the requesting connection's farm or permissions. An executed mock of the original event confirms no caller-farm check at event level. Actual ability to exploit this in FS25 depends on its network object permissions; do not claim proven exploitation. The author supports MP, but this should be tested with distinct farms before approval.

## Finding 5 — efficiency, economy, hooks

WheelPalletShop globally wraps BuyVehicleData.buy and several ShopConfigScreen methods; Manager appends VehicleSaleSystem.onVehicleWillSell. These hooks merit ModMixer inspection in the user's large contracts/shop mod stack, but no active conflict is demonstrated. Near player, every 200ms pallet zone checks can scan mission vehicles; 3D wheel/belt previews add a setup cost. Shop wheel configuration option price plus base pallet price is used; this is not full independent real tire/part accounting. Selling last owned/leased vehicle of a model can auto-sell all compatible spare wheel pallets.

## Recommended ownership / future implementation

Do NOT add Use Up Your Tyres alongside Reifen merely to enable Wheel Pallet wear state. Retain Reifen 1.2.2.70 as physical wear owner, MR healthy friction, Mud 1.4.1 as pressure/sink/contact and RC as composer. Existing Reifen getWheelCompatibilityData and getWheelWearRadius API-v1 are valuable read providers but do NOT by themselves authorize safe write/restore of used tires. No RC runtime bridge yet: an external wear adapter would need per-physical-wheel IDs, a versioned serializable owner contract with Reifen, pressure state from Mud, and safe vehicle identity handover. Not a simple renaming of uytTravelledDist. No RE runtime code now.

A future independent RE wheel-set inventory module could implement original storage/workshop/rack workflows, owned sets/finance, service time and reversible transaction states DRAFT -> RESERVED -> PREPARED -> APPLYING -> VERIFIED -> COMMITTED, with replay/rollback. Implement clean-room originals; the uploaded author Lua files have all-rights-reserved headers, not permission to reuse code or art.

First test only in a cloned save: Wheel Pallet alone, one owned GIANTS tractor and two genuine tire configs, swap and reverse with save/reload; then same tractor under exact MR, Mud, RMS beta2, Reifen and RC with measured wear/radius, pressure, service and unique ID before/after. Observe deletion-time errors, attached/AI references and persistence. Multi-farm MP only after valid caller authorization is independently demonstrated. No terrain retest required.

Status: exact ZIP audit plus 5 Lua/4 XML checks and two original-code isolated behavior tests COMPLETE. Game, multiplayer, Reifen physical wear transfer and whole-vehicle persistence UNVERIFIED. Docs-only; no RC/RE build or gameplay hook change.

Prior research: docs/research/2026-10-18-autoswitch-decision-policy-and-wheel-racks.md
RC Reifen lifecycle audit: https://github.com/rafaaelalves/FS25_RealismCompatibility/blob/main/docs/audits/2026-09-23-reifen-delete-lifecycle-audit.md
Official UYT description: https://www.farming-simulator.com/mod.php?mod_id=321793&title=fs2025
Wheel Pallet listing: https://www.kingmods.net/en/fs25/mods/84347/tire-pallet-for-changing-wheels
