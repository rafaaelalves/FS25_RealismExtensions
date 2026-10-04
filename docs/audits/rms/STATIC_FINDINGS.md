# RMS static findings ledger

Baseline: RMS `0.10.0.0`, ZIP SHA-256 `6741f193f22a5f85f5543c73d7f566b6686ab90bf7b705fd66d6d3421cb0d021`.

Pass 1 scope: architecture, scheduling, networking, persistence and authority. This ledger is intentionally incomplete until subsystem passes finish.

Evidence labels:
- **CONFIRMED_STATIC** — source proves the condition/path.
- **STRONG_CANDIDATE** — source strongly indicates a defect/risk but engine/runtime semantics still matter.
- **DESIGN_RISK** — architectural tradeoff/collision surface rather than a direct bug.
- **POSITIVE_PATTERN** — implementation worth retaining/learning from.
- **RUNTIME_PENDING** — needs controlled FS25 evidence.

## RMS-01 Reinitialize event lacks server-side admin authorization
**CONFIRMED_STATIC**

`RMS_SettingsPage` normally exposes settings changes only to server/master users, but `RMS_ReinitializeVehiclesEvent:run()` accepts any client-originated request and directly calls `RealisticMechanicalSystems.reinitializeAllVehicles()`.

Patch candidate: repeat the same master-user validation on the server event boundary.

## RMS-02 Start-button event does not authenticate vehicle controller
**CONFIRMED_STATIC**

`RMS_StartButtonEvent:run()` accepts a synchronized RMS vehicle, writes its start-button flags and can invoke `RMS_Preheat.requestStart()` on the server.

It does not check `vehicle:getOwnerConnection() == connection` or otherwise bind the request to the player controlling that vehicle.

Patch candidate: mirror the ownership pattern already used by `RMS_DrivetrainEvent`.

## RMS-03 Client start-effect sync trusts target vehicle
**CONFIRMED_STATIC**

`RMS_EffectSyncEvent` intentionally allows client-to-server traffic for three start-related effects:
- `ENGINE_HARD_START_MODIFIER`;
- `GLOW_PLUG_HARD_START_MODIFIER`;
- `ENGINE_FAILURE`.

The server accepts the vehicle/effect payload without verifying the sender controls the vehicle. It also accepts status/timer fields without a strict transition validator.

Patch candidate: authenticate controller + whitelist legal client-origin transitions; keep final start outcome server-owned.

## RMS-04 Pending dirty masks retain connection keys without visible cleanup
**STRONG_CANDIDATE**

`spec.rmsPendingByConnection` is a normal strong-key table. Connections are added during initial stream handling. Pass-1 source scan found no disconnect removal or weak-key mode.

Long dedicated-server sessions with player churn could retain obsolete connection objects per RMS vehicle.

Runtime proof: join/leave many clients and inspect key count / memory. Defensive patch: weak keys or explicit disconnect cleanup.

## RMS-05 Maintenance history is unbounded and fully sent on join
**CONFIRMED_STATIC design/performance scaling issue**

Maintenance entries are append-only, no cap/pruning was found, and the full log is serialized in every vehicle's initial stream as a `UInt16` count plus serialized snapshots.

Each entry stores system/breakdown/effect/indicator state in addition to service metadata.

Short saves are fine; very long fleet saves can grow save size, join bandwidth and deserialize cost without bound.

## RMS-06 100 ms fast path discards missed elapsed intervals
**CONFIRMED_STATIC cadence behavior / DESIGN_RISK**

`onUpdateTimer` uses modulo when it crosses 100 ms, then runs exactly one step with fixed `updateDt=100`. A 400 ms delayed frame does not run four fast steps and does not pass 400 ms into timers/effects.

This bounds work but causes active-effect timers/control accumulators to under-advance across hitches.

Patch research: classify consumers; use elapsed/clamped dt for timers while keeping expensive control sampling bounded.

## RMS-07 50/200/500 ms state snapshots also discard missed intervals
**CONFIRMED_STATIC cadence behavior / DESIGN_RISK**

All three snapshot timers use modulo and run once after an overrun with the nominal delay value.

Some snapshot functions are pure observations; others maintain windows/derived accumulators. Those need a focused cadence audit so a hitch does not silently lose physical history.

