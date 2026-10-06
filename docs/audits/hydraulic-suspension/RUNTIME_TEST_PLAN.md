# Hydraulic Suspension runtime test plan

Baseline: exact external `1.6.9.0` package plus current target stack.

Purpose: learn the engine behavior and validate the phenomenon. This plan does not imply the external mod will remain installed.

## A. Baseline without HSS

Run with target MR/RC/Mud/RMS stack, HSS OFF.

For at least:
- one large tractor whose front suspension is visually modeled;
- one tractor with simple front wheel suspension;
- one independent-suspension candidate if available.

Record:
- static front suspension length;
- front wheel loads;
- spring/damping values/multipliers if diagnostic access allows;
- response over one bump;
- response after adding/removing front ballast;
- heavy rear implement weight transfer.

Goal: establish what vanilla + MR already owns.

## B. HSS ownership observation

HSS ON, same machines.

Verify:
- when MR calls suspension multipliers;
- whether HSS suppresses them as source predicts;
- effective front spring/damping after suppression;
- whether rear MR behavior remains different from front.

This test is diagnostic, not a target behavior.

## C. Load leveling

Change front/rear load in controlled steps.

Measure:
- ride-height error before leveling;
- settling time;
- overshoot;
- final suspension stroke;
- left/right load difference.

Compare current HSS load-ratio controller with the proposed ride-height closed loop.

## D. Mode transitions

AUTO -> WORK -> LOCKED -> MANUAL where supported.

Look for:
- ride-height jumps;
- wheel-shape rebuilds;
- spring/damping discontinuities;
- tire visual deformation discontinuity;
- MR state divergence.

## E. Bump / articulation

Test:
- one wheel over a rock;
- diagonal ditch;
- repeated rough road;
- low-speed crawl.

Separate:
- real physics movement;
- wheel visual movement;
- synthetic `positionY` movement.

Especially validate vehicles whose XML already has a physical axle component/joint.

## F. Power hop

Create a repeatable high-draft/slip case.

Record:
- front/rear slip;
- suspension stroke;
- vertical load;
- chassis pitch/vertical acceleration if available.

Question:
Does slip residual correlate reliably with actual vertical hop?

The result informs the clean RE detector.

## G. Braking/acceleration pitch

Repeat hard brake and launch.

Compare:
- `getLastSpeed` derivative;
- body acceleration if available;
- actual front suspension response.

## H. Multiplayer authority

On dedicated/server + client:
- owner changes mode;
- another player in same farm attempts to change the vehicle remotely if practical;
- different-farm client attempts request;
- manual height spam.

A future RE implementation must reject unauthorized transitions.

## I. Physics rebuild lifecycle

Trigger:
- vehicle reset;
- workshop/configuration change;
- leave/re-enter physics;
- load second save in same process.

Check suspension hook/visual ownership remains singular.

## Evidence wanted for clean implementation

- exact logs around MR suspension calls;
- wheel/suspension diagnostics before/after HSS;
- video/screenshots for ride-height and bump behavior;
- save/reload behavior;
- MP logs from both sides.

The most important output is the **MR composition contract**, not a subjective "feels softer".


# Release 1.0.0.0 additional runtime plan

The original A-I tests remain valid. Add the following before any absorption decision.

## J. Server/client profile and settings authority

Use dedicated server + at least one client.

Create a deliberate server/client mismatch where practical:
- different physical profile/custom profile values;
- different camber/visual settings;
- different local HUD settings.

Verify separately:
- actual server spring/damping/ride-height behavior;
- client HUD system/profile values;
- client visual wheel behavior;
- mode/manual capability presentation.

Goal:
determine which release values are genuinely authoritative and which clients independently reconstruct from local settings.

Acceptance direction for RE:
- local HUD placement may differ;
- authoritative capability/profile identity must not;
- visual-only preferences may differ only when they cannot falsely represent physical state.

