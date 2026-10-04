# Linear beam and nonlinear truss buckling

## Purpose and Scope
Own conservative beam linear buckling load pencil and exact-geometry symmetric two-bar snap-through continuation. Parent ../DESIGN.md; no children. Initial admitted implementation domain; selected behavioral/profile evidence is recorded by the parent composition index.

## Responsibilities and Boundaries
Own the stated physical/numerical operations and immutable result evidence. Runtime evolution, accepted events, geometry generation, producer source changes and whole-target qualification belong to other owners. Public callable operations are protocol requirements.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Parent](../DESIGN.md) | parent | IM28 dispatch | Scope and registration | No execution qualification yet |
| [PhysicalModels](../PhysicalModels/DESIGN.md) | depends on | Identified physical pencils and finite complex values | Admission/value authority | Binding and original equations remain required |
| [Numerics](../../../Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | NumericalWork, budgets, linear solve | Explicit bounded computation | Failed nested work may be unavailable |
| [Flexible](../../../Physics/Flexible/Tetrahedra/DESIGN.md) | depends on | Actual mass/tangent assembly | Physical nodal producer | Tet4 does not certify beams |
| [Equilibrium](../../Equilibrium/Linearization/DESIGN.md) | depends on | Actual reduced pencil | Operating point authority | Supplied reduction only |
| [Tests](../../../../../Tests/MechanicsStructuralAnalysisTests/DESIGN.md) | used by | Behavioral oracles | Local proof ownership | Root owns exact profiles |

## Architecture
```text
physical identified input -> admission/budget -> local owned workspace
 -> original mechanical equation checks -> immutable result or typed failure
```

## Contracts and Invariants
Linear beam generalized problem K0 phi=P G phi uses assembled Hermite elastic/geometric operators, explicit homogeneous boundaries and original residual, P in N. Semidefinite G is not silently inverted; selected retained beam boundary domain has positive definite G, other domains fail. Lowest positive load is a linearized bifurcation threshold only. Nonlinear model: two identical pin-ended axial Hooke bars between fixed supports (+/-a,0) and vertically guided apex (0,y), natural length l0=sqrt(a^2+h^2), U=EA/l0*(sqrt(a^2+y^2)-l0)^2. Downward P(y)=-dU/dy, tangent d2U/dy2=2EA/l0*(1-l0*a^2/l^3). The guide explicitly removes horizontal perturbations; classification concerns the remaining vertical coordinate only. Displacement control preserves caller ordered y branch, evaluates original force/energy/tangent and declares positive/zero/negative local vertical tangent. Bisection brackets tangent zero between physical samples with original force/tangent checks and bounded work; a real critical load/limit point is distinct from convergence failure. Horizontal/symmetry-breaking modes, material plastic buckling, nonlinear beam continuum and arbitrary element postbuckling are not qualified; callable unsupported requests carry markers and fail.

## State, Ownership, and Lifecycle
All input/law/binding/result values are immutable Sendable. Per-call arrays and exclusive inout NumericalWork have one caller owner and no shared cache. Inputs remain unchanged on success/failure. Native/WASM/Embedded use identical storage/conformance and no conditional isolation. Cancellation callback is immutable @Sendable context; callers own its lifetime and any shared mutation through the same Mutex/actor on all targets. No unsafe buffers. Retained input/output arrays count in declared conservative peak reserve; caller separately budgets aggregate results retained across calls. Metadata bytes and coordinate count are admitted before allocation/traversal.

## Failure, Concurrency, and Constraints
Caller controls maximum coordinates/metadata, arithmetic/storage/iterations, positive-mass/spectral/original residual tolerances and cancellation. Checked sizes precede allocation, scalar finite checks precede publication. Each bounded row/iteration polls cancellation. No guessed cap, hidden backend or success on iteration exhaustion. Failed nested linear work is explicitly unavailable and caller must not continue under a fabricated remaining budget.

## Verification and Change Impact
Euler pinned column mesh refinement from assembled G; nonlinear truss independent force/energy directional derivatives, analytic limit-point oracle and both sides of tangent sign; reversed branch ordering, strain envelope, no bracket, iteration/cancel limits and unchanged immutable input. Changes in equations, scaling, boundary/binding or residual authority invalidate this child and dependent root structural probes; unchanged supplier evidence is reused.
