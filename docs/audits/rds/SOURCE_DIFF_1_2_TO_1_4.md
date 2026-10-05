# RDS exact-source update audit — 1.2.0.0 -> 1.4.0.0

Updated: 2026-10-05

## Exact archives

Previous baseline:
- `FS25_RealisticDieselStart 1.2.0.0`
- SHA-256: `e22816e712ef6a48c8f0210209f9983a7c4da3bc55a6267a7fbaad5c5f6bacbd`

Current user-supplied archive:
- `FS25_RealisticDieselStart 1.4.0.0`
- SHA-256: `a2a983c7754bc4fb3dffc04839fb16cf844c72d7664ae78cfcd70fcf3c15721c`

No public GitHub repository was found; this file is therefore the current exact-source upstream baseline for this project.

Diff size:
- source/XML lines: about 3,090 -> 4,057;
- `RealDieselStart.lua`: 1,643 -> 1,934 lines;
- `RDSHud.lua`: 656 -> 1,073 lines;
- `RegisterSpecialization.lua`: 88 -> 190 lines;
- about 1,420 inserted/changed lines across 12 files;
- no source files removed and no new Lua modules added.

## What 1.4 actually changed

### 1. ADS coexistence became a real composition layer

1.4 removes ADS from the explicit conflict list.

It now:
- globally intercepts `Motorized.actionEventToggleMotorState` and suppresses that action for non-electric RDS vehicles, so ADS cannot bypass the staged RDS key path;
- mirrors RDS key-down/key-up into ADS private start-button fields;
- optionally calls `ADS_StartButtonEvent.send`;
- recognizes when `startMotor()` was intercepted by another owner and keeps the RDS state in external CRANKING until the motor actually starts or the player releases the key;
- confirms start from `onStartMotor` instead of assuming `startMotor()` succeeded.

This fixes the 1.2 false-RUNNING problem and supports ADS hard starts much better.

**Architecture lesson:** distinguish "start request accepted" from "engine is actually running", and make the final transition event-driven.

**Remaining concern:** the integration is private-contract-heavy. It writes `spec_AdvancedDamageSystem.startButtonDown/startButtonHeld/startButtonUp` directly and references `ADS_StartButtonEvent`. Native RE should instead use a provider/API boundary.

### 2. Diesel Fuel System integration is capability-driven

1.4 exposes `RealDieselStart.SC_COMPAT=true` and conditionally consumes:
- `vehicle:scGetColdStartFactor()`;
- `vehicle:scGetStartBlockReason(shortText)`.

The cold-start factor modifies combustion difficulty and a blocked fuel system can provide the real reason shown by RDS.

This is a strong positive pattern:
- no hard dependency;
- feature detection;
- owner-specific reason remains authoritative;
- UI avoids duplicated warnings through an explicit compatibility flag.

The archive itself does not implement the advertised common-rail priming-pump mechanics; that behavior, if present, is on the fuel-system side.

### 3. Realistic Brakes integration adds a narrow pneumatic API

RDS now registers:
- `rdsGetAirPressure()`;
- `rdsSetAirPressure(bar)` — server-only.

The comments state Realistic Brakes 1.3 uses these to equalize/fill trailer air from the truck.

Positive lesson: the state owner exposes a small capability surface instead of the consumer reading private spec tables.

Important improvement for RE: do not expose arbitrary absolute `setPressure` as the primary transfer contract. A conservation-aware operation such as `requestAirTransfer` / reservoir-volume exchange is safer and easier to audit.

### 4. Input migration is much more mature

The default synthetic clutch binding moves from `L` to `Alt+L`.

The migration:
- inspects the player's existing binding;
- changes it only if it is still the old exact default;
- preserves custom mappings;
- saves the profile through InputBinding APIs;
- writes a one-time migration marker;
- notifies the player later.

This is a reusable RE pattern for future keymap migrations.

Remaining issues:
- the synthetic clutch itself remains a second, non-physical clutch;
- the 400/550 ms start-input dead band still exists;
- the migration installs a global `FSBaseMission.update` append solely to count down one notification timer. RE should reuse its existing lifecycle/update service instead of adding a global hook for one delayed message.

### 5. HUD engineering improved substantially

New useful patterns:
- listens for UI-scale changes and recomputes geometry only when the setting changes;
- anchors to the native speedometer rather than a fixed screen position;
- separates width/height conversion and respects aspect ratio;
- pixel-snaps small indicators for cleaner sampling;
- chooses ADS/no-ADS layout **per vehicle**, including ADS-excluded vehicles;
- supports live calibration and stores separate layout offsets;
- hides the duplicate RDS thermometer when ADS owns that vehicle's temperature presentation.

These are useful precedents for a future RE shared HUD.

However, the 1.4 HUD has grown to >1k lines largely because each external layout is hand-managed. RE should prefer semantic slots/layout ownership rather than hard-coded "with ADS / without ADS" coordinate sets.

### 6. Glow curve was recalibrated, not redesigned

1.2:
- max 25 s;
- 1.0 s per degree below 20 C.

1.4:
- max 20 s;
- 0.45 s per degree below 20 C.

This is a meaningful gameplay calibration improvement and confirms the old curve was too slow.

The architectural limitation remains: one global curve still applies to all non-electric motorized vehicles. RE should retain technology/profile-based glow behavior.

