# ADR 0003 — Functional absorption is allowed when it improves the architecture

Status: accepted  
Date: 2026-09-29

## Context

The initial project framing strongly emphasized keeping mature specialist mods external. That remains the default, but some external mods create compatibility bridges, duplicate UI/input, or prevent a cleaner shared state model.

Dynamic PTO is the motivating example: RC already contains substantial composition logic solely to translate its state into MR/RMS semantics.

## Decision

RealismExtensions may clean-room reimplement and eventually replace an external mod when the replacement has a concrete architectural benefit.

This is not source absorption. We do not copy third-party source/assets unless an explicit compatible license allows it and doing so is deliberately approved.

## Evaluation criteria

Prefer functional absorption when it:
- removes duplicated/conflicting ownership;
- eliminates a substantial compatibility bridge;
- consolidates authoritative state;
- reduces duplicated HUDs/keybinds/settings;
- improves player/AI consistency;
- materially improves performance or maintainability.

Prefer external ownership when:
- the specialist is deep/mature and already composes cleanly;
- replacement would mostly reproduce working code with no system-level benefit;
- unique assets/shaders are expensive to recreate;
- the external project is actively evolving in a useful direction.

## Current implications

- Dynamic PTO: strong candidate to absorb.
- True AI Tracks: strong candidate to absorb into TerrainDeformation.
- Reifen: candidate by layers; visual wear makes full replacement expensive.
- MR/Mud/RMS/SoilCompaction/RealisticHarvesting: remain external by default.
