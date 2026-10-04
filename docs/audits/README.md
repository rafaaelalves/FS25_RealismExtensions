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
