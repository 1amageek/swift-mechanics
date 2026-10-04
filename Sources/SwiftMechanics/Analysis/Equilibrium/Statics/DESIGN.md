# Original-balance static solve
## Purpose and Scope
Parent [Equilibrium](../DESIGN.md). Children: none. Initial admitted implementation domain; behavioral/profile qualification pending. IM17/ST-001..004/ST-008 full requirement ownership persists.
## Responsibilities and Boundaries
Owns dimensionless KKT construction, actual producer rank/feasible seed for retained affine time-independent constraints, independent physical final acceptance and reaction ambiguity. Constraints must share IDs/dimensions/scales/revision with force chart. Non-affine/moving/contact constraints are callable admission failures with incomplete markers; no inactive contact inference. Actual ConstraintAssembling establishes independent rows, with all retained rows checked before and after solve. Reaction policy forbids ambiguity or explicitly picks the independent-row representative with dependent multipliers zero. This is not minimum-norm or unique physical support allocation.
## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Equilibrium](../DESIGN.md) | parent | dispatch/ownership | composition | root owns module index |
| [Nonlinear](../../../Mathematics/Nonlinear/DESIGN.md) | depends on | original residual solve | bounded numerical candidates | no stability inference |
| [Constraints](../../../Physics/Constraints/DESIGN.md) | depends on | affine retained rows/rank | physical geometry authority | no inferred reactions |
| [Dynamics](../../../Physics/Dynamics/DESIGN.md) | depends on | original inertial action/mass | operating mass authority | no force tangent API supplied |
## Architecture
```text
seed + caller branch box -> actual affine constraint assembly/rank -> generic-scalar KKT -> Nonlinear solve -> original force + every retained row + rank recheck -> accepted stationary point
```
## Contracts and Invariants
KKT is S_i*gradient_i/E + sum J_ri*mu_r=0 and selected g_r=0. Physical generalized reaction applied to body is -E/S_i*sum J_ri*mu_r; balance gradient+E/S_i*sum J_ri*mu_r=0. Report multipliers for every original row, dependent lambda zero, generalized reaction and reactionNullity. Numerical acceptance never establishes stability, uniqueness or closest equilibrium. Final physical acceptance has independently selected force-per-coordinate and constraint residual tolerances. Failed supplier work marked unavailable stops without retry. ConstraintAssembling failures other than published nonlinear failures may occur after a successful hidden nested solve; their unavailable nested work is conservatively explicit and terminates sweeps. Rank may not change inside accepted assembly branch. StaticConstraints carries a caller response NumericalBudget; response and nested nonlinear budget caps are split from remaining enclosing work before invocation. Simultaneous storage caps are reserved before allocation and actual known work is absorbed once; final evaluator work is similarly bounded. Identifier limits are per identifier, coordinate/row/case limits bound their count.
## State, Ownership, and Lifecycle
Inputs/providers/results/history are immutable Sendable. Work and local workspace are exclusively caller/operation owned, reused in iteration. No global cache, target conditional storage, unchecked isolation or hidden branch mutation. Required protocol witnesses are used across targets. Returned arrays own their storage; no escaped pointer/view.
## Failure, Concurrency, and Constraints
Caller bounds coordinates/rows/cases/metadata/storage/work before traversal/allocation. Nonfinite/stale/chart/domain/branch/rank/original-balance/derivative/reduction failures and cancellation are typed. Numerical/callback/constraint/dynamics work remains identified; failed unreported supplier work is explicit and disallows retry. Float64 reference CPU and explicit LU/Cholesky capability are admitted; no backend fallback. Bounded phase functions keep Embedded stack use local; no custom stack profile.
## Verification and Change Impact
[Test owner](../../../../../Tests/MechanicsEquilibriumTests/DESIGN.md) owns analytic spring/hanging load, branch loading/unloading, ambiguity, original directional pendulum/constrained derivatives and mixed sweep failures. Root owns selected Native/WASM/Embedded integration. Changes to force/chart/row/mass/basis or continuation identity invalidate dependent analyses.
