# RMS integration and patch opportunities

Baseline: RMS `0.10.0.0`.

## Boundary with RealismCompatibility

The RC work already answers concrete overlap questions. This audit must not clone that responsibility.

Known RC ownership:
- `MRRMS` restores RMS transmission/breakdown consequences bypassed by MoreRealistic and synchronizes MR driven-wheel metadata after RMS drivetrain changes;
- `RMSDynamicPTO` composes Dynamic PTO's effective ratio into RMS PTO capacity/stress and removes duplicated synthetic grunt-load stress.

Therefore pass-1 findings divide into three categories:
1. **upstream RMS patch** — RMS source itself can be corrected;
2. **RC integration/provider** — cross-mod ownership or normalized state;
3. **RE consumer/design precedent** — learn from state but do not take ownership.

## Upstream patch candidates

### P1 — authorize fleet reinitialization on server

Add master-user validation inside `RMS_ReinitializeVehiclesEvent:run()` rather than relying on GUI visibility.

### P2 — authenticate start-button sender

Before mutating start state on a client-originated event, require the target vehicle to be controlled by that connection (or an equivalent GIANTS player/vehicle validation).

### P3 — constrain client-originated start effect transitions

For the three allowed start effects:
- authenticate controlling connection;
- accept only expected states/transitions;
- clamp/ignore client timer payload where the server can derive it;
- keep start success/failure random decision server-side.

### P4 — clean pending connection masks

Add explicit disconnect cleanup or safe weak-key semantics for `rmsPendingByConnection`.

### P5 — exact MTBF hazard helper

Replace `dt / meanTime` with `1 - exp(-dt / meanTime)` in `RMS_Utils.getChancePerFrameFromMeanTime()`.

This aligns transient random effects with the already-correct primary breakdown hazard formula.

### P6 — bounded scheduler debt repayment

Evaluate a maximum number of core vehicle slots per frame. Retain remaining debt instead of attempting unlimited catch-up after a severe hitch.

Only pursue if runtime profiling shows recovery-frame spikes.

### P7 — reduce fleet-wide raiseActive scan

Profile the per-frame `RMS_Main.vehicles` wake loop. If material, maintain a set of unattended running machines or lower the scan cadence.

### P8 — maintenance-log scaling

Keep persistent history, but decouple all-history network transfer from ordinary join:
- pagination/on-demand historical fetch;
- compact older snapshots;
- configurable retention.

### P9 — package LICENSE/NOTICE with the game ZIP

The official repository already has both files; include them with releases so source headers do not point to an absent file.

## RC provider opportunity

RMS replaces vanilla damage, so external systems should not infer mechanical condition from `Wearable.damageAmount`.

A normalized RC provider could expose read-only RMS state such as:
```text
mechanical.available
mechanical.conditionOverall
mechanical.serviceLevel
mechanical.systems.engine.condition / stress
mechanical.systems.transmission.condition / stress
mechanical.systems.hydraulics.condition / stress
mechanical.systems.cooling.condition / stress
mechanical.systems.electrical.condition / stress
mechanical.systems.chassis.condition / stress
mechanical.systems.fuel.condition / stress
mechanical.systems.pto.condition / stress
mechanical.activeBreakdownSeverity
mechanical.engineTemperature
mechanical.transmissionTemperature
mechanical.batterySoc
mechanical.systemVoltage
mechanical.drivetrain.driveMode
mechanical.drivetrain.diffLockState
mechanical.excluded
```

Provider design rules:
- read-only;
- owner mod remains RMS;
- fail closed if source contract changes;
- no RE feature should reach directly into large RMS private tables when RC can normalize the state once.

Do not add a provider merely because data exists. Add fields when a concrete RE/RC consumer justifies them.

## RE learning opportunities

### Condition / Stress / Service separation

This is one of RMS's strongest conceptual models.

RE systems with degradation should avoid one generic `health` scalar when the phenomenon actually has:
- long-term condition/life;
- accumulated abuse/stress;
- consumable/service state.

### Causal failure selection

RMS records which wear factors have been active and biases failure type toward the history that caused it. That produces a much better simulation narrative than selecting a random applicable failure.

This pattern could inform future RE systems without copying RMS mechanical ownership.

### Multi-rate scheduling

RMS demonstrates a useful fleet-distributed heavy scheduler, but also exposes the importance of classifying what can be sampled, what must integrate elapsed time, and what should be event-driven.

### Atomic persistent transactions

