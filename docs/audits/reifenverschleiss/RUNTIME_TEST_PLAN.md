# Reifenverschleiss focused runtime test plan

Runtime work is deferred until the game machine is available.

Use the RE evidence ladder: static -> harness -> runtime -> physical/causal -> scenario -> regression.

## T1 — clean install settings default
Remove/back up Reifen settings XML and start a disposable session.

Verify displayed/effective lifetime:
- expected from constant: 1500 km;
- expected from current source flow: 350 km.

## T2 — wheel eligibility matrix
Test:
- normal pneumatic tractor tire;
- dual/twin;
- solid wheel;
- PalletTruck;
- Kärcher/helper equipment;
- implement caster/helper wheel;
- crawler internal wheel.

Record manifest classification and saved wear entry.

Goal: define WheelEligibility contract.

## T3 — healthy friction ownership
At ~0% wear, sample:
- incoming coefficient from GIANTS/MR/Mud;
- Reifen target;
- outgoing coefficient.

Test several terrain/wetness states.

Expected direct Reifen behavior:
upstream terrain coefficient is normalized/replaced.
Expected RC MRTireWear:
healthy composed grip is preserved exactly.

## T4 — high-wear curve monotonicity
Use wheel/tire setups spanning low and high `frictionScale`.

Sample target at:
0, 15, 25, 40, 60, 75, 80, 85, 90, 95, 100%.

Invariant for desirable wear model:
increasing wear never improves final grip.

## T5 — deleted vehicle lifecycle
Reproduce old 1.2.2.65 scenario with 1.2.2.67:
- controlled/known vehicle;
- delete/sell/reset object;
- remain in save for >15 seconds.

Instrument:
- currentVehicle;
- wear update calls;
- ground-sample calls;
- WFS node/shape mappings;
- deleted/isDeleting state.

Acceptance after fix:
zero calls into deleted wheel/entity nodes.

## T6 — EWFS ownership scope
In multiplayer or representative mission setup test:
- own vehicle;
- leased own-farm vehicle;
- mission vehicle;
- foreign-farm vehicle;
- map/traffic motorized object if reachable.

Record WFS registration/lock state.

Expected desired policy:
EWFS acts only on intentionally eligible player-farm equipment/controller paths.

## T7 — EWFS performance
Large fleet save.

Record per second:
- mission.vehicles scan count;
- vehicles scanned;
- registered update count;
- updateBlocker calls;
- CPU time.

A/B current 10ms scan vs lifecycle/slow discovery prototype.

## T8 — mission reload lifecycle
Without restarting FS25:
1. load save A;
2. trigger repair/repaint and confirm reset callback;
3. leave to menu;
4. load save B;
5. repeat.

Expected current-source issue:
message subscription can be absent in save B.

## T9 — native repair/repaint service semantics
At controlled nonzero wear:
- repaint only;
- repair only;
- custom WHEELS;
- custom TRACKS;
- custom ROLLERS;
- custom ALL.

Record which wear components reset and cost charged.

Decision goal:
choose intended service semantics before any patch.

## T10 — workshop affordability
Use farm balance lower than replacement price.

Attempt purchase.

Record:
- reset performed?;
- money before/after;
- negative balance behavior.

## T11 — workshop multiplayer authorization
Two farms/clients.

Client A attempts purchase for:
- own vehicle;
- Client B vehicle if synchronized/targetable.

Server telemetry:
- requesting connection farm;
- vehicle owner farm;
- authorization result;
- charged farm.

Security invariant:
requesting connection cannot modify/spend another farm without explicit permission.

## T12 — workshop requester sync
Client initiates valid purchase.

Record wear on:
- server;
- requesting client;
- second same-farm client;
- foreign client.

Expected current-source risk:
requesting client receives no reset mirror because it is the ignored connection.

## T13 — multiplayer wear progression
Host/dedicated + at least two clients.

Use same vehicle and compare every 30 s:
- selected reference km;
- wheel wear channels;
- track/roller state;
- visual wear;
- server structural radius.

Goal:
prove whether normal wear is synchronized or merely independently simulated.

## T14 — multi-farm save persistence
Dedicated/hosted server with two farms.

Accumulate wear on vehicles from both farms, save/reload.

