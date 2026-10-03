# ScalarJointPorts

## Purpose and Scope
Parent [MechanicsConstraints](../DESIGN.md); no children. One-coordinate revolute/prismatic passive spring/damper/Coulomb constitutive ports and two-sided limit rows or finite compliant penalty. Initial JT-005/006; downstream dynamics/evolution owns activation/reaction/impact integration. Full assigned requirement ownership remains after this initial producer handoff.

## Responsibilities and Boundaries
Own the contracts below. Consumer owns time evolution, rigid binding, force inference and acceptance of persistent state. Immutable query geometry and contributor values have no hidden history.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [Parent](../DESIGN.md) | parent | IM12 dispatch | Initial domain qualification only |
| [AssemblyProjection](../AssemblyProjection/DESIGN.md) | coordinates with | Identified equation/solve boundary | Preserve scale/revision and all rows |
| [Numerics](../../MechanicsNumerics/LinearAlgebra/DESIGN.md) | depends on | NumericalWork/typed failures/linear solves | Caller budgets; no backend fallback |
| [Nonlinear](../../MechanicsNonlinear/NonlinearSolve/DESIGN.md) | depends on | Original-residual solve | Square smooth KKT only |
| [Joints](../../MechanicsJoints/JointManifolds/DESIGN.md) | depends on | Real scalar manifold | Quaternion charts not admitted |
| [Tests](../../../Tests/MechanicsConstraintsTests/DESIGN.md) | used by | Behavioral contract proof | Exact paths only |

## Architecture
```text
identified immutable input + caller policy/work
 -> shape/domain/finite admission
 -> actual local equations / numerical operation
 -> independent original residual or port power evidence
 -> immutable result or typed failure
```

## Contracts and Invariants
Actual JointManifold must have matching scalar revolute/prismatic q-v chart. Position/rate and conjugate effort use SI length/linear force or angle/torque; angular coordinates are explicitly unwrapped. Spring force=-k*(q-qref), potential=k*(q-qref)²/2; damper=-c*v, dissipative power=-c*v². Sliding Coulomb=-f*sign(v), power=-f*abs(v). At zero speed friction is a set-valued interval [-f,f], with no fabricated selected static effort. Limits expose lower gap q-lower, upper gap upper-q and derivatives ±1. Compliant limit contact admitted only for penetration: compressive k*(-gap)+c*max(-gapRate,0), equal sign mapping; potential k*penetration²/2 and nonpositive damping power. Hard unilateral limits expose rows only, no inferred reaction. Restitution/impact and periodic wrap have explicit unsupported failures; no fallback.

## Runtime Flows
Admission precedes traversal and allocation; bounded local phases keep compiler fixed stack frames separate. Final cancellation check precedes publication. Failed suppliers stop immediately; no retry or substitution.

## State, Ownership, and Lifecycle
Immutable Sendable inputs/results; exclusive inout NumericalWork and operation-local arrays. Borrow caller arrays and retain them through value ownership; output arrays allocate once per operation. Internal KKT scalar evaluation writes supplier-owned poisoned output directly, without per-iteration equation arrays. No shared mutable state, target branches or unsafe pointers.

## Failure, Concurrency, and Constraints
Caller maximum coordinate/row/fill capacities, domain/correction/rank/residual tolerances and numerical policies own admission. Logical loops/scalar arithmetic charge NumericalWork before work; each trigonometric invocation is one declared primitive unit, not a guessed floating arithmetic expansion. Separate outer, nonlinear and linear ledgers retain actual supplier work; nonlinear failure includes its last iterate/residual and work, while failed linear partial work is unavailable and execution halts. Constructor shape checks are constant-time; full array validation is operation-budgeted. All successful output entries are finite, original acceptance is independent of supplier stopping tolerance.

## Verification and Change Impact
Time-dependent polynomial derivatives, loop roots, weighted assembly/projection and full-row redundancy/contradiction, knife-edge acceleration terms, geometric correction and kinetic-energy reporting, passive/limit energy and dissipation, shape/domain/capacity/rank/correction/nonfinite/budget/cancellation/supplier failures. Changed equations, units or failure/resource contracts invalidate the direct constraint evolution/transmission/operating-point consumers and root profiles.
