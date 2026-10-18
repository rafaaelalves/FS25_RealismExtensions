# Documentation map

Use documents by purpose instead of reading everything.

- `project/CONTEXT.md`: shortest restart/handoff context.
- `project/PROJECT_STATUS.md`: current truth.
- `project/OWNERSHIP.md`: normative ownership.
- `project/ARCHITECTURE.md`: stable architecture/rules.
- `project/ROADMAP.md`: future capability sequence.
- `decisions/`: why non-obvious decisions were made.
- `audits/`: evidence about external mods.
- `research/`: unresolved technical exploration.

Do not duplicate current status into audit/research notes. Link to the canonical file instead.

## Recent external-mod lessons

- [`research/2026-10-18-ttd-v3.7-terrain-response-lessons.md`](research/2026-10-18-ttd-v3.7-terrain-response-lessons.md): **research-only TTD v3.7** — surface classification and bounded per-machine calibration ideas, height-reference false-positive test cases, no radius/friction/terrain physics copy.

- [`research/2026-10-18-dynamicdrivepro-terrain-writer-safety-lessons.md`](research/2026-10-18-dynamicdrivepro-terrain-writer-safety-lessons.md): **research-only DynamicDrive Pro 1.0.1.0** — uninitialized/wrong-scope module examples, raw attempted terrain-height/XML replay, safe actor and provenance tests for V3; no code absorption.
