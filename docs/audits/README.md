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

- [TerraFarm deep architecture/compatibility audit](./terrafarm/README.md) — machine lifecycle, TerrainDeformation pipeline, multiplayer/persistence, landscaping areas, official machine-addon extensibility, integration tiers and risk matrix.
- [MoreRealistic deep architecture/compatibility audit](./morerealistic/README.md) — global-vs-converted ownership, wheel/traction/mass model, drivetrain/PTO/workload architecture, static findings, integration opportunities and runtime test plan.
- [Reifenverschleiss deep architecture/compatibility audit](./reifenverschleiss/README.md) — persistent tire/track/roller wear, friction/radius ownership, crawler visuals, EWFS, multiplayer/workshop lifecycle, integration opportunities and runtime test plan.
- [Realistic Mechanical Systems deep architecture/compatibility audit](./rms/README.md) — static/source audit closed for 0.10.0.0: architecture, scheduling, networking, drivetrain topology, wear/breakdowns, thermal/electrical, service/fluids, AI/leasing/UI, cross-mod findings, patch opportunities and runtime plan.
- [MudSystemPhysics deep architecture/compatibility audit](./mudsystemphysics/README.md) — current 1.3.4.0 same-version rebuild audited by exact SHA; core RC/RE contracts preserved, native Reifen integration added, MP/lifecycle changes documented, and runtime smoke matrix identified.
- [Persistent Tracks functional-absorption assessment](./persistenttracks/README.md) — static safety/provenance check, native TireTrackSystem record/replay architecture, simplification/streaming analysis, limitations versus RE, multiplayer gap and recommended clean functional reimplementation.
- [Visual Mud Tracks selective-absorption assessment](./visualmudtracks/README.md) — evaluates rut physics/lifecycle, sink-to-terrain handoff, direct terrain writes, persistence/MP chunking, tire pressure, soil/crop systems and identifies selective RE improvements without absorbing the monolith.
- [True AI Tracks functional-absorption assessment](./trueaitracks/README.md) — exact-source comparison against current TerrainDeformation, confirms RE supersedes AI physical deformation, isolates native AI tire-track visuals as the remaining absorption capability, and corrects the 2.2.0.1 scan-gate finding by exact hash.
- [Hydraulic Suspension System assimilation audit](./hydraulic-suspension/README.md) — evaluates active/self-leveling front suspension, MR spring/damper ownership collision, physical/visual architecture, MP/config defects and a clean compositional ActiveSuspension design.
- [Realistic 4x4 Traction System assimilation audit](./4x4-traction/README.md) — separates useful traction-demand/decision semantics from an inferior duplicate physical drivetrain owner, rejects bundled CTIS ownership and proposes richer RMS AUTO/lock demand logic.
- [Realistic Diesel Start functional-absorption audit](./rds/README.md) — exact 1.2 -> 1.4 source diff; staged ignition/ADS/fuel-provider lessons, redesigned server-authoritative pneumatics, HUD/input/lifecycle findings and performance opportunities.
- [Realistic Brakes deep architecture/compatibility audit](./realistic-brakes/README.md) — exact 1.3.0.0 source audit of parking ownership, engine/Jake conflict with MR, brake thermal/fade, trailer air/spring brakes, networking, controllers, performance, RDS/native-AIR integration and runtime gates.
