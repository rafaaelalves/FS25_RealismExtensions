# TerrainDeformation algorithm comparison

Updated: 2026-09-29

## Compared systems

- FarmKit NXRealisticWheelPhysics custom ruts;
- True AI Tracks 2.2.0.1;
- RealismExtensions TerrainDeformation pipeline.

## FarmKit custom ruts

FarmKit nxApplySlipDeformation is a useful prototype and proved that FS25 TerrainDeformation brushes can create gameplay ruts.

Its response uses:

- field/on-ground gating and minimum speed;
- longitudinal slip threshold and speed scaling;
- lateral damage approximated from steering input times vehicle speed;
- one 500 ms deformation tick per wheel;
- fixed per-wheel accumulated-depth ceiling;
- wheel/tire profile multiplier;
- global wetness multiplier;
- FarmKit ground-profile deform multiplier;
- freeze/thaw multiplier;
- an explicit 0.5 AI multiplier;
- one soft-circle TerrainDeformation object/job per deformation event;
- crop destruction coupled to the same rut event.

Strengths: simple, visible, understandable and covers longitudinal plus some lateral behavior.

Limitations for the current stack:

- lateral scrub is steering proxy rather than measured lateral wheel slip;
- wetness is mostly FarmKit/global-state derived rather than RC/Mud local state;
- depth memory belongs to a wheel, not the terrain location;
- repeated passes from different wheels/vehicles do not share one physical ground history;
- one brush generally creates one deformation object/job;
- AI gets an arbitrary physics multiplier rather than the same state-response law;
- footprint does not use measured wheel load/tire pressure;
- crop damage and rut ownership are coupled.

## True AI Tracks

True AI Tracks is much narrower. It mainly enables the game's native displacement/tire-track behavior for AI and attached implements.

It does not provide the RE-style pressure/wetness/slip response model or custom spatial rut history.

Its exact 2.2.0.1 source also appears to contain a scan-gate unit mismatch: the accumulator uses normal FS dt milliseconds while the threshold compares against CHECK_INTERVAL / 1000. That makes the advertised 150 ms mission-wide rediscovery gate likely execute effectively every frame.

RE avoids a mission-wide vehicle scan by injecting one wheeled-vehicle specialization and processing only that object's wheels.

## RealismExtensions pipeline

StateContract -> FootprintModel -> TerrainResponseModel -> SpatialHistory -> TerrainWriter.

### Inputs

- real wheel contact position;
- longitudinal and lateral slip;
- vehicle and wheel-surface speed;
- local physical wetness;
- hard-freeze state;
- structural radius;
- tire/support width;
- tire pressure;
- wheel load and confidence;
- observed sink depth;
- Mud ground-profile identity/potential.

### Footprint

When pressure state exists, pneumatic footprint is load/pressure driven instead of using only width/radius geometry. The old MR-style width * radius * 0.53 approximation remains a low-confidence fallback.

Crawlers fail closed rather than being modeled as very wide tires.

### Response

- vertical pressure and susceptibility determine bounded rut capacity;
- observed Mud sink is a minimum physical anchor;
- longitudinal slip produces excavation;
- lateral slip produces scrub and width growth;
- shear is based on relative contact displacement, so stationary wheelspin and locked-wheel sliding both work;
- shear response saturates rather than growing without bound;
- repeated passes converge asymptotically toward a terrain-cell capacity.

### Spatial/runtime architecture

- history belongs to quantized terrain cells rather than a wheel;
- paths are sampled between consecutive wheel contacts;
- parked wheels hit a cheap activity gate before provider/model work;
- writer has brush/job/frame budgets and bounded backlog;
- similar brush depths can be batched into one TerrainDeformation object;
- queued objects are deleted after completion callback;
- server is the sole terrain writer.

## Is RE objectively better?

Architecturally, several improvements are concrete and testable: better source state, shared spatial history, measured lateral slip, stationary wheelspin, event-driven vehicle ownership, batching, budgets, bounded queue and explicit lifecycle.

Physical fidelity is not yet fully proven. Soil susceptibility and rut-capacity constants are provisional because we do not have calibrated FS25 soil parameters. Runtime visual calibration and performance measurements are still required.

Therefore the current claim is:

RE has a stronger architecture and richer physically relevant inputs than the audited alternatives; its final physical calibration is still an experimental model, not a validated universal soil model.

## Scientific basis

The design borrows concepts rather than claiming a full calibrated terramechanics implementation:

- pressure-sinkage models separate vertical support/sinkage from shear behavior;
- Janosi-Hanamoto-style shear-displacement curves motivate saturating, not unlimited-linear, shear response;
- agricultural tire literature supports using inflation pressure/load to reason about surface contact pressure;
- tracked systems require separate treatment because local roller/bogie pressure differs from nominal average track pressure.

See the project research notes for source links and parameter assumptions.