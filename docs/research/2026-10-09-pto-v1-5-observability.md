# Native PTO V1.5 — estimated shaft RPM and worker transition diagnostics

Date: 2026-10-09
Branch: `feat/pto-v1-5-observability`
Scope: RE HUD/AI instrumentation only, based on RE main `2534cec4` after PTO V1 merge. No RC, MR, RMS or terrain changes.

## Instrument

The existing dashboard icon and nominal selected family (540/540E/1000/1000E) remain unchanged. A second compact line appears only while a PTO implement is engaged:

- `540` — **nominal gearbox setting**, not measured current shaft speed.
- `≈415` — **kinematic estimate**: physical engine RPM divided by the selected effective PTO motor ratio. This is **not** an independent shaft sensor and **does not** prove actual mechanical slip or attachment status.

The value is taken from the existing RE owner state and physical engine RPM, with neither new MR hooks nor overwritten game physics. A render-only exponential low-pass (default 350ms) reduces text jitter. Readout resets on disengage, invalid ratio, vehicle/gear change and HUD reset; raw value remains available through `getDiagnostics().lastEstimatedRpm`. The smoothed number is `lastDisplayedRpm`; the old `lastActualRpm` remains as a deprecated alias for the *unsmoothed kinematic estimate*, for downstream diagnostics compatibility.

Configuration in `scripts/Config.lua` / `ptoHud`:

- `showEstimatedRpm=true`
- `rpmTextSizePx=8`
- `rpmTextGapPx=3`
- `rpmSmoothingMs=350`

The fallback mode text includes the estimate when engaged and valid, but omits it when disengaged, invalid or disabled. Text is anchored below the existing nominal selector, near the vanilla speed cluster/RMS; it has no independent large panel. The standard HUD layout/scale controls remain functional. Under-RPM **never causes a new red warning**; the only existing critical states are physical gear mismatch and engaged high-speed transport advisory.

## Event-only AI decisions

`PTOControl.lua` emits a compact INFO message tagged `PTO AI |` on *meaningful PTO worker decisions*, with the vehicle, selected family, saved operator family, required family, retained hand throttle and reason:

- suitable gear selected or already compatible;
- blocked conflicting requirements, unresolved family or unavailable physical gearbox;
- refused to change gear because the shaft is engaged;
- restoration deferred pending disengagement, then restored (or declined if unavailable).

Duplicate `onAIJobStarted` / `onAIFieldWorkerStart` callbacks with the same resulting decision are deduplicated; unrelated non-PTO fieldworkers are silent. No per-frame diagnostic output is added; the rare deferred restoration may invoke the existing event logger only on the state transition. Enabled by default with `diagnostics.ptoWorkerEvents=true`, independently of the verbose/performance diagnostics. Set `false` for fully silent worker decisions.

These messages are *source-level observability*, not proof that Courseplay/GIANTS execute the events on every machinery type. Actual powered-implement coverage remains version-specific. We will use the messages to distinguish **missing AI callback** from **governor under load** without asking users to reproduce existing save/load tests.

## Automated acceptance

Extend the existing HUD and control harnesses to assert:

- nominal + estimate on engagement, no estimate when disconnected;
- smoothing changes only displayed value, raw kinematic value remains unchanged;
- invalid ratio suppresses the estimate rather than inventing a value;
- option disables only the supplemental text;
- event messages for selection, deduplication, deferred shift and safe restoration;
- no logging on ordinary non-PTO activity or when the option is OFF;
- no change to manual player mode, AI gearbox selection, physical shaft interlock, MR/RMS bridge or terrain defaults.

CI parses Lua, runs the whole harness collection, verifies XML and emits a mod ZIP. A single observational smoke may later validate 1080p positioning, but manual retests are not required to accept this static/CI milestone.
