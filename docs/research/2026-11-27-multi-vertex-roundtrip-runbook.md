# Controlled multi-vertex MAIN reversible experiment

Purpose: establish immediate physical readback of two adjacent vertices under the same bounded executor, not actual wheel damage, fine displacement, collision, agricultural recovery, or persistence. Uses synthetic depth targets intentionally. No other native writes authorized.

## Preparation

Use an expendable cloned Estancia Sao Carlos save on FS25 1.25.1.0, with SHADOW and controlled write trial enabled. Use CI-approved exact build. Do not enable other active terrain writers, grading tools, or workers. Choose a fresh patch far from all loaded vehicles, away from boundaries and construction edits. On foot. No previous absolute trial, arm or calibration in this session. Do not use main save. A COPY acknowledgment is not proof of a copy. RE observes its own queue and hook integrity, not a global lock on every GIANTS job.

```
reTerrainTrial probe
reTerrainTrial status
reGeoMark
reGeoSnap beforeAbsolute
reTerrainTrial absoluteCheck
reTerrainTrial patchRoundTrip 0.0038910505836576 COPY
reGeoSnap afterPatch
```

Stop on any refusal or failure. Do not retry in session. Expected PATCH DOWN two distinct vertices (center and +1 MAIN x), PATCH UP reverse order, PATCH ROUNDTRIP RESULT matched=true calls=4 state=RESTORED downState=COMPLETE verified=2 recovered=2. Each change approximately one q; observed result compared to original, entire 5x5 halo, and private paid depth. No sidecar, no save permission. Quit without saving regardless of success; send log.txt and ModMixer. Real engine quantization can differ between heights; a failed q match is evidence, not a reason to relax safety blindly.

Separate follow-up for staged single-vertex recovery persistence: a fresh different cloned save with no prior absolute witness. DOWN, explicit absolutePersist COPY, manually save, exit process and reload, absoluteVerify. Re-mark same exact native vertex, beforeAbsolute snapshot, absoluteStageUp q COPY, explicit absolutePersist COPY, save/exit/reload, absoluteVerify. Require both staged matches in logs. Do not combine with immediate patch roundtrip in the same session. No collision/fine or career release permission.
