# ManifoldProjection

## Purpose and Scope
Parent: [Constraints](../DESIGN.md). No children. Own bounded local manifold position assembly using an explicitly supplied positive tangent metric and accumulated path correction bound. This is not the existing quadratic closest-point KKT operation and guarantees neither stationarity nor global closest position.

## Responsibilities and Boundaries
Own tangent correction, actual public root/joint retraction, full original row and rank acceptance, immutable assembly result and failed-work prefix. GeometricRelations owns equations and returns the independently recomputed original sample after diagnostic comparison; Joints owns manifold integration; AssemblyProjection owns rank; Numerics owns linear solve. Velocity consistency, physical impulse/reaction/work and Runtime publication belong to upper Mechanisms consumers.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Constraints](../DESIGN.md) | parent | Requirement owner/index | Direct requirement/design owner | Root owns manifest/profiles |
| [GeometricRelations](../GeometricRelations/DESIGN.md) | depends on | HolonomicGeometryProviding, sealed original acceptance | Lower producer consumed by this component | Do not trust supplier residual diagnostics |
| [AssemblyProjection](../AssemblyProjection/DESIGN.md) | depends on | ConstraintRankAnalyzing | Lower producer consumed by this component | Retain original IDs; no KKT reuse |
| [JointManifolds](../../../Modeling/Joints/JointManifolds/DESIGN.md) | depends on | JointMotionEvaluating.integrating | Lower producer consumed by this component | q/v counts differ for quaternion charts |
| [LinearAlgebra](../../../Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | LinearSolving, NumericalWork | Lower producer consumed by this component | Original Gram residual checked |
| [Tests](../../../../../Tests/MechanicsGeometricConstraintTests/DESIGN.md) | used by | Assembly/failure behavior | Consumer of this component | Upper owns dynamic energy |

## Architecture
```text
strict external chart admission
 -> evaluate + independent original geometry
 -> rank of all tangent rows
 -> A W^-1 A^T solve -> dimensionless tangent correction
 -> path-bound check -> public joint/root manifold retraction
 -> repeat or full-row/rank accepted immutable result
```

## Contracts and Invariants
A local step solves selected rows with positive diagonal tangent metric W and retracts actual SI tangent increments S*delta. Sum sqrt(delta^T W delta) is the reported path correction and must remain within the caller bound before retraction. Every original declared row and the independent full physical axis cross residual must pass, final rank must retain the initial rank; the independent-row representative may change as the chart rotates, and zero rank with nonzero residual fails. Rank ambiguity/redundancy policy is explicit. Initial external quaternion state is validated by the compiled model without normalization; off-norm stage correction belongs to upper evolution. Position assembly preserves v/time/acceleration; the upper owner must subsequently reconcile velocity. Geometric correction has no physical work interpretation and result reports no invented work or stationarity.

## Runtime Flows
Storage and irreversible work are admitted before supplier calls. Each supplier receives a remaining-budget seeded NumericalWork; counters/budget are compared on both success and failure before propagation. Linear API failure has unknown work and terminates. Retraction slices root/joint q/v using public layout and JointMotionEvaluating.integrating(timeStep:1); no qdot=v approximation is made for quaternion charts. Immutable preparation/evaluation/linear/retraction/result phases end before later rich publication temporaries.

## State, Ownership, and Lifecycle
All policies/contexts/results are immutable Sendable; operation-local inout work/buffers have one caller owner. No mutable shared state exists, so Native/WASM/Embedded have identical storage/conformance and no synchronization exceptions.

## Failure, Concurrency, and Constraints
Failures retain actual admitted NumericalWork prefix, last attempted valid position and explicit supplier-work availability. Caller controls maximum iterations, storage/arithmetic, correction and rank/residual tolerances. Supplier ledger reset is rejected even when supplier throws; admission quantum survives. Cancellation is checked around opaque calls and final publication. Unknown failed work is never retried. Prescribed/planar/disconnected domains are rejected by lower admission; no fallback.

## Verification and Change Impact
Tests cover perturbed fourbar assembly, mixed manifold norm preservation, all-row redundancy versus contradiction, toggle/zero-rank, correction/iteration/work capacities, invalid initial quaternion, stale supplier source, successful and failed ledger reset, late cancellation and failed linear work. Changes require future upper endpoint/impulse/energy tests; lower completion does not qualify long-run TI004 or all CN004 domains.
