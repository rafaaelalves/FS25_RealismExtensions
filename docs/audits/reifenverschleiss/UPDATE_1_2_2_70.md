# Reifenverschleiss 1.2.2.70 update audit

Date: 2026-10-06

## Exact package

- archive: `FS25_Reifenverschleiss.zip`
- modDesc version: `1.2.2.70`
- title: Real Physics - Tire Wear DEV
- author: duestereLegende
- SHA-256: `938363f661dc8a6943fcddc5fa766d63ff79702962746b513e39cdef3e172d6a`
- declared multiplayer support: true
- package entries: 27
- Lua: 11 files / 11,407 source lines
- XML: 8; all parsed successfully
- executable payload: none found
- path traversal entries: none found
- reusable source license in ZIP: not found

Comparison baseline:
- Reifenverschleiss `1.2.2.67`
- SHA-256 `4d645f1e1e2ac3aaef4f4291fe2de9f27835efa499a45069a1c8172bedd6ff3a`

The public distributor labels this release `V1.2.2.7`, while the supplied package itself declares `1.2.2.70`. Project compatibility evidence always keys off the exact package's internal version + SHA.

## Executive result

Recommendation remains:

**KEEP + INTEGRATE. DO NOT ABSORB THE MOD INTO RE.**

Upgrade recommendation at source level: **YES**, with the RC update in
`research/reifen-1.2.2.70-current-base`, followed by runtime validation.

The release materially improves its interoperability surface:
- public compatibility API v1;
- explicit wear-only structural radius API;
- coordinated Mud 1.3.6 radius channel;
- stable non-versioned mod filename;
- proper l10n packs and workshop localization.

It does **not** remove the need for RC:
- Reifen still writes an absolute final `tireGroundFrictionCoeff`;
- MR must remain owner of healthy/base terrain-tire grip;
- the existing FORCE-WEAR/RMS topology mismatch remains;
- Mud local wetness still does not feed the wear model;
- EWFS broad polling/control ownership remains;
- workshop/multiplayer authority defects remain.

## Solution-quality gate

### Upstream API v1
Classification: **GOOD_AND_ADOPT_PRINCIPLE**

The new API separates questions from shared-state mutation:

```lua
getWearAppliedTargetForScale(vehicle, wheel, nativeStart)
getWheelWearRadius(vehicle, wheel)
getWheelCompatibilityData(vehicle, wheel, nativeFrictionScale)
getCompatibilityApiVersion() -> 1
```

Strong principles:
- caller supplies an explicit friction baseline;
- Reifen remains owner of its own wear curve;
- structural wear radius is published as owner truth;
- the API states that temporary external radius is allowed and must not feed back as Reifen's wear baseline;
- API version is explicit.

These are principles RC/RE should adopt in our own provider contracts.

### Native Mud↔Reifen integration as a whole
Classification: **FUNCTIONALLY_CORRECT_BUT_NOT_OUR_ARCHITECTURE**

Good:
- Mud uses Reifen API v1 instead of temporarily mutating `frictionScale` when available;
- Reifen publishes an explicit structural radius channel for Mud;
- wear remains structural while pressure/sink remain temporary.

Still weaker than our desired architecture:
- Mud discovers Reifen mostly by function/API shape rather than negotiating the published API version;
- Mud injects `__MudRadiusCombiner` into Reifen's private environment;
- compatibility may install late, making legacy-wrapper order observable;
- private `__rv*` fields remain part of the Mud radius handoff;
- compatibility hooks do not have a full versioned registration/lifecycle contract.

Preferred clean-room endpoint remains provider/capability registration rather than cross-environment mutation.

## RC consequence

### MRTireWear remains required

Reifen 1.2.2.70 still appends to `WheelPhysics.updateFriction` and finally performs:

```lua
physics.tireGroundFrictionCoeff = targetApplied / physics.frictionScale
```

Therefore native Reifen remains an **absolute final grip writer**.

RC must still convert Reifen's own wear target into a non-boosting relative degradation of MR's healthy coefficient.

### Public API v1 must remain semantically pure

An initially attractive option was to wrap `getWearAppliedTargetForScale()` directly.

Rejected.

That would make a public API whose contract is "Reifen wear target for this baseline" silently return "MR × Reifen composed target" to every future consumer.

The final RC design therefore:
- leaves compatibility API v1 untouched;
- uses it as semantic/version evidence;
- consumes `getWheelWearRadius()` for structural state;
- retains the bounded one-time Mud 1.3.6 outer-wrapper repair only when the exact audited API-v1 boundary appears.

This is less globally elegant than a true provider-registration API, but it preserves upstream API semantics.

### Structural radius integration improves

Preferred order now becomes:

```
Reifen API v1 getWheelWearRadius()
        ↓
Mud coordinated __rvDesiredRadius fallback
        ↓
legacy Reifen rvRoundPhysicalRadius fallback
        ↓
unworn/original radius markers
```

