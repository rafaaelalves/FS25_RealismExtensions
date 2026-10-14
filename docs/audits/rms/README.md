# Realistic Mechanical Systems deep architecture/compatibility audit

Updated: 2026-10-07

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

## 0.11.0.0 update

Latest exact package:
- version: `0.11.0.0`;
- SHA-256: `75f092abcec813cc8d56af6b7e84a21ca204d39e6825d34054ba4e376d6932cd`;
- official tag: `v0.11.0.0`;
- official release asset digest matches the supplied ZIP exactly;
- detailed delta: [UPDATE_0_11_0.md](./UPDATE_0_11_0.md).

The recommendation remains **KEEP + INTEGRATE**.

RMS 0.11 is source-compatible with the current MRRMS, MudRMS and RMSDynamicPTO
ownership model, but MudRMS required one RC hardening because upstream renamed
the private module table from `RMS_Consumptables` to `RMS_Consumables`.

The hardened bridge now validates the registered vehicle-function contract
instead of either private module name.

RMS 0.10 remains the runtime-VERIFIED release until the 0.11 in-game matrix is
completed.

Purpose: complement, not repeat, the RealismCompatibility RMS work. RC already owns concrete overlap/composition problems such as `MRRMS` and `RMSDynamicPTO`. This RE audit studies RMS as a complete simulation product: its internal state model, scheduling, lifecycle, persistence/network architecture, design patterns, defects, upstream-patch candidates, provider opportunities and ideas worth learning from.

## Audit status

Static/source phase: **CLOSED for 0.10.0.0 and updated through exact 0.11.0.0 source**.

The audit was completed in focused passes over:
1. architecture / scheduling / networking / persistence / authority;
2. drivetrain / differential topology / AUTO / differential locks / parking brake / wind-up / Enhanced Vehicle coexistence;
3. condition / stress / wear / breakdown selection and progression;
4. engine/transmission thermal / electrical / battery / preheat / external power;
5. service / physical fluids / field care / hand tools / workshop economy;
6. AI worker / used-vehicle initialization / leasing / UI / lifecycle/performance edges;
7. cross-mod implications against current RC and exact Reifen source.

Further source reading should now be hypothesis-driven by a runtime result, upstream change, or a concrete new integration question.

Runtime phase: **pending/deferred**. The focused matrix is in `RUNTIME_TEST_PLAN.md`.

## Recommendation

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

## Highest-value findings

See `STATIC_FINDINGS.md` for the full evidence-ranked ledger. Highest-value items include:
- client reinitialize request lacks a server-side master-user check;
- start-button and client-originated start-effect events lack vehicle-controller validation;
- per-connection dirty-mask table has no visible disconnect cleanup;
- maintenance history is unbounded and fully serialized to joining clients;
- the `100 ms` and `50/200/500 ms` timers discard missed intervals after long frames;
- the main scheduler preserves core time by catch-up, but an unbounded catch-up burst can amplify a hitch;
- the fleet is scanned every server frame solely to keep unattended running vehicles active;
- transient-effect MTBF helper uses linear `dt / T`, while the main breakdown probability correctly uses the exponential hazard formula;
- RMS deliberately zeroes vanilla damage, making a normalized mechanical-condition provider preferable to downstream mods reading vanilla damage;
- the release ZIP references GPL `LICENSE` headers but does not itself contain the repository `LICENSE`/`NOTICE` files;
- diff-lock auto-release clears the retained lock request even though the settings promise automatic re-engagement;
- RMS runtime topology changes make Reifen 1.2.2.67's cached FORCE-WEAR differential shares stale;
- the Enhanced Vehicle settings cache and leasing wrappers have second-save lifecycle hazards;
- deleting a jumper-connected vehicle can leave a stale reciprocal external-power reference;
- the direct `SpeedMeterDisplay.draw` override is not exception-safe;
- maintenance history and pending-connection state deserve long-session/dedicated-server validation.

## Positive patterns worth learning from

- server-authoritative persistent simulation;
- domain-separated dirty groups with thresholded synchronization;
- atomic workshop stock/money transaction;
- capability-driven eligibility rather than exact vehicle lists;
- migration path from the parent ADS state;
- explicit separation of Condition, Stress and Service;
- contextual breakdown selection based on accumulated causal factors rather than pure random failure type;
- per-system simulation with shared normalized lifecycle.

## Companion documents

- `ARCHITECTURE_AND_SCHEDULING.md` — lifecycle, cadence and fleet scheduler.
- `NETWORK_PERSISTENCE_AUTHORITY.md` — dirty groups, initial stream, persistence and request authority.
- `DRIVETRAIN_AND_CROSSMOD.md` — 2WD/4WD/AUTO topology, diff lock, wind-up, Enhanced Vehicle, MR and Reifen implications.
- `STATIC_FINDINGS.md` — evidence-ranked defect/risk/positive-pattern ledger.
- `INTEGRATION_OPPORTUNITIES.md` — upstream patch candidates, RC/provider opportunities and RE design lessons.
- `RUNTIME_TEST_PLAN.md` — focused validation matrix.

## Closure statement

RMS is not a functional-absorption target. It is a mature-enough specialist to remain the mechanical owner, while selected source defects should preferably be fixed upstream and cross-mod topology/state should be normalized through RC where a real consumer exists.

The most important new compatibility result from this audit is the confirmed **RMS drivetrain ↔ Reifen FORCE-WEAR cache mismatch**. The most important architectural lessons are the separation of condition/stress/service, causal failure selection, semantic dirty groups and atomic fluid/service transactions.