Verify both persist identically.

## T15 — roller random factor MP
Purchase/spawn a fresh tracked vehicle in MP with no saved Reifen state.

Capture `rollerLifetimeFactor` on server/clients before save.

Invariant:
one authoritative factor per track.

## T16 — rubber vs steel roller speed penalty
Bring both track types to equivalent roller wear.

Record:
- roller detection;
- wear;
- motor maxForwardSpeed;
- applied factor.

This resolves source-vs-public-description intent.

## T17 — WFS brake-force composition
During the 5 s lock window alter brake force through another owner/failure system.

Check whether WFS restore overwrites the new value.

## T18 — roller max-speed composition
Combine worn roller speed limit with another mechanical/damage speed cap.

Desired composition:
most restrictive valid limit wins without either owner permanently overwriting the other's baseline.

## T19 — FORCE-WEAR 2WD/4WD/AUTO
Use RMS + MR + Reifen on switchable drivetrain.

Hold load/route constant and test:
- 2WD;
- 4WD;
- AUTO disengaged;
- AUTO engaged.

Capture per wheel:
- RMS drive mode;
- MR `mrIsDriven`;
- Reifen differential share;
- Reifen forceWear delta;
- applied torque.

Critical invariant:
a genuinely disengaged axle receives no longitudinal drive-force wear.

## T20 — differential cache invalidation
Switch drive mode after Reifen has cached differential shares/capacity.

Check whether shares change.

If an integration is needed, invalidate only on effective drivetrain-layout changes.

## T21 — Mud local wetness integration
Find two field locations with same global weather wetness but different Mud local wetness.

Record Reifen:
- wetScale source;
- ground class;
- distance/slip wear factor.

Current source expected:
same Reifen wetness despite different Mud local state.

Then test a scoped local-wetness adapter without copying Reifen formulas.

## T22 — structural radius + Mud transient radius
Controlled worn tire at several pressures/mud states.

Capture:
- GIANTS radiusOriginal;
- Reifen rvRoundPhysicalRadius;
- Mud __tpOrigRadius;
- Mud desired/current radius;
- final physics.radius.

Invariant:
structural wear is baseline exactly once; transient pressure/sink remains on top.

## T23 — packaging/reload state
Load multiple saves in one process and monitor:
- source-time settings reads;
- WFS state maps;
- Workshop install flags;
- Mud compatibility install flags.

Goal:
separate benign one-time global wrappers from stale per-mission state.

## T24 — custom workshop localization
Run EN/PT-BR language.

Verify which text remains German.

Low priority, but closes the UI audit.

## T25 — performance profile
Large fleet with:
- many ordinary wheels;
- crawlers;
- Mud active;
- AD/CP active.

Profile separately:
- core currentVehicle;
- Motorized automated-driver bridge;
- 1 s ownership caches;
- visual workers;
- Mud overlay;
- EWFS.

Expected hotspot candidate: EWFS fleet polling.


## T26 — Raptor left/right visual asymmetry
Force clearly different wear on left and right Raptor crawlers.

Capture:
- core wear per crawler;
- shader `crawlerProfileWear` per render node.

Expected current source:
both sides receive the maximum crawler wear.

Acceptance after fix:
each render side tracks its own crawler state.

## T27 — special crawler workshop reset matrix
For Raptor, A8800/Hover, Hannibal and Volvo:
1. create visible track wear;
2. use native repair;
3. use native repaint;
4. use custom ALL;
5. use custom TRACKS.

Immediately after each action, before entering/driving the vehicle, read:
- persistent wear;
- renderer-specific shader parameter;
- visible state.

Goal:
prove the current ALL/native reset lag and verify a unified refresh dispatcher.

## T28 — visual numeric-node cache reuse
Sell/return and respawn the same crawler family repeatedly in one session.

Instrument:
- old/new node IDs;
- slot-cache entries;
- original/current material IDs;
- whether material installation runs;
- shader parameter availability.

Critical case:
engine reuses a numeric node ID while stale Reifen cache entry remains.

## T29 — generic/Raptor material cache lifecycle
Return/sell a generic rubber crawler and a Raptor, then spawn another instance.

Record cached original->wear material IDs and verify every cached material entity is still valid before setMaterial/use.

