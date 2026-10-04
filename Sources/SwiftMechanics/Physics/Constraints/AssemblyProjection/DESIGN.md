# AssemblyProjection

## Purpose and Scope
Parent [MechanicsConstraints](../DESIGN.md); no children. Weighted closest-point assembly and admissible speed projection; own rank, redundancy, correction and original residual evidence. Initial CN-004..007/KI-008 closed Euclidean domain. Branch is explicitly caller-selected through initial point; no global branch enumeration, dynamics reactions, mixed graph or long-run integration qualification. Full assigned requirement ownership remains after this initial producer handoff.

## Responsibilities and Boundaries
Own the contracts below. Consumer owns time evolution, rigid binding, force inference and acceptance of persistent state. Immutable query geometry and contributor values have no hidden history.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [Parent](../DESIGN.md) | parent | IM12 dispatch | Initial domain qualification only |
| [CoordinateEquations](../CoordinateEquations/DESIGN.md) | coordinates with | Identified equation/solve boundary | Preserve scale/revision and all rows |
| [Numerics](../../../Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | NumericalWork/typed failures/linear solves | Caller budgets; no backend fallback |
| [Nonlinear](../../../Mathematics/Nonlinear/NonlinearSolve/DESIGN.md) | depends on | Original-residual solve | Square smooth KKT only |
| [Joints](../../../Modeling/Joints/JointManifolds/DESIGN.md) | depends on | Real scalar manifold | Quaternion charts not admitted |
| [Tests](../../../../../Tests/MechanicsConstraintsTests/DESIGN.md) | used by | Behavioral contract proof | Exact paths only |

## Architecture
```text
identified immutable input + caller policy/work
 -> shape/domain/finite admission
 -> actual local equations / numerical operation
 -> independent original residual or port power evidence
 -> immutable result or typed failure
```

## Contracts and Invariants
`ConstraintRankAnalyzing.rank` admits a retained velocity sample and returns the existing scaled two-pass rank evidence directly, without a projection or solver invocation. Nonzero drift and acceleration bias are validated but do not establish feasibility. Rank zero is a valid numerical result when redundancy is allowed; every original row remains the consumer's acceptance responsibility. The operation reserves checked `2*m*n + 3*n + 4*m` scalar-equivalent storage before rank workspace allocation, charges the existing admission/rank loops, and checks cancellation before publication. It uses no nonlinear/linear supplier and changes no state. Consumers requiring reactions must independently establish the original dynamic balance and full retained-row consistency.

Two-pass modified Gram-Schmidt on scaled rows selects independent original row IDs and reports dependent IDs; caller rank threshold and redundancy policy own admission. Assembly minimizes 0.5*(x-x0)ᵀW*(x-x0) locally with selected constraints using square KKT equations and verified Nonlinear. Tangent contains W+sum(mu*H), Jᵀ/J, zero multiplier block; final all original rows and stationarity must pass independent acceptance. This is a local stationary closest-point candidate, not certified global minimum. Root selection is seeded; no force result is fabricated. Velocity projection solves selected A*W^-1*Aᵀ lambda=A*u+b via verified Cholesky, uNext=u-W^-1*Aᵀlambda, then checks every original row, including redundancy. Correction metric W is positive dimensionless diagonal supplied by caller. Velocity energy change=energyScale/2*(uNextᵀW*uNext-uᵀW*u); this has mechanical kinetic meaning only when caller supplies physical energy metric provenance. Assembly objective/correction are geometric, no physical introduced work is available without a velocity/energy port. Reaction ambiguity m-rank is reported; uniqueness of geometric correction does not certify dynamic reaction uniqueness.

## Runtime Flows
Admission precedes traversal and allocation; bounded local phases keep compiler fixed stack frames separate. Final cancellation check precedes publication. Failed suppliers stop immediately; no retry or substitution.

## State, Ownership, and Lifecycle
Immutable Sendable inputs/results; exclusive inout NumericalWork and operation-local arrays. Borrow caller arrays and retain them through value ownership; output arrays allocate once per operation. Internal KKT scalar evaluation writes supplier-owned poisoned output directly, without per-iteration equation arrays. No shared mutable state, target branches or unsafe pointers.

## Failure, Concurrency, and Constraints
Caller maximum coordinate/row/fill capacities, domain/correction/rank/residual tolerances and numerical policies own admission. Logical loops/scalar arithmetic charge NumericalWork before work; each trigonometric invocation is one declared primitive unit, not a guessed floating arithmetic expansion. Separate outer, nonlinear and linear ledgers retain actual supplier work; nonlinear failure includes its last iterate/residual and work, while failed linear partial work is unavailable and execution halts. Constructor shape checks are constant-time; full array validation is operation-budgeted. All successful output entries are finite, original acceptance is independent of supplier stopping tolerance.

## Verification and Change Impact
Time-dependent polynomial derivatives, loop roots, weighted assembly/projection and full-row redundancy/contradiction, knife-edge acceleration terms, geometric correction and kinetic-energy reporting, passive/limit energy and dissipation, shape/domain/capacity/rank/correction/nonfinite/budget/cancellation/supplier failures. Changed equations, units or failure/resource contracts invalidate the direct constraint evolution/transmission/operating-point consumers and root profiles.

The additive rank operation passed four new Native behavioral cases, all nineteen Constraints cases and the 346-case registered composition. The original Native/WASM/Embedded public probe invokes the required standalone rank protocol on actual evaluated retained rows and verifies dependence/nullity. Existing projection/assembly acceptance remains separately exercised; rank does not certify reactions.
