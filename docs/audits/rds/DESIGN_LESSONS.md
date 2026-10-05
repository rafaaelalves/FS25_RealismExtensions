# RDS reusable design / optimization lessons

Updated: 2026-10-05
Source baseline: exact RDS 1.4.0.0 archive.

Purpose: preserve useful engineering ideas even when the owning RDS implementation is not suitable for direct absorption.

## 1. Capability APIs beat private-state scraping

Good examples in 1.4:
- RDS consumes optional `scGetColdStartFactor()`;
- RDS consumes optional `scGetStartBlockReason()`;
- RDS exposes `rdsGetAirPressure()`;
- RDS exposes server-only `rdsSetAirPressure()`.

The important pattern is not the exact names. It is:
- no required dependency;
- test for capability;
- let the capability owner provide semantics/reason;
- avoid consumers reconstructing state from private tables.

RE/RC direction:
- publish small read-only normalized contracts;
- publish intent/transaction APIs for mutation;
- include provider/version/runtime-status metadata where practical.

For physical resources, prefer operations over setters. `setPressure(7.2)` is easy but cannot prove conservation. A future pneumatic API should expose reservoir volume/capacity and a transfer/withdraw/deposit transaction.

## 2. Confirm transitions from authoritative state

1.4 no longer assumes that calling `startMotor()` means the engine started.

It requests a start, checks whether the motor state actually moved, and also listens for later `onStartMotor` confirmation when ADS owns a difficult-start sequence.

General lesson:
- commands are intents;
- callbacks/state transitions are outcomes;
- HUD/persistence should follow outcomes.

This is directly reusable for:
- PTO engagement;
- engine start;
- workshop transactions;
- terrain jobs;
- attachment/hydraulic operations.

## 3. Input migration should preserve user choice

RDS 1.4 detects whether a player still uses the obsolete exact default `L` mapping before migrating to `Alt+L`.

It does not overwrite a custom binding.

Generic RE migration rule:
1. version a migration;
2. inspect old exact default;
3. change only unchanged defaults;
4. preserve user customization;
5. persist one completion marker;
6. report the migration once.

Improvement: keep migration inside the existing RE lifecycle/scheduler rather than adding a dedicated global mission-update hook for notification timing.

## 4. UI geometry should react to configuration events, not frame polling

RDS subscribes to the UI-scale setting and recomputes normalized sizes only when the setting changes.

This is a good optimization pattern.

RE shared HUD should cache:
- UI scale;
- anchor rectangles;
- slot geometry;
- text/icon sizes.

Invalidate on:
- UI-scale setting event;
- HUD replacement/recreation;
- resolution/aspect transition if exposed;
- provider/layout slot change.

Do not recompute stable geometry every draw.

## 5. Tiny icons need aspect-aware sizing and pixel snapping

RDS 1.4 documents and fixes a subtle UI bug: using the same normalized scalar for width and height did not yield square pixels on screen.

Useful shared-HUD rules:
- convert width and height separately;
- honor `g_screenAspectRatio`;
- pixel-snap small telltales/lines;
- use explicit atlas dimensions.

This should become a small RE HUD utility rather than repeated module-local math.

## 6. Layout ownership should be semantic, not mod-name-specific

RDS improved from "ADS installed?" to "ADS actually manages this vehicle?".

That is better, but the next step for RE is not more pairs of coordinate sets.

Prefer:
```text
slot ENGINE_WARNING
slot START_STATUS
slot PTO_STATUS
slot PNEUMATIC
slot MECHANICAL_STATUS
```

Providers/components reserve slots. The layout engine packs active slots.

This removes:
- per-mod hardcoded offsets;
- `withADS` / `withoutADS` variants;
- repeated calibration logic as more RE modules appear.

## 7. User calibration tools are valuable, but should not become production architecture

RDS's console commands were useful during visual tuning:
- position offsets;
- simulated ADS/no-ADS layout;
- live glow color.

That is an excellent development workflow.

RE lesson:
- keep dev-only calibration/debug commands;
- once a layout rule is validated, move constants/profiles into declarative data;
- avoid shipping a thousand-line HUD whose correctness depends on manually tuned branches.

## 8. AI interaction and physical state are separate concerns

RDS fixes helper deadlock by forcing AI air pressure to at least the governor cut-in threshold.

The important lesson is correct: human interaction complexity should not deadlock AI.

The exact implementation should not be copied because it mutates the persistent resource magically.

RE should distinguish:
- physical state;
- operator interaction policy;
- AI readiness policy.

For example an AI may perform an abstract pre-trip preparation step while the physical model advances consistently.

## 9. Frame-rate work should be classified by semantic cadence

RDS still does a large amount of work from `onUpdate`, including:
- thermal progression;
- air physics;
- held-key timing;
- preheat timers;
- failed-crank timers;
- warm-up consequences.

These do not all require frame cadence.

Proposed RE cadence split:
- input edge / held-key responsiveness: frame while active;
- HUD: draw cadence;
- pneumatic physics: 100–250 ms server cadence;
- thermal/provider sampling: 100–250 ms or provider revision;
- offline leakage: elapsed-time reconciliation;
- warning state: change-driven / low cadence.

This follows the good multi-rate lesson already extracted from RMS.

## 10. Remove retired state when UX changes

RDS 1.4 removed the READY blink/progress presentation but retained:
- timer state;
- constants;
- overlay allocations;
- unreachable rendering branches.

RE should treat feature removal as a cleanup task:
- state;
- persistence;
- network fields;
- overlays;
- console commands;
- tests;
- telemetry.

A CI/static harness can assert referenced/registered resources where practical.

## 11. Runtime provenance should be generated, not handwritten

The exact 1.4 archive still prints `v1.2.0.0` from the main script.

RE's CI-stamped BuildIdentity is the preferred general solution:
- branch;
- commit;
- workflow run;
- build time.

Never rely on a manually edited diagnostic version string for experimental builds.

## 12. Compatibility logic should graduate into explicit contracts

RDS 1.4's ADS composition is clever but depends on:
- private ADS spec fields;
- a named ADS event class;
- a global overwrite of a base motor action.

This is appropriate evidence of a missing contract, not a pattern to perpetuate.

For RE:
- adapter can temporarily use private internals during research;
- final architecture should expose owner APIs;
- RC should hold unavoidable external-private adapters;
- RE core should consume normalized/provider contracts.

## 13. Error/reason propagation improves UX and debugging

RDS asks the fuel system for the specific start-block reason and displays that rather than a generic "failed".

This is worth standardizing.

A provider response should be able to return:
```text
allowed
reasonCode
localizedReason / reasonArgs
retryable
owner
```

Useful for:
- start interlocks;
- PTO mismatch;
- workshop refusal;
- terrain operation refusal;
- AI readiness.

## 14. Narrow public APIs need invariants

The new pneumatic getter/setter is useful because it removes private-table access, but it has weak semantics.

A good public API must document invariants:
- valid range;
- authority;
- units;
- conservation;
- side effects;
- revision/change notification.

This is especially important for future RE state providers so external mods do not begin writing normalized state casually.

## Optimization shortlist for native RE replacement

1. event-driven final start confirmation;
2. per-vehicle provider resolution cached until ownership changes;
3. state revisions for HUD;
4. frame update only while input/start interaction is active;
5. pneumatic simulation on bounded fixed cadence;
6. full initial stream + thresholded dirty sync;
7. shared HUD slot/layout service;
8. settings/migration handled by existing RE lifecycle;
9. no duplicate visual writes in both update and post-update;
10. no unused overlay/state allocation.
