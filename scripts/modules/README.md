# Gameplay modules

Each module owns exactly one documented phenomenon.

Before adding a module:
1. add/update the ownership matrix;
2. document required StateContract fields;
3. add an ADR if it overlaps an existing specialist owner;
4. add deterministic harness coverage where possible;
5. add runtime diagnostics/telemetry before broad testing.

Modules must fail closed when required authoritative state is unavailable.
