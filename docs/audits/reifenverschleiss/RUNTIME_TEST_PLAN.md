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
