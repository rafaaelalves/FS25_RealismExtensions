# Tire footprint and ground-pressure model

Updated: 2026-09-29

Status: first pure-model prototype; no terrain writes.

## Why RE owns this model

The current specialist stack exposes useful authoritative facts but no neutral contact-footprint contract.

MoreRealistic currently estimates a contact patch with:

```text
area ~= width * radius * 0.53
```

and derives its pressure proxy from load / area.

That approximation is useful as evidence and as a degraded fallback, but it cannot express a central real-world relationship: for a correctly loaded radial agricultural tire, surface contact pressure tracks inflation pressure closely. It also cannot cleanly distinguish pneumatic tires from tracked running gear.

RealismExtensions therefore owns the conversion from normalized wheel state into a footprint/ground-pressure estimate.

## Physical references

University of Minnesota Extension summarizes agricultural compaction research as follows:

- correctly inflated radial tires exert soil pressure roughly 1-2 psi above inflation pressure;
- lower inflation enlarges the footprint and reduces surface compaction;
- duals/triples reduce load per tire and required inflation pressure;
- tracks typically produce low nominal average pressure, but local pressure is strongly affected by rollers, suspension stiffness, track stiffness and dynamic weight transfer.

These observations justify separate pneumatic and crawler models rather than one width/radius formula.

References:
- https://extension.umn.edu/natural-resources/conservation/agricultural-soil-and-water/soil-compaction
- https://blog-nwcrops.extension.umn.edu/2019/10/soil-compaction-and-ruts-what-can-you-do.html

## Pneumatic v1

When authoritative tire pressure is available:

```text
effectiveSupportPressure =
    inflationPressure + casingAllowance

targetContactArea =
    wheelLoad / effectiveSupportPressure

footprintLength =
    targetContactArea / supportWidth
```

Initial casing allowance:

```text
10 kPa ~= 1.45 psi
```

This sits inside the 1-2 psi range reported for radial tires and is deliberately configurable.

The result is constrained only by a hard geometric limit:

```text
footprintLength <= tireDiameter
```

If requested support area exceeds that possible geometry, the model preserves the geometry and reports the resulting higher ground pressure rather than silently inventing area.

### Why supportWidth, not base tire width

For one ordinary tire:

```text
supportWidth ~= tire width
```

For MR dual/triple wheel definitions, `mrTotalWidth` accumulates the additional tire widths. The normalized RC provider therefore exposes:

- `baseTireWidthM`
- `supportWidthM`

The same load and pressure require approximately the same total support area; extra width mainly shortens the required patch length. This is more coherent than multiplying area by tire count while leaving load unchanged.

## Pressure-state source

MudSystemPhysics 1.3.4.0 already has persistent per-wheel tire-pressure state:

- minimum 0.8 bar;
- maximum 2.8 bar;
- field preset 1.0 bar;
- road preset 2.4 bar;
- per-wheel current/target state;
- savegame persistence;
- pressure-dependent grip/sink/radius effects.

RC exposes current pressure as normalized provider data rather than letting TerrainDeformation read Mud internals.

This is an implementation source for the current stack, not permanent ownership. A future native RE tire-pressure/CTIS owner can populate the same contract.

## Geometry fallback

If no authoritative pressure is available, the v1 model may use the existing MR-style approximation:

```text
area = supportWidth * structuralRadius * 0.53
```

This result is explicitly labeled:

```text
model = GEOMETRY_FALLBACK
confidence = LOW
```

It exists to keep the system usable without Mud tire pressure, not because RE considers it the preferred physics model.

## Load confidence

RC exposes both:

- `wheelLoadN`
- `wheelLoadMeasured`

Pressure-driven results are:

- HIGH confidence when load is measured from wheel contact;
- MEDIUM when load came from deterministic mass/axle fallback;
- LOW for geometry-only pressure fallback.

This distinction should flow into diagnostics rather than changing gameplay through hidden arbitrary multipliers.

## Sink and wetness are deliberately not folded into tire area

The footprint model records but does not consume:

- `sinkDepthM`
- `physicalGroundWetness`

Those belong to the soil deformation-response layer.

The tire footprint answers:

> What support geometry/pressure is the wheel applying?

The terrain model later answers:

> How much does this soil deform under that support state?

Keeping those questions separate prevents wetness from becoming a second fake tire-pressure model.

## Crawler/track state — intentionally unresolved

The v1 model refuses to fake crawlers as wide tires.

A track needs at least:

- track group identity;
- track support width;
- actual ground-contact length;
- group load rather than repeated per-roller load;
- roller/bogie layout or another pressure-concentration approximation;
- dynamic load transfer if available.

A simple `weight / rectangular track area` is insufficient because real track pressure contains local peaks under rollers.

Until that group model exists:

```text
isCrawler == true
    -> footprint unavailable
    -> reason = crawler support-group geometry not implemented
```

This is preferable to generating confidently wrong rut pressure.

## Outputs

`FootprintModel.compute(context)` currently returns:

- support width;
- footprint length;
- contact area;
- ground pressure;
- target pressure (when pressure-driven);
- inflation pressure;
- model kind;
- confidence;
- geometry-limited flag;
- load provenance quality.

It performs no GIANTS terrain write.

## Next step

The next physical layer is **deformation susceptibility / response**.

It should combine:

- footprint pressure/geometry;
- longitudinal slip excavation;
- lateral scrub;
- physical ground wetness;
- freeze state;
- ground identity;
- existing sink depth;
- repeated-pass history;

without reusing Mud's sink coefficients as if they were terrain-deformation coefficients.

Before that gameplay prototype, crawler grouping should be researched separately rather than blocking the first pneumatic-tire path.
