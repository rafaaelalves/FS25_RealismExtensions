# Reifenverschleiss static findings ledger

Baseline: Reifenverschleiss `1.2.2.67`, SHA-256 `4d645f1e1e2ac3aaef4f4291fe2de9f27835efa499a45069a1c8172bedd6ff3a`.

Evidence labels:
- **CONFIRMED_STATIC** — source proves the behavior/condition.
- **STRONG_CANDIDATE** — architecture strongly indicates a problem, runtime semantics still matter.
- **DESIGN_RISK** — compatibility/model choice rather than a direct coding error.
- **RUNTIME_PENDING** — needs controlled FS25 evidence.

## R-01 Clean-install lifetime default mismatch
**CONFIRMED_STATIC**

`DEFAULT_KM=1500`, but `RS.load()` starts with `selectedIndex=1`; no settings file therefore yields 350 km.

## R-02 Generic wheel eligibility
**CONFIRMED_STATIC design gap**

Every non-crawler wheel with wheelIndex becomes a wear object except specific hard-coded exceptions. No pneumatic/solid/helper classifier.

## R-03 Absolute wear friction ownership
**CONFIRMED_STATIC**

Reifen writes final `tireGroundFrictionCoeff = target/frictionScale`, replacing previous surface coefficient semantics rather than composing relative degradation.

## R-04 High-wear curve can increase on low native baseline
**CONFIRMED_STATIC mathematical condition / RUNTIME_PENDING incidence**

75% target = `nativeStart/1.8`; 90% target = absolute 0.55.
For `nativeStart < 0.99`, the curve rises from 75% to 90% wear.

## R-05 Deleted-vehicle runtime eligibility guard missing
**CONFIRMED_STATIC**

Persistence rejects `isDeleted/isDeleting`; runtime `isRelevantPlayerVehicle` does not.
The 1.2.2.65 deletion-error mechanism remains present in 1.2.2.67 core.

## R-06 currentVehicle nil hold can retain deleted vehicle
**DESIGN_RISK / lifecycle amplifier**

`setVehicle(nil)` intentionally preserves `currentVehicle`. Without an explicit Vehicle.delete cleanup this can extend the window in which stale vehicle state is sampled.

## R-07 EWFS ownership scope exceeds OWN-WEAR scope
**CONFIRMED_STATIC**

Fleet scan calls `updateBlocker` for all mission vehicles without farm/mission/deletion eligibility.

## R-08 EWFS numeric weak-key maps retain strong vehicle refs
**CONFIRMED_STATIC**

`nodeVehicles` and `shapeVehicles` use numeric node IDs as weak keys. Numeric keys do not disappear with vehicle GC; strong values retain vehicle objects. No delete cleanup exists.

## R-09 EWFS redundant fleet update
**CONFIRMED_STATIC performance issue**

At 10 ms cadence it scans all mission vehicles, then loops all registered vehicles and updates them again.

## R-10 EWFS strong roller speed-state table has no delete cleanup
**CONFIRMED_STATIC lifecycle issue**

`rollerMaxForwardSpeedState` is a normal table keyed by vehicle and is never cleared on Vehicle.delete.

## R-11 EWFS brake restoration can overwrite another owner
**DESIGN_RISK**

Captures original `motor.brakeForce`, sets original+100, later restores the captured value. A legitimate external change during the lock window can be lost.

## R-12 Roller maxForwardSpeed is an absolute writer
**DESIGN_RISK**

Writes `motor.maxForwardSpeed=origin*wearFactor`; can compete with mechanical failure/speed-limit owners.

## R-13 Published steel-track speed malus mismatch
**CONFIRMED_STATIC source/docs mismatch**

Public feature description says rubber and metal tracked vehicles receive roller max-speed penalty. Source explicitly accepts only `RUBBER_TRACK` and excludes `STEEL_TRACK`.

## R-14 Repair resets custom tire/track wear
**CONFIRMED_STATIC intentional behavior**

`VEHICLE_REPAIRED` invokes custom wear reset.

## R-15 Repaint resets custom tire/track wear
**CONFIRMED_STATIC intentional behavior / gameplay loophole**

`VEHICLE_REPAINTED` invokes the same mechanical wear reset. Dedicated roller wear is not reset by this generic path.

