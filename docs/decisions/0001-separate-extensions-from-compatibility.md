# ADR 0001 — Keep RealismExtensions separate from RealismCompatibility

Status: accepted  
Date: 2026-09-28

## Context

RealismCompatibility exists to preserve and compose ownership between external realism mods. Recovering unique FarmKit phenomena such as geometric ruts would require either unsafe post-facto restoration/private-local manipulation inside RC or a new implementation.

## Options

1. Add new realism simulation directly to RC.
2. Build a separate modular realism-extension mod consuming normalized RC state.
3. Fork/copy FarmKit.

## Decision

Choose option 2.

RC remains a compatibility coordinator. RealismExtensions owns only missing phenomena with explicit boundaries.

FarmKit implementation/assets are not copied. New behavior is designed clean-room.

## Consequences

Benefits:
- RC remains small and conceptually stable;
- new phenomena can evolve independently;
- one normalized provider isolates modules from specialist internals;
- clean removal/testing of individual extensions.

Costs:
- two repositories/mods must coordinate an API;
- versioning of the provider contract becomes important.

Revisit only if the separation creates greater runtime coupling than it removes.
