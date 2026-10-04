# Wheel / track support topology study

Status: implementation on `feat/wheel-support-topology`; paired with RC
`feat/wheel-support-topology-v2`.

## Problem

Terrain v1 receives normalized wheel state from RealismCompatibility, but its
contact model historically had two structural gaps:

1. dual/triple tyres were represented only by aggregate `supportWidthM`, so RE
   wrote one continuous terrain strip including the real gap between tyres;
2. crawler/track wheels were explicitly rejected by FootprintModel, so tracked
   machines could participate in MR/Mud mobility physics but create no
   persistent RE terrain deformation.

## Source evidence

### FS25 wheel topology

Public mirrors of FS25 scripts show:
- Wheel owns a primary WheelVisual plus zero or more `additionalWheel(?)`;
- each WheelVisual has an explicit physical width;
- additional wheels are positioned through `setConnectedWheel(..., offset)`;
- `getWidthAndOffset()` returns the real lateral support position;
- Wheel.finalize expands the physics wheel shape from the outer extents.

Therefore dual/triple topology is already present in the loaded GIANTS wheel
structure and should not be guessed from model names.

Reviewed mirrors:
- MyGameSteamOfficial/fs25-lua-api, Wheel.lua / WheelVisual.lua;
- umbraprior/FS25-Community-LUADOC.

### MoreRealistic

Current MR source exposes:
- `mrTotalWidth`, accumulating additional wheel support widths;
- `mrTrackFx`, default 3 for crawler and 1 for ordinary wheel;
- pressure/rolling-resistance geometry based on
  `width * (radius * mrTrackFx) * 0.53`.

This is the strongest existing contract for average crawler support length.
RE therefore consumes it instead of inventing a separate track multiplier.

### Mud / Reifen / SoilCompaction ownership

Mud remains owner of measured load, pressure, wetness, slip and sink.
Reifen remains owner of tyre wear/structural radius contribution composed by
RC/MRMud. SoilCompaction remains owner of its own compaction model.

RE does not add a tyre-type multiplier. Differences already expressed in
upstream traction/slip/sink/load are consumed once.

## RC wheel context v2

The paired RC feature exposes:
- `supportKind = ROUND_WHEEL | CRAWLER`;
- `supportSegments[] = {offsetM,widthM,radiusM}`;
- `supportSegmentCount`;
- `supportContactWidthM`;
- `supportSpanM`;
- `supportGapWidthM`;
- `tireTypeName`;
- `trackFootprintFactor`.

Where WheelVisual topology is unavailable, RC falls back to one aggregate
segment. It never invents a dual gap.

Crawler pressure from Mud's generic Wheels pressure state is not exported as
normalized pneumatic pressure.

## RE FootprintModel v2

### Round wheels

Pressure-driven area remains:
`A = wheelLoad / (inflationPressure + casing allowance)`.

For multiple support segments:
- total area is unchanged;
- load/area are divided proportional to segment width;
- every patch retains the same average ground pressure;
- lateral offsets are preserved.

This means a dual no longer creates one solid rut across the center gap.

### Crawlers

Crawler average support geometry uses:
`length = structuralRadius * trackFootprintFactor * 0.53`
`area = supportWidth * length`
`pressure = wheelLoad / area`.

The long support is discretized into a bounded number of longitudinal terrain
patches. This discretization is only geometric:
- total area/load are conserved;
- every patch has the same average pressure;
- exposure share sums to one so adding patches does not multiply the pass.

No bogie/idler pressure-peak model is attempted because the normalized source
stack does not expose reliable per-roller load distribution.

## TerrainDeformation routing

The engine transforms lateral support offsets using the actual wheel/link
local X axis when available. Longitudinal crawler patches use the wheel local Z
axis. Movement direction is a degraded fallback.

History, SurfaceResponse, target recovery and writer ownership remain unchanged;
they simply receive multiple real contact patches for one GIANTS wheel when
topology requires it.

Loaded-contact safety uses the complete support span, not only summed rubber
width.

## Deliberately not solved here

### Solid/small-wheel pneumatic eligibility

Earlier RC audits established that Mud injects TirePressureSystem broadly into
GIANTS `Wheels` types and Reifen similarly lacks a general pneumatic/solid
semantic classifier.

There is still no stable source contract that lets RC reliably distinguish
every tiny solid caster/industrial wheel from a pneumatic tyre. Do not add
radius, vehicle-name or tireType heuristics merely to make the data look clean.

Crawler is the one unambiguous case and is fixed explicitly.

### SoilCompaction formulas

The new topology is not injected into SoilCompaction. Its own model already
owns compaction/contact semantics. Integrate only if runtime/source evidence
later proves a compatibility loss.

## Runtime telemetry

Footprint telemetry now includes:
- segmented support contexts;
- crawler contexts;
- segmented/crawler terrain patch counts;
- contact width vs full span/gap;
- maximum support segment count;
- track factor/contact length;
- load/area/pressure.

This should allow validation during ordinary gameplay rather than a dedicated
matrix of every wheel configuration.
