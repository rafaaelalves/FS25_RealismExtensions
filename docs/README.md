# Documentation map

Updated: 2026-10-02

Use documents by purpose instead of reading everything.

## Restart / handoff
- `project/CONTEXT.md`: stable project orientation and ownership.
- `project/CURRENT_HANDOFF.md`: exact current implementation, runtime evidence and next test.
- `project/PROJECT_STATUS.md`: capability status/blockers.
- `DEVELOPMENT_PROCESS.md`: evidence-first development, telemetry and runtime-test rules.

## Architecture / decisions
- `project/OWNERSHIP.md`: normative phenomenon ownership.
- `project/ARCHITECTURE.md`: stable module boundaries.
- `project/ROADMAP.md`: capability progression.
- `decisions/`: non-obvious decisions and their rationale.

## Evidence / research
- `audits/`: external-mod source audits and reusable precedents.
- `audits/terrafarm/README.md`: active TerraFarm architecture audit.
- `research/`: unresolved technical research.
- `research/giants-cultivator-work-semantics.md`: current GIANTS Cultivator work-state contract.

## Runtime protocols
- `tests/`: versioned/manual runtime test protocols (not Lua harnesses).
- Current recovery test: `tests/terrain-recovery-v22-runtime.md`.

Do not duplicate current status into audit/research notes. Link back to `CURRENT_HANDOFF.md` for the live state.
