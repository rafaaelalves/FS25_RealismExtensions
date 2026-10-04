# Realistic Mechanical Systems deep architecture/compatibility audit

Updated: 2026-10-03

Exact package audited:
- mod: `FS25_RealisticMechanicalSystems`
- version: `0.10.0.0`
- ZIP SHA-256: `6741f193f22a5f85f5543c73d7f566b6686ab90bf7b705fd66d6d3421cb0d021`
- author: Squallqt
- declared multiplayer support: true
- Lua source size: 55,655 lines

Official source line:
- repository: `Squallqt/FS25_RealisticMechanicalSystems`
- current repository release/documentation line: `0.10.0.0`
- license: GNU GPL v3.0
- provenance: independent fork of Advanced Damage System, maintained separately since 2026-06-30

Purpose: complement, not repeat, the RealismCompatibility RMS work. RC already owns concrete overlap/composition problems such as `MRRMS` and `RMSDynamicPTO`. This RE audit studies RMS as a complete simulation product: its internal state model, scheduling, lifecycle, persistence/network architecture, design patterns, defects, upstream-patch candidates, provider opportunities and ideas worth learning from.

## Audit status

**PASS 1 COMPLETE — architecture / scheduling / networking / persistence / authority.**

The RMS audit is intentionally not closed. The source is large enough that focused passes are more useful than one undirected read.

Planned focused passes:
1. drivetrain / differential topology / AUTO / diff locks / parking brake / wind-up / Enhanced Vehicle coexistence;
2. wear / stress / breakdown selection / progression / general wear;
3. thermal / electrical / battery / preheat / exhaust;
4. service / physical fluids / field care / hand tools / economy;
5. AI / used vehicles / leasing / UI / performance edges;
6. cross-mod provider and runtime test plan.

## Provisional recommendation

**KEEP + INTEGRATE. Do not absorb RMS wholesale into RealismExtensions.**

RMS is a deep specialist and already owns a coherent mechanical-maintenance domain:
- per-system condition, stress and service;
- contextual wear;
- breakdown selection and staged failure effects;
- thermal and electrical simulation;
- workshop/service lifecycle;
- physical fluids and contamination;
- drivetrain modes and mechanical consequences;
- AI behavior, used-vehicle initialization and persistent history.

RE should learn from and consume RMS state where another RE capability genuinely needs mechanical context. RC remains the place for overlapping runtime ownership with MR, Dynamic PTO, Mud or other specialists.

## Core architecture found in pass 1

RMS is a vehicle specialization plus a global coordinator.

Eligibility is capability/rule based rather than a hand-maintained vehicle list. The specialization requires motorized + wheels + enterable and rejects several unsuitable classes. Registered vehicles are restricted to owned, leased or mission property with a valid farm.

RMS explicitly steps aside when Advanced Damage System is loaded, and its save schema contains both RMS and legacy ADS keys for migration.

### Multi-rate simulation

The simulation is deliberately split across several rates:
- rendered-frame path: state timers, transmission thermal, preheat and client presentation;
- `100 ms`: fast control/effect path, drivetrain update, warnings, breakdown active functions and several derived states;
- `50 / 200 / 500 ms`: three state-snapshot groups;
- `250 ms`: server core simulation for wear, engine thermal, electrical charging, service and breakdown progression;
- `30 s`: low-frequency metadata/weather/roof work.

`RMS_Main` spreads the `250 ms` core work across the registered fleet instead of updating every vehicle on the same frame.

Important correction to the interrupted prior audit: engine and transmission thermal are not accidentally double-integrated. `onUpdate` requests transmission-only thermal work; `rmsUpdate` requests engine-only thermal work. This is an intentional split-rate pipeline.

### Server authority

The heavy simulation is server-owned. Random persistent outcomes such as wear/failure/service results are predominantly generated on the server, then replicated.

Networking uses 11 incremental dirty groups:
- state;
- service context;
- telemetry;
- thermal;
- electrical;
- field care / physical fluids;
- wear;
- breakdowns;
- service progress;
- tutorial data;
- drivetrain.

The full initial stream additionally carries the complete maintenance log and exhaust-deposit state.

Dirty groups use per-connection pending masks and epsilon/change detection to avoid resending continuous values unnecessarily. This is a strong pattern worth retaining conceptually.

### Service transaction model

The workshop transaction path is notably defensive:
- validates service state and workshop availability;
- allocates owned physical fluid stock where required;
- calculates dealer fluid cost separately;
- validates farm balance;
- starts service before committing consumables;
- verifies that reserved fluid requirements still match;
- restores consumed stock if the transaction fails;
- debits money only after successful setup.

This is a positive atomic-transaction precedent for future economy/resource systems.

## Relationship to existing RC work

Do not recreate RC bridges inside RE.

Current boundaries remain:
- `MRRMS`: MR healthy drivetrain/gearbox ownership + RMS mechanical/breakdown/drivetrain-state consequences;
- `RMSDynamicPTO`: Dynamic PTO ratio/output semantics composed into RMS PTO capacity/stress;
- other RMS compatibility work should remain in RC when the problem is ownership between active mods.

This audit may identify upstream RMS fixes or new provider boundaries. A source defect is not automatically an RC responsibility.

## Pass-1 high-value findings

See `STATIC_FINDINGS.md` for evidence tiers and details. Highest-value items so far:
- client reinitialize request lacks a server-side master-user check;
- start-button and client-originated start-effect events lack vehicle-controller validation;
- per-connection dirty-mask table has no visible disconnect cleanup;
- maintenance history is unbounded and fully serialized to joining clients;
- the `100 ms` and `50/200/500 ms` timers discard missed intervals after long frames;
- the main scheduler preserves core time by catch-up, but an unbounded catch-up burst can amplify a hitch;
- the fleet is scanned every server frame solely to keep unattended running vehicles active;
- transient-effect MTBF helper uses linear `dt / T`, while the main breakdown probability correctly uses the exponential hazard formula;
- RMS deliberately zeroes vanilla damage, making a normalized mechanical-condition provider preferable to downstream mods reading vanilla damage;
- the release ZIP references GPL `LICENSE` headers but does not itself contain the repository `LICENSE`/`NOTICE` files.

## Positive patterns worth learning from

- server-authoritative persistent simulation;
- domain-separated dirty groups with thresholded synchronization;
- atomic workshop stock/money transaction;
- capability-driven eligibility rather than exact vehicle lists;
- migration path from the parent ADS state;
- explicit separation of Condition, Stress and Service;
- contextual breakdown selection based on accumulated causal factors rather than pure random failure type;
- per-system simulation with shared normalized lifecycle.

## Next pass

Drivetrain is the next high-value subsystem because it already intersects RC `MRRMS`, Reifen FORCE-WEAR and the earlier Realistic 4x4 audit. The goal is not to rediscover the existing RC bridge, but to understand RMS differential discovery, AUTO decisions, lock semantics, wind-up model, parking-brake ownership and public/provider opportunities.