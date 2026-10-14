# PTO V1.6 — release-candidate scope and review results

**Review date:** 2026-10-13 (some 2026-10-14 local logfile filenames). Target: **personal FS25 singleplayer / local-host play**. Multiplayer remains **NOT VALIDATED**, see https://github.com/rafaaelalves/FS25_RealismExtensions/issues/46.

## Merged feature intent (parent PR #39 and child PR #45)

1. Preserve real tractor PTO capability profiles and native shaft-engagement interlock; operator can select 540/540E/1000/1000E **only if equipped**, and changes while mechanically engaged are forbidden.
2. Hand throttle requests engine RPM; when player operates manually, MR should not silently demand its own PTO governor's minimum RPM. MR/GIANTS own actual engine torque and load; RC owns the compatibility adaptation; RMS owns degradation/wear. AI can choose only a verified nominal family and retains its own automatic governor.
3. HUD displays **estimated kinematic** shaft RPM, not a physical shaft sensor; compatibility is ternary `COMPATIBLE`/`INCOMPATIBLE`/`UNKNOWN`. For power consumers lacking an evidenced shaft, the neutral `PWR?` observation is **not** an asserted cardan.
4. `rePTOInspect` is on-demand, read-only; no per-frame console inspection.
5. Server authorizes PTO requests against connection/vehicle controller user; initial/dirty update snapshots are accepted only from the authoritative server. **No published guarantee of live MP compatibility** until issue #46 is completed.
6. TerrainDeformation remains **disabled** by default for this PTO release, independent of the mud/ground projects.

## Field evidence already obtained (user log files)

- Berthoud Vantage 4300, Fiat 180-90 DT: input mechanical PTO confirmed, 540/1000 ratio changes effective output and equivalent torque; MR 12 kW load stays constant; unknown exact pump gearbox, so **do not** force a gear or spraying-speed changes.
- Horsch Avatar 12.25 SD: no native input PTO, MR still calculates 20 kW auxiliary; a powered pneumatic seeder is not a mechanically engaged tractor cardan.
- Krone VariPack V 190 XC Plus, Fendt 512 Vario: true connected cardan, selected 540E, estimated shaft ~606 RPM at engine 1926 and ~252 at engine 800; active MR loads ~46.87 and ~14.09 kW respectively, going to 0 when stopped. The difference does not isolate RPM-vs-feed dynamics, so cannot establish RPM-dependent baling throughput.
- Historic Heizohack/Jenz tests already confirmed manual RPM governor/RC MR scopes in principle; new bridge bug found in final code review (below). **No runtime validation of the resulting fix yet.**
- Existing unrelated failures: ManualAttach `delete(nil)` on shutdown, duplicate CBI6800CT specializations, occasional Fendt wheel-shape physics warnings, and ModMixer static suspected-hook reports. No direct evidence that PTO caused them.

## Final review findings and corrections

### A. Real chipper's physical shaft family vs MR internal load RPM

The Heizohack HM10-500 K/KF physically uses a PTO/cardanic and belt-drive transmission rated **up to 1000 RPM** according to vendor specifications. The *maximum* is not an OEM minimum or a claimed 780 RPM physical safety limit:
https://www.fuelwood.co.uk/Wood-Chippers/HM10-500K.aspx

In MR 0.26.10.08, the Heizomat `hm10500KF.xml` assigns raw `powerConsumer.ptoRpm=540` and explicitly calls a generic 10-kW load **hydraulics, not PTO**. Its power consumer still carries the separate wood-crusher dynamic work demand; `MR_WoodCrusher.lua` pauses feeding if normalized `mrPtoCurrentRpmRatio < 0.78`, an MR modeling choice.

Prior RC `PTOState.lua` normalized by raw 540, despite RE's **PROFILE** having an independently sourced physical nominal 1000 family. This makes MR's feeder RPM ratio too high. **Fix in RC PR #25**: for `requirementSource="PROFILE"` and known valid `requiredGearboxFamilyRpm`, normalize by that family; otherwise preserve raw MR loads. Profile 1000 plus raw 540 now yields `effectiveMotorRatio *1000/540` when scoped to MR's canonical 540 channel. Horsch remains shaftless, Berthoud 500 unknown retains raw 500, Krone 540 remains nominal 540. This is an **RC implementation fix**, not a demand for new RE physics.

RC PR: https://github.com/rafaaelalves/FS25_RealismCompatibility/pull/25
Technical source audit: https://github.com/rafaaelalves/FS25_RealismCompatibility/blob/fix/pto-profile-nominal-mr-normalization/docs/research/2026-10-13-pto-heizohack-nominal-mr-bridge-fix.md

### B. Network stream framing follows the GIANTS convention

Original interim MP guard wrote one `false` presence bit on client->server `onWriteUpdateStream` and read it back, which diverges from the GIANTS `ForageWagon:onWriteUpdateStream` / `onReadUpdateStream` convention. **Final correction** in RE PR #39 and #45: no bits written **or read** on client->server PTO specialization update stream; only the server->client stream includes the dirty presence bit and accepted state. `PTOStateEvent` separately authorizes incoming client commands against the active vehicle controller. This was covered by new source harness tests and CI; live MP remains unverified.
GIANTS reference: https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=676&version=script

### C. Boundaries unchanged

No generic compressor/pump/fan throughput multiplier; no synthetic stall engine on baler overload; no forced spray rate change from higher PTO speed. MR already handles baler feed tonnage and additional power; the future RPM-to-throughput coupling is **V2 research**, not V1.6 release criteria.

## Release gates

| Gate | Evidence | Disposition |
|---|---|---|
| Source syntax, XML, harnesses, mod ZIP | RE CI PR #39/#45 passing; RC PR #25 passing | PASS |
| Runtime mechanical PTO + neutral shaftless classification | Berthoud, Horsch, Krone user logs | PASS on listed fixtures |
| Correct nominal bridge for crusher `PROFILE 1000 / raw 540` | MR source, RC code, State+Bridge regression harness | PASS in automated scope; **actual in-game cutoff untested** |
| Safe maintenance of 500 unknown, 540 native, shaftless Horsch | RE/RC regression harness plus prior logs | PASS within stated scope |
| Standalone PTO without MR | `tests/pto_physics_harness.lua` CI; not broad FS25 in-game matrix | PASS harness only |
| Live multiplayer enter/handoff/late join | No user availability | DEFERRED — issue #46; do not claim validated MP |
| New baler-speed or sprayer-output mechanics | Out of scope | NOT REQUIRED |

**Suggested optional post-merge smoke:** if user later tests the HM10/Fiat or 6R at selected **1000 PTO**, compare a steady estimated physical shaft RPM ~700 (MR feed expected OFF) to ~800 (feed may resume), with RC PR #25 installed. Do not call this a universal *real machine* cutoff; other MR feed constraints (timers, load, pipe, etc.) can independently pause it. Capture only one normal log if doing so; never repeat Horsch/Berthoud/Krone tests solely due to this correction.

## Release and rollback instructions

Merge order: **RC PR #25 first**, RE parent **#39** next, RE child **#45** after rebasing/retargeting to `main`. Preserve normal GitHub merge history for stacked PR ancestry when possible. Check actual post-merge main CI and artifact SHA.

For personal singleplayer release, record MP `NOT VALIDATED` visibly; do not mislabel it as proven. The `main` branch's normal CI is necessary. Keep the last known-good RE ZIP and RC ZIP outside the mods folder for easy rollback; FS25 loads only the intended `FS25_RealismExtensions.zip` and `FS25_RealismCompatibility.zip` versions. Do not activate external Dynamic PTO simultaneously as another PTO authority.
