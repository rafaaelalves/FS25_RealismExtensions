# Real Tire Wear 1.6.0.0 assimilation audit

Updated: 2026-10-06

Exact source audited:
- archive: `FS25_RealTireWear.zip`
- mod: Real Tire Wear
- version: `1.6.0.0`
- author: Marcus (Cobra Modding)
- ZIP SHA-256: `5bee35b0e0e88b3c8b03f0027abff00935469ef06679b24e309bc43355d314da`
- declared multiplayer support: true
- package entries: 23
- Lua: 2 files / 11,174 lines
- XML: 6
- no executable payload/path traversal found
- changelog/public release: 1.6.0.0 fixes track-system issues

Purpose:
evaluate Real Tire Wear as **clean-room assimilation research for RealismExtensions**,
not as a new target-stack dependency.

## Executive decision

Classification:

**CANDIDATE_ABSORB / REDESIGN — HIGH VALUE**

Do **not** install it alongside Reifenverschleiss in the target stack and do
**not** copy the implementation wholesale.

The best target is a native RE capability tentatively named:

`RunningGearWear`

rather than `TireWear`, because the long-term owner should model distinct:
- pneumatic tires;
- solid tires where meaningful;
- rubber tracks;
- steel tracks;
- rollers/idlers when their wear has gameplay consequences.

Real Tire Wear contributes strong ideas for:
- server-authoritative per-wheel state;
- compact initial/incremental synchronization;
- monotonic relative grip degradation;
- puncture/air-loss UX;
- axle-aware tire replacement;
- warning/service presentation.

Its wear physics should **not** be adopted unchanged.

## Why this is more interesting than simply keeping another external mod

The target stack already has Reifenverschleiss as tire/track wear owner.

Absorption becomes justified only if RE can materially improve the capability.

This audit finds several concrete reasons it can:
1. Reifen's wear/friction ownership currently requires RC translation.
2. Real Tire Wear demonstrates a cleaner server-authoritative network model.
3. Both external mods independently duplicate wheel classification, visual
   material work, service UI and physics writes.
4. RE/RC already have normalized access to slip, load, wetness, support
   geometry, sink and structural-radius provenance.
5. A native wear owner can use those authoritative inputs instead of re-inferring
   them.
6. A native provider can expose wear/grip/structural state directly and reduce
   the need for private cross-mod contracts.
7. The two external mods reveal complementary good patterns, allowing RE to
   avoid inheriting either implementation's weaknesses.

## Key comparison with Reifenverschleiss

| Domain | Real Tire Wear | Reifenverschleiss | Preferred RE direction |
| --- | --- | --- | --- |
| persistent state | per wheel | tire + first-class track/roller domains | typed running-gear units |
| wear model | one multiplicative factor × vehicle distance | separated distance/slip/time/force channels | separated physical/diagnostic channels |
| MP progression | server-authoritative + initial stream + incremental events | continuous authority less explicit in audited source | server authoritative |
| grip | monotonic relative factor 1.0→0.4 | absolute target requiring RC correction | publish relative degradation |
| structural radius | effectively absent/incomplete in 1.6 | strong wear-only structural radius + API v1 | explicit RE structural owner state |
| puncture | native leak/damage/service UX | mainly interoperability with other puncture/wear owners | native failure state, pressure-aware |
| crawlers | wear persists on member wheels; visual averages members | crawler/track is first-class wear object | first-class rubber/steel track unit |
| service | axle/damaged/all + funds check | richer running-gear workshop | typed service units + authoritative permissions |
| visual wear | custom tire/track shaders | richer multi-family renderer work | clean-room asset/shader layer |
| hot-path design | many per-tick wheel/visual writes | large/complex system with several polling paths | dirty/event-driven where possible |

## Strong positive patterns worth adopting

### Server owns wear progression
Only the server accumulates distance/wear and decides punctures.

Clients receive:
- initial wear/damaged state in the vehicle stream;
- incremental `TireWearEvent` state when 8-bit packed wear or damage changes.

This is substantially cleaner than independently simulating durable wear on
every peer.

### Compact synchronization
Wear is packed into one byte.

That gives ~0.39% wear resolution and bounds incremental network traffic to at
most ~255 wear transitions per service life per unit, plus failure transitions.

