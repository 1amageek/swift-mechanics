# CoordinateEquations

## Purpose and Scope
Parent [MechanicsConstraints](../DESIGN.md); no children. Identified bounded Euclidean charts and smooth quadratic holonomic equations, affine velocity rows and a planar knife-edge nonintegrable constraint. Initial CN-001/002/003 and explicit polynomial distance/plane query domain for KI-006/007. No general CAD/query callback, quaternion chart, discontinuity interpolation or mixed articulated/maximal graph qualification. Full assigned requirement ownership remains after this initial producer handoff.

## Responsibilities and Boundaries
Own the contracts below. Consumer owns time evolution, rigid binding, force inference and acceptance of persistent state. Immutable query geometry and contributor values have no hidden history.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [Parent](../DESIGN.md) | parent | IM12 dispatch | Initial domain qualification only |
| [AssemblyProjection](../AssemblyProjection/DESIGN.md) | coordinates with | Identified equation/solve boundary | Preserve scale/revision and all rows |
| [C math](../../../Mathematics/ScalarFunctions/DESIGN.md) | depends on | Bounded libm sine/cosine calls | Same verified ABI on each target |
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
Layout identifies UInt64 coordinate IDs, revision, physical coordinate dimensions, positive SI coordinate scales S and time scale T. Input q/v/time use SI; x=q/S, u=v*T/S, tau=time/T. Holonomic values g and rows Jx, gtau and accelerationBias are dimensionless; physical derivatives follow dg/dt=(Jx*u+gtau)/T, d²g/dt²=(Jx*(a*T²/S)+bias)/T². Each quadratic row is c+a*x+0.5*xᵀH*x+b*tau+0.5*d*tau²+tau*e*x, with symmetric H. Bias=uᵀH*u+2*e*u+d. Caller bounds positions/time and capacity before traversal. Affine speed samples retain every identified row A*u+b=0. Knife edge x/y share length scale, theta is an angle; A=(-sin(theta),cos(theta),0), bias=-thetaRate*(cos(theta)*xRate+sin(theta)*yRate), declared nonintegrable. All coordinates and derivatives remain identified and finite.

## Runtime Flows
Admission precedes traversal and allocation; bounded local phases keep compiler fixed stack frames separate. Final cancellation check precedes publication. Failed suppliers stop immediately; no retry or substitution.

## State, Ownership, and Lifecycle
Immutable Sendable inputs/results; exclusive inout NumericalWork and operation-local arrays. Borrow caller arrays and retain them through value ownership; output arrays allocate once per operation. Internal KKT scalar evaluation writes supplier-owned poisoned output directly, without per-iteration equation arrays. No shared mutable state, target branches or unsafe pointers.

## Failure, Concurrency, and Constraints
Caller maximum coordinate/row/fill capacities, domain/correction/rank/residual tolerances and numerical policies own admission. Logical loops/scalar arithmetic charge NumericalWork before work; each trigonometric invocation is one declared primitive unit, not a guessed floating arithmetic expansion. Separate outer, nonlinear and linear ledgers retain actual supplier work; nonlinear failure includes its last iterate/residual and work, while failed linear partial work is unavailable and execution halts. Constructor shape checks are constant-time; full array validation is operation-budgeted. All successful output entries are finite, original acceptance is independent of supplier stopping tolerance.

## Verification and Change Impact
Time-dependent polynomial derivatives, loop roots, weighted assembly/projection and full-row redundancy/contradiction, knife-edge acceleration terms, geometric correction and kinetic-energy reporting, passive/limit energy and dissipation, shape/domain/capacity/rank/correction/nonfinite/budget/cancellation/supplier failures. Changed equations, units or failure/resource contracts invalidate the direct constraint evolution/transmission/operating-point consumers and root profiles.
