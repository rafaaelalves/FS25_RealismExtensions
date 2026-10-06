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
- [Reifenverschleiss deep architecture/compatibility audit](./reifenverschleiss/README.md) — persistent tire/track/roller wear, friction/radius ownership, crawler visuals, EWFS, multiplayer/workshop lifecycle, integration opportunities and runtime test plan.
- [Realistic Mechanical Systems deep architecture/compatibility audit](./rms/README.md) — static/source audit closed for 0.10.0.0: architecture, scheduling, networking, drivetrain topology, wear/breakdowns, thermal/electrical, service/fluids, AI/leasing/UI, cross-mod findings, patch opportunities and runtime plan.
- [MudSystemPhysics deep architecture/compatibility audit](./mudsystemphysics/README.md) — current 1.3.4.0 same-version rebuild audited by exact SHA; core RC/RE contracts preserved, native Reifen integration added, MP/lifecycle changes documented, and runtime smoke matrix identified.
- [Persistent Tracks functional-absorption assessment](./persistenttracks/README.md) — static safety/provenance check, native TireTrackSystem record/replay architecture, simplification/streaming analysis, limitations versus RE, multiplayer gap and recommended clean functional reimplementation.
- [Visual Mud Tracks selective-absorption assessment](./visualmudtracks/README.md) — evaluates rut physics/lifecycle, sink-to-terrain handoff, direct terrain writes, persistence/MP chunking, tire pressure, soil/crop systems and identifies selective RE improvements without absorbing the monolith.
- [True AI Tracks functional-absorption assessment](./trueaitracks/README.md) — exact-source comparison against current TerrainDeformation, confirms RE supersedes AI physical deformation, isolates native AI tire-track visuals as the remaining absorption capability, and corrects the 2.2.0.1 scan-gate finding by exact hash.
- [Hydraulic Suspension System assimilation audit](./hydraulic-suspension/README.md) — BETA 2 + release 1.0.0.0 lineage; evaluates compositional ActiveSuspension, LoaderRideControl, presentation-only CabIsolation, MR spring/damper ownership collision, MP/config/lifecycle risks and transferable engineering patterns.
- [Realistic 4x4 Traction System assimilation audit](./4x4-traction/README.md) — separates useful traction-demand/decision semantics from an inferior duplicate physical drivetrain owner, rejects bundled CTIS ownership and proposes richer RMS AUTO/lock demand logic.
