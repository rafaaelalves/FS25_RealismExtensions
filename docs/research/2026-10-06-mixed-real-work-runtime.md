# Mixed real-work runtime checkpoint — 2026-10-06

## Scope

This checkpoint records a long mixed gameplay session rather than a synthetic
PTO test. The session included:
- normal player driving and field work;
- prolonged PTO-consumer operation;
- transport with a PTO consumer active;
- John Deere 6R 155 PTO mode selection;
- Courseplay/personnel handoff;
- an AI field worker cultivating with a 7R 310 + MR Koralin 9-840;
- sustained terrain deformation/recovery activity.

Runtime build identities:
- RE `feat/pto-control` commit
  `d9732d1a46fd6b8ce0cad8dedf0e357d9cd61014`;
- RC `feat/pto-control-bridge` commit
  `010fdd1d33d2db747d5f4060758f2a099b541c05`.

This note is observational. No physics correction is implied solely by these
results.

## PTO findings

### 6R selector/profile path

The evidence-backed 6R 155 profile was active with mode mask 7
(540 / 540E / 1000). The operator changed:
- 540 -> 540E while the attached consumer required 1000, retaining mismatch;
- 540E -> 1000, clearing mismatch.

This validates the selector -> state -> mismatch -> HUD chain during ordinary
gameplay.

### Useful under-speed baseline from a native-fallback combination

A later Fendt 1050 Vario + RBM2000 combination used the conservative
`NATIVE_FALLBACK` 540-only profile with RE hand throttle released
(`handTarget=0`).

Observed while the PTO consumer remained active:
- stationary: actual PTO approximately 347 rpm;
- moving/working: approximately 479–527 rpm;
- transport speeds could retain approximately 521–527 rpm and correctly enter
  the advisory transport-warning state.

This is important because it proves that the current MR/implement stack does
**not universally force every PTO consumer immediately to nominal shaft RPM**.
The prior 6R/1000-rpm case that rose to approximately 1080 rpm in ROAD is thus
implement/drivetrain-path dependent.

Before suppressing MR's `minRotForPTO` behaviour globally, the exact
conditions that produce automatic engine-speed enforcement must be classified.

### Hand-throttle bridge not exercised

The session is a clean baseline for PTO behaviour with the RE governor
released. Final RC telemetry reported:
- `handThrottleGovernorScopes=0`;
- `handThrottleControlCalls=0`.

Therefore this run cannot validate or invalidate the new RPM-based hand
throttle. It is useful precisely because it isolates existing MR/PTO-consumer
behaviour from the RE governor.

The native PTO bridge itself was heavily exercised, with only one availability
check and very few state-cache misses. This supports the current revision-cache
architecture.

## AI field-work / terrain findings

### Worker detection is functioning

Courseplay fieldwork planning resolved an 8.4 m working width. Immediately
after personnel/Courseplay handoff, RE began classifying samples as
`AI_FIELD`.

The active combination was observed as:
- tractor: `7R_310__Cultivo_6_`;
- implement: `MR_Koralin_9-840__Cultivo_6_`;
- recovery width: approximately 8.25–8.40 m;
- recovery profile: `SHALLOW_DISC`.

### Active-cultivator ownership guard behaves as designed

During sustained AI cultivation, final actor totals were approximately:
- PLAYER: 183,896 samples / 86,591 brushes;
- AI_FIELD: 266,171 samples / 131 brushes.

At the same time, `activeCultivatorRutSkips` reached approximately 266,048.
This is consistent with the current ownership rule: while a valid soil-repair
implement is actively cultivating, RE keeps wheel/context/visual-track and
upstream specialist physics alive but suppresses RE persistent-rut generation
for the whole tractor/implement combination. The cultivation/recovery system
owns the resulting persistent terrain state.

The small number of AI brushes occurs primarily around startup/transition before
the working-tool suppression becomes authoritative. This is not yet classified
as a defect, but it is worth retaining as a transition-edge test.

### Recovery remained bounded and useful

At the end of the worker session:
- recovery calls: 19,970;
- work areas processed: 19,927;
- target jobs applied: 406;
- target improvements: 119;
- target worsenings: 20;
- residual reduction: 2.5450 m;
- residual worsening: 0.0520 m;
- center raise: 2.6599 m;
- center lower: 0.0670 m;
- failed terrain jobs: 0;
- target timeouts: 0.

The reduction:worsening ratio remains strongly positive and no catastrophic
geometry behaviour is visible in the telemetry.

### Recovery optimization candidate

`intentEmpty` reached 19,621 out of 19,970 recovery calls (about 98.3%).
Recovery accumulated approximately 19.6 s of CPU time during the long worker
period, averaging roughly 0.98 ms per recovery call with a maximum of 2.86 ms.

This does not by itself establish a gameplay performance problem, but it is a
clear optimization target. Before changing recovery semantics, investigate:
- a cheap candidate-history / area-overlap rejection before full intent build;
- caching repeated empty work-area queries;
- whether recurring Courseplay work-area callbacks can be coalesced without
  losing legitimate newly-created rut history.

Do not optimize by weakening the active-cultivator ownership guard or by
skipping valid recovery targets.

## AI visual tire tracks

The AI visual-track policy remained installed. Before the worker began, almost
all lower-chain queries were allowed. During prolonged worker operation,
`baseDenied` increased substantially.

This is not an error: RE removes only GIANTS' blanket AI-active suppression and
still respects lower-chain distance/quality/owner decisions. The growth in
denials while a remote worker runs is consistent with desired culling rather
than forcing every distant AI track to render.

## Performance / unrelated hitch

During Courseplay fieldwork-course generation, the game reported an emergency
garbage-collection pass:
- memory jumped from roughly 693 MB to 1.66 GB in less than one frame;
- full GC took approximately 522 ms;
- post-GC usage returned to roughly 666 MB.

This coincides with Courseplay island/headland course generation and is far
larger than any individual RE terrain callback observed in the same session.
Treat it as an external hitch unless further evidence links RE allocations to
that frame.

## Stability

No RE or RC Lua runtime error was observed in this session. Terrain jobs ended
with zero failed jobs and queues drained.

ModMixer reported:
- 58 active tracked hook targets;
- zero targets with unknown hooks;
- the expected MR/Mud/RMS vehicle-physics chains;
- healthy boot confirmation.

The old Dynamic PTO package was still present in the mods directory, but RC
reported `DynamicPTO=-`; legacy external-PTO bridges remained inactive and
the native RE bridges were active. There is no evidence of duplicate Dynamic
PTO physics in this save.

## Next investigation

The next PTO study should instrument one or two representative consumers rather
than change behaviour immediately. Capture together:
- RE hand-throttle target;
- actual engine RPM;
- selected PTO ratio;
- actual PTO RPM;
- implement-required PTO RPM;
- MR resolved required motor-RPM range / `minRotForPTO`;
- consumed PTO torque;
- engine load/torque;
- work output or specialization state;
- instantaneous fuel rate if a stable source is available.

Compare at least:
1. ROAD + active consumer below nominal RPM;
2. explicit low hand-throttle target;
3. hand-throttle target near rated PTO engine RPM;
4. high load that physically pulls RPM below target.

The objective is to determine when MR's automatic PTO minimum-RPM behaviour is
necessary drivetrain protection, when it is an unwanted automatic throttle, and
where under-speed implement consequences should be owned.
