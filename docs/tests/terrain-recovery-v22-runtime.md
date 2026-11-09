# TerrainRecovery v22 runtime protocol

Updated: 2026-10-02
Active branch: `feat/terrain-recovery`

## Hypothesis

Repeated cultivator passes must remain physical work even when the vanilla agricultural state no longer changes.

The v21 failure mode was:
- first pass changes field state: `realArea>0`;
- repeated pass may report `realArea=0, area>0`;
- v21 incorrectly stopped recovery and stopped root-combination rut suppression in that state.

v22 should preserve:
- recovery while `area>0` and GIANTS reports physical work;
- root-combination persistent-rut suppression during the same physical work.

## Build identity requirement

At startup the log must contain:

`[RealismExtensions] BuildIdentity | branch=feat/terrain-recovery commit=... run=... builtAt=...`

Record the full line with the test result. Do not evaluate a runtime log without first confirming build identity.

## Test equipment

Use the same tractor + cultivator combination used in recent recovery tests when possible:
- Case IH Steiger 785 Quadtrac;
- MR Koralin 9-840.

Do not change unrelated soil/physics mods between A/B passes.

## Test layout

Prepare two adjacent strips:

A. **Sentinel smooth strip**
- repair manually with Construction/Amenizar until visually acceptable;
- this strip tests whether the tractor/cultivator still creates destructive persistent terrain writes.

B. **Damaged strip**
- leave visibly rutted/rough;
- this strip tests whether repeated physical passes converge toward smoother terrain.

## Procedure

1. Start a fresh session/log and confirm BuildIdentity.
2. Drive to the test area with implement raised.
3. Do not count transport-to-field deformation as cultivation evidence.
4. Lower/activate cultivator before entering Strip A.
5. One straight pass across Strip A.
6. Stop shortly after leaving the strip.
7. Repeat the same line a second time.
8. Repeat a third time if the first two passes are safe enough.
9. Perform equivalent passes on Strip B.
10. Preserve the complete game log and ModMixer log.

Do not manually repair between passes.

## Expected telemetry

Every ~5 seconds:

`TerrainWindow 5s | work=... changed=... repeat=... processedArea=... repeatArea=... smooth=... callbacks=... improved=... worsened=... rutBlocked=... protected=... rutAccepted=...`

`RutWriters runtime | vehicles=[NAME=TOTAL(+WINDOW)] roots=[NAME=TOTAL(+WINDOW)]`

Cumulative v22 line must also expose:
- physical;
- changed;
- repeat;
- changedArea;
- processedArea;
- repeatArea;
- active marks/hits;
- smoothing jobs/brushes.

## Acceptance criteria

### Physical-work semantics
On second/third pass:
- `repeat > 0`;
- `repeatArea > 0`;
- `processedArea` continues growing even if `changedArea` does not.

### Rut suppression
During windows with physical cultivator work:
- `rutBlocked > 0` is expected;
- Koralin/root writer window deltas should remain zero or be explainable by samples outside the active-work interval;
- `rutAccepted` should ideally be zero for the root combination while work is active.

### Recovery
Damaged strip:
- smoothing callbacks > 0;
- roughness improvement must exceed worsening by a meaningful margin;
- second/third pass must continue applying recovery rather than stopping because field state is already cultivated.

### Destructive regression
The manually smooth sentinel strip must not become visibly rutted again due to RE persistent LOWER writes.

## Rejection / next isolation

If Strip A degrades and the same window shows:
- **rutAccepted/root writer delta > 0**: remaining rut-suppression leak.
- **rutAccepted=0 but worsened smoothing > 0 / terrain degrades**: isolate SMOOTH by running cultivation suppression with recovery disabled.
- **no RE writes and no damaging SMOOTH but terrain degrades**: investigate another mod/native terrain writer and add external-write probes.
- **repeat=0 on repeated physical passes**: WorkDetector semantics are still wrong.

## Evidence recording

After the test update `docs/project/CURRENT_HANDOFF.md` with:
- BuildIdentity;
- user visual observation;
- exact relevant TerrainWindow excerpts;
- writer-window attribution;
- what was proven/falsified;
- next hypothesis.

