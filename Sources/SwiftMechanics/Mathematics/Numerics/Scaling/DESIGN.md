# Equation scaling and perturbation

## Purpose and Scope

Parent: [MechanicsNumerics](../DESIGN.md). Owns explicit dimensional scaling and bounded diagonal regularization for IM03 SO-006.

## Responsibilities and Boundaries

Owns positive SI dimension-labelled row and column reference quantities, nondimensional equation transformation/recovery and perturbation evidence. Caller owns physical dimension assignment and whether the altered model is acceptable. This component never silently applies scaling or regularization.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Core Units](../../Core/Units/DESIGN.md) | depends on | PhysicalDimension | dimension identities | scales are SI quantities |
| [Linear algebra](../LinearAlgebra/DESIGN.md) | depends on | DenseMatrix and residual evidence | equation storage/acceptance | original equations stay authoritative |

## Architecture

```mermaid
flowchart LR
  Original[A*x = b] --> Scale[Ahat_ij = A_ij*c_j/r_i; bhat_i=b_i/r_i]
  Scale --> Recover[x_j=c_j*xhat_j]
  Original --> Perturb[Areg=A+diag(delta)]
  Perturb --> Evidence[delta norm; delta*x; original residual]
```

## Contracts and Invariants

Row reference r_i has the physical dimension of b_i; column reference c_j has the dimension of x_j. Records derive each matrix coefficient dimension from the row/column pair and preserve those labels. Values are positive finite SI magnitudes. Ahat and bhat are dimensionless and recovery restores original unknown magnitudes. Diagonal regularization supplies one explicit SI coefficient per coordinate, carrying the derived row/column coefficient dimension; mismatches fail. Each nonnegative coefficient perturbation is bounded by a caller-selected positive SI magnitude with the same coefficient dimension. The output reports every dimensional delta, the maximum dimensionless fraction of its corresponding bound, and evaluated original residual and dimensional model effect diag(delta)*x. No perturbation norm compares different physical dimensions. The effect report scalar residual norm admits a common equation dimension only; heterogeneous equation dimensions are rejected and must be nondimensionalized before a shared scalar residual policy is meaningful. Success of an altered solve never asserts that the original equation is satisfied. Bounds and all arithmetic must stay finite.

## State, Ownership, and Lifecycle

Immutable Sendable value records own COW arrays. Every solve owns its mutable workspace and returns owned arrays; no shared mutable caches, global state, unsafe pointers, or platform-dependent isolation are used. Matrix input ownership lasts through the synchronous operation. Cancellation is checked at bounded iteration/factorization safe points.

## Failure, Concurrency, and Constraints

Invalid dimensions, nonfinite inputs/results, numerical rank loss, nonpositive curvature/pivots, unsupported capability, cancellation and exhausted caller budgets are typed failures. No fallback changes precision, backend or algorithm. Checked products precede allocation; conservative simultaneous scalar workspace and arithmetic work are charged before use. The caller chooses resource limits and tolerances. Independent calls share no mutable state.

## Verification and Change Impact

[Test owner](../../../../../Tests/MechanicsNumericsTests) uses mixed mass/length units and SI magnitudes, recovers the known solution and checks dimension mismatch/invalid scales. A rank-deficient original matrix is solved with an explicitly allowed diagonal perturbation, and the nonzero original residual matches the reported model effect. Exceeding policy fails. Consumers must review changed dimensional or perturbation semantics.