Compare with A8800/special-steel fresh-per-node strategy.

## T30 — early crawler classification timing
Probe:
- onLoad;
- onLoadFinished;
- immediate visual refresh;
- first controlled frame.

Record:
- loadedCrawler availability;
- motionPath kind;
- vehicle type cache.

Goal:
determine whether a premature false/nil classification can occur before render geometry settles.

## T31 — Volvo safety path
Instrument the exact Volvo immediate-load path.

Verify:
- `_inImmediateLoadRefresh` state;
- controlledVehicle state;
- attempted material replacements;
- frame spacing before parameter write.

Do not deliberately remove the remaining controlled-vehicle safety gate in production runtime.

## T32 — second-save EWFS entry hook
Without restarting FS25:
1. load save A and verify VehicleSystem.setEnteredVehicle refresh;
2. return to menu;
3. load save B;
4. enter/tab a vehicle.

Record:
- WFS.installed;
- vehicleSystemEnterHooked;
- whether save B's VehicleSystem method is wrapped;
- latency until HUD/lock state refreshes through fallback paths.


# 1.2.2.70 additional runtime gates

The existing T1-T32 remain applicable unless a test explicitly targets a
finding resolved statically by the update.

## T33 — API-v1 purity under full stack

Stack:
- MR;
- Mud 1.3.6;
- Reifen 1.2.2.70;
- current RC candidate.

Instrument:
- `getCompatibilityApiVersion()`;
- direct `getWearAppliedTargetForScale(..., 1.0)`;
- legacy/final `getWearAppliedTarget()`;
- final `tireGroundFrictionCoeff`.

Invariant:
- API-v1 direct result remains Reifen-only;
- RC does not alter the public API function identity;
- final physical grip is MR healthy grip × Reifen wear degradation exactly once.

## T34 — both Mud/Reifen installation orders

Force/observe both effective orders if possible:
1. RC target wrapper established before Mud's late Reifen compatibility;
2. Mud compatibility already top-level before RC target composition.

Expected:
- identical final grip;
- `mudApiV1Rewraps` is at most the one audited setup repair;
- boundary settles;
- no continuing hook-order polling after setup;
- Reifen API v1 remains untouched.

## T35 — structural-radius provenance

Controlled worn tire with Mud pressure/sink.

Capture:
- Reifen `getWheelWearRadius()`;
- `__rvDesiredRadius`;
- `rvRoundPhysicalRadius`;
- MRMud structural snapshot;
- ExtensionsStateProvider structural radius/source;
- final `physics.radius`.

Invariant:
- API-v1 wearRadius is the preferred structural owner truth;
- Mud/private channel agrees or is only fallback;
- pressure/sink never feeds back as Reifen structural wear.

## T36 — canonical mod-name detection

Run using the standardized `FS25_Reifenverschleiss.zip` package.

Confirm RC detects:
- active TireWear;
- version `1.2.2.70`;
- canonical mod environment;
- SOURCE_COMPATIBLE confidence.

Legacy versioned filename detection remains regression-only.

## T37 — API contract fail-closed diagnostic

Development/harness-only unless a safe malformed fixture exists.

If version reports/claims the audited release but API v1 is incomplete or
reports a different API version, MRTireWear must refuse source confidence rather
than silently use legacy assumptions.

## T38 — localization/service regression

With PT-BR/EN (or another available language):
- open Settings;
- open custom running-gear workshop;
- inspect type/size/price/action labels;
- perform no purchase unless using a disposable save.

Goal:
confirm R-33/R-34/R-35 are genuinely resolved in normal UI, not only statically.

## Updated promotion gate for 1.2.2.70

Before promoting from SOURCE_COMPATIBLE to runtime-validated:
1. MRTireWear ACTIVE with 1.2.2.70;
2. API-v1 purity test passes;
3. healthy/no-wear MR grip remains unchanged;
4. controlled wear applies degradation once;
5. structural radius uses Reifen public API provenance;
6. Mud pressure/sink remains transient;
7. no new RC/Reifen/Mud Lua errors;
8. existing high-value T19/T20 and T21 opportunities remain separate follow-up
   investigations rather than blockers for the version upgrade.