## K. Cab-isolation lifecycle and compatibility

Test interior camera with:
- smooth road;
- repeated bumps;
- side slope;
- hard braking/acceleration;
- enter/exit vehicle repeatedly;
- switch interior/exterior cameras;
- vehicle reset;
- workshop/configuration change if applicable;
- second save loaded in the same process.

Also test with any target-stack camera/head-motion mod if present.

Observe:
- duplicate transform insertion;
- camera drift;
- parent hierarchy after reset/reload;
- interaction with other camera rotations;
- whether the visual correction tracks chassis attitude or produces false motion.

Goal:
decide whether presentation-only CabIsolation has value and whether hierarchy reparenting is actually required.

## L. Loader ride-control actuator binding

Use at least:
1. a standard front loader whose arm movingTool is recognized;
2. a loader/attachment with unusual movingTool naming if available;
3. a loader where the joint is detected but no `ARM` movingTool can be bound.

For each:
- below and above activation speed;
- empty and heavy bucket/tool;
- attach/detach;
- operator arm movement while ride control is active;
- rough road;
- braking/acceleration;
- reverse travel;
- reset/workshop/physics-removal path.

Record independently:
- loader detected;
- actuator found;
- controller requested active;
- actual arm correction;
- HUD active indicator;
- fallback suspension damping state.

Critical question:
can the current release reproduce the static HSS-21 case where HUD/fallback say ride control is active but no arm correction exists?

## M. Loader control quality

For a successfully bound loader, log:
- chassis vertical acceleration;
- arm angle and angular velocity;
- commanded/base arm movement;
- controller offset;
- tool/load oscillation;
- speed.

Compare:
- ride control OFF;
- HSS release controller ON.

Evaluate:
- peak acceleration;
- settling time;
- overshoot;
- load bounce;
- whether the controller fights intentional operator commands;
- whether the correction remains bounded at travel/angle limits.

This decides whether the phenomenon is worth implementing, not whether the exact HSS tuning should be retained.

## N. Loader lifecycle / physics guard

Specifically exercise:
- attach loader;
- activate ride control above threshold;
- reset vehicle;
- enter workshop or configuration flow;
- remove/re-add physics if reproducible;
- detach loader while controller has non-zero offset.

Watch for:
- stale offsets;
- arm motion while the vehicle is outside normal physics lifecycle;
- dirty movingTool writes after detach;
- offset not returning to baseline.

This targets HSS-23.

## O. Settings UI lifecycle

Open/close the in-game Settings page repeatedly and, if available, combine with another mod using similar settings injection.

Check:
- duplicated controls;
- duplicated frame hooks;
- controls surviving save reload;
- disabled server-only controls on clients;
- correct value persistence;
- behavior after game/UI update.

This is primarily a learning test for a potential shared RE settings adapter.

## P. Network bandwidth / visual reconstruction

With multiplayer logging/telemetry:
- drive repeatedly over rough terrain;
- observe dirty-flag/update frequency;
- compare synchronized slow state with local high-frequency wheel motion.

Goal:
validate the positive HSS-25 pattern quantitatively.

For a future RE implementation, prefer:
- authoritative slow/effective state;
- event-driven mode/config changes;
- local non-authoritative high-frequency presentation;
- no per-frame networked wheel visual state.

## Updated exit gates

Before implementing **ActiveSuspension**:
1. all original exit gates remain;
2. authoritative server/client profile contract is defined.

Before implementing **LoaderRideControl**:
1. at least one robust actuator-binding strategy is proven;
2. detected/bound/active states are separated;
3. intentional operator motion composes cleanly with transient correction;
4. lifecycle/reset/detach behavior is safe;
5. the physical benefit is measurable against OFF baseline.

Before implementing **CabIsolation**:
1. decide explicitly whether scope is visual isolation or true cab physics;
2. prove camera hierarchy install/uninstall safety;
3. test compatibility with target camera mods.
