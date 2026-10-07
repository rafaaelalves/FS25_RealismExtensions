# Audit workspace

One subdirectory per audited external mod.

Minimum audit record:
- exact mod name/version/hash or source commit;
- source availability/license/governance;
- hooks/overwrites/listeners;
- state read/writes;
- overlap with target stack;
- unique phenomena worth retaining;
- performance architecture;
- UI/input footprint;
- multiplayer/persistence behavior;
- recommendation: KEEP, INTEGRATE, FUNCTIONALLY REPLACE, ABSORB, or DO NOT USE.

Never infer an absorption decision from feature similarity alone.


## Audit method: compatibility + engineering learning

Every external-code audit has two outputs:

1. **ecosystem decision** — determine ownership, overlap, integration/bridge opportunities, performance/lifecycle risks and whether the capability belongs in RC, RE, the external mod, or nowhere;
2. **engineering learning** — reconstruct why the author chose the architecture, identify useful invariants/patterns, compare them with our current approach, and deliberately improve our own design rules where the evidence is stronger.

The goal is **not** to make our code look like the audited author's code. Extract principles, not authorship/style.

Version handling:
- exact same version/hash: re-check coverage and fill gaps;
- new version/hash in the same lineage: preserve the prior audit and add a delta/comparison;
- different mod/code line: create a new audit.

Preferred intervention order:
1. stable communication/API contract;
2. integration/bridge;
3. reusable compatibility primitive;
4. systemic architectural improvement;
5. defensive patch;
6. third-party-specific correction only as a last resort.

### Mandatory solution-quality gate before changing RC/RE

An upstream mod implementing compatibility with another mod is **evidence**, not automatically the design target.

Before changing RC or RE because of an upstream integration, explicitly answer:

1. What physical/state ownership problem is the upstream code trying to solve?
2. Is its composition mathematically/semantically correct for the owners involved?
3. Does it solve only the pairwise case, or does it remain correct in our larger stack?
4. Does it depend on load order, private fields, monkey-patching, polling, duplicated state or temporary mutation?
5. Is there a cleaner public/provider/capability boundary available?
6. Would adapting RC/RE to that implementation copy upstream technical debt into our architecture?
7. Can RC adapt only the unavoidable external boundary while preserving a cleaner internal contract?
8. Does the upstream change make any existing bridge obsolete, or merely change how that bridge must compose?
9. If we do change RC/RE, is the change bounded, capability/version gated, identity checked where needed, lifecycle-safe and fail-closed for unknown future versions?

Classify the upstream solution separately from our response:
- **GOOD_AND_ADOPT_PRINCIPLE** — implementation reveals a principle we should standardize;
- **FUNCTIONALLY_CORRECT_BUT_NOT_OUR_ARCHITECTURE** — interoperate minimally, do not reproduce it;
- **PAIRWISE_FIX_ONLY** — works for two mods but needs a broader stack composition layer;
- **FRAGILE / PATCH_AROUND_ONLY_IF_REQUIRED** — do not normalize it into project architecture;
- **SUPERSEDES_RC** — remove/reduce an RC bridge only when the upstream owner now covers the same semantic boundary completely.

No RC/RE code change is complete until this gate is documented.

RC should not become a generic third-party bug-fix layer. RE should not become a compatibility layer: it owns realism capabilities we deliberately implement/absorb after external ownership is removed or avoided.

For every useful pattern, record:
- problem being solved;
- chosen abstraction/ownership boundary;
- why it likely works;
- tradeoffs/failure modes;
- how our current architecture differs;
- whether the principle should change our coding/design practice.


- [TerraFarm deep architecture/compatibility audit](./terrafarm/README.md) — machine lifecycle, TerrainDeformation pipeline, multiplayer/persistence, landscaping areas, official machine-addon extensibility, integration tiers and risk matrix.
- [MoreRealistic deep architecture/compatibility audit](./morerealistic/README.md) — global-vs-converted ownership, wheel/traction/mass model, drivetrain/PTO/workload architecture, static findings, integration opportunities and runtime test plan.
- [Reifenverschleiss deep architecture/compatibility audit](./reifenverschleiss/README.md) — exact 1.2.2.67 baseline + 1.2.2.70 update; persistent tire/track/roller wear, public compatibility API v1, friction/radius ownership, Mud coordination, crawler visuals, EWFS, multiplayer/workshop lifecycle, RC integration opportunities and runtime plan.
- [Realistic Mechanical Systems deep architecture/compatibility audit](./rms/README.md) — exact 0.10.0.0 baseline + 0.11.0.0 update; architecture, scheduling, networking, drivetrain topology, PTO/electrical/fluids, MRRMS/MudRMS/RMSDynamicPTO contracts, cross-mod findings, patch opportunities and runtime matrix.
- [MudSystemPhysics deep architecture/compatibility audit](./mudsystemphysics/README.md) — audited through 1.3.6.0 by exact SHA; core RC/RE ownership preserved, Reifen API/radius composition strengthened, RC wrapper-order hardening identified/implemented, chunked atomic wetness scheduling documented, TTD removal assessed, and targeted upgrade smoke matrix defined.
- [Persistent Tracks functional-absorption assessment](./persistenttracks/README.md) — static safety/provenance check, native TireTrackSystem record/replay architecture, simplification/streaming analysis, limitations versus RE, multiplayer gap and recommended clean functional reimplementation.
- [Visual Mud Tracks selective-absorption assessment](./visualmudtracks/README.md) — evaluates rut physics/lifecycle, sink-to-terrain handoff, direct terrain writes, persistence/MP chunking, tire pressure, soil/crop systems and identifies selective RE improvements without absorbing the monolith.
- [True AI Tracks functional-absorption assessment](./trueaitracks/README.md) — exact-source comparison against current TerrainDeformation, confirms RE supersedes AI physical deformation, isolates native AI tire-track visuals as the remaining absorption capability, and corrects the 2.2.0.1 scan-gate finding by exact hash.
- [Hydraulic Suspension System assimilation audit](./hydraulic-suspension/README.md) — BETA 2 + release 1.0.0.0 lineage; evaluates compositional ActiveSuspension, LoaderRideControl, presentation-only CabIsolation, MR spring/damper ownership collision, MP/config/lifecycle risks and transferable engineering patterns.
- [Realistic 4x4 Traction System assimilation audit](./4x4-traction/README.md) — exact 1.6.0.0 baseline + 1.7.0.0 update; separates useful traction-demand/decision semantics from duplicate drivetrain ownership, rejects bundled CTIS ownership, audits the new settings/HUD authority model, and proposes richer RMS AUTO/lock demand logic plus a stronger shared settings contract.
\n- [Real Tire Wear 1.6.0.0 assimilation audit](./realtirewear/README.md) — clean-room RunningGearWear candidate; server-authoritative wear/networking and service/failure UX are valuable, while root-distance wear physics, crawler identity, hot-path writes and workshop hooks require redesign.\n
- [Realistic Diesel Start 1.4.0.0 audit](./realistic-diesel-start/README.md) — update audit of native ADS/Fuel/RealisticBrakes interoperability; partially retires the old RDSADS bridge and narrows RC to thermal/preheat/cold-consequence composition.
