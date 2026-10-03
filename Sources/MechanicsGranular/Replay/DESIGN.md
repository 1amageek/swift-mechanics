# Replay

## Purpose and Scope
Bounded immutable continuation checkpoint. Initial admitted implementation domain; behavioral/profile qualification pending. Parent [module](../DESIGN.md); no children.

## Responsibilities and Boundaries
Own exact in-process GranularCheckpoint values and bounded restore, seeded distribution output and retained RuntimeRandomState. Does not own Runtime wire serialization/session contributor schema or model replacement.

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
Checkpoint retains immutable complete state and exact immutable model owner. Restore requires same owner, validates capacities/storage under current policy, cancellation before publication. It preserves every particle motion, ContactHistory, transported basis, RNG seed/state/draws, time and step. No reconstructed spring history or reseeded RNG.

## Runtime Flows
No byte serialization claim. Full-task accepted/rejected/restart integration of granular contributor history and RNG through Runtime remains an explicit gap. CPU deterministic replay means same build and same provider implementations; target-wide bitwise floating point identity is not claimed. Runtime session acceptance remains upstream/downstream integration work; no fake session success API.

## State, Ownership, and Lifecycle
Inputs/results are immutable Sendable; workspace and caller ledgers are exclusive inout. Array COW publication preserves prior states; next mutation may copy bounded retained capacity. No shared mutable cache, target-specific isolation or unsafe borrow. Immutable model owner keeps identity/geometry/materials alive.

## Failure, Concurrency, and Constraints
GranularError retains typed Core/Numerical/Collision/Contact/Runtime failures. Supplier inout work remains actual supplier evidence; no guessed conversion into numerical arithmetic. Independent supplier invocation cap applies before calls. Stop once on failure; no retry/fallback. Non-sphere/dynamic finite-mass boundary/instant-impact/antipodal transport callable paths explicitly fail with INCOMPLETE_IMPLEMENTATION markers.

## Verification and Change Impact
Tests execute two-sphere collision/momentum, settling, moving-plane shear/torque/work, cohesive attraction, seeded weighted distribution/replay, and invalid/capacity/cancellation/supplier failures. Numerical success alone is insufficient. Changes invalidate module/root selected profile proof; no independent build by this owner.

### Selected AF17 execution evidence

Native every-history/basis/RNG replay and weighted physical sampling oracles passed. Original public profiles execute bounded value replay and required seeded physical sampling; no Runtime contributor or wire serialization is inferred. Exact profile identity and root logs are indexed by the [parent design](../DESIGN.md); the corresponding test owner retains the independent physical oracles. Private stack diagnostics are not qualification.
