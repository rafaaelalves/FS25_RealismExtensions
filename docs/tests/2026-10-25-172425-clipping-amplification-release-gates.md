# 2026-10-25 17:24 — clipping screenshot, RE toggle ambiguity, native rut amplification and release readiness

**Primary evidence:** user screenshot showing Fiat 180-90 DT partially penetrated below apparent tilled field surface; exact `log(20261025-172425).txt` (~6,804 lines including several load/save cycles) and `ModMixer(20261025-172425).log` (143 lines). Compare `log(20261025-155629).txt`. User reports a similar clipping image after “RE disabled”. Important: the **runtime log still shows RE and TerrainDeformation enabled** throughout the observed starts; no definitive event proving RE was absent or all hooks inactive. Treat this as **reported A/B**, not conclusive isolated RE removal. Clipping remains visually credible and was observed even before this logged native LOWER burst.

## Verified exact build / initialization

- `FS25_RealismExtensions` ZIP remains available AND `Load mod` in session; startup `BuildIdentity branch=64/merge commit=d2600080d7d985edc637dbc96784d4d1e1169cee run=40206209999`. The earlier session likewise was on this build.
- `TerrainMode journalRequested=true causalRequested=true legacyTARGET=false`, `TerrainDeformation=ENABLED`, `native journal ready restored=872 rejected=0`; `TireTrack capture initialized`. Thus **do not certify no-RE A/B from this log**. Maybe user disabled it for a different load or via ModMixer and later re-enabled; data cannot decide.
- Actual GIANTS wheel errors `Wheel shape not found for getContactPoint` **absent** from this run. The errors seen in earlier logs were near vehicle deletion and do not explain screenshot.
- ModMixer runtime named hooks present MR/Mud on WheelsUtil and WheelPhysics; `0 vetoes`, known hook chain. A June 1 scan-based “CRITICAL” is not proof of current conflict. RC last telemetry still `MRMud.updateFrictionCalls=230660, rollingResistanceCalls=229859, localWetnessOverrides=229675`; other model call counts recovered to 21,540. Therefore **cannot attribute visual clipping to a proven MR/Mud hook stomp**.

## Confirmed freeze transition, rut burst and huge geometric delta

- Loaded state `TerrainFreezeState frozen=true airC=-2.34 wetness=0`. At **14:23:05**, `frozen=false airC=-2.00 wetness=0.615`. This is GIANTS **air** temp reported by Mud/RC, not measured soil temperature. The instantaneous `<-2°C` flag as documented in Mud v1.3.7.0 (no thermal inertia) explains a sudden step in permanent yielding. No Brazil-specific override desired.
- For ~12 min until this transition, `wheelAccepted=0, wheelConfirmed=0`. By **14:23:54**, only ~49s after the transition: `wheelAccepted=166 wheelDeferred=516 wheelConfirmed=30 noEffect=136 nativeAmplified=25 nativeGuard=29 cap=29 oldHollow=0`. This proves causal RE rut writing **became active late in the session** despite the user believing RE off in an earlier screenshot.
- Six bounded paired `TerrainNativeDelta` samples at coordinates ~x315–318,z309–311 and `wetness=0.611`, `pressurePa=250000`, `slip=0.415–0.817`, `bearingRatio=1.26–1.74`:
  - requested **0.0024m**, observed native max **0.0078m** (several),
  - requested **0.0024m**, observed max **0.0584m**,
  - requested **0.0024m**, observed max **0.1128m**,
  - requested **0.0024m**, observed max **0.1479m**.
