# Native PTO selective consolidation — RE

Date: 2026-10-08

Selective port of PTO contract, native GIANTS specialization, RPM ratio and manual governor, HUD/controls and harnesses onto RE main. No experimental terrain/recovery/track code from the feature branch is imported. Existing main TerrainDeformation settings and implementations remain unchanged. Workflow builds icon DDS and runs all harnesses; BuildIdentity is stamped. Legacy DynamicPTO is treated as an exclusive incompatible owner in PTOBootstrap.

Merge gate: combined smoke with matching RC consolidation build, verifying non-PTO cultivator / true PTO implement, MR manual throttle behavior, RMS native PTO bridge and existing Mud/Reifen/RMS compatibility. Retain feat/terrain-recovery as separate canonical development branch.
