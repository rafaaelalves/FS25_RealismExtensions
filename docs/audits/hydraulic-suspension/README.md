# Hydraulic Suspension System assimilation audit

Updated: 2026-10-04

Exact package audited:
- mod: `FS25_HydraulicSuspensionSystem`
- title: Hydraulic Suspension System (BETA 2)
- author: Zasty Chalk
- version: `1.6.9.0`
- ZIP SHA-256: `d2dd55186758dcaa5d61feeae8f3d25c442208e73e5d4723f04df2178e17e10c`
- declared multiplayer support: true
- package: 34 entries, no executable payloads / no path traversal found
- Lua source: 4 files, 1,837 lines, ~79 kB
- public distribution line: KingMods Hydraulic Suspension System
- source-code reuse license: **not found in the ZIP**

Purpose: evaluate whether the useful suspension phenomena should become a clean RealismExtensions capability. This is not a recommendation to add the external mod to the target stack and not a source-port exercise.

## Executive decision

**CANDIDATE_ABSORB / REDESIGN. DO NOT PORT THE IMPLEMENTATION.**

There is a real capability gap worth pursuing:
- active/hydropneumatic front suspension;
- load leveling / ride-height regulation;
- mode-dependent damping;
- real-system capability differences such as manual ride height and speed-limited lock;
- potentially anti-dive and oscillation mitigation.

But the exact mod cannot become the architectural template because its current MoreRealistic coexistence strategy is explicit ownership seizure: on controlled front wheels it replaces `setSuspensionMultipliers`, records later calls from other mods and refuses to apply them.

Our target stack already treats MoreRealistic as the global baseline WheelPhysics owner, including advanced spring support. An RE active-suspension module must **compose with that baseline**, not silence it.

The candidate capability therefore remains gated by a clean MR/RC suspension contract.

## What the mod actually owns

The mod injects a vehicle specialization into tractor types with Motorized + Wheels, then performs runtime eligibility checks.

It identifies front wheels, measures contact force, adjusts:
- spring multiplier;
- damping multiplier;
- wheel `positionY` as a hydraulic-cylinder/ride-height actuator;
- per-frame wheel visual information;
- optional simulated rigid-axle/independent articulation.

It also owns:
- AUTO / MANUAL / LOCKED state;
- implicit WORK state;
- profile selection;
- manual ride-height input;
- savegame mode/offset;
- multiplayer visual state;
- HUD.

Server owns physics. Clients primarily receive visual/effective state.

## Positive architecture

### Split-rate control and actuation

The heavy controller runs around every 200 ms while cylinder/spring movement is advanced every rendered update.

This is a good separation:
- expensive state decisions do not need frame frequency;
- actuator motion still looks/feels continuous;
- spring changes and cylinder compensation are ramped together to avoid height jumps.

### Load-based leveling

The source reads front-wheel contact force and filters it before deriving a load ratio.

This is much better than using only attached implement mass or a static ballast classification.

### Real work signal when available

WORK mode can consume actual Soil & Draft Physics draft force. Without that specialist it can use MoreRealistic's applied implement force.

Using actual draft is superior to treating "implement lowered" as equivalent to "tractor is working hard".

### Capability-aware profiles

Profiles distinguish:
- rigid vs independent systems;
- manual-height capability;
- auto-level availability;
- lock speed;
- leveling speed/lag;
- travel information;
- pitch damping.

The pattern is worth retaining even though the current profile matching and tuning are not strong enough for a final RE implementation.

## Major ownership problem: MoreRealistic

The current mod comments explicitly state that on front wheels HSS becomes the spring/damper owner.

It wraps each controlled wheel's `setSuspensionMultipliers`.

When HSS itself calls the function it forwards to the captured implementation.

When another mod calls it:
- the requested spring/damping values are stored;
- they are not applied.

That avoids a literal write fight, but it does so by discarding the other owner's dynamic suspension decision.

This is unacceptable for RE's target architecture.

The existing MR audit confirms that MR globally owns major WheelPhysics behavior and includes advanced spring support. A future RE suspension capability must have a composition boundary such as:

```
MR / vanilla passive suspension baseline
              |
       normalized baseline
              |
ActiveSuspension controller
              |
   one suspension actuator
```

Not:

```
MR writes -> RE/HSS intercepts -> discard
```

## Better physical model proposed for RE

The external mod's load-ratio controller is a useful prototype, not the final control law.

