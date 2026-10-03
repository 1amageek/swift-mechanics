# ParticleState

## Purpose and Scope
Particle distributions and immutable physical state. Initial admitted implementation domain; behavioral/profile qualification pending. Parent [module](../DESIGN.md); no children.

## Responsibilities and Boundaries
Own solid, untextured isotropic sphere mass/inertia, identified collision/material binding and CPU model admission; Replay owns weighted sampling. Angular orientation is a gauge for this sphere domain; world angular velocity is physical. Model is an immutable Sendable reference retained by state; exact reference identity binds in-process continuation. Full EX-004 remains open.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [Core](../../MechanicsCore/DESIGN.md) | depends on | SI vectors/rotations | Explicit typed failures |
| [Collision](../../MechanicsCollision/DESIGN.md) | depends on | analytic framed witnesses | No box/mesh/approximate geometry admission |
| [ContactLaws](../../MechanicsContactLaws/DESIGN.md) | depends on | material pairs, history and force | Spring friction is not exact Coulomb |
| [Numerics](../../MechanicsNumerics/DESIGN.md) | depends on | NumericalWork | Separate supplier units |
| [Runtime](../../MechanicsRuntime/DESIGN.md) | depends on | RuntimeRandomState | No session/wire checkpoint claim |
| [Tests](../../../Tests/MechanicsGranularTests/DESIGN.md) | used by | physical/failure oracles | Execution is root-owned |

## Architecture
```text
identified immutable model/state -> bounded owned operation -> immutable contribution or typed failure
```

## Contracts and Invariants
Caller supplies all unordered sphere/sphere laws followed by every sphere/plane law in row order. No absent-pair default. Sphere radius equals zero-margin exact analytic proxy radius; mass positive, I=2mr²/5 positive finite. Planes are exact half spaces with tangent translation and normal-axis spin. Constructor normal-velocity and angular-alignment tolerances have separate m/s and 1/s units; each step additionally bounds h times normal speed/tilt rate by caller geometric length/normal tolerances. Geometry remains frozen, and tolerated floating alignment error is an explicit local approximation. Disabled/trigger/mutual-mask-vetoed pairs fail admission, rather than erase a law. All bodies/colliders are distinct, common identified frame/revision; material references match each ordered law. Only compliantDampingOnly loss admitted. Hertz/Hunt-Crossley effectiveRadius must agree with sphere/sphere harmonic radius or sphere/plane radius to caller length tolerance; resistanceRadius remains an explicitly caller-declared constitutive length, not an inferred bearing lever.

## Runtime Flows
Seeded weighted integer selection uses RuntimeRandomState and rejection sampling, retaining all draws including rejected ones. Density/radius define mass; positions are supplied separately. Numerical work and supplier ledgers precede allocations/math. Runtime RNG internal arithmetic has fixed published generator meaning, and invocation attempts have their own limit. No automatic random packing or overlap removal. Constant-size supporting constructors validate scalar domains without traversing identity strings; body/proxy equality belongs bounded preparation.

## State, Ownership, and Lifecycle
Inputs/results are immutable Sendable; workspace and caller ledgers are exclusive inout. Array COW publication preserves prior states; next mutation may copy bounded retained capacity. No shared mutable cache, target-specific isolation or unsafe borrow. Immutable model owner keeps identity/geometry/materials alive.

## Failure, Concurrency, and Constraints
GranularError retains typed Core/Numerical/Collision/Contact/Runtime failures. Supplier inout work remains actual supplier evidence; no guessed conversion into numerical arithmetic. Independent supplier invocation cap applies before calls. Stop once on failure; no retry/fallback. Non-sphere/dynamic finite-mass boundary/instant-impact/antipodal transport callable paths explicitly fail with INCOMPLETE_IMPLEMENTATION markers.

## Verification and Change Impact
Tests execute two-sphere collision/momentum, settling, moving-plane shear/torque/work, cohesive attraction, seeded weighted distribution/replay, and invalid/capacity/cancellation/supplier failures. Numerical success alone is insufficient. Changes invalidate module/root selected profile proof; no independent build by this owner.

### Selected AF17 execution evidence

Native admitted sphere/plane preparation and invalid/capacity/supplier cases passed. Original Native/WASM/Embedded public required two-sphere preparation executes; broader shape/Runtime domains remain unavailable. Exact profile identity and root logs are indexed by the [parent design](../DESIGN.md); the corresponding test owner retains the independent physical oracles. Private stack diagnostics are not qualification.
