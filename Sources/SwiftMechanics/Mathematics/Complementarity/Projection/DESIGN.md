# Circular cone projection

## Purpose and Scope
Parent: [MechanicsComplementarity](../DESIGN.md). Owns Euclidean projection and primal/dual feasibility violation for the admitted orthant/product circular cones. Children: none.

## Responsibilities and Boundaries
Orthant projection is max(x,0). For cone input (n,t), r=||t||: retain if n>=0,r<=μn; zero if n+μr<=0; otherwise n'=(n+μr)/(1+μ²),t'=μn' t/r. μ=0 is the normal ray and tangential components project to zero. Associated cone equations belong to Problem; convergence and acceptance belong to Solve.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Module](../DESIGN.md) | parent | Component boundary | Composition | No physical law substitution |
| [Problem](../Problem/DESIGN.md) | depends on | ConeLayout and errors | Input meaning | Tangent coordinate basis identity is caller owned |
| [Solve](../Solve/DESIGN.md) | used by | Projection/violation protocol requirements | Iteration and original residual | Caller owns workspace |

## Architecture
```text
input + ConeLayout -> ReferenceConeProjector -> existing output buffer
input + primal/dual selector -> original cone violation scalar
```

## Contracts and Invariants
Projection services declare callable requirements, accept exclusively caller-owned output and NumericalWork, and retain nothing. Orthant violation is max_i(-x_i,0). Cone primal violation max(-n,r-μn,0), dual violation max(μr-n,0). Zero violation is equivalent to membership; finite tolerance has these published coordinate meanings. Stable scaled two-component norm avoids squaring huge/tiny coordinates directly. Arithmetic overflow is rejected rather than clamped. Each pass is O(n); no arrays, intermediate collections or size-dependent allocation is created inside projection/violation. Work charges a conservative scalar arithmetic/comparison bound before each block and cancellation is observed before every pass and block.

## State, Ownership, and Lifecycle
ReferenceConeProjector is an immutable stateless Sendable service. Input, output and work are caller-owned values; output is usable only after successful projection, with no transactional partial-output promise for this low-level operation. Solver owns and discards any partial workspace on failure. No pointer, shared mutation or target conditional is present.

## Failure, Concurrency, and Constraints
Wrong buffer dimension, nonfinite input/law, overflow, cancellation and arithmetic budget exhaustion fail explicitly. Cone coefficients require μ>=0 and finite 1+μ²; this is an arithmetic admitted domain, not an empirical friction cap.

## Verification and Change Impact
[ProjectionTests](../../../../../Tests/MechanicsComplementarityTests/ProjectionTests.swift) checks interior/polar/boundary and μ=0 projection, independent distance/KKT normal direction, primal/dual membership and finite overflow/domain/budget failures. Frozen absolute 1e-12+relative 1e-11 for small dimensionless fixtures. Changes recheck solver original residual and iteration; geometry/contact consumers remain unverified.
