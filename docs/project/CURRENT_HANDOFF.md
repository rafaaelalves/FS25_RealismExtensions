# Current development handoff — experimental terrain, 2026-11-13

## 27-Nov-2026 — integer MAIN patch envelope (SHADOW)

Planner V8 adds planMainPatch and console patchPlan <candidate_q_m> <max_added_gradient> (5x5 around reGeoMark). Caller-supplied research q and maximum gradient of NEW modeled depth, not absolute terrain slope or a verified soil friction parameter. Floor each supported cap to whole q without upward rounding; integer 8-neighbor monotone relaxation with zero-new-depth outer halo, no spreading into unsupported vertices. Axial/diagonal limits based on actual horizontal grid distance. Reports quantization vs slope withholding and final maximum added gradient; sums of depth are not physical volume. Bounded 7x7 maximum, 32768 inspected members, N+1 sweeps, deterministic pure read-only model. No native height reads, no actual debt/ownership reconciliation, no write ordering or budget reservation, no production permission, no claim of collision/fine channel. Existing projection/legacy peak preserved. Test isolated peak, broad patch, low center, zero step gradient, below-q, actual projection and repeat. 0.02 m/m is a test assumption only; not a calibrated gameplay limit. Next compare actual terrain reference/readback and recovery plan without conflating model delta with cumulative paid native debt.

## 27-Nov-2026 — MAIN spatial projection, no-write

Planner V7 keeps V6 max depth and virtual history unchanged. Added on-demand projectMain(ix,iz) / reTerrainTrial projection after reGeoMark. Estimate area-weighted NEW logical cell depth over a MAIN square: clipped disjoint canonical logical cells, dedup MAX at aliases, uncovered area zero, adjacent buckets for crossing seams, bounded 4096 members. Track only growth with existing MAIN_RESEARCH_CANDIDATE evidence separately; later wide samples never retroactively certify narrow debt, recovery conservatively removes broad credit, work-area removal erases support. Broad modeled coverage >= existing 75% threshold yields a capped comparison target ONLY; no write authorization, no verified native interpolation, shape/collision or fine mesh guarantee, no per-frame scan, no persisted authority. Tests full square, alias, narrow strip, mixed growth, seams and worked area clearing. This is an intermediate volume-average model, not a proven smooth rut profile.

## 27-Nov-2026 — real roundtrip passed; staged persistence research

Real test: PR #64 comment 7225328557, x360 z389, one down/up native quantum each 0.0038909912109375m, nine original vertices restored. Do not repeat immediate test. New isolated optional commands absoluteStageDown q COPY and absoluteStageUp q COPY: save/quit/reload DOWN first and verify; only then restore that exact persisted depression in a new session with a private journal reconstructed from a strict staged witness. Save/quit/reload UP and verify distinct direction and all nine heights. Stage DOWN requires a new disposable copy without an existing witness; legacy witness cannot grant UP permission. The UP save replaces the DOWN witness only via explicit absolutePersist COPY. Record both logs; not proof of a process restart from Lua, collision, fine mesh or career ownership. SHADOW unchanged. No new live test until CI and next review.

## 27-Nov-2026 — CI regression: retain both geometry and exclusivity checks

PR #86 run 46046658157 failed in terrain_absolute_height_experimental_backend_harness.lua:88. Cause: the prior reordering let a session/MP transition inside validateBeforeSubmit bypass the final exclusivity check. Restore preflight -> exclusivity recheck -> direct full-footprint comparison (no rebase) in both absolute candidates. Preserve the existing late-neighbor regression and add symmetric recovery exclusivity regression. Existing backend assertion unchanged. No SHADOW or gameplay policy change. CI must pass before issuing a new test ZIP.

## 27-Nov-2026 — symmetric absolute preflight and finishing scope

Before the first live roundtrip, require all nine reserved MAIN vertices in the downward candidate, matching the upward candidate. Both now run the injected exclusivity callback before the final native footprint readback, so a late foreign neighbor edit during that check refuses the setter. Added synthetic truncated-footprint and late-neighbor regressions. No change to SHADOW, quantum, native API or gameplay writer. CI still not returned by the available GitHub status endpoints; no new test results claimed.

