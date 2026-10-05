# RDS upstream 1.4 provenance / closure notes

Updated: 2026-10-05

This file originally tracked RDS 1.4 from public changelog evidence because the
archive was unavailable.

That limitation is now closed.

## Exact current archive

User-supplied:
- mod version: `1.4.0.0`;
- ZIP SHA-256: `a2a983c7754bc4fb3dffc04839fb16cf844c72d7664ae78cfcd70fcf3c15721c`.

Exact diff against the earlier supplied 1.2 archive is documented in:
`SOURCE_DIFF_1_2_TO_1_4.md`.

No public GitHub repository was found during either search pass, and the
supplied 1.4 ZIP does not contain a LICENSE file. Continue to treat replacement
as clean-room functional reimplementation, not source/assets reuse.

## Changelog claims now source-confirmed

Exact 1.4 code confirms:
- ADS removed from the explicit conflict list;
- engine-key interception added for ADS coexistence;
- external/difficult ADS crank lifecycle support;
- L -> Alt+L synthetic-clutch migration;
- brake-light spring-brake fix;
- per-vehicle ADS-aware HUD layout/thermometer suppression;
- UI-scale-aware HUD positioning;
- RDS pneumatic getter/setter API for Realistic Brakes;
- Diesel Fuel System cold-start factor/start-block reason hooks;
- AI air-pressure workaround;
- shorter glow-preheat calibration.

## Claims only partially visible from the RDS side

The changelog says contact runs a common-rail priming pump.

The RDS archive does not contain a priming-pump call. The behavior may be
implemented in Diesel Fuel System by observing RDS/motor contact state.
Therefore this audit does not claim the pump implementation is proven without
that mod's source.

Trailer-air equalization logic is likewise not in RDS. RDS only exposes the
truck pressure methods; Realistic Brakes owns the consumer/transfer logic.

## New exact-source issues not visible from changelog

- local `math.random()` still decides an RDS start failure;
- client damage event remains under-authorized;
- no full initial pneumatic stream;
- 400/550 ms input dead band remains;
- direct RDS thermal/torque/damage ownership remains;
- pneumatic energy-proxy consumption remains;
- dead HUD state/resources and lifecycle cleanup issues remain;
- runtime diagnostic still prints `v1.2.0.0` from the 1.4 archive.

## Status

Current-upstream source comparison: **CLOSED for supplied 1.4.0.0**.

Reopen only for a newer exact RDS archive, an official source repository, or a
focused dependency audit (Realistic Brakes / Diesel Fuel System / ADS update).
