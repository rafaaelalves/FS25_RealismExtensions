# Reifenverschleiss persistence, multiplayer and workshop audit

## 1. Persistence architecture

Reifen declares `rvOwnWearPersistence` as a GIANTS vehicle specialization.

Before vehicle types are finalized, the loader injects that specialization into all vehicle types.

Lifecycle:
1. `onLoad` captures raw saved OWN-WEAR without building the final wheel/crawler manifest too early;
2. `onLoadFinished` resolves the completed vehicle and applies saved state;
3. visual state is refreshed after restoration;
4. `saveToXMLFile` writes wear under the native vehicle XML key.

This is a strong persistence design.

## 2. Persisted identity

Wheel states use stable wheel keys based primarily on wheel index.

Track states include:
- key/signature;
- crawler index;
- side;
- all wear channels;
- roller state/lifetime.

The source contains migration handling for earlier track-key forms.

## 3. Ownership limitation in persistence

Persistence uses `isOwnedFarmVehicleForPersistence`, which requires:
- valid, non-deleting vehicle;
- current player's farm;
- OWNED/LEASED;
- no mission state/attacher chain.

This is reasonable in single-player/client-local thinking.

For a server-authoritative multiplayer save, however, tying save eligibility to `g_currentMission:getFarmId()` is suspicious:
- dedicated server may have no normal player farm;
- hosted server can have a host farm different from another player's farm;
- other farms' wear can therefore be omitted from server persistence.

Status: **STRONG_CANDIDATE** pending dedicated/multi-farm runtime semantics.

## 4. Ongoing wear is not explicitly network replicated

The only custom event found is the workshop replacement event.

Normal per-wheel/per-track wear progression has no:
- update stream;
- dirty flag;
- wear-state event.

Core wear calculation is not server-only.

Each peer can therefore maintain its own local OWN-WEAR state.

Further divergence inputs:
- reference lifetime is stored in local `modSettings/FS25_Reifenverschleiss/settings.xml`;
- roller lifetime factor is randomized before being persisted;
- local player-farm gating can differ by peer.

Physical round-tire radius is changed only on server, while visual state on clients reads local wear.

This architecture needs explicit multiplayer validation before `multiplayer supported=true` can be considered causally proven.

## 5. Workshop purchase event authority

`RPReifenWechselnEvent` is server-authoritative for price/reset/money, which is the correct direction.

But the server request handler checks only:
- vehicle exists and is synchronized;
- connection exists.

It does **not** verify:
- connection's farm owns/leases the vehicle;
- player has workshop/service permission;
- requested vehicle is in an eligible workshop context;
- connection is authorized to spend the vehicle owner's farm money.

The server derives `farmId` from the vehicle and debits that farm.

This is a real authorization defect in multiplayer.

## 6. No affordability check

The release source explicitly says:
`TEST build: deliberately NO balance/affordability check.`

After successful wear reset it unconditionally calls:
`addMoney(-price, farmId, ...)`.

Therefore server-side purchase acceptance is not conditioned on sufficient balance.

This is a release-build economy defect/choice and should be fixed upstream or with an explicit version-gated hotfix if relevant.

## 7. Requesting-client synchronization bug

Client purchase path:
1. send `RPReifenWechselnEvent`;
2. return true locally without resetting local wear.

Server:
1. resets authoritative/local server wear;
2. broadcasts the same event with the requesting `connection` as ignoreConnection.

The requesting client is therefore excluded from the only explicit custom reset mirror.

Because ongoing wear is not otherwise a replicated state, the buyer can retain stale local wear/visual state.

Other clients can also reject the mirrored reset because `resetRunningGearWorkshop` applies local-player-farm eligibility.

This is a concrete MP protocol flaw.

## 8. Repair/repaint reset bridge

Reifen deliberately subscribes to:
- `VEHICLE_REPAIRED`;
- `VEHICLE_REPAINTED`.

Both call a custom wear reset.

The reset clears wheel/track distance/slip/time/force wear and visuals. The generic reset does not separately reset roller wear; the dedicated workshop ALL path does.

This means ordinary native repair and even repaint can provide a free tire/track wear reset outside Reifen's dedicated component-pricing system.

This appears intentional in source, so classify it as a **confirmed balance/design loophole**, not an accidental typo.

It is also an unusual coupling: repaint semantics should probably not own mechanical running-gear replacement.

## 9. Mission reload subscription bug

At mission unload:
`g_messageCenter:unsubscribeAll(ReifenVerschleissInstance)`.

But the persistent core table keeps:
`_workshopMessageHooksInstalled = true`.

On a later mission loaded in the same game process, the loader sees the flag and skips subscription.

Result:
native repair/repaint reset callbacks can disappear after changing saves without restarting the game.

This is a confirmed lifecycle bug.

## 10. Source packaging loads modules redundantly

modDesc extraSourceFiles includes:
- WFS;
- purchase event;
- Loader;
- Settings;
- Workshop.

The Loader itself sources:
- purchase event;
- Core;
- Visual;
- Settings;
- Workshop;
- WFS;
- all Mud compatibility modules.

Therefore:
- WFS and purchase event are parsed once before Loader and again inside Loader;
- Settings is loaded inside Loader and then again afterward by modDesc;
- Workshop is loaded inside Loader and then again afterward.

The current code mostly survives because actual hooks install later and globals are reset before mission load.

Still, this causes duplicate settings-file I/O and brittle source-time state replacement.

Clean packaging should define every module once and explicitly order dependencies.

## 11. Hard-coded German workshop UI

Although modDesc contains localization keys, much of the custom dialog is hard-coded German:
- detected parts;
- classification;
- total price;
- purchase question;
- custom button labels.

This is a straightforward localization/polish defect for non-German users.

## 12. Hotfix priority

If optional owner-mod fixes are carried locally, multiplayer/lifecycle fixes have higher priority than cosmetic UI:
1. vehicle deletion/runtime eligibility;
2. workshop event authorization + requester synchronization;
3. mission reload subscription reset;
4. EWFS stale mappings/cleanup;
5. clean-install reference setting;
6. affordability;
7. localization/packaging cleanup.