## R-16 Workshop client request lacks authorization
**CONFIRMED_STATIC MP defect**

Server does not validate requesting connection farm/ownership/workshop permission before resetting vehicle and debiting vehicle owner's farm.

## R-17 Workshop has no affordability check
**CONFIRMED_STATIC**

Release source explicitly disables balance checking and always debits after reset.

## R-18 Requesting client excluded from reset-sync broadcast
**CONFIRMED_STATIC MP protocol defect**

Client sends purchase without local reset. Server broadcasts reset event while ignoring requesting connection.

## R-19 Cross-farm reset mirror can fail local eligibility
**STRONG_CANDIDATE**

Client-side reset calls local-player-scoped `resetRunningGearWorkshop`; non-owner peers can reject the mirror. Because wear is not otherwise replicated this can leave peer-local state divergent.

## R-20 Wear progression has no explicit network replication
**STRONG_CANDIDATE**

No update-stream/dirty/event path exists for ongoing wear. Local settings and randomized roller lifetime can diverge across peers. Dedicated/multi-farm test required.

## R-21 Server persistence is local-player-farm scoped
**STRONG_CANDIDATE**

Save eligibility depends on `g_currentMission:getFarmId()`, which may not represent all farms on a dedicated/hosted multiplayer server.

## R-22 Mission reload loses repair/repaint subscription
**CONFIRMED_STATIC lifecycle bug**

Unload unsubscribes the core but does not reset `_workshopMessageHooksInstalled`; next mission can skip resubscription.

## R-23 Mud local wetness not consumed
**CONFIRMED_STATIC integration gap**

Wear physics reads global GIANTS wetness/rain; local Mud field wetness is absent. FIELD classification also precedes MUD classification.

## R-24 Mud version profile does not select behavior
**CONFIRMED_STATIC**

1.2.2.67 detects Mud profiles, but compatibility consumers only test "active"; unknown/newer versions still receive the same private-field path.

## R-25 Mud final-owner hook is globally invasive
**DESIGN_RISK**

Reifen appends to global `SpecializationUtil.raiseEvent` and inspects every `onUpdate`, plus a fleet fallback every 750 ms.

## R-26 Mud overlay numeric weak cache
**CONFIRMED_STATIC minor lifecycle/perf issue**

`M._last` is weak-key but keyed by numeric shader node IDs and is not reset in deleteMap.

## R-27 Physical radius writer can briefly race Mud transient radius
**DESIGN_RISK**

Visual wear worker writes structural target directly into current `physics.radius`; Mud compatibility updates baseline for subsequent pressure processing. Current stack runtime has been healthy, so no demonstrated failure.

## R-28 FORCE-WEAR uses cached GIANTS differential topology
**CONFIRMED_STATIC**

Differential wheel shares and torque capacity are cached per vehicle from GIANTS graph.

## R-29 FORCE-WEAR does not consume MRRMS effective driven flags
**STRONG_CANDIDATE cross-mod mismatch**

RC dynamically changes `mrIsDriven` for 2WD/4WD/AUTO without rebuilding differential graph. Reifen can continue force-wearing disengaged axle wheels.

## R-30 Roller lifetime randomness is not explicitly network synchronized
**STRONG_CANDIDATE MP divergence**

New roller states use `math.random()`; value is persisted but no normal network state sync exists.

## R-31 Width/radius "physical factor" is diagnostic-only for DIST/SLIP
**CONFIRMED_STATIC model/documentation drift**

The load-width-radius combined factor is calculated by `wheelDiagnostic` but not used by ordinary DIST/SLIP wear. Width/radius mainly influence FORCE-WEAR capacity.

## R-32 Source packaging double-loads modules
**CONFIRMED_STATIC packaging issue**

modDesc and Loader redundantly source Event/WFS/Settings/Workshop. Settings performs file load twice.

## R-33 Workshop localization is partially hard-coded German
**CONFIRMED_STATIC polish defect**

Custom dialog text/buttons largely bypass l10n despite available localization infrastructure.

## R-34 Mod description lifetime list is stale
**CONFIRMED_STATIC documentation issue**

Top EN/DE description lists only 1000/1500/2000, while actual choices also include 350/500/750.

