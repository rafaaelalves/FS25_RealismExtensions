# Reifenverschleiss deep architecture/compatibility audit

Updated: 2026-10-06

Exact source audited:
- mod: `FS25_Reifenverschleiss_RELEASE_1_2_2_67`
- version: `1.2.2.67`
- ZIP SHA-256: `4d645f1e1e2ac3aaef4f4291fe2de9f27835efa499a45069a1c8172bedd6ff3a`
- author: duestereLegende
- declared multiplayer support: true
- Lua source size: ~11.2k lines

Comparison baseline:
- previous RC source: `1.2.2.65`
- ZIP SHA-256: `06a5b97cf3a9abebd98922cdba8861a06269324ac111e91acc64e2d357155712`
- `.65 -> .67` changes are almost entirely Mud compatibility/version-detection changes. The wear core differs only by its version string; Visual, WFS, Workshop, Settings and purchase-event source are unchanged.

## 1.2.2.70 update

Latest exact source:
- mod: `FS25_Reifenverschleiss`
- internal version: `1.2.2.70`
- ZIP SHA-256: `938363f661dc8a6943fcddc5fa766d63ff79702962746b513e39cdef3e172d6a`
- public release label: `V1.2.2.7`
- detailed delta: [UPDATE_1_2_2_70.md](./UPDATE_1_2_2_70.md)

The recommendation remains **KEEP + INTEGRATE**.

The important release change is not a new wear solver. It is a substantially
better interoperability surface:
- compatibility API v1 with explicit friction baseline;
- public wear-only structural radius;
- bundled compatibility data with ownership semantics;
- coordinated Mud radius channel;
- stable mod filename and real l10n.

RC now prefers the public structural API but deliberately does **not** wrap or
change the meaning of `getWearAppliedTargetForScale()`. MRTireWear remains
necessary because Reifen's own final friction writer is still absolute.

The older 1.2.2.67 section below remains the historical baseline rather than
being rewritten.

Purpose: complement the existing RealismCompatibility Reifen audit. RC already proved MR tire-wear friction composition and worn structural-radius composition. This audit studies Reifenverschleiss itself: wear model, wheel/track classification, force/load semantics, visuals, physical radius, EWFS, workshop economy, persistence/networking, lifecycle, performance and cross-stack opportunities.

## Executive result

Recommendation: **KEEP + INTEGRATE**.

The core idea is valuable and fills a real gap:
- persistent per-wheel/per-track wear;
- independent distance/slip/time/force wear channels;
- load/ground/weather-dependent wear;
- crawler/roller support;
- structural tread-radius loss;
- workshop replacement/economy;
- AI/Courseplay/AutoDrive wear support.

Do not absorb the full mod into RE. RE should consume structural tire/contact state where useful; RC should arbitrate cross-mod physics ownership.

However, Reifen has three surfaces that deserve more scrutiny than the wear engine itself:
1. **absolute friction ownership**, which is semantically incompatible with MR/Mud-style composed terrain grip;
2. **EWFS/roller speed-control**, which wraps broad control/physics paths and has weak lifecycle/ownership boundaries;
3. **multiplayer/workshop authority**, where local-player-scoped wear state and server-authoritative purchase logic do not form a clean synchronized model.

## Architecture at a glance

```
                        OWN-WEAR
                           |
         +-----------------+------------------+
         |                 |                  |
      WHEELS             TRACKS            ROLLERS
         |                 |                  |
   DIST / SLIP       DIST / SLIP        mileage-only
   TIME / FORCE      TIME / FORCE       lifetime factor
         |                 |                  |
         +--------+--------+------------------+
                  |
             persisted state
                  |
        +---------+----------+
        |                    |
   friction malus       visual/structural wear
                             |
                  round-tire radius baseline
                             |
                       Mud compatibility

Control-side systems:
  EWFS startup lock
  AutoDrive wear speed cap
  rubber-track roller max-speed cap

Service-side systems:
  workshop inventory/pricing
  network replacement event
  native repair/repaint reset bridge
```

## Important version result

The RC's source-compatible acceptance of Reifen `1.2.2.67` for `MRTireWear` is justified:
- core wear/friction code is unchanged from `1.2.2.65`;
- physical visual/radius code is unchanged;
- workshop/WFS code is unchanged;
- `.67` adds Mud runtime/version detection and Mud overlay compatibility updates.

Therefore old runtime proof of the MRTireWear core still applies to that exact behavior, while the new Mud compatibility paths require their own interpretation.

