# Native PTO V1 — AI-selected gearbox and release closure (2026-10-09)

## Architecture and user requirement

- A worker using a mechanical PTO tool should select the installed nominal shaft-speed family (540 or 1000) before engaging it. The worker must not inherit a mismatching player gear.
- The GIANTS/MR governor continues to own autonomous engine RPM; RC MRPTO head e52687bf fixes saved player hand throttle accidentally constraining AI RPM.
- RE modifies *only the effective gearbox selection* at server-side AI start, preserving the player's previous gear and throttle. It uses the same proven selected motor ratio in RC MRPTO / RMSPTO.

## Implementation

- AI events: `onAIJobStarted` (prior to field engagement), `onAIFieldWorkerStart` (fallback), `onAIJobFinished`, `onAIFieldWorkerEnd`. They are idempotent. For attached new equipment while AI active, refresh requirement and choose only while disengaged.
- Read `Resolver.collectRequirements`: no selection without known EXACT requirement, no conflicts or unknown additional PTO demands. Prefer nominal 540/1000 gear; use supported economy gear only if the physically available standard is absent and ratio is defined.
- Never round 750/900/1300 to 540/1000. Never add uninstalled hardware. If the implement is already running, don't shift gears. Under an unsupported requirement, preserve current state; no magic fix.
- Only server changes AI gears; updates are propagated using the existing PTO state event and dirty flags. No synthetic torque, engine-RPM floor or forceful gearbox shift while engaged.
- `spec.aiOriginalMode` is *transient* and saved in XML as the player's previous gear, not the AI mode. `handThrottlePercent` remains untouched throughout. After the worker leaves, restore the previous gear if disconnected. If still engaged, the deferred restoration checks only until shaft disengagement and then restores. A cheap `onUpdate` early return is used for this rare condition only.
- Manual operator commands are rejected while worker has control (or pending restoration); the worker gear is not supposed to be manually edited during fieldwork.
- No terrain changes. In standalone or no-worker operation the prior feature remains unchanged.

## Evidence and limitations

- Previous real paired build at RE 2a471dba + RC ca1ce3c0 validated nominal PTO selector, manual throttle response, saved game restart, MR/RMS bridges, terrain OFF.
- New bridge and AI gear code require green CI. Actual Courseplay fieldwork remains **not re-tested**, because supplied live terrain is unusable for an independent PTO workload experiment. This is a specifically identified validation limitation, not a reason to ask the user to redo save-mode tests.
- Client events show the effective selected gear in the HUD; save XML persists the original operator gear even while AI active. Dedicated multiplayer acceptance may be part of future supported-mode validation.

## Future scope

Physical PTO overspeed, shaft slip, clutch wear and implement-specific productivity belong in V1.5/V2 with MR/RMS ownership; no universal speed multiplier.