This reduces RC dependence on private implementation fields for the current release.

The same preference is used by:
- `MRMud`;
- `MRTireWear.getPermanentStructuralRadius`;
- `ExtensionsStateProvider`.

### Version confidence

`1.2.2.70` is eligible as **SOURCE_COMPATIBLE** for `MRTireWear`, but RC also runtime-checks that the exact audited API-v1 surface exists.

A package claiming 1.2.2.70 but missing:
- `getCompatibilityApiVersion()`;
- API version `1`;
- `getWearAppliedTargetForScale()`;
- `getWheelWearRadius()`;

fails closed instead of inheriting source confidence from the version string alone.

## Findings changed from 1.2.2.67

### Resolved/improved

- **R-33 workshop localization** — substantially resolved. Workshop strings now route through `rvL10n()` with DE/EN/ES/FR/RU packs.
- **R-34 stale description lifetime list** — resolved. Description lists 350/500/750/1000/1500/2000 km.
- **R-35 stale option l10n keys** — current language packs match the active reference choices.
- **R-27 structural-radius interoperability** — materially improved by the public wear-radius API and coordinated Mud structural channel, although the visual worker still owns/directly writes current radius during its update.
- **R-24 Mud version/profile weakness** — partially superseded for radius semantics by capability/API checks, but the profile detector itself is still not a full semantic negotiation protocol.

### Still present

- **R-01** clean-install 350 km default mismatch.
- **R-02** broad generic wheel eligibility.
- **R-03/R-04** absolute wear friction ownership and non-monotonic low-baseline edge.
- **R-05/R-06** runtime deletion/currentVehicle lifecycle risk.
- **R-07 through R-12** EWFS scope/polling/state ownership concerns.
- **R-13** source still applies roller max-speed penalty only to confidently detected `RUBBER_TRACK`, while public description says rubber and metal tracks.
- **R-14/R-15** native repair/repaint wear reset semantics.
- **R-16 through R-22** workshop/network/persistence authority/lifecycle findings.
- **R-23** local Mud wetness still absent from Reifen's wear physics.
- **R-25/R-26** invasive Mud final-owner/overlay cache mechanics.
- **R-28/R-29** cached GIANTS differential torque shares remain stale across RMS topology changes.
- **R-30** randomized roller lifetime still has no explicit network synchronization.
- **R-31/R-32** diagnostic-only width/radius factor and duplicate module sourcing remain.
- **R-39 through R-48** visual/crawler/EWFS findings remain unless runtime evidence says otherwise.

## New engineering conclusions

### Stable baseline should be an input, not temporary shared-state mutation

API v1 is a direct improvement over the legacy compatibility technique.

Preferred pattern:

```
specialist.evaluate(input, explicitBaseline)
```

not:

```
save shared field
mutate shared field
call specialist
restore shared field
```

### Publish owner truth separately from effective actuator state

`getWheelWearRadius()` distinguishes:
- Reifen-owned permanent wear radius;
- external temporary effective radius.

This is exactly the type of distinction needed for RC/RE:
- structural truth;
- temporary consequence;
- final engine actuator.

### API version + capability shape + exact source evidence

A numeric API version is useful, but not sufficient alone.

The RC gate combines:
1. exact source/version evidence;
2. API version;
3. required capability shape;
4. runtime tests.

### Do not contaminate a public provider to solve a private composition problem

The rejected RC API-wrapper prototype is itself a useful lesson:
a convenient hook point is not automatically the correct ownership boundary.

## Remaining RC/RE opportunities

No new generic Reifen hotfix is approved.

Still open, but separate from this update:
1. **Mud local wetness → Reifen wear input** — promising, but must be cross-audited against other moisture owners before implementation.
2. **RMS effective drive topology → Reifen FORCE-WEAR** — still a real source mismatch; runtime magnitude test remains the gate before a narrow bridge.
3. **WheelEligibility provider** — still justified because Mud/Reifen independently classify wheel-like objects.
4. **running-gear state provider** — Reifen API v1 makes a normalized provider cleaner, but do not build one until at least two real consumers require more than structural radius.

## Static completion state

Static/source audit for 1.2.2.70: **complete**.

RC source/harness validation: pending final CI confirmation on
`research/reifen-1.2.2.70-current-base`.

Remaining work after CI: in-game/runtime validation only.


### Canonical-name migration safety

The stable filename is an upstream improvement, but migration itself creates a
new stack hazard: an old versioned technical mod and the new canonical mod can
coexist as two distinct active script mods if both ZIPs are left installed.

RC previously preferred the canonical identity and could miss that both sets of
hooks were live.

The Reifen 1.2.2.70 RC branch now treats:
- canonical + legacy;
- or multiple legacy release identities;

as ambiguous and fails closed.

This is a reusable lesson:
> when an upstream project changes technical identity, compatibility discovery
> must detect migration duplicates, not merely learn the new name.