The workshop fluid/economy path is a strong reference for:
- reserve;
- validate;
- apply;
- verify;
- rollback;
- commit;
- charge.

### Semantic network groups

RMS's domain dirty masks are preferable to syncing one giant state structure. Any future state-rich RE module should use similarly explicit domains.

## Hotfix policy

If RC ever carries an RMS source hotfix rather than waiting for upstream:
1. name it explicitly as an owner-mod hotfix;
2. exact-version/source-shape gate it;
3. detect upstream-fixed shapes and report `NOT REQUIRED`;
4. keep it separate from `MRRMS`, `RMSDynamicPTO` or unrelated bridges;
5. remove it when the supported RMS line contains the fix.

The default preference is upstream correction because RMS is public GPL source and actively maintained.

## Cross-mod questions queued for later passes

- Does RMS drivetrain AUTO/lock logic expose a stable provider boundary that can replace RC private-state reads?
- Does Reifen FORCE-WEAR's cached GIANTS differential topology misallocate force wear after RMS 2WD/4WD/AUTO changes?
- Are Mud wheel-slip/ground-state inputs already consumed by RMS in the best place, or can RC provide a more authoritative input without duplicating wear?
- Does Dynamic PTO integration need a formal RMS PTO state API instead of runtime wrapping?
- Which RMS mechanical states are useful to RE terrain/crop/surface systems without creating inappropriate mechanical coupling?
- Are any global RMS motor/physics overwrites bypassed by MR, Courseplay, AutoDrive or other active stack members beyond the overlaps RC already repairs?

## Additional upstream patch candidates from focused passes

### P10 — retain differential-lock request across speed release
Keep `diffLockRequested` true while the effective lock is automatically disengaged above the release speed. This makes the implementation match its own tooltip and existing two-state model.

### P11 — reset Enhanced Vehicle cache across mission lifecycle
Clear the cached settings/deadline on map load/delete or backward clock movement.

### P12 — clean external-power links on vehicle deletion
Call the reciprocal disconnect path from RMS vehicle deletion and when a stored partner is found invalid/deleted.

### P13 — make SpeedMeter HUD override restoration exception-safe
Guarantee restoration of temporary `getDamageAmount` methods and HUD visibility even if the delegated draw fails.

### P14 — prevent leasing wrapper stacking
Install `SellVehicleEvent.run` and `ShopController.sell` wrappers once rather than on every `Mission00.load`.

### P15 — initialize weather state at map load
Populate `RMS_Main.currentWeather` immediately instead of waiting for a randomized 30-second metadata update.

## Confirmed cross-mod opportunity — RMS + Reifen

The Reifen 1.2.2.67 FORCE-WEAR cache is now source-confirmed stale across RMS topology changes.

Preferred ownership order:
1. RMS owns the live differential topology.
2. Reifen owns tire/track wear.
3. Reifen rebuilds its drive-share cache when topology revision/signature changes.
4. RC should normalize/expose final drivetrain state only when needed by consumers; it should not become a second drivetrain solver.

If an upstream Reifen fix is unavailable, an RC bridge can be considered, but it should be explicitly scoped and exact-version gated rather than hidden inside `MRRMS`.

## RMS public provider opportunity

The audit found enough repeated private-state interest to justify proposing a small RMS-side read-only API before adding more RC private-table adapters.

High-value contract surface:
```text
getMechanicalState(vehicle)
getSystemCondition(vehicle, system)
getSystemStress(vehicle, system)
getDrivetrainState(vehicle)
getEffectiveDrivenWheels(vehicle)
getDrivetrainTopologyRevision(vehicle)
getThermalState(vehicle)
getElectricalState(vehicle)
```

The API should expose normalized values and identities, not mutable internal tables.

Especially valuable is a monotonically changing `topologyRevision` (or stable topology signature) whenever RMS rebuilds/restores the differential graph. Reifen, MR/RC and future consumers can invalidate caches cheaply without polling private structures.

## What RE should copy conceptually, not functionally

- condition / stress / service as separate dimensions;
- factor-stat attribution for explaining degradation;
- causal/applicability-weighted breakdown selection;
- split rates chosen by semantic need;
- server-owned persistent randomness;
- semantic dirty-state groups;
- atomic stock/money/resource transactions;
- capability-driven vehicle applicability;
- explicit legacy-save migration.

These patterns are reusable architecture ideas. RMS mechanical simulation itself remains external ownership.