## High-value positive patterns

### Crawler is a first-class wear object
Reifen explicitly groups GIANTS crawler members and persists one wear object per track rather than treating internal pseudo-wheels as independent tires. This is a strong precedent for RE ContactFootprint.

### Wear channels are separated
Distance, slip, active work time and longitudinal force each have independent state and can be diagnosed/persisted independently. This is materially better than one opaque "wear += speed * dt" accumulator.

### Persistence lives with the vehicle
The mod injects a real vehicle specialization and stores OWN-WEAR under each vehicle in native `vehicles.xml`, with capture at onLoad and application at onLoadFinished. This is a strong lifecycle pattern.

### Structural radius is explicitly named
Round tires expose:
- `rvRoundOriginalPhysicsRadius`;
- `rvRoundPhysicalWear`;
- `rvRoundPhysicalRadius`.

That is a substantially better cross-mod contract than deriving permanent tread loss from transient `wheel.physics.radius`.

### Snow composition is relative
The snow add-on preserves the previous/native friction result and applies a relative factor. This is the pattern the general wear-friction path should follow as well.

## Highest-value findings

Detailed evidence lives in `STATIC_FINDINGS.md`.

The most consequential current findings are:
- clean-install lifetime setting resolves to 350 km despite `DEFAULT_KM=1500`;
- generic wheel manifest has no pneumatic/solid/helper-wheel eligibility abstraction;
- normal wear friction is an absolute final target, not a relative degradation;
- the old deleted-vehicle lifecycle problem remains structurally present in `.67`;
- EWFS scans/locks beyond the OWN-WEAR ownership scope and retains stale numeric node/shape mappings;
- EWFS fleet scanning is effectively per-frame and duplicates already-registered vehicle updates;
- native repair/repaint deliberately resets custom wheel/track wear, creating a service/economy bypass;
- client workshop purchase lacks farm/permission/affordability validation;
- requesting MP client can be excluded from the only reset-sync event;
- continuous wear state is not modeled as an explicitly server-authoritative replicated state;
- Mud local wetness is not consumed by Reifen wear physics;
- `.67` Mud "version profiles" are detection metadata but do not actually select different compatibility behavior;
- FORCE-WEAR derives/caches driven-wheel torque shares from GIANTS differential topology and does not consume RC/MR dynamic `mrIsDriven` state;
- public behavior says tracked-vehicle roller speed malus covers rubber and metal tracks, while source deliberately applies it only to `RUBBER_TRACK`;
- physical width/radius factors are computed for diagnostics but do not directly feed DIST/SLIP wear; width/radius matter mainly in FORCE-WEAR torque capacity;
- source packaging redundantly loads several modules twice;
- Raptor visual wear collapses per-track asymmetry to the most worn crawler;
- special crawler full-reset paths do not immediately clear renderer-specific wear parameters;
- multiple visual "weak" node caches are numeric-keyed and therefore do not expire with vehicle/node lifetime;
- the Volvo immediate-load safety flag is never assigned;
- EWFS's mission-specific VehicleSystem enter hook is not reinstalled after loading a second save in the same process.

## Relationship to existing RC integration

### MRTireWear
Keep the current ownership:
- MR owns healthy/base terrain-tire friction;
- Reifen owns relative degradation from wear;
- RC prevents Reifen's absolute coefficient write from replacing MR/Mud terrain semantics.

### MRMud structural radius
Permanent Reifen tread loss is structural baseline.
Mud pressure/sink is transient deformation.

The existing RC structural-radius composition is conceptually correct and already runtime validated.

### MRRMS / dynamic driven wheels
The later RMS 0.10.0.0 deep audit closed this source-level question.

RMS physically removes/rebuilds the GIANTS differential graph during 2WD/4WD/AUTO transitions, while Reifen FORCE-WEAR computes and caches torque shares from that graph. The cached shares can therefore become stale after an RMS topology change. RC MRRMS repairs MoreRealistic metadata but does not invalidate Reifen's cache.

This is now a confirmed static cross-mod mismatch. Focused runtime remains useful to quantify the wear error and validate the eventual fix.

## Audit status

Static/source audit: **CLOSED for 1.2.2.67 and updated through exact 1.2.2.70 source**. Further source work should be triggered by a runtime finding or a concrete cross-mod question.

Runtime validation: **deferred**. Tests are listed in `RUNTIME_TEST_PLAN.md`.

The next useful source work should be cross-mod-specific rather than another undirected reread.
