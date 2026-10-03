# Symmetric mechanical pencils

## Purpose and Scope
Own Float64/reference CPU mass-whitened symmetric modal eigensolve and Rayleigh damped modal poles. PhysicalModels owns physically admitted pencil creation. Parent ../DESIGN.md; no children. Initial admitted implementation domain; selected behavioral/profile evidence is recorded by the parent composition index.

## Responsibilities and Boundaries
Own the stated physical/numerical operations and immutable result evidence. Runtime evolution, accepted events, geometry generation, producer source changes and whole-target qualification belong to other owners. Public callable operations are protocol requirements.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Parent](../DESIGN.md) | parent | IM28 dispatch | Scope and registration | No execution qualification yet |
| [PhysicalModels](../PhysicalModels/DESIGN.md) | depends on | Identified physical pencils and finite complex values | Admission/value authority | Binding and original equations remain required |
| [Numerics](../../MechanicsNumerics/LinearAlgebra/DESIGN.md) | depends on | NumericalWork, budgets, linear solve | Explicit bounded computation | Failed nested work may be unavailable |
| [Flexible](../../MechanicsFlexible/Tetrahedra/DESIGN.md) | depends on | Actual mass/tangent assembly | Physical nodal producer | Tet4 does not certify beams |
| [Equilibrium](../../MechanicsEquilibrium/Linearization/DESIGN.md) | depends on | Actual reduced pencil | Operating point authority | Supplied reduction only |
| [Tests](../../../Tests/MechanicsStructuralAnalysisTests/DESIGN.md) | used by | Behavioral oracles | Local proof ownership | Root owns exact profiles |

## Architecture
```text
physical identified input -> admission/budget -> local owned workspace
 -> original mechanical equation checks -> immutable result or typed failure
```

## Contracts and Invariants
M must be positive definite after explicit boundary reduction. K and C finite symmetric; exact symmetry admission (source roundoff must be corrected by its owner). Caller coordinate scales, energy and time scales normalize mixed-unit pencils before Jacobi diagonalization. Maximum-pivot Jacobi uses bounded iterations and owned arrays reused per rotation. Mass eigenvalues below caller positive threshold fail; no regularization. Every published phi satisfies original K phi=lambda M phi and phi^T M phi=1, pairwise M orthogonality and complete retained n-mode accounting. lambda has s^-2; stable oscillatory, neutral within caller threshold, and negative/unstable classifications are separate. No global nonlinear stability/uniqueness claim. Rayleigh damped poles require original C=alpha M+beta K, nonnegative alpha/beta and positive modal lambda; publish two complex roots and verify original quadratic action, including real overdamped and repeated critical roots. Nonproportional damped eigenanalysis is callable typed unsupported with an incomplete marker.

## State, Ownership, and Lifecycle
All input/law/binding/result values are immutable Sendable. Per-call arrays and exclusive inout NumericalWork have one caller owner and no shared cache. Inputs remain unchanged on success/failure. Native/WASM/Embedded use identical storage/conformance and no conditional isolation. Cancellation callback is immutable @Sendable context; callers own its lifetime and any shared mutation through the same Mutex/actor on all targets. No unsafe buffers. Retained input/output arrays count in declared conservative peak reserve; caller separately budgets aggregate results retained across calls. Metadata bytes and coordinate count are admitted before allocation/traversal.

## Failure, Concurrency, and Constraints
Caller controls maximum coordinates/metadata, arithmetic/storage/iterations, positive-mass/spectral/original residual tolerances and cancellation. Checked sizes precede allocation, scalar finite checks precede publication. Each bounded row/iteration polls cancellation. No guessed cap, hidden backend or success on iteration exhaustion. Failed nested linear work is explicitly unavailable and caller must not continue under a fabricated remaining budget.

## Verification and Change Impact
Beam frequencies/refinement, zero modes, compressed negative modes, original pencil and orthogonality; analytic under/critical/over damped poles; invalid mass, residual rejection, insufficient iterations, stale and cancellation. Changes in equations, scaling, boundary/binding or residual authority invalidate this child and dependent root structural probes; unchanged supplier evidence is reused.