Finishing decision: do not append a blind SMOOTH job to verified restitution. Existing TerrainWriter SMOOTH is a native brush affecting a neighborhood, not an independently verified per-vertex original-height restoration. It may change untouched slope or RE baseline and invalidate provenance. Exact restitution to the original MAIN geometry already removes the RE-authored height residual at that vertex; optional future smoothing needs its own actual worked-area and pre/post geometry contract, not inferred fine-surface ownership. GIANTS FS25 WheelDestruction smoothHeightAtPosition uses a material/density-height updater (https://gdn.giants-software.com/documentation_scripting_fs25.php?category=93&class=906&version=script), while getTerrainHeightmapUnitSize explicitly refers to MAIN (https://gdn.giants-software.com/documentation_scripting_fs25.php?category=28&function=812&version=engine). TerraFarm 1.6.0 release/issue #97 (https://github.com/scfmod/FS25_TerraFarm/issues/97) distinguishes grade targets and position checks for smoothing, not a fine-wheel read/write interface. Prior FarmKit source audit does not demonstrate a recovery owner. No verified public fine-cell API was found. Do not conflate these domains.

Next decisive milestone is the already-prepared two-call roundtrip on a disposable clone, after source/mock CI is confirmed. More speculative geometry implementation cannot establish engine upward behavior. No requirement to redo whole crop cycles.

## 24-Nov-2026 — bounded reversible MAIN experiment (CI not yet confirmed)

Added explicit `reTerrainTrial absoluteRoundTrip <candidate_q_m> COPY` on the draft branch. It creates a private RAM journal and a single paid cumulative budget, refuses any existing observation/fence in the 3x3, checks singleplayer/SHADOW, save identity, intact observers, idle RE writer and loaded contact before each setter, verifies down before permitting up, and compares all nine final heights against the original at 1um. At most two native calls. No persisted witness or career ownership; after any attempt the runtime is quarantined, and a failed physical attempt quarantines the live journal. Quit without saving even on success. The COPY literal is operator acknowledgment, not proof of clone or exclusion of every external writer. Mock regressions exercise floor/nearest, no-op, loaded contact between phases, prior ownership and repeated commands. A separate live test and persistence/collision validation are still required. No main/RC change and no automatic budget installation.

## 24-Nov-2026 — isolated UPWARD candidate preflight hardening

Source review identified that paid-depth mismatch was detected only after the physical setter. The isolated absolute recovery candidate now checks the paid cumulative depth, pending state and quantum before reservation and immediately before the setter. Settlement still independently verifies the physical receipt. Its 3x3 neighbor tolerance is now 1um (generic queued recovery unchanged); invalidated candidate receipts cannot remain pending. Added regressions for absent/mismatched paid depth and 5um diagonal collateral. CI status not yet established at commit creation. No game proof, no automatic runtime writer, no main merge. Next: prepare the guarded reversible MAIN experiment, then physical UPWARD readback and persistence on a disposable clone. Do not repeat full agricultural cycles.

## 15-Nov-2026 (morning): bounded MAIN observation ledger + cross-XML presence witness — CI GREEN

**Latest code commit `2941e4d7cbdc84e6745f8f38645d4c021afbe61d`** — [full GitHub Actions PASS](https://github.com/rafaaelalves/FS25_RealismExtensions/actions/runs/43715032823). PR #64 still DRAFT, only feature branch modified; docs-only commits follow. Detailed [quota and witness note](../research/2026-11-15-native-geometry-observation-quota-and-presence-witness.md).

- V5 `TerrainGeometryJournal` already capped `recoveryFences` at 50k, but `observations` was **unbounded**. Added default 50k `maxObservations` hard cap, tracked `observationCount`, and **pre-native reservation** `reservedObservationSlots`. `Journal:begin` budgets the entire native footprint including potentially affected neighbors and all independent currently pending jobs. Overflow refuses `GEOMETRY_OBSERVATION_CAPACITY` before any native write; callbacks release reservations for both success and failure. Physically moved new vertices consume actual slots; a completely repaired center frees its observation slot while its separate historical recovery fence remains. **No LRU eviction.**
- Dangerous external direct insertion from `TerrainAbsoluteRecoveryCandidate.untrust` now delegates to counted `Journal:invalidateRecoveryCandidate`. On post-native unsafe readback with full quota, **quarantine**, never fabricate paid geometry or erase other old deny records. Export also verifies `#actualObservations==observationCount`, quarantining out-of-band mutations before writing a v5 manifest.
- Prior intact v5 XML manifest detects *partial* truncation but not loss of the **whole** geometry journal. The mechanical v2 `realismExtensionsTerrain.xml` now stores optional `#geometryJournalExpected`. Core writes a true expectation if the module/journal or a prior witness was present, and carries it through normal/deferred load. An expected but **missing** `realismExtensionsGeometryJournal.xml` globally quarantines research MAIN writes instead of silently proceeding as a new save. Old history XML without witness and genuinely new saves remain readable. **Still NOT an atomic native/GIANTS save.**
- Lua harnesses extended: concurrent disjoint reservations, full quota and untouched old ownership, full-recovery observation deletion with retained recovery fence, quota import refusal, experimental untrusted callback after physical edit, direct side-map mutation count mismatch, lost expected sidecar with legacy/new-career distinction. All pass in CI `43715032823`.
- Save log now reports observation and fence quota consumption. No physical FS25 upward q-step evidence added. Current source remains `TerrainPermanentActuator="SHADOW"`, no default `absoluteHeightBudget`; no RE/RC main merge, no live field test or production build.

**Next:** verify a real one-q UPWARD physical recovery under an exclusive **disposable cloned-save** permission and 3x3 native/collision/save-roundtrip checks when justified. Avoid expanding journal complexity as a substitute for a real GIANTS physical actuator proof. Long-term 50k caps are conservative refusal stops, not production spatial-index scaling.

---

## 15-Nov-2026: MAIN geometry journal V5, structural save manifest, quarantine — CI GREEN

**Latest CODE commit `fd8acf990d3205a71b533813fd4212a891cec80a`: [full GitHub Actions PASS](https://github.com/rafaaelalves/FS25_RealismExtensions/actions/runs/43671450310)**. Draft PR #64 stays isolated, main unchanged. New research note: [MAIN journal v5 integrity and quarantine](../research/2026-11-15-main-journal-v5-structural-manifest-quarantine.md).

- V4 importer silently omitted certain malformed or heavily foreign-edited saved vertices, potentially losing recovered-epoch denial entries on a truncated XML. V5 `TerrainGeometryJournal` and `TerrainPersistence` now record `cellCount`, `fenceCount`, and independently computed coordinate-key fingerprints (`cellKeys`, `fenceKeys`) for both classes of MAIN history. A missing recovery row, replaced coordinate or incomplete header is rejected.
- Import stages both observation and recovery maps **atomically in Lua** and publishes them only when structural, map, unit, capacity, unique-key and native-readback checks succeed. Corrupt/incompatible **existing** geometry files quarantine the journal, invalidate physical ownership and paid-epoch proof, block further RE MAIN writer/recovery access and prohibit overwriting the old sidecar on the next save. Quarantine warning is visible at normal and deferred game load and on save.
- On independently observed external height edits, V5 **retains** the vertex as `owned=false`, instead of dropping it. Future physical lowering on that known location is denied; no foreign edits are interpreted as new RE geometry. Export of existing records does not silently discard unexpected height changes; missing native readback refuses export.
- V1–V4 legacy file compatibility remains, conservatively: V3/V4 may retain physically checked recovery samples but NEVER acquire new V5 `accounted` authority through migration without a V5 structural manifest. A truly **absent** sidecar does not establish whether a save is new or its historical journal was deleted — automatic MAIN writer remains disabled.
- Added `tests/terrain_geometry_manifest_v5_harness.lua` (row truncation, equal-count key substitution, missing header, foreign 60mm edit retained through save/reload, existing corrupt/wrong-map file quarantine, new career without sidecar); adapted older geometry/persistence harnesses. Final CI succeeded on `fd8acf99`.
- **Not solved:** GIANTS native heightmap and RE XML do not share an atomic transaction; V5 count/key fingerprints are noncryptographic and do not authenticate height values; observation coverage needs scalable partitioning for production; no real upward quantized physical restitution, collision, separate fine 0.125m wheel heightfield or MP proof. Never enable `absoluteHeightBudget`/lift `TerrainPermanentActuator="SHADOW"`, merge PR #64, distribute or ask for full plow/sow/harvest tests without actual physical actuator evidence.

**Next research focus:** bound/partition the long-term set of observed MAIN vertices without dropping old-generation deny markers, and assess crash/save ordering. The next *physical* milestone is one controlled upward 1q cloned-save native test (3×3/readback/save-reload/collision), not a broad field retest.

---

## 14-Nov-2026 (evening): v4 recovery fences + budget verification BEFORE paid trust — CI GREEN

**Latest checked code:** `2362c6e2bd7e8325bb866e702890873dfd474145`; [GitHub Actions PASS](https://github.com/rafaaelalves/FS25_RealismExtensions/actions/runs/43668564061). PR #64 remains DRAFT, only experimental branch changed. No new physical FS25 validation.

- **Concrete safety bug corrected:** v3 `finishRecovery` could persist a "trusted" recovered MAIN height before the quantized ledger proved previously paid native depth. The old absolute setter also checked only physical trust, not whether a post-recovery epoch had ever been *accounted*. It could create a bypass for stale wheel-demand replay on a fresh process.
- `TerrainGeometryJournal.VERSION=4` separates `trusted` (real observed MAIN geometry) from `accounted` (journal-issued physical recovery receipt matched to previously paid budget); initial finished recovery is `accounted=false`. `TerrainQuantizedHeightBudget.VERSION=9` first calls pure `verifyRecoveryProof`, validates old committed physical depth, and only then consumes that proof to set `accounted=true` and issue a fresh-epoch fence. A mismatched ledger quarantines without consuming the receipt. **Native `getLoweringBudget` now independently denies `UNACCOUNTED_RECOVERY_EPOCH`** before an absolute setter can even request a plan.
- Geometry sidecar gains `#accounted`. V1/V2 still import conservatively. **Legacy V3 recovered fences keep physical trust only, NEVER implicitly gain paid accounting**, because V3 did not persist this fact. This is fail-closed compatibility; no old save is retroactively certified. Anomaly invalidation now also revokes recovery fences throughout the monitored 3×3 native footprint.
- Recovery tombstones have a **50,000 experimental count cap, no eviction**. An attempt to recover a new vertex when full is denied before native writes; oversized fence imports are rejected intact. This is an interim safety ceiling, not a sustainable production scaling design.
- New `tests/terrain_recovery_accounting_fence_harness.lua` and updated persistence/journal harnesses pass: wrong committed depth, interrupted/unaccounted proof, correct reconciliation, post-reload stale replay, V3 migration without accounting, no-ledger recovery, resource exhaustion and anomalous queue output. See [v4 design / proof / limitations](../research/2026-11-14-recovery-atomic-accounting-v4-and-bounded-fences.md).
- **Not solved:** GIANTS terrain save and XML sidecar are not a proven atomic transaction; actual 1-q UPWARD setter/collision/reload is still not validated; 0.125m fine wheel physical layer, multiplayer semantics, unbounded long-farm journal, and full real agricultural tillage restitution are not proven. Keep `TerrainPermanentActuator="SHADOW"`, runtime `absoluteHeightBudget=nil`, no production build, no main merge and no repetitive game tests yet.

**Next focused engineering:** bounded recovery-fence lifecycle without stale demand reopening and crash/save-generation semantics; then decide whether a single isolated, explicitly guarded upward-q cloned-save test is justified, while separately researching the fine 0.125m wheel displacement API. Don't re-run large plow/seed/harvest loops as a substitute for physical proof.

---

## 14-Nov-2026 (later): actual server-wheel source + persistent recovery fence v3 — CI GREEN

**Latest runtime/harness code:** `b038b10224265fe2c54167cfe1f1e2f09321b6b5`; [GitHub Actions PASS 43639272963](https://github.com/rafaaelalves/FS25_RealismExtensions/actions/runs/43639272963). PR #64 remains DRAFT. This is a code milestone, not validated field geometry.

- `TerrainFreshWheelSource.lua` uses server `Engine.processSample` wheel-object identity, actual contact context, path continuity and MAIN footprint research gate to compute **independent post-recovery** plastic-model history. It is wired through `TerrainDeformationEngine.lua` but runs ONLY if a separate `runtime.absoluteHeightBudget` has been explicitly installed. That runtime budget is still **nil in the normal SHADOW profile**; no automatic native writer/physical recovery was activated. Its output is only a research ticket, never a native mutation.
- `TerrainGeometryJournal.VERSION=3` persists native physically validated **partial or complete recovery fences** in the existing `realismExtensionsGeometryJournal.xml`: immutable original MAIN height, last measured height, vertex, completed/trusted state. A fully restored vertex can lose its old rut observation yet keep a stale-wheel replay tombstone. Foreign drift (strict 10µm), ownership inconsistency, generic untrusted height raise or collateral revokes recovery fence authority, and the downgraded marker remains in the sidecar. Existing **v1 and v2 read compatibility** is retained; old v2 contains no recovery-epoch proof.
- `TerrainQuantizedHeightBudget.VERSION=7` offers `seedPersistedRecovery` after strict v3 sidecar/native-height validation. It seeds only measured remaining physically owned depth and keeps `recoveryEpochPending=true` without any terrain write. `TerrainFreshWheelSource` cold-starts that pending fence on first real server wheel observation and intentionally does **not** grant instant new damage; later same-wheel traveled contact + independent post-baseline model growth remains required.
- Deterministic `terrain_fresh_wheel_source_harness.lua`, `terrain_recovery_epoch_persistence_harness.lua` plus updated Journal/Persistence harnesses pass Lua CI, including XML partial/full reload, retained tombstones, foreign 20µm edit quarantine, legacy v1/v2 and a fresh post-reload server wheel sequence. **These use mocked GIANTS native height and do NOT prove native upward restitution, wheel collision, fine 0.125m terrain, atomic GIANTS save, MP or gameplay acceptance.**
- Code/ownership boundaries and next release gates: [14-Nov detailed research](../research/2026-11-14-server-wheel-source-and-recovery-fence-v3.md). Do not request another complete cultivation cycle, merge main, lift 10–12cm limits or deploy on production save.

**Next:** (1) review save/geometry-fence cardinality and lifecycle/transaction atomicity; (2) isolate a single real upward native q-step/roundtrip on a **verified disposable cloned career** only when prepared; (3) prove or explicitly exclude the separate 0.125m native wheel-displacement persistence/restoration API. Automatic RE MAIN wheel writing remains prohibited.

---

## 14-Nov-2026 implementation update — distinct post-recovery damage epoch (code + CI)

**Actual code completed on experimental PR #64, still NOT released.** The previous 13-Nov recovery receipt now returns the journal-confirmed MAIN position/heights, and `TerrainQuantizedHeightBudget.VERSION=6` supports `observeFreshDamage`, a strict **RAM-only** post-recovery wheel epoch fence. The first fresh time-ordered sample establishes a baseline; a subsequent same-wheel, server-clock-monotonic, path-continuous MAIN-compatible sample with new post-baseline modeled plastic damage issues an identity-bound, bounded target ticket. Replayed old target/false token, duplicate source sequence, non-traveled/narrow contact, and unexplained 10µm native drift fail closed. The experimental `TerrainAbsoluteVertexCandidate:applyOne` accepts the optional token; normal 3-arg callers stay blocked after recovery.

**GitHub Actions pass for code commit `d3d11a9608cf2f1df1666f20a6cb7ea688760066`:** [run 43575956289](https://github.com/rafaaelalves/FS25_RealismExtensions/actions/runs/43575956289). New `tests/terrain_fresh_damage_epoch_harness.lua` uses mock MAIN geometry and a fake server clock; it does **not** validate any GIANTS in-game wheel sample or native upward recovery. Early CI found a strict under-q funding edge; fixture was corrected by providing explicit real additional budget, **never** by relaxing spend precision. Repeated same-sequence funding was separately blocked.

**Next implementation prerequisite (NOT completed):** a server-owned, never-client-provided real wheel-source adapter producing a fresh cumulative plastic-demand counter after actual journal-confirmed recovery. Current runtime does NOT install `absoluteHeightBudget`, does NOT invoke `observeFreshDamage`, and retains `TerrainPermanentActuator="SHADOW"`. No new user game test or build is justified by these mock harnesses alone. Epoch fences/authorization remain in RAM, hence safe persistent recovery generations on reload and distinct 0.125m native fine-wheel geometry are still unresolved.

Detailed source/limits: [14-Nov research note](../research/2026-11-14-fresh-post-recovery-wheel-damage-epoch.md).

---

> Active engineering reference for the experimental branch ONLY. The historical September 30 text below is preserved as archived context. Do not use its old checkout/build advice.

## Source of truth and release boundary

- RE feature head when recorded: `feat/terrain-native-transaction-v1-2026-10-23@02505258a234f9194c25612587b2bb51a6b702bc`, draft [PR #64](https://github.com/rafaaelalves/FS25_RealismExtensions/pull/64), [terrain release blocker #63](https://github.com/rafaaelalves/FS25_RealismExtensions/issues/63). The PR description's last narrative update was October 25; later source commits and November research notes supersede it. Re-read the actual branch head before subsequent modifications.
- Production RE/RC mains are separate. RE terrain `TerrainPermanentActuator="SHADOW"` here, with **no automatic RE MAIN excavation**; independent isolated `COPY` trial is not a gameplay writer. Keep RC physics ownership and version compatibility outside this terrain branch; reconcile current main and feature separately **after real acceptance**.
- Last source commit with code in this checkpoint: `a30ea8d2` (one-shot recovery receipt ↔ cumulative paid depth/old wheel-target freeze); latest `02505258` documents the integration. CI green for code: [Actions 43446353385](https://github.com/rafaaelalves/FS25_RealismExtensions/actions/runs/43446353385). Mock tests do not prove live upward native movement.

## What is actually proven in FS25 — do not rerun old trials

1. Estância São Carlos 1.4 / FS25 1.25.1, **ONE MAIN vertex**, x=348,z=387: on November 11 a guarded request of nominal `q=255/65535m=3.8910505836576mm` lowered native MAIN height from `152.50973510742188m` to `152.50584411621094m`. Measured lowering `3.8909912109375mm`, about **59nm below nominal**. The 3×3 immediate writer check passed. No extrapolation to arbitrary adjacent cells or native 0.125m fine wheel surface.
2. After genuine FS25 save/exit/restart, a **new independent** native `reGeoVertex 348 387` read on November 12 returned `152.505844116m`, equal at displayed precision. Thus a MAIN physical write persisted for this map/vertex; a witness-sidecar `WITNESS_SAVE_SESSION_CHANGED` error was separate and does **not** show terrain recovery. Old 1.5mm→3.891mm responses are consistent with sub-quantum requests, not proven arbitrary multiplier.
3. Historical R1/R7 TARGET recovery **failed gameplay**: many passes still left severe holes. TerraFarm/manual Amenizar behaves differently. Do not ask the user to repeat the rejected harvest→plow→disc→seed loop merely for telemetry. Previously reported RE-OFF wheel clipping belongs to a separate session without supplied log and must not be falsely attributed to the RE-on run.

## Source engineering implemented through November 13 (PR #64, NOT released)

- `TerrainGeometryJournal` distinguishes actual GIANTS MAIN readback from calculated model debt, preserves immutable RE first-touch baseline, rejects unexplained physical owner drift beyond 10µm, persists server-only geometry sidecar, and uses bounded transaction/callback attribution.
- `TerrainAbsoluteVertexCandidate` and `TerrainQuantizedHeightBudget` use a conservatively FUNDED q-step with distinct readback and spending tolerances. A cumulative target is relative to the actual immutable RE original height; journal-owned measured `committedM` seeds a new process across reload to avoid duplicate excavation. No automatic normal wheel source is authorized to call the setter.
- `TerrainCausalRecovery` and separate `TerrainAbsoluteRecoveryCandidate` can model/attempt RE-owned restoration with 3×3 MAIN checks, including diagonal collateral; physical completion does not accept a full remaining ~3.891mm step or ~2.46mm residue as repaired. The isolated absolute **UPWARD** one-q candidate is Lua MOCK-validated for floor/nearest, **not exercised in FS25**.
- New journal-issued, one-use readback proof links actual recovery to `TerrainQuantizedHeightBudget.VERSION=5`; `syncVerifiedRecovery` reduces cumulative paid depth to measured remaining owned depth and freezes the **old wheel-source target** (`recoveryEpochPending`). This avoids a proven repair being instantly re-dug by stale target replay. `TerrainCausalRecovery` optional budget handoff remains inactive because normal runtime does NOT install `absoluteHeightBudget`.
- MAIN geometric representability is not equivalent to fine tire prints. The current per-contact SHADOW footprint screen requires physically continuous motion and high broad-cell coverage; an ordinary narrow tire has inadequate 1m MAIN support. The native 0.125m sparse wheel-displacement read/save/replay/repair API remains **unproven**. TireTrackSystem visuals and density-fill height smoothing do not certify wheel collision or deformation persistence.

## Precisely where work must resume

1. **Fresh damage-source epoch after physically verified recovery:** design a source-specific, monotonic handshake for actual NEW post-repair wheel exposure/contact; bind its cumulative target to the remaining independently owned native depth; reject old virtual source/history replay, forged/duplicate epochs, teleport/path discontinuity, partial/reloaded baseline mismatch, and foreign edits. This is NOT YET WIRED. Do not resolve `recoveryEpochPending` via a boolean, a timer, an arbitrary fresh frame, or by clearing the ledger.
2. **Read-only / mocked end-to-end contracts first:** cover partial q→remaining q→zero, actual after-readback debt, legitimate fresh wheel damage vs old stale source, multiple nearby vertices, saved journal bootstrap, and 3×3 collateral. Keep normal actuator SHADOW and do not promote mock results as gameplay.
3. **One small controlled real UPWARD/round-trip engine acceptance** on a verified *disposable cloned career* only after guards are ready. Prove exact physical MAIN height, no neighbor spill, collision and correct persistence with a trusted freshly RE-authored rut. No more sub-q repetition. Only then discuss broad worked-area recovery and one primary + at most one secondary appropriate pass.
4. **Fine native wheel-height channel capability** must be proven independently or the product must explicitly scope its persistent feature to adequately broad MAIN earthworks and retain GIANTS-native fine wheel effects without claiming RE-owned fine-rut persistence.
5. Keep ~10–12cm provisional excavation limits, no automatic external-height recovery, no foreign mod-physics takeover, and no merge/release until gameplay and save/MP (where applicable) acceptance. Do not generate a player build for documentation-only updates.

Canonical recent notes:
- [13 Nov — exact recovery / epoch gap](../research/2026-11-13-native-main-one-step-recovery-and-epoch-handoff.md)
- [12 Nov — verified save/reload MAIN readback](../research/2026-11-12-main-one-quantum-save-reload-confirmed.md)
- [12 Nov — cumulative reload + truthful closure](../research/2026-11-12-cumulative-reload-and-physical-recovery-closure.md)
- [12 Nov — owner drift, quantization vs persistence](../research/2026-11-12-main-height-persistence-vs-quantization-and-ownership-safety.md)
- [Terrain release reset](../research/2026-10-23-terrain-recovery-release-reset.md)

---

# Archived 2026-09-30 development handoff

Updated: 2026-09-30

## Active work

- Branch: `feat/terrain-distance-response-v7`
- Purpose: remove low-speed/update-cadence excavation bias and collect explicit dual/twin footprint evidence.
- v6 remains the baseline integrated in `main`; TerrainDeformation is not complete yet.
- This v7 branch is a runtime-test branch, so TerrainDeformation and verbose diagnostics are intentionally enabled here only.

## New runtime evidence from 2026-09-30 log

- True AI Tracks 2.2.0.1 was loaded in the supplied session, so that run cannot prove RE parity with AI/implement deformation.
- John Deere S700/S780 asset load shows `dual002.i3d`.
- Mud restored tire pressure at 2.40 bar in that session.
- RE remained stable during the longer run: 4,083 accepted brushes, 574 native jobs, 0 failed jobs, and terrain history grew from 12,483 to 16,155 persisted cells.
- RC reuse remained healthy: 10,956 contexts, 10,956 slip snapshot hits, 0 direct slip reads, and 10,956 speed/wheel-speed hint hits.

## v7 model change

The v6 response could deepen the same history cell more simply because a slow vehicle generated more 250 ms samples over the same ground.

v7 changes progression from sample-driven recursion to cumulative physical exposure:
- normal rolling exposure comes from vehicle travel distance relative to contact-patch length;
- longitudinal excavation exposure comes from newly accumulated relative longitudinal displacement;
- lateral scrub exposure comes from newly accumulated lateral displacement;
- the terrain cell stores cumulative `deformationExposure`;
- rut target is reconstructed from total exposure + current capacity instead of applying another pseudo-pass each sample.

A harness now compares equal 2 m traversals at 2 km/h and 12 km/h, plus a finer 50 ms subdivision. Equivalent physical travel must converge within 0.5 mm.

Stationary wheelspin remains supported because relative wheel/soil displacement still grows when body speed is near zero.

## Dual/twin diagnostics added

The runtime log now reports:
- base tire width;
- total support width;
- support/base width ratio;
- wheel load;
- contact area;
- min/max ground pressure;
- tire inflation pressure;
- count of contexts with wide support geometry.

Do not add a hard-coded dual multiplier yet. Exact SoilCompaction source notes that FS may represent a dual set as one wider wheel contact; RE first needs runtime evidence of how MR/Mud expose the S700's load/width/pressure combination.

## Next runtime test

1. Use the same S700/S780 with duals.
2. Compare controlled straight driving over similar wet field ground at:
   - ~2-3 km/h with low slip;
   - ~10-12 km/h with similarly low slip.
3. Then deliberately induce wheelspin at low vehicle speed.
4. Keep tire pressure unchanged for the speed comparison; record whether it is 2.40 bar.
5. For a second comparison, if convenient, repeat one pass at Mud's lower field pressure.
6. True AI Tracks may remain installed for this specific low-speed/dual test, but a later dedicated AI parity test must run with it disabled.

Expected v7 result:
- controlled low-speed travel must no longer dig more merely because it is slow;
- true wheelspin must still excavate progressively;
- diagnostics must reveal whether dual support width is actually reaching RE and what ground pressure the current stack computes.

## Additional runtime findings from the S780 field test

The user lowered Mud tire pressure from 2.40 bar to the automatic field target near 1.00 bar and was able to recover the S780 from the original rut. During the later re-stuck period:
- local wetness observed by RC was commonly ~0.32-0.54, not near 1.0 saturation;
- wide support reached RE (max support width 1.30 m, ratio up to 2.0);
- contact area reached ~0.62 m2 and minimum calculated ground pressure ~110 kPa;
- MRMud telemetry showed applied radius deltas typically around 0.07-0.13 m rather than the previous raw ~0.30 m sink interpretation;
- perma-stuck remained false and drag ratio stayed low while vehicle speed fell to fractions of km/h.

This makes a chassis/terrain high-centering hypothesis plausible: the wheel/radius model may still have traction available while the undeformed terrain between wheel tracks contacts the vehicle body.

Do not assume a dual must be represented as two separate RE contacts yet. The exact SoilCompaction source records an in-game precedent where FS exposes a dual/twin set as one wider physics contact. We need authoritative spacing/visual geometry before splitting that footprint.

## Diagnostics added after that finding

- RE now measures the terrain height at the midpoint between left/right wheel contacts on each axle and compares it with the plane interpolated between both wheel-track heights.
- Runtime telemetry reports max central crest and counts above 5/10/15 cm.
- The diagnostic is slope-invariant in the harness: a planar cross-slope produces zero crest while a true 12 cm center ridge is reported as 12 cm.
- RC MRRMS now emits per-vehicle drivetrain state: primary/engageable wheel indices, active 4WD state and MR-driven wheel indices/count. This avoids interpreting the old global lastDrivenWheelCount gauge as if it necessarily belonged to the S780.

## Completion blockers after v7

- validate that the v7 distance-based response behaves correctly in runtime;
- determine whether central terrain crest/high-centering is the dominant cause of the remaining S780 stalls;
- verify S780 rear-wheel-assist/4WD reaches MR wheel ownership correctly;
- validate dual/twin behavior without inventing unsupported split-contact geometry;
- design soft-ground underbody/belly interaction only after high-centering is measured;
- implement grouped crawler/track support;
- validate player + GIANTS AI + Courseplay + wheeled implements with True AI Tracks disabled;
- resolve native AI tire-track permission ownership;
- complete external-source crosswalk before declaring TerrainDeformation finished.


## v9 experimental SoilMassTransport

Branch: `feat/terrain-mass-transport-v9`

This is a TerrainDeformation feature, not a separate gameplay module.

Purpose:
- replace pure height removal with partial surface-mass redistribution;
- use GIANTS callback `displacedVolume` as the mass budget;
- create positive terrain berms only after a successful lowering callback;
- keep the untransported fraction as compaction/sub-surface rearrangement;
- preserve v7 distance/cadence-invariant rut response.

Current v9 behavior:
- moving wheel samples carry travel direction, wetness, deformability and slip into the writer;
- lowering jobs remain the authoritative rut operation;
- successful callbacks allocate the actual displaced volume across contributing brushes;
- `SoilMassTransportModel` computes a bounded transport fraction from wetness, deformability and longitudinal slip;
- transported volume is split into left/right lateral berms perpendicular to travel;
- lateral slip can bias which berm receives more material;
- berms are queued as separate positive TerrainDeformation jobs;
- raise jobs never generate further transport, preventing recursion;
- coalescing remains enabled only when transport direction/state are compatible.

Mass-balance telemetry:
`SoilMassTransport runtime | source=... targetTransport=... raised=... realization=... compaction=... balanceError=... berms=... raiseJobs=... rejects=...`

Interpretation:
- `source`: real lowering volume reported by GIANTS for brushes eligible for transport;
- `targetTransport`: fraction of source volume assigned to surface berms;
- `raised`: real positive volume reported by GIANTS for berm jobs;
- `realization = raised / targetTransport`;
- `compaction`: source volume intentionally not returned to the surface;
- `balanceError = raised - targetTransport`.

The first runtime goal is calibration/shape validation, not acceptance:
1. verify berms appear on both sides of moving wheel ruts;
2. ensure berms do not create unstable walls or obvious terrain inflation;
3. measure realization ratio and mass-balance error;
4. compare dry/firm vs wet/plastic soil;
5. compare low-slip rolling vs wheelspin;
6. verify performance/job counts remain acceptable;
7. only then decide whether to extend toward rearward shear, relaxation and implement-driven field repair.

Do not merge v9 until runtime evidence shows both geometry and mass balance are plausible.


## v9.0 runtime result and v9.1 retune

The first mass-transport runtime proved the architecture works but rejected the initial calibration.

Observed in the 2026-10-01 S780 test:
- berms were visually far too aggressive, especially toward vehicle center;
- early realization ratios reached 16-17x;
- later realization stabilized around 7-8x;
- at source=16.841 m3, targetTransport=5.814 m3, GIANTS reported raised=48.054 m3 (realization=8.26);
- the test commonly ran near local wetness ~0.35-0.51 with 1.00 bar tire pressure;
- therefore the first linear wetness transport curve moved far too much surface soil for merely damp/trafficable conditions.

v9.1 changes:
- transport is now strongly nonlinear with a plastic-wetness threshold;
- around ~0.50 wetness + low slip, surface transport is intended to remain around 0.5-1% and compaction dominates;
- truly wet/plastic soil + severe slip can ramp toward a hard 18% surface-transport ceiling;
- additive raise height is calibrated by 0.10 based on the measured runtime over-realization;
- microscopic berms are no longer rounded upward to the minimum terrain brush; their mass is folded into compaction instead;
- the berm facing vehicle center is resolved geometrically from vehicle root/contact position, not from wheel-side assumptions;
- inner berm share is capped near 18% of transported mass and its per-operation raise height is capped at 1 mm;
- outer berms may reach 3 mm per operation in severe conditions.

Next runtime acceptance criteria:
1. ordinary 0.35-0.55 wetness should show rutting/compaction with little or no obvious berm;
2. inner berms must not create a center ridge capable of interfering with the vehicle;
3. realization should move much closer to 1.0 and must no longer sit at 7-17x;
4. severe wetness + wheelspin should still produce visible lateral displacement;
5. job/brush growth must remain manageable.


## v10 experimental plasticity response

Branch: `feat/terrain-plasticity-response-v10`

Purpose:
- decouple instantaneous Mud sink from persistent RE rut geometry;
- preserve Mud authority over mobility while letting RE decide how much sink becomes permanent plastic terrain deformation;
- stop treating every transient wheel-radius sink peak as an immediate permanent heightfield lower bound.

Runtime motivation:
- v9.1 S780 test often operated around local wetness ~0.35-0.57 at 1.00 bar;
- the RE static/slip capacities peaked around ~0.05 m while `modelRut/modelCap` reached ~0.138 m;
- this happened because `observedSinkM` from Mud was included directly in `rutCapacityM=max(static, slip, observedSink)`;
- the same session began with ~49,294 restored history cells, so existing field geometry is heavily contaminated by earlier experimental versions.

v10 model:
- `observedSinkDepthM` remains the authoritative instantaneous Mud consequence;
- `sinkPlasticTransfer01` is computed from a nonlinear wet-plasticity curve plus slip activation;
- `persistentSinkDepthM = observedSinkDepthM * sinkPlasticTransfer01`;
- only `persistentSinkDepthM`, static rut capacity and slip rut capacity participate in persistent geometry;
- around moderate wetness (~0.50) and low slip, transient sink transfer is deliberately small;
- near very wet/plastic conditions, and especially with severe slip, transfer rises strongly but remains bounded below 100%;
- existing rut history is never automatically healed.

Diagnostic line:
`TerrainPlasticity sample | wet=... slip=... instantSink=... transfer=... persistentSink=... staticCap=... slipCap=... rut=... maxInstant=... maxPersistent=... maxTransfer=...`

Mass-accounting correction:
- source-volume shares rejected by SoilMassTransport are now counted as compaction/sub-surface rearrangement;
- the harness requires `source = targetTransport + compaction` before positive raise realization is considered.

Runtime test requirement:
- use a previously undeformed area or a clean backup; the current field contains ~49k persisted experimental cells and earlier heightmap edits cannot be safely reconstructed;
- compare moderate damp/trafficable soil against substantially wetter soil;
- keep tire pressure appropriate for field work;
- verify moderate wetness can show instantaneous sink/resistance without converting the full sink into a permanent rut;
- verify genuinely wet + high-slip conditions still produce deeper persistent deformation.

Do not merge v10 until this separation is validated in runtime.
