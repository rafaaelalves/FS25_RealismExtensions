# FarmKit capability + asset audit

Source: FarmKit `1.0.0.3`, commit `8ee55d9b8efe6f58ecc2984bd276c7a130d8f0bd`.

This file answers a different question from the RC compatibility audit: **what should RealismExtensions eventually produce, improve or replace?**

## Group 1 — High-value clean-room replacements, no custom asset blocker

### Terrain deformation
Recover and improve:
- longitudinal slip ruts;
- lateral scrub;
- repeated-pass accumulation;
- wetness/freeze sensitivity;
- player + AI + implement wheel coverage.

Do not reproduce FarmKit sink/grip/stuck ownership.

### Furrow interaction
FarmKit's dynamic furrow detection and collider-width behavior is unique in the current stack. A future clean-room module can consume MR suspension state rather than resetting/owning suspension itself.

### Crop interaction
Potentially combine:
- speed-based crop damage;
- load/footprint influence;
- steering/lateral scrub;
- wetness sensitivity;
- off-field vegetation/meadow damage;
- CropDestructionAnywhere-style ownership-rule removal where appropriate.

## Group 2 — Retained FarmKit features that can be improved/replaced later

### Implement dust
FarmKit's concept is useful: scale existing work particles and add fade tails. Observed runtime intensity can look exaggerated.

Future direction:
- use implement work state and soil moisture;
- calibrate against implement type, speed and actual working load;
- avoid a global visually arbitrary multiplier;
- reuse existing particle systems when possible.

No new particle art is required for a first implementation.

### Road spray
Good phenomenon, but FarmKit currently uses its own wet particle assets.

Future direction:
- own original particle asset or use a defensible GIANTS/runtime source;
- consume local road wetness/rain rather than only global wetness;
- scale by speed, wheel width and water state;
- coordinate with wheel dirt/cleaning state from Mud.

This is asset-bearing and therefore not first-wave.

### Engine sound propagation
Conceptually valuable:
- distance rolloff;
- occlusion;
- low-pass;
- Doppler.

Before replacing:
- exact audit against soundExpansionMP;
- verify CPU cost of raycasts/occlusion;
- preserve MR as engine/RPM synthesis owner.

### HUD
FarmKit's UI is not a target to clone. A future Extensions HUD should consume normalized authoritative state and replace fragmented/contradictory overlays across the stack.

## Group 3 — Keep external / do not reproduce now

- wheel mud/dirt particles: Mud owner;
- grip/sink/stuck/viscous resistance: MR/Mud owner;
- engine bog/implement torque heuristic: MR/RMS/PTO ownership;
- body roll implemented as a second direct dynamics writer: not desired;
- load spill: RealPhysics external;
- Planner/PF UI: useful but not a first-wave physics goal;
- Straw Refeed: retain/audit future RHM bridge before deciding replacement.

## Asset conclusion

The most important features lost by RC's conservative FarmKit profile are **not blocked by custom assets**.

The main asset-heavy FarmKit contribution relevant to future replacement is road/wheel wet particle presentation. Ruts, furrows and crop interaction can start entirely as code/runtime-primitive work.