## RMS-08 Core scheduler can produce an unbounded catch-up burst
**CONFIRMED_STATIC performance architecture**

The 250 ms fleet scheduler preserves accumulated timing debt and computes however many vehicle slots are due. No per-frame upper bound is applied.

This preserves core simulated time but a severe frame/server hitch can cause multiple full fleet rotations on the recovery frame.

Potential patch: bounded updates-per-frame while carrying residual debt.

## RMS-09 Every server frame scans the entire RMS fleet to call raiseActive
**CONFIRMED_STATIC performance architecture**

Before the distributed scheduler, RMS iterates every registered vehicle every frame and calls `raiseActive()` for inactive vehicles whose motor is ON.

This appears to keep unattended running machines alive for fast/thermal paths. It scales with fleet size × server frame rate.

Do not optimize blindly; profile first. Candidate redesign: track running inactive vehicles through motor-state transitions.

## RMS-10 MTBF helper is only linearly timestep-adjusted
**CONFIRMED_STATIC numerical inconsistency**

The primary breakdown probability correctly uses:
`1 - exp(-dt / MTBF)`.

`RMS_Utils.getChancePerFrameFromMeanTime()` instead returns:
`dt / meanTimeMs`.

Several transient breakdown effects use the helper. For normal small `dt` the approximation is close, but it is less timestep-invariant and increasingly inaccurate for large dt relative to mean time.

Low-risk upstream patch: use the exact exponential form consistently.

## RMS-11 Engine/transmission thermal are split-rate, not double-updated
**POSITIVE_PATTERN / prior hypothesis closed**

Source disproves the interrupted-audit concern that thermal systems are accidentally integrated twice.

`onUpdate` requests transmission only; `rmsUpdate` requests engine only.

Future audit should evaluate whether the chosen different cadences are appropriate, not whether duplicate integration exists.

## RMS-12 Workshop service transaction has rollback semantics
**POSITIVE_PATTERN**

Fluid stock allocation, service initialization, requirement verification, exact consumption and money debit are ordered as one server transaction with restoration on failure.

This is a useful reference for future RE persistent-resource systems.

## RMS-13 RMS intentionally destroys vanilla damage as an interoperability signal
**CONFIRMED_STATIC ownership decision / integration opportunity**

`updateDamageAmount` returns zero for managed RMS vehicles and the 100 ms path also resets nonzero vanilla damage to zero.

That is coherent because RMS replaces vanilla mechanical damage/sell-price semantics, but other mods cannot use vanilla damage as a proxy for RMS health.

Integration direction: expose/consume normalized RMS mechanical state through RC instead of reconstructing health from vanilla `Wearable`.

## RMS-14 Release ZIP omits the referenced license/provenance files
**CONFIRMED_STATIC packaging issue**

Lua headers say GPL v3-or-later and `See LICENSE`, but the audited ZIP contains neither `LICENSE` nor `NOTICE`. The official repository contains both.

Upstream packaging cleanup candidate.

## RMS-15 Global/UI hook surface is broad but mostly composable
**DESIGN_RISK / RUNTIME_PENDING**

Pass 1 found global hooks around mission lifecycle, workshop UI, statistics UI, shop attributes and `BuyVehicleData` streams, plus per-vehicle overwritten specialization methods such as motor start, speed limit and vehicle physics.

Most use GIANTS `Utils.*Function`/`superFunc` patterns. Existing runtime logs showed shared hook targets without unknown-hook/veto failures in that session.

Do not patch hook presence alone. Investigate only concrete pointer drift, bypass or ordering failures.

## RMS-16 Primary persistent randomness is server-owned
**POSITIVE_PATTERN**

Used-vehicle initialization, service outcomes and persistent breakdown choices are performed on server-owned paths and then synchronized.

This avoids peer-local random divergence for the core mechanical model.

## RMS-17 State synchronization is domain-separated and thresholded
**POSITIVE_PATTERN**

Eleven dirty groups plus per-domain epsilon/change detection prevent the large RMS state model from becoming one monolithic every-frame stream.

Possible refinement is lifecycle cleanup of the per-connection masks, not replacement of the architecture.