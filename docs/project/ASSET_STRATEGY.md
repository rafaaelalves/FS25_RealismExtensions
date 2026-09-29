# Asset strategy

Updated: 2026-09-29

RealismExtensions is clean-room not only in Lua logic but also in visual/audio content.

## Asset classes

### A — No custom runtime asset required
Prefer these first. The feature can use GIANTS runtime primitives, existing vehicle data, terrain brushes, standard GUI primitives, or programmatic drawing.

Examples:
- terrain deformation/ruts;
- crop state writes;
- PTO state/modes and logic;
- differential/traction state logic;
- persistence/telemetry;
- simple HUD panels drawn from standard UI primitives.

### B — Small original UI asset optional
The feature works without copied assets; original icons can be created later.

Examples:
- PTO mode icon;
- wetness/slip symbols;
- settings/menu artwork.

### C — Custom particles/materials needed
Implementation is feasible, but asset work is part of the feature scope.

Examples:
- road spray particles;
- custom mud/dust particles;
- specialized visual surface contamination.

### D — Custom shader/material pipeline required
High-cost. Do not promise replacement before a technical prototype proves that a clean-room shader/material strategy is viable.

Example:
- Reifen-style visible tread/track-profile wear.

## FarmKit asset dependency findings

At source snapshot `1.0.0.3 / 8ee55d9...`, FarmKit contains about 1 MB of custom asset data, but most unique gameplay ideas do **not** require those assets.

| FarmKit capability | Custom assets needed to reproduce behavior? | Notes |
|---|---:|---|
| custom geometric ruts / slip deformation | no | uses TerrainDeformation runtime brushes |
| realistic plowing / furrow collider width | no | logic/collider manipulation |
| speed-based crop damage | no | density/crop state logic |
| off-field foliage/grass damage | no | density map logic |
| implement dust scaling/tails | usually no | modifies existing implement particle systems |
| wheel mud particles | yes for FarmKit's own look | but Mud remains owner; we do not need to reproduce it |
| road water spray | yes for an equivalent standalone visual | FarmKit clones its own wet particle asset |
| HUD wet/rain icons | yes if identical design desired | we should use our own UI/iconography |
| Planner/PF dialogs | XML layout, no large art requirement | can use standard GUI components if ever reimplemented |
| engine spatial sound propagation | no custom sound required | transforms existing sound samples |
| load spill | no unique art identified | external RealPhysics remains preferred |
| straw refeed | no | state/routing logic |

### FarmKit custom asset inventory relevant to gameplay
- `assets/NXMud/NXMudDiffuse.dds`
- `assets/NXMud/NXMudNormal.dds`
- dry/wet particle I3D + shape holders
- `gui/wet.dds`
- `gui/rain.dds`
- GUI XML layouts
- mod icon

Conclusion: **the features we most want first—ruts, scrub deformation, furrow interaction and crop interaction—are not blocked by needing FarmKit assets.**

## Dynamic PTO asset finding

The audited `1.1.2.0` ZIP is logic-heavy. Its runtime panel assets are tiny and replaceable; the large majority of packaged image bytes comes from the mod icon.

Conclusion: asset burden is **not** a reason to keep Dynamic PTO external.

## Reifen asset finding

Reifen `1.2.2.67` is different:
- persistent wear logic is ordinary Lua/state;
- visual tire/track wear uses custom material holders and custom shader files;
- visual code replaces/copies texture maps and writes custom shader parameters;
- physical round-tire radius is synchronized with the visual tread-loss model.

Conclusion: logic can be studied/reimplemented independently, but **visual parity is a separate shader project**. Do not remove Reifen from the live stack until visual/workshop/persistence replacement quality is acceptable.
