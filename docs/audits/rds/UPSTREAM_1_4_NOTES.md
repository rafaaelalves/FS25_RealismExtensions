# RDS current-upstream notes (1.3 / 1.4)

Updated: 2026-10-05

## Evidence limitation

No public GitHub repository for Realistic Diesel Start / GN Realism was found during this audit.

Newest public release identified: **1.4.0.0**, published 2026-10-04.

The actual 1.4 Lua source was not available in this session. Everything below is therefore public changelog/description evidence only, not source verification.

Primary 1.4 page:
https://fs22mods.com/realistic-diesel-start-v1-4-0-0/

Historical 1.3 page:
https://fs25.net/realistic-diesel-start-v1-0/

## 1.3.0.0 reported changes

Public changelog reports:
- Advanced Damage System compatibility;
- shorter/more realistic cold glow preheat;
- helper freeze during air build-up fixed;
- false visual running state after unsuccessful start fixed;
- new dashboard icons and ADS-aware layout.

Implications for the 1.2 audit:
- the 1.2 speculative visual-running path was a real upstream issue;
- AI/air readiness could deadlock helpers;
- upstream itself considered the cold preheat duration too long;
- ADS is moving from explicit conflict toward composition.

Do not infer how these were implemented without source.

## 1.4.0.0 reported changes

Public changelog reports:
- dedicated clutch binding moved from `L` to `Alt+L` because shared FS25 key bindings can leave only one action active;
- migration preserves custom bindings where possible;
- spring/low-air brake-light behavior corrected to prevent battery drain and restore pedal-controlled brake lamps;
- trailer air supply added with Realistic Brakes 1.3.0.0;
- HUD alignment corrected for non-1.0 UI scale and ADS layouts;
- ADS hard-start behavior revised so difficult-start faults can keep cranking until success;
- start key no longer bypasses glow plugs or stops the engine incorrectly on release;
- ADS 0.9.2.8 is the reported tested baseline.

Implications:
- input collision is a proven operational issue, not a theoretical concern;
- 1.2 brake-light ownership was wrong and has been changed upstream;
- fragmented HUD coexistence continues to require maintenance;
- ADS start composition remains complex;
- trailer pneumatics now cross into another GN Realism specialist.

## Absorption consequence

Upstream progress does not make RDS a poor mod. It strengthens the architectural case for native RE ownership in this particular stack:

- start intent repeatedly needs to compose with ADS/RMS;
- RDS carries its own HUD/input/settings state;
- air behavior now reaches a separate brake mod;
- RE already has a shared HUD and capability-ownership architecture.

The goal is therefore clean functional integration, not reproducing RDS implementation details.

## Required exact-source follow-up

When RDS 1.4 ZIP/source becomes available, diff it against the supplied 1.2 baseline for:
1. ADS integration;
2. input/clutch migration;
3. AI/helper pneumatic behavior;
4. brake-light correction;
5. Realistic Brakes/trailer-air API;
6. HUD scaling/lifecycle;
7. initial stream/network authority;
8. license/provenance;
9. hot-path/performance changes.

Then mark every 1.2 finding as still present, fixed upstream, changed-but-relevant, or obsolete.
