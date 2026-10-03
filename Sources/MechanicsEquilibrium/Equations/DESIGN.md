# Identified smooth SI static equations
## Purpose and Scope
Parent [Equilibrium](../DESIGN.md). Children: none. Initial admitted implementation domain; behavioral/profile qualification pending. IM17/ST-001..004/ST-008 full requirement ownership persists.
## Responsibilities and Boundaries
Owns bounded immutable coordinate/parameter identity, scales, closed coordinate/load domains and two actual conservative models: separable linear/cubic spring with caller constant/load-direction force, and selected one-coordinate pendulum potential. No arbitrary unimplemented callback is declared. Required force evaluator operations expose original physical gradient, tangent, parameter derivative and energy; immutable provider must preserve descriptor identity and calibrated meaning. The spring gradient is a_i*q_i+b_i*q_i^3-c_i-p*l_i; tangent diagonal a_i+3*b_i*q_i^2; potential sum(a_i*q_i^2/2+b_i*q_i^4/4-c_i*q_i-p*l_i*q_i). Pendulum gradient G*sin(theta)-p*T, tangent G*cos(theta), potential G*(1-cos(theta))-p*T*theta. G=m*g*l in Nm, T in Nm; q radians. Closed finite domains are caller authority, not a promise of stable/unique/global equilibrium.
## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Equilibrium](../DESIGN.md) | parent | dispatch/ownership | composition | root owns module index |
| [Nonlinear](../../MechanicsNonlinear/DESIGN.md) | depends on | original residual solve | bounded numerical candidates | no stability inference |
| [Constraints](../../MechanicsConstraints/DESIGN.md) | depends on | affine retained rows/rank | physical geometry authority | no inferred reactions |
| [Dynamics](../../MechanicsDynamics/DESIGN.md) | depends on | original inertial action/mass | operating mass authority | no force tangent API supplied |
## Architecture
```text
identified SI model + normalized coordinate -> actual smooth original force/tangent/energy -> scaled numerical adapter
```
## Contracts and Invariants
Coordinates have unique UInt64 IDs, explicit Core dimensions length/angle, positive SI scales S, revision/model stamp, frame EntityID, compiler joint EntityID bindings and identity. Energy scale E>0 normalizes force balance S_i*gradient_i/E. Parameter has identity, dimension and closed bounds; builtin models use a dimensionless load multiplier. Provider scalar methods accept a normalized point prefix of coordinateCount; trailing reaction slots are excluded from force semantics. All model arrays are bounded before traversal, and all numeric callbacks consume NumericalWork. No gravity is inferred from geometry.
## State, Ownership, and Lifecycle
Inputs/providers/results/history are immutable Sendable. Work and local workspace are exclusively caller/operation owned, reused in iteration. No global cache, target conditional storage, unchecked isolation or hidden branch mutation. Required protocol witnesses are used across targets. Returned arrays own their storage; no escaped pointer/view.
## Failure, Concurrency, and Constraints
Caller bounds coordinates/rows/cases/metadata/storage/work before traversal/allocation. Nonfinite/stale/chart/domain/branch/rank/original-balance/derivative/reduction failures and cancellation are typed. Numerical/callback/constraint/dynamics work remains identified; failed unreported supplier work is explicit and disallows retry. Float64 reference CPU and explicit LU/Cholesky capability are admitted; no backend fallback. Bounded phase functions keep Embedded stack use local; no custom stack profile.
## Verification and Change Impact
[Test owner](../../../Tests/MechanicsEquilibriumTests/DESIGN.md) owns analytic spring/hanging load, branch loading/unloading, ambiguity, original directional pendulum/constrained derivatives and mixed sweep failures. Root owns selected Native/WASM/Embedded integration. Changes to force/chart/row/mass/basis or continuation identity invalidate dependent analyses.
