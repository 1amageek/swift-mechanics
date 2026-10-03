# Smooth supplied-reduction operating-point linearization
## Purpose and Scope
Parent [Equilibrium](../DESIGN.md). Children: none. Initial admitted implementation domain; behavioral/profile qualification pending. IM17/ST-001..004/ST-008 full requirement ownership persists.
## Responsibilities and Boundaries
Owns actual Dynamics mass binding and smooth first-order state/input/output derivatives on the admitted affine q=v scalar tree chart. Caller supplies N (q perturbation per dimensionless reduced displacement); every retained J*N=0, dimension n-rank and full-column-rank SPD Gram are revalidated. General nullspace construction is not implied. Dynamics mass comes from real RigidDynamicsSystem; its snapshot is compared to a fresh actual CompiledModel evaluation at equilibrium q with zero v/a and matching time/tree/layout/body poses. Original zero-acceleration inertia must vanish. Nonsmooth, moving constraints, non-scalar/free/custom tree charts and singular reduction fail. This first mass-binding path admits spatial body records with exact descriptor inertia association; planar inertia conversion and zero-free-coordinate state realization are explicit unsupported admissions. Dynamics loads are not adopted as force laws: the identified static force provider owns K and input derivatives.
## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Equilibrium](../DESIGN.md) | parent | dispatch/ownership | composition | root owns module index |
| [Nonlinear](../../MechanicsNonlinear/DESIGN.md) | depends on | original residual solve | bounded numerical candidates | no stability inference |
| [Constraints](../../MechanicsConstraints/DESIGN.md) | depends on | affine retained rows/rank | physical geometry authority | no inferred reactions |
| [Dynamics](../../MechanicsDynamics/DESIGN.md) | depends on | original inertial action/mass | operating mass authority | no force tangent API supplied |
## Architecture
```text
accepted force/constraints -> supplied N checks -> actual operating snapshot + mass -> reduced M/K/D/input/output -> original directional force/constraint/inertia probes -> A/B/C report
```
## Contracts and Invariants
For constant affine constraints, reduced K=N^T*H*N, M=N^T*Mphysical*N, D=N^T*Dphysical*N, input force=-N^T*dgradient/dp. State is [eta,etaDot], A=[0 I;-M^-1*K -M^-1*D], B=[0;M^-1*input]. Caller output map y=O*qPerturbation publishes output dimensions; C=[O*N,0]. Physical q=N*eta, rates=N*etaDot; reduced stiffness J, mass J*s^2, damping J*s. Original directional gradients at q±h*Ncolumn check tangent and full constraint directions; originalInertialForce checks mass action, not only stored matrix agreement. These derivatives qualify this local smooth operating point, not modal/stability results. Result publication checks the caller cancellation authority after the final actual input solve, output assembly and finite-value acceptance. Cancellation at this boundary returns typed cancelled failure while preserving consumed work; no linearization is published.
## State, Ownership, and Lifecycle
Inputs/providers/results/history are immutable Sendable. Work and local workspace are exclusively caller/operation owned, reused in iteration. No global cache, target conditional storage, unchecked isolation or hidden branch mutation. D is the caller published symmetric linear damping law; active negative coefficients are admitted without any passivity/stability classification. Required protocol witnesses are used across targets. Returned arrays own their storage; no escaped pointer/view.
## Failure, Concurrency, and Constraints
Caller bounds coordinates/rows/cases/metadata/storage/work before traversal/allocation. Nonfinite/stale/chart/domain/branch/rank/original-balance/derivative/reduction failures and cancellation are typed. Numerical/callback/constraint/dynamics work remains identified; failed unreported supplier work is explicit and disallows retry. Float64 reference CPU and explicit LU/Cholesky capability are admitted; no backend fallback. Bounded phase functions keep Embedded stack use local; no custom stack profile.
## Verification and Change Impact
[Test owner](../../../Tests/MechanicsEquilibriumTests/DESIGN.md) owns analytic spring/hanging load, branch loading/unloading, ambiguity, original directional pendulum/constrained derivatives and mixed sweep failures. A real ReferenceLinearSolver delegate completing Gram/K/D/input solves then setting cancellation on the fourth solve verifies the final publication gate. Root owns selected Native/WASM/Embedded integration. Changes to force/chart/row/mass/basis or continuation identity invalidate dependent analyses.