### 7. AI air deadlock was fixed through abstraction

When AI is active, RDS clamps air pressure to at least governor cut-in pressure.

This prevents the previous stop/go helper deadlock.

Lesson worth keeping: AI should not be forced through every manual readiness gesture.

But the exact implementation is intentionally magical: persistent pressure can jump upward for free. RE should model an explicit AI readiness policy (fast pre-trip fill / bypass of player interaction / bounded preparation) without mutating the physical reservoir merely to avoid a deadlock.

### 8. Brake-light ownership was corrected

1.4 no longer forces service brake lights from the spring-brake state and no longer clears normal pedal brake lights each frame.

This closes the earlier RDS-16 defect and validates the ownership rule:
- service brake lamps follow service demand;
- spring/parking brake state is separate.

### 9. The core pneumatic physics is otherwise essentially unchanged

The source still uses:
- one 0..10 bar reservoir;
- constant compressor rate independent of RPM;
- one truck-category heuristic;
- leakage from vanilla damage;
- continuous held-pedal consumption scaled by speed and mass;
- spring-brake physical force only above a speed threshold;
- no apply/release hysteresis;
- no full initial state stream.

Therefore the proposed RE pneumatic redesign remains valid.

### 10. Warm-up became load-sensitive but still duplicates specialist thermal ownership

1.4 now samples `motor:getSmoothLoadPercentage()` and heats faster under load.

This is conceptually better than a fixed warm-up timer.

Two caveats:
- comments repeatedly say "RPM/load", but the implementation uses load, not engine RPM;
- RDS still owns its own `engineHeat`, direct `motor.torqueScale` derate and speed-based generic cold damage.

RE should learn from the **load-sensitive state progression**, not absorb this second thermal/damage owner.

## Source defects / cleanup opportunities still present in 1.4

### U14-01 — internal version diagnostic is stale
The 1.4 archive ends with:

`Script principal cargado (v1.2.0.0)`.

This makes runtime provenance unreliable. RE's CI-stamped BuildIdentity is the better pattern.

### U14-02 — HUD dead state/resources
Current source still carries:
- `READY_BLINK_TIME_MS` and `readyBlinkTimer`, although READY blinking was removed from the HUD;
- `showBar` initialized false and never enabled;
- `statusText` initialized nil and never assigned;
- `barBg` / `barFill` allocated even though the remaining main progress bar never renders;
- `tickMark` allocated but unused.

This is a useful reminder to remove retired presentation state when UX changes.

### U14-03 — HUD lifecycle leak
`tickMark` is created but not deleted.

`rdsHudSinADS` is registered by each HUD instance but `delete()` removes only `rdsHudPos` and `rdsHudReset`.

Second-mission / same-process behavior deserves runtime validation.

### U14-04 — local stochastic start decision remains
RDS still rolls `math.random()` in `tryCrank()` on the local control path.

The later damage may be sent to the server, but the combustion outcome itself is not server-authoritative.

### U14-05 — client damage request remains under-authorized
`RDSDamageEvent` still accepts a synchronized target vehicle and arbitrary float amount without controller validation.

### U14-06 — initial pneumatic stream is still deliberately absent
The source still documents that a joining client may briefly see the default pressure until the first event update.

### U14-07 — start timing dead band remains
Release at 401–549 ms still performs neither short press nor crank.

### U14-08 — broad motorized eligibility remains
The specialization still attaches to every motorized vehicle type and only explicitly excludes electric vehicles.

### U14-09 — duplicate visual compatibility work remains
`rdsApplyIgnitionVisualStates()` still runs from both `onUpdate` and `onPostUpdate`.

## Updated absorption conclusion

1.4 is clearly better software than the supplied 1.2 baseline and contains several patterns worth learning from.

It does **not** invalidate the functional-absorption decision.

Instead it sharpens the target:
- keep the staged operator UX and event-confirmed final start transition;
- adopt capability APIs and graceful optional integration;
- adopt safe keybind migration and scale-aware HUD patterns;
- do not reproduce private ADS table coupling;
- do not reproduce duplicate thermal/damage ownership;
- redesign pneumatics around conservation and physical pressure demand;
- make authority, initial sync, lifecycle and diagnostics first-class from the beginning.


## Current RealismCompatibility implication

Current RC version policy verifies RDS `1.2.0.0` for `RDSADS`; RDS
`1.4.0.0` is not accepted by that bridge.

That fail-closed behavior is correct.

Do **not** add 1.4 as SOURCE_COMPATIBLE to the historical bridge:
- upstream RDS now owns its own ADS interaction;
- the bridge was designed to repair 1.2 ownership gaps;
- activating both would risk double-routing start gestures/hard-start state.

If RDS 1.4 + ADS is used externally during migration, let upstream RDS handle
that pair and keep RC `RDSADS` inactive/unsupported.

The native RE replacement should eventually remove the need for either path.

## Classification lesson from old RC

The historical RC bridge already improved one upstream behavior:
- it classified explicit `FillType.DIESEL`;
- it bypassed electric and no-diesel consumers.

Exact RDS 1.4 still enables its sequence for every non-electric motorized
vehicle.

Therefore the old RC classification logic is a **better precedent** than
current upstream RDS for RE `StartProfileResolver`.