The exact encoding is not sacred, but the principle is strong:
> durable slow-changing state should replicate as quantized authoritative state,
> not as per-frame simulation traffic.

### Relative grip degradation is monotonic
The curve is:
- 0–70% wear: 1.00 → 0.80;
- 70–90%: 0.80 → 0.55;
- 90–100%: 0.55 → 0.40.

Unlike Reifen's audited absolute target curve, it cannot improve grip merely
because the upstream healthy coefficient is low.

### Service units are axle-aware
Local-Z grouping is used to discover axles, with fallback grouping when geometry
is unavailable.

This is a useful generic service-identity idea even though the final RE model
should use a normalized running-gear topology rather than rediscovering it only
inside the workshop.

### Failure UX is coherent
Puncture state drives:
- air-loss sound;
- progressive visible deformation;
- warning icon;
- helper warning;
- service option;
- speed limitation.

The physics behind it is incomplete, but the user-facing causal chain is good.

## Important weaknesses that block direct assimilation

### Wear is based on vehicle translation distance
The core equation is effectively:

```
wearIncrease =
    vehicleDistance / lifetime
    × slipFactor
    × relativeLoadFactor
    × speedFactor
    × groundFactor
```

This means:
- a wheel spinning hard while the vehicle barely moves can produce almost no
  wear;
- inside/outside tires in a turn receive the same base distance;
- wheel circumferential travel is not the primary distance source.

A native RE owner should use contact/tread travel or dissipated slip work rather
than root-node distance as the fundamental quantity.

### Load is relative to the vehicle average
`loadFactor` compares a wheel's contact force with the average of the vehicle's
currently contacting wheels.

This distributes wear between wheels, but cannot tell the difference between:
- every tire lightly loaded;
- every tire overloaded by 80%.

RE should use absolute normalized load/contact pressure where available.

### Ground factor is coarse and questionable
The fixed factors are:
- road: 1.00;
- hard: 1.08;
- field: 1.15;
- soft: 1.25.

Because slip already multiplies wear separately, this can double-penalize soft
soil and makes no explicit distinction between abrasive dry road, moist soil,
mud, stone, etc.

RE can use normalized ground profile/wetness and separate:
- surface abrasiveness;
- slip energy;
- contact pressure;
- thermal contribution.

### Physical tread-radius loss is effectively not implemented
Constants such as `PHYSICS_TREAD_LOSS_FACTOR` exist, but source use is absent.

`updatePhysicalRadius()` currently targets the stored original radius, so it
restores/holds the original physics radius rather than applying wear shrink.

Reifen's public wear-radius contract is a stronger design reference here.

### Puncture physics is mostly presentation + speed cap
A puncture:
- sets damaged state;
- animates visual tire deformation over ~8 s;
- plays an air-loss sound;
- caps the vehicle combination to 15 km/h.

It does not model a dedicated pressure state, puncture rolling resistance,
sidewall load or puncture-specific grip loss.

A native RE failure should integrate with the target-stack pressure owner rather
than introduce another hidden tire-pressure simulation.

### Crawler persistence is not first-class
Wear remains on individual wheel objects.
Crawler visual wear averages the discovered member tires.

For RE, use Reifen's stronger principle:
> a physical track assembly is a first-class wear object; internal pseudo-wheels
> are contact/roller members, not independent tire replacements.

## Licensing/provenance rule

The supplied ZIP contains no LICENSE file.

The source header also says that the script must not be changed without the
author's permission. A public distribution page separately labels the file GPL.

Those signals conflict.

Project policy:
**treat Real Tire Wear strictly as clean-room behavioral/engineering research
unless a clear authoritative license grant is verified separately.**

Do not copy:
- Lua implementation;
- shaders;
- materials;
- sounds;
- GUI code/assets.

## Detailed files

- [STATIC_FINDINGS.md](./STATIC_FINDINGS.md)
- [ASSIMILATION_OPPORTUNITIES.md](./ASSIMILATION_OPPORTUNITIES.md)
- [RUNTIME_TEST_PLAN.md](./RUNTIME_TEST_PLAN.md)

## Current status

Static/source audit: **complete enough for assimilation decision**.

Implementation: **not started**.

Runtime testing of Real Tire Wear itself is optional, because the target is not
to adopt the mod. Runtime tests should be run only where they resolve an
uncertain engine behavior or calibrate a future RE model.