Recommended RE model:

### State estimator
Inputs:
- actual front wheel vertical loads;
- actual suspension stroke / suspensionLength;
- stroke velocity;
- vehicle longitudinal acceleration;
- pitch rate if available;
- roll/left-right stroke difference;
- speed;
- actual draft/drawbar load where normalized;
- current passive spring/damping baseline.

Use dt-normalized/exponential filters rather than per-update fixed smoothing weights.

### Ride-height controller
Control the physically meaningful variable:
- target suspension stroke / target ride height.

Use:
- load as feed-forward;
- ride-height error as closed-loop feedback;
- actuator rate limits;
- travel limits;
- deadband;
- anti-windup.

This is more robust than estimating the entire correction from `restLoad / spring`.

### Damping controller
Spring and damping are separate concerns.

Profiles may request:
- comfort damping;
- work damping;
- transient pitch damping;
- locked behavior.

Do not make "work" automatically mean a globally stiffer spring unless the real system/profile warrants it.

### Power-hop detection
The current mod infers power hop when front slip deviates enough from its smoothed average.

Better:
- detect periodic front-axle stroke/load oscillation;
- combine with body pitch/vertical acceleration;
- optionally use periodic slip as corroborating evidence;
- require frequency/energy persistence before changing mode.

Slip alone is too indirect.

### Anti-dive / anti-rise
The current source differentiates `getLastSpeed()`.

Prefer actual chassis longitudinal acceleration / root-body velocity where available, then combine with pitch-rate/stroke response.

## Eligibility/profile strategy

The current fallback is:
- tractor type;
- allowed brand;
- >= 5 t;
- front wheel travel >= threshold;
- not crawler.

It then falls back from exact filename patterns to an entire brand profile.

That is useful for coverage but too broad for a high-fidelity RE feature.

Recommended priority:
1. explicit verified vehicle/system profile;
2. explicit capability metadata;
3. conservative generic active-suspension profile only when strong runtime evidence exists;
4. otherwise OFF.

Unknown tractors should not silently be assigned a real-world suspension system merely because their brand normally offers one.

Profiles should distinguish **capability** from **tuning**:
- hasAutoLevel;
- hasManualHeight;
- lock semantics;
- rigid/independent;
- ride-height range;
- actuator rate;
- validated travel;
- controller tuning.

## Visual/physical boundary

Current source:
- creates an `hssLift` transform;
- reparents wheel representation nodes;
- replaces per-wheel `getVisualInfo`;
- repeatedly reasserts `positionY`;
- has no explicit onDelete restoration path for the captured wheel methods/visual hierarchy.

A future implementation should have one lifecycle-safe wheel/suspension adapter:
- captured pointer identity;
- clean install/uninstall;
- no permanent anonymous per-wheel replacement;
- no visual hierarchy mutation unless it is proven necessary;
- physical actuator and presentation state explicitly separated.

## Networking

Positive:
- server owns physical control;
- clients receive compact effective state;
- continuous physical calculation is not peer-local.

Negative:
- mode event lacks controller/ownership authorization;
- raw manual offset is accepted at the event boundary.

RE must validate:
- controlling connection / permitted farm;
- legal mode transition;
- manual capability;
- requested height range.

## Settings migration

The package says user profiles/settings survive mod updates.

Exact source increments `settingsVersion` when built-in profiles change. If the saved file is older, it deletes/recreates the settings XML instead of migrating known user values/custom profiles.

Therefore profile/schema updates can discard customization.

RE should use schema migration:
- read old known fields;
- merge new defaults;
- preserve unknown/user profiles;
- write upgraded schema only after successful merge.

## Licensing / clean-room rule

No explicit reusable source license was found in the supplied ZIP.

Treat all future work as clean-room functional reimplementation based on observed phenomena and public/game contracts.

## Recommendation

Pursue a future **ActiveSuspension** capability only if a composable MR baseline can be established.

Status:
- phenomenon: **valuable**;
- current external implementation: **not suitable as owner in target stack**;
- code reuse: **no**;
- architecture reuse: **selective concepts only**;
- implementation: **defer until MR/RC suspension ownership contract is proven**.

Companion docs:
- [Static findings](./STATIC_FINDINGS.md)
- [Assimilation design](./ASSIMILATION_OPPORTUNITIES.md)
- [Runtime plan](./RUNTIME_TEST_PLAN.md)
