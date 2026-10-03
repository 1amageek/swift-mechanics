# Complementarity problem records

## Purpose and Scope
Parent: [MechanicsComplementarity](../DESIGN.md). Owns dimensionless numerical QP/LCP input, cone/law/layout identity, acceptance policy and immutable optional continuation records for SO-004/005. Children: none.

## Responsibilities and Boundaries
The mathematical problem is min 0.5 xᵀAx+bᵀx over K. Orthant K gives the frictionless LCP x>=0,w=Ax+b>=0,x_i w_i=0. Circular cone blocks use coordinates (normal,tangent1,tangent2), ||t||<=μn, μ>=0; their dual requires w_n>=μ||w_t||. This is the associated convex cone problem, including normal dilation coupling. Non-associated Signorini/Coulomb physics is explicitly unsupported. IM21 owns contact law/geometry/physical unit mapping. Admitted A is finite and exactly symmetric positive definite under the caller-selected Cholesky pivot threshold. The verified Numerics Cholesky solver performs a budgeted zero-RHS admission preflight, including for initially accepted iterates. No general nonsymmetric LCP claim is made.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Module](../DESIGN.md) | parent | SO numerical scope | Composition | Physical contact remains separate |
| [Numerics linear algebra](../../MechanicsNumerics/LinearAlgebra/DESIGN.md) | depends on | DenseMatrix<Double>, NumericalBudget/Work/Termination | Storage and numerical records | Float64 referenceCPU only |
| [Projection](../Projection/DESIGN.md) | used by | ConeLayout | Numeric domain | Coordinate order is canonical |
| [Solve](../Solve/DESIGN.md) | used by | Problem, policies and cache | Acceptance authority | Cache is optional |

## Architecture
```text
(A,b,cone,semanticIdentity) -> ComplementarityProblem
(frozen scales,4 absolute bounds,relative bound,max iterations,budget) -> Solve policy
(exact problem,iterate,inverse row bound) -> caller-owned cache/restart value
```

## Contracts and Invariants
Problem inputs are immutable Sendable. Identity includes revision, ordered unique coordinate IDs, frame/layout revision and law revision; callers increment affected revisions whenever coordinate meaning/basis or law semantics change. Cache retains exact A,b,cone and identity in addition to iterate and scalar row-bound preconditioner. Cache use checks all of them, including preconditioner equality with recomputed bound. Explicit restart construction rejects invalid iterate dimensions/nonfinite values and invalid step. There is no hidden cache, normalization substitution or foreign engine. Backend and precision are selected explicitly and unsupported selections fail.

Acceptance uses frozen caller reference scales: primal/optimality thresholds absolute+relative*primalScale; dual absolute+relative*dualScale; complementarity absolute+relative*primalScale*dualScale. All scales are finite positive; bounds finite nonnegative. No candidate-dependent inflation is permitted. Problem construction owns input-sized value storage; solve accounts retained input/cache and workspaces before allocating its local arrays, with checked integer size arithmetic. Input construction and external serialization are caller responsibilities.

## State, Ownership, and Lifecycle
All records own arrays by Swift value semantics. Cache creation/restoration takes owned values; no borrowed pointer escapes. Accepted continuation is an explicit result cache; failed/cancelled trials cannot mutate caller input. Runtime checkpoint lifecycle remains IM08/24. No shared mutable state or platform-specific storage/conformance exists.

## Failure, Concurrency, and Constraints
Invalid dimensions, nonfinite input, law/matrix/capability rejection, stale cache, invalid restart and numerical policy failures are typed. NumericalError and NumericalTermination are reused, with domain-specific errors mapped to their semantic termination. No guessed capacity/iteration cap is installed.

## Verification and Change Impact
[Tests](../../../Tests/MechanicsComplementarityTests) use independent manufactured orthant/cone optima, indefinite/nonsymmetric matrices, incompatible layout and stale revisions/basis/law/A/b/preconditioner. Cold/warm/replay must meet identical original acceptance. Changing records rechecks projection/solve and future IM21/24 consumers. Root owns exact platform composition.
