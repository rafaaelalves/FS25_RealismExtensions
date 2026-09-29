# ADR 0002 — Do not create a second traction or sink simulation

Status: accepted  
Date: 2026-09-28

## Context

The target stack already has mature owners: MR for base dynamics/traction and Mud for local wetness, sink, terrain resistance and stuck behavior.

Terrain deformation needs slip, sink and ground state, but does not need to own those causes.

## Decision

RealismExtensions treats traction, slip inputs, sink, wetness and stuck state as inputs. It may create geometric/visual/persistent consequences from them, but must not change those values merely to make its effects occur.

## Consequence

A vehicle may become physically stuck before/without a supported deformation surface. That is preferable to inventing a competing force model. Missing geometry is an extension-coverage problem, not permission to duplicate Mud physics.