## R-35 Stale l10n option keys
**CONFIRMED_STATIC cleanup**

modDesc contains 10/50/100/200 km localization keys not present in current selectable values.

## R-36 Snow friction uses healthier composition semantics
**CONFIRMED_STATIC positive finding**

Snow path preserves native/current friction and applies relative own factor with self-stack protection. Recommended precedent for ordinary wear friction.

## R-37 Crawler grouped wear model
**CONFIRMED_STATIC positive finding**

Crawler is one track wear object; hidden reference wheels are not individual tire wear objects. Recommended architectural precedent for grouped contact identity.

## R-38 .65 -> .67 core behavior unchanged
**CONFIRMED_STATIC provenance**

Core differs only by version string. Visual, WFS, Workshop, Settings and purchase-event files are identical. .67 changes target Mud compatibility/version guard only.

This means old RC validation remains relevant to core behavior, and old core lifecycle defects cannot be assumed fixed by the .67 update.


## R-39 Raptor visual uses maximum wear for both tracks
**CONFIRMED_STATIC**

Raptor render refs are pooled at vehicle level; one `wear=max(left,right,...)` scalar is applied to every ref. Per-track persistent asymmetry is lost visually.

## R-40 Special crawler full-reset path misses renderer-specific wear parameters
**CONFIRMED_STATIC**

ALL/native repair/repaint reset paths mainly clear `trackProfileWear` and the immediate reset explicitly invokes only the T9 worker. Raptor/A8800/Hannibal/Volvo use other shader parameters and can remain visually worn until their proper worker runs later.

## R-41 Visual weak-node caches use numeric keys
**CONFIRMED_STATIC lifecycle defect**

Multiple supposedly weak per-node material/classification tables are keyed by numeric node IDs. Entries do not disappear through weak-key GC, so reused node IDs can inherit stale state. This directly undermines the source's stated "one fresh material per live node lifetime" protection.

## R-42 Volvo immediate-load crash guard flag is never assigned
**CONFIRMED_STATIC dead guard**

`_inImmediateLoadRefresh` is read by the Volvo safety path but never set anywhere. A second controlled-vehicle gate may still prevent the dangerous timing, so a crash is not asserted.

## R-43 Crawler kind can cache a premature negative forever
**STRONG_CANDIDATE**

If `loadedCrawler` is absent during first classification, `rvDetectCrawlerMotionPathKind` caches false; vehicle type is then cached with no retry. Late-ready steel geometry can remain classified as fallback rubber.

## R-44 Generic/Raptor global material caches retain known dead-material lifecycle pattern
**STRONG_CANDIDATE**

A8800/special steel explicitly stopped globally reusing material entities because returned/rented vehicle material IDs became invalid. Generic `trackMaterialCache` and Raptor `raptorTrackMaterialCache` still use global numeric material-ID caches without deletion/mission invalidation.

## R-45 Generic crawler renderer mutates GIANTS `scrollerNodes[].nodes`
**DESIGN_RISK**

When GIANTS does not supply `entry.nodes`, Reifen synthesizes and writes the field into the engine-owned crawler structure rather than storing a private normalized target list.

## R-46 Passive visual predicate uses pcall success instead of returned attacher
**CONFIRMED_STATIC low severity**

`isPassiveObject = ... and pcall(getAttacherVehicle,...)` is true whenever the method executes successfully, even when it returns nil.

## R-47 EWFS mission-specific VehicleSystem hook is one-mission-only
**CONFIRMED_STATIC lifecycle bug**

`WFS.install` wraps the current mission's VehicleSystem instance and latches `installed/vehicleSystemEnterHooked`. Mission unload never clears those flags, so a second mission in the same process does not wrap its new VehicleSystem instance.

## R-48 IGNITION omission is not a confirmed vanilla bypass
**CONFIRMED_STATIC audit correction**

EWFS does not explicitly branch on `MotorState.IGNITION`, but GIANTS' normal ignition flow enters IGNITION from OFF while EWFS is already locked, and STARTING then creates the timer. When the ignition key returns from START to IGNITION while the engine runs, GIANTS keeps MotorState ON.

Therefore the omission is only a robustness concern for nonstandard external state manipulation, not a demonstrated vanilla five-second bypass.
