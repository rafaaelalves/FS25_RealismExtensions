# Development and runtime-validation process

Updated: 2026-10-02

## Why this exists

TerrainDeformation/TerrainRecovery development lost time because runtime hypotheses were sometimes tested with insufficient causal telemetry. Successful API calls, aggregate counters, and visual impressions were occasionally treated as stronger evidence than they were.

The project now follows an evidence-first loop.

## Branch policy

Use one long-lived feature branch per active capability, not one branch per experimental version.

Current TerrainRecovery branch: `feat/terrain-recovery`.

Experimental milestones remain recoverable through Git commits, CI artifacts, CHANGELOG/research notes, and tagged/recorded runtime evidence. Create a separate branch only for genuinely parallel/risky work that must coexist.

## Evidence ladder

A claim advances only as far as its evidence:

1. **Static/source evidence** — API/source says an operation should be possible.
2. **Harness evidence** — deterministic logic and contracts behave as designed.
3. **Runtime execution evidence** — the expected path actually executes in FS25.
4. **Physical evidence** — measured game state/heightfield changes as intended.
5. **Causal evidence** — telemetry attributes the physical change to the intended writer/operation.
6. **Scenario evidence** — controlled A/B runtime scenarios behave correctly.
7. **Regression evidence** — adjacent scenarios and the target mod stack remain correct.

Do not promote a feature because an API returned success if the physical state was not measured.

## Telemetry phases

### Discovery / early implementation
Use high observability. Record:
- inputs and normalized state provenance;
- operation owner/source;
- eligibility and rejection reasons;
- before/after physical measurements;
- requested vs observed magnitude;
- per-vehicle/root attribution;
- performance/job counts;
- changed vs unchanged/repeated work;
- asynchronous callback outcome.

Prefer counters/histograms and five-second summaries over per-frame log spam.

### Calibration
Keep causal counters and before/after probes. Add distributions/buckets only for parameters being calibrated. Remove redundant per-event detail after its question is answered.

### Stabilization
Keep cheap invariant/health telemetry always available:
- errors/rejections;
- operation counts;
- owner/source attribution;
- requested vs realized totals;
- performance maxima;
- impossible-state counters.

Expensive geometry/probes remain switchable.

### Periodic revalidation
Re-enable high observability after:
- a major engine/game update;
- changes to RC/provider contracts;
- changes to Mud/MR/RMS interaction;
- a new vehicle/contact class (crawler, dual, implement);
- a new terrain writer/recovery algorithm;
- unexplained visual regressions.

There is no assumption that a feature has reached a permanent "final" state.

## Runtime telemetry design rules

1. **Cumulative + windowed:** cumulative totals show lifetime behavior; short-window deltas establish causality.
2. **Attribute every terrain write:** vehicle, root combination, operation/source and relevant control/work state must be recoverable.
3. **Measure both sides:** requested deformation alone is insufficient; capture observed physical response.
4. **Distinguish no-op from failure:** an API call can succeed while changing nothing.
5. **Distinguish state change from physical work:** e.g. Cultivator `realArea` is changed agricultural area; `area`/work state represents processing.
6. **Async-safe:** callbacks own completion/realization facts.
7. **Performance-budgeted:** diagnostics should usually aggregate rather than print per sample.
8. **Hypothesis-driven:** every new experimental behavior needs named acceptance/rejection criteria before runtime testing.

## Controlled runtime test template

Before handing a build to the user, document:
- build commit/artifact;
- hypothesis;
- exact vehicle/implement;
- terrain/state prerequisites;
- steps/passes;
- variables intentionally held constant;
- telemetry lines expected;
- acceptance criteria;
- rejection criteria;
- known contamination from earlier experimental terrain/save history.

After the run:
- preserve the log identity;
- record observations separately from interpretation;
- calculate deltas for the relevant interval;
- state what was proven, falsified, and still unknown;
- update CURRENT_HANDOFF immediately.

## CI / harness rules

Every discovered runtime bug that can be represented without FS25 must gain a regression harness before the fix is considered stable.

Harnesses should cover semantic boundaries, not only happy paths. Example from v22:
- `realArea > 0, area > 0`: first agricultural pass;
- `realArea = 0, area > 0, isWorking = true`: repeated physical pass;
- inactive/no-area path: no recovery.

CI success is necessary, never sufficient for physical terrain acceptance.

## Research / external-mod audit rule

External mods are precedents, not dependencies by default. Audits should extract:
- lifecycle;
- work/contact detection;
- spatial representation;
- terrain API usage;
- batching/cadence;
- callbacks and realization accounting;
- server/client ownership;
- persistence/networking;
- configuration boundaries;
- failure handling;
- performance strategy.

Record what should be adopted conceptually, what should not, and why.
