# Reifenverschleiss architecture and wear model

## 1. Core domain model

Reifen creates its own persistent OWN-WEAR state independent of GIANTS vehicle damage/wear.

Per wheel/track:
- `distanceWear`;
- `slipWear`;
- `timeWear`;
- `forceWear`;
- effective distance;
- slip distance;
- diagnostic ground/load values.

Tracks additionally own:
- `rollerWear`;
- `rollerLifetimeFactor`;
- `rollerDistanceM`.

The aggregate wear value is the clamped sum of the four main channels. Roller wear remains a separate running-gear service state.

## 2. Reference lifetime

The technical reference remains 100 km:
`WEAR_REFERENCE_DISTANCE_M = 100000`.

The selected lifetime scales rates with:
`100 / selectedKm`.

Available choices:
- 350;
- 500;
- 750;
- 1000;
- 1500;
- 2000 km.

### Configuration inconsistency

`DEFAULT_KM=1500`, but `load()` resets `selectedIndex=1` before reading the settings file. If no version-2 settings file exists, effective reference distance is therefore 350 km.

This is a confirmed clean-install behavior mismatch.

## 3. Vehicle ownership gate

OWN-WEAR is deliberately restricted to:
- current player's farm;
- OWNED or LEASED property;
- no mission vehicle;
- no mission vehicle in the attacher chain;
- explicit incompatible vehicles excluded.

This is conceptually good for single-player/user-farm semantics.

Important lifecycle flaw:
`isRelevantPlayerVehicle` does **not** reject `isDeleted/isDeleting`, while the persistence equivalent does. The old deleted-wheel runtime failure therefore remains structurally possible in 1.2.2.67.

## 4. Wear manifest

### Ordinary wheels
Every non-crawler wheel with a `wheelIndex` becomes a tire-wear object except specific hard-coded exceptions such as Hover helper wheels.

There is no generic classifier for:
- pneumatic tire;
- solid wheel;
- caster/helper wheel;
- roller;
- decorative/technical wheel.

This is the same eligibility-domain problem found in Mud TirePressure.

### Crawlers
Crawler membership is built from `spec_crawlers.crawlers`.
Internal pseudo-wheels are excluded from individual tire wear and become reference data for one track object.

Track identity includes:
- crawler index;
- side;
- structural signature;
- reference wheels;
- rubber/steel classification.

This is a strong architecture precedent.

## 5. Distance wear

Distance wear requires real movement/rotation gates and uses:
- traveled distance;
- load/rest-load ratio;
- running-gear type;
- ground class;
- weather state;
- selected reference lifetime.

Ground classes:
- ROAD;
- FIELD;
- HARD;
- SOFT;
- MUD.

Running gear:
- STREET;
- OFFROAD;
- RUBBER_TRACK;
- STEEL_TRACK.

Weather is exclusive rather than multiplicative:
- dry 1.0;
- wet 0.80;
- rain 0.70;
- snow 0.60;
with a steel-track-on-road exception.

## 6. Slip wear

Slip wear uses slip distance and nonlinear slip intensity.

Important positive behavior:
stationary wheelspin can still produce slip wear through a time-based fallback rather than requiring vehicle translation.

Passive attached implements disable active slip/force semantics and retain distance/time behavior.

## 7. Time wear

Time wear is field-only.

Activation:
- at least ~2 km/h;
- movement confirmed for 2 s.

A 30 s / 50 m window increases time wear during slow field work, with an extra harvesting bonus for a non-passive machine using an active front harvest attachment.

This creates useful "hours of agricultural work" wear distinct from road mileage.

## 8. FORCE-WEAR

The force channel models longitudinal drivetrain stress.

Inputs include:
- current applied motor torque or torque-curve fallback;
- drive demand;
- gear ratio;
- differential-derived wheel torque shares;
- wheel/track torque-capacity proxy;
- load;
- slip separation;
- movement.

The model deliberately reduces force-wear contribution as slip becomes extreme so slip wear can become the dominant mechanism.

### Width/radius relevance

Wheel/track geometry is important in FORCE-WEAR torque capacity.

However the earlier `getWheelPhysicalFactors(load,width,radius)` function is only surfaced in diagnostics. Its combined width/radius factor is not used directly in ordinary DIST/SLIP wear.

Therefore source comments about a "physically based load/width/radius wear model" overstate the current role of width/radius in the ordinary distance/slip channels.

## 9. Dynamic drivetrain mismatch candidate

Reifen recursively reads GIANTS `spec_motorized.differentials` and caches:
- vehicle torque capacity;
- differential wheel shares.

RC MRRMS dynamically changes:
- `wheel.physics.mrIsDriven`;
- `spec_wheels.mrNbDrivenWheels`
for RMS 2WD/4WD/AUTO.

It does not reconstruct GIANTS differential topology.

Reifen therefore has no current input telling its cached FORCE-WEAR allocation that an engageable axle has been disengaged.

This is a genuine cross-mod compatibility candidate and should be runtime/harness tested.

## 10. Caches

Most vehicle-keyed physics caches use weak keys, which is reasonable:
- manifests;
- wear state;
- torque capacity;
- torque stress;
- differential shares;
- dynamic drive/force state.

But "cached forever because geometry/topology is assumed immutable" becomes semantically wrong if another mod dynamically changes drivetrain ownership without changing the GIANTS graph.

A future invalidation/adapter should be event/state-driven rather than recomputing every frame.
