# ProblemContracts

## Purpose and Scope
Parent [module](../DESIGN.md); no children. Own normalized finite-box affine LP/strictly convex affine QP input, physical normalization metadata, original certificate/status meanings and caller resource policy. Selected initial convex domain qualified; execution evidence and its platform scope are owned by the [parent evidence record](../DESIGN.md#selected-af18-qualification). Full OP-004/009 remains open.

## Responsibilities and Boundaries
Immutable records and required OptimizationSolving operation. Cost/constraints are original dimensionless normalized coefficients, supplied from caller physical model. No nonlinear callback, identification, runtime command or physical reaction claim in this handoff. Infinite boxes/general indefinite or semidefinite QP are unavailable; no inferred global nonlinear result.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [Numerics](../../MechanicsNumerics/DESIGN.md) | depends on | Dense/CSR immutable coefficients, SIReferenceQuantity, NumericalWork | Work/precision/backend remain caller-owned |
| [ConvexPrograms](../ConvexPrograms/DESIGN.md) | used by | Real enumeration/certification | Dense KKT fill is explicit |
| [Tests](../../../Tests/MechanicsOptimizationTests/DESIGN.md) | used by | Independent original equations | Root owns execution |

## Architecture
```text
physical references + normalized original problem -> required solve -> certificate/status or typed failure
```

## Contracts and Invariants
Original objective f=constant+c^T*x+.5*x^T*H*x, E*x=b, A*x<=d, lower<=x<=upper. H absent means LP; present H must be symmetric strictly positive definite. Sparse affine derivatives are accepted as CSR; selected reference method materializes explicitly budgeted dense KKT, not a sparse backend. Positive SI variable/cost/row reference quantities and identified variable IDs/source/revision accompany normalized coefficients; returned physical point is variableReference*x and physical objective=costReference*f. Multipliers are normalized mathematical conjugates; physical row multiplier=costReference/rowReference*lambda with corresponding dimensional meaning, not a dynamic reaction.
Optimal means original primal feasibility, nonnegative inequality/bound duals, stationarity and complementarity accepted under separate original primal/dual/stationarity/complementarity scales with caller absolute/relative dimensionless tolerances AND admitted convexity. Strict QP uniqueness follows qualified SPD curvature; LP uniqueness is not established. Infeasible requires independently accepted Farkas certificate against ORIGINAL equalities, inequalities and box rows after complete original basis processing; no-feasible candidate alone is insufficient. Resource, rank uncertainty and nonconvergence never become infeasible. Unbounded selected family is not published in this handoff.

## State, Ownership, and Lifecycle
Immutable Sendable models/results. NumericalWork and EnumerationWorkspace are exclusive inout; no shared mutable state or target-conditioned conformance. Input CSR/scalar arrays borrowed through retained immutable owners; scalar buffers reused for each candidate. Immutable output copies have declared bounded publication purpose.

## Failure, Concurrency, and Constraints
Typed OptimizationFailure retains phase, underlying cause, known work/candidate count, last assessed feasibility residual, explicit original/phase-I problem identity, and unavailable failed supplier work. Phase-I residuals cannot be presented as original-problem feasibility. Logical initialized/COW scalar slots and row/variable/nonzero/fill/candidate capacities checked before allocation. UTF8 metadata traversal is charged before equality; no guessed operational caps. Callback-free initial domain; late cancellation prevents publication. Root retains all builds/commits.

## Verification and Change Impact
LP/QP analytic optima and original dual signs, physical reference scaling, tied LP, equality rank rejection, Farkas infeasible, budget/cancellation, actual failed linear supplier and invalid returned ledger/residual. Future nonlinear/estimation changes must use this fixed status/certificate authority, without broadening its guarantee.