- Same 30 positively moving native events aggregate `nativeActualMaxSum=1.0623m nativeRequestedSum=0.0712m`, ratio about **14.9×**. These are SUMS of per-operation MAX sampled vertex delta, NOT ground depth of one rut nor volume. **Critical release blocker:** requested 2.4mm is not a verified maximum physical result; 10cm guard restricts later writes but can neither stop same-callback 14.8cm displacement nor precisely balance deep rut severity.
- `TerrainGeometryJournal:complete` measures before/after sampled main-heightmap vertices *within the callback*, but this only establishes a net height change during a native operation, not sole causal ownership of that delta if a third-party engine/physical writer intervened. Journal locks RE-owned same-vertex transactions; native engine channel/brush semantics and other writers still need evidence. Do not label every delta a GIANTS engine bug without isolating this.
- Native save later `saved native geometry journal cells=937 unknown=0`; import/export works, but a first touch may own huge unexpected geometry.
- 0 `TerrainWorldMaintenance.periods` during the run; **migration not exercised in actual gameplay**. Code/harness verified subscription/territory/queued journal work only. Requires at least one actual game period change with verified NPC authorized RE ruts and/or public dirt paint.
- Previous 15:56 session (same build) 78 genuine tillage-area recovery callbacks, 78 improved, 26 physically closed; current 17:24 session 0 new tillage recovery callbacks, so **newly-allowed rut writes WHILE the same implement works** have NOT been proven to coexist with native TARGET in same area/time. Spatial guard in source protects actual worked area while not protecting entire tractor. Needs focused criterion, not more general crop-cycle tests.

## Why 1m journal alone cannot certify what the player SEES / where wheels COLLIDE

GIANTS official FS25 engine interview explicitly says wheel/terrain physical deformation uses **0.125m** resolution, with CPU procedural component and distance-dependent terrain geometry meshes: https://www.farming-simulator.com/newsArticle.php?lang=en&country=us&news_id=569 . Our journal `unit=1m` represents a MUCH coarser native sampled subset; it does not characterize all fine rut cross-section/contact height/visual wheel deformation/suspension. A mismatch of transient wheel sink, wheel visual position and high-res displacement remains plausible without a RE LOWER. GIANTS `WheelVisualPartTire:update` also modifies visual tire morphology/suspension length independently of terrain height: https://gdn.giants-software.com/documentation_scripting_fs25.php?category=93&class=914&version=engine . Thus:
- Do **not** assume screenshot is caused by RE's journal, MR/Mud conflict, or tire visual mesh alone.
- A clean before/after same position measuring **wheel collision contact**, effective wheel radius/sink from Mud, native high-res displacement, and 1m sampled journal height is needed before recommending compatibility changes.
- If user toggled RE OFF after it had already written persistent geometry on this save, those old holes do NOT evaporate; such an A/B doesn't clear historic RE terrain causation.

## Release gate decision (2026-10-25)

**NOT release-ready, even with fixed 10cm cap.** Keeping the guard is a temporary harm reduction but it is NOT an effective output clamp. Do not remove. The residual risk is confirmed by `actualMax=0.1479m` after `requested=0.0024m`. Key gates:
1. Understand native brush values vs actual geometry (coarse/fine/wheel contact), isolate third-party interference, redesign actuation or a controlled effect to ensure bounded physical outcome without flattening legitimate terrain.
2. Simultaneous working tractor wheel rut formation and implement repair must be stable and physically appropriate (source logic + CI green but runtime not proven), including AI and hard wet conditions.
3. Ported NPC/municipal PERIOD_CHANGED maintenance must actually run on suitable farmland/public surface, repair truly, respect ownership and geometry on real map. RE-owned reference only; unknown third-party, natural terrain and landscaping remain conservatively protected.
4. Soil-freeze classification and physics coherent; compare real air threshold, Mud sink and visual wheel/collision channel. No region-specific hacks.
5. SP save/load established; test after actual NPC month, multiplayer behavior, memory/performance bounds, old save migration. Deep rut mass transport/recovery process remains unsatisfactory/unproven.
6. Enforce no false positives: CI is green but doesn't validate GIANTS native engine runtime.

Recommended engineering next step: focused isolated native brush probe with **one** controlled rut geometry transaction; log pre/post **per-vertex full displacement cross-section**, native callback returned volume, wheel contact/visual/sink proxies, freeze context and active writer ownership, with zero/RE-only/Mud+MR options in disposable copy. No requirement to repeat another season's generic cultivation. No additional ZIP merely for docs.
