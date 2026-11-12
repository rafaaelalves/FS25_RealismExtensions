# 12-Nov-2026 — FS25 MAIN native height persistence confirmed with exact independent readback

## Evidence

**Original write:** Live FS25 1.25.1 in Estância São Carlos 1.4, savegame2 on 11-Nov-2026, RE build `cfda2d87`, command `reTerrainTrial absoluteStep 0.0038910505836576 COPY`. Native `setTerrainHeightAtWorldPos` transaction measured one center vertex `x=348,z=387`:

- before = `152.50973510742188m`
- immediately after = `152.50584411621094m`
- measured difference = `0.0038909912109375m` = `3.8909912109375mm`
- requested nominal q=`255/65535m` = `3.8910505836576mm`
- absolute quantization difference q-measured ~`0.00005937mm` (about 59nm), BELOW the full q request. One-vertex 3×3 check passed, no readback amplification. One sample only; not proof of all maps or geometry channels.

**Save:** 11-Nov-2026 user executed `absolutePersist COPY` and saved game, then exited and reloaded same career. The RE XML **witness** was NOT saved because `WITNESS_SAVE_SESSION_CHANGED`; this is a separate scripting guard issue. The RE native geometry journal did save 938 (937 before). No immediate raw vertex reading occurred after that reload.

**Independent validation:** 12-Nov-2026 user installed updated RE build `824fb447` (CI run 43210339939), started savegame2, executed `reGeoVertex 348 387`. Actual GIANTS `getTerrainHeightAtWorldPos` returned:

```
MAIN_VERTEX center x=348.000 z=387.000 y=152.505844116m
MAIN_VERTEX_ROW z=386.000 westY=152.486373901 centerY=152.490264893 eastY=152.490264893
MAIN_VERTEX_ROW z=387.000 westY=152.505844116 centerY=152.505844116 eastY=152.509735107
MAIN_VERTEX_ROW z=388.000 westY=152.529190063 centerY=152.529190063 eastY=152.529190063
```

This is **identical to all displayed digits** of the immediate postwrite y value of 11-Nov. Independent native readback after game save and a process restart has therefore shown **persistence of this one MAIN vertex geometry lowering in this specific career and map**. The witness sidecar problem did NOT prove any physical persistence defect. The new `reGeoVertex` reader is read-only with no write-queue prerequisites; it succeeded and printed all nine vertices. No new RE permanent write in 12-Nov session (TerrainTrial OBSERVE_ONLY, SHADOW); RE restored 1501 terrain history and 938 geometry journal records, rejected=0. A metadata count alone would not be proof; the direct native y readback is.

## Regression baked into research harness

`tests/terrain_absolute_vertex_candidate_harness.lua` commit `deae41bf` adds a source-grounded sample using the **exact reported floating-point before and after values**. It requires the one full q authorized center step to be accepted, the measured depth never greater than q, and 100%-unchanged **CUMULATIVE q target replay** to cause ZERO additional native setter calls. Retains the remaining ~59nm in the ledger (no unrequested full step). This is a pure mock test and does not prove live continuous driving behavior. CI success: https://github.com/rafaaelalves/FS25_RealismExtensions/actions/runs/43212832994 .

## What is proven versus not

**PROVEN in one scenario**: q-sized absolute native MAIN height change with exact amplitude, one-center immediate 3×3 check, stable native y after actual save/reload, 1m MAIN unit; the previous 1.5mm→3.891mm output is consistent with a below-quantum request. The map's actual heightScale property inside its I3D still needs independent verification if we want a permanent per-map quantum whitelist. Do not confuse 12-Nov neighbor values after the test with pre-test neighbor baselines: without exact previous 3×3 raw heights, long-term neighbor nonmovement cannot be independently proven from this after-only log. Immediate side-effect check on 11-Nov passed under its configured 1µm threshold.

**NOT PROVEN**: repeated/adjacent or wide-area MAIN edits, 0.125m sparse physical wheel rut geometry save/replay, terrain collision correctness, ownership and recovery, plowing/neighbor/municipality restoration, multiplayer, capless depth. Also note `TerrainAbsoluteVertexCandidate` still uses native `journal:getLoweringBudget(...,0.10,0.12)` and the experimental backend `maxDebtM=0.10`; do NOT lift safety depth limits based on one 3.891mm MAIN point.

## Stack observations

- RE `824fb447` loaded, RC PR55 merge `6dde79ec`, MR 0.26.10.08, Mud 1.4.0.0, RMS 1.0.0.0-beta.1, RH 1.6.5.0, WA 1.4.1.0.
- RC MR+Mud, MR+RMS, Mud+RMS, MR+RE PTO, RMS+RE PTO active SOURCE_COMPATIBLE; RMS+RH no longer FAILED. Only two read-only `PENDING_GAMEPLAY` advisory risks (RMS/RH/WA harvest interaction, RMS beta/Reifen wheel torque wear) remain.
- ModMixer BOOT CONFIRMED HEALTHY, no terrain-specific crash. Known `FS25_CBI6800CT` duplicate specialization errors and `manualAttach delete(nil)` during game quit are unrelated to this native height readback.

## Next release gate

Stop further same-vertex persistence tests. Advance in stages:
1. Demonstrate sequential cumulative q-sized MAIN edits without double digging on a confirmed disposable copy, across two or more neighboring vertices and at different model depths with full 3×3 collateral checks. Do not extrapolate one sample to capless whole-field deformation or authorize a premature merge.
2. Separately prove a true fine native physical wheel-rut path and persistence, or explicitly scope any playable terrain milestone to broad MAIN height operations with native GIANTS fine tire effects left to GIANTS. Do not mislabel visual TireTrack archive as physical persistence.
3. Establish owned geometry recovery after cultivation, seeding and independent repair; never repair foreign height edits on a metadata assumption.
4. Only after passes reconcile divergent draft terrain PR64 with current RE main and review release gating. Keep production SHADOW and preserve old and new career backups separately.

**No new manual test is required just to re-prove this exact persisted vertex.**
