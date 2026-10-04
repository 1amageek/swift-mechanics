# Explicit branch continuation and bounded load sweeps
## Purpose and Scope
Parent [Equilibrium](../DESIGN.md). Children: none. Initial admitted implementation domain; behavioral/profile qualification pending. IM17/ST-001..004/ST-008 full requirement ownership persists.
## Responsibilities and Boundaries
Owns immutable accepted branch identity/envelope/history and per-case parameter/result/failure provenance. The load/displacement path is caller-selected, with finite branch box, maximum normalized step and explicit seed. No automatic root branch switch, arc-length limit-point handling or constitutive hysteresis is invented. Builtin laws are memoryless; loading/unloading fixture demonstrates the selected reversible branch, not material hysteresis.
## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Equilibrium](../DESIGN.md) | parent | dispatch/ownership | composition | root owns module index |
| [Nonlinear](../../../Mathematics/Nonlinear/DESIGN.md) | depends on | original residual solve | bounded numerical candidates | no stability inference |
| [Constraints](../../../Physics/Constraints/DESIGN.md) | depends on | affine retained rows/rank | physical geometry authority | no inferred reactions |
| [Dynamics](../../../Physics/Dynamics/DESIGN.md) | depends on | original inertial action/mass | operating mass authority | no force tangent API supplied |
## Architecture
```text
explicit seed/branch -> case solve -> accepted state updates caller continuation
failure -> previous accepted seed retained + case status
unknown failed supplier work/resource/cancel -> remaining cases not attempted with reason
```
## Contracts and Invariants
Every case retains model/layout revision, branch ID, parameter value, supplied/accepted seed and explicit accepted/failure/not-attempted status. State reuse requires matching model/branch/domain/revision and parameter authority. Accepted root must remain in branch box and below caller step limit. Failure never seeds later successful cases. Per-case parameter outside domain is recorded without nonlinear supplier work; unknown failed work, cancellation or exhausted cumulative ledgers stop. Stability/limit-point and uniqueness are not inferred from branch box or local tangent.
## State, Ownership, and Lifecycle
Inputs/providers/results/history are immutable Sendable. Work and local workspace are exclusively caller/operation owned, reused in iteration. No global cache, target conditional storage, unchecked isolation or hidden branch mutation. Required protocol witnesses are used across targets. Returned arrays own their storage; no escaped pointer/view.
## Failure, Concurrency, and Constraints
Caller bounds coordinates/rows/cases/metadata/storage/work before traversal/allocation. Nonfinite/stale/chart/domain/branch/rank/original-balance/derivative/reduction failures and cancellation are typed. Numerical/callback/constraint/dynamics work remains identified; failed unreported supplier work is explicit and disallows retry. Float64 reference CPU and explicit LU/Cholesky capability are admitted; no backend fallback. Bounded phase functions keep Embedded stack use local; no custom stack profile.
## Verification and Change Impact
[Test owner](../../../../../Tests/MechanicsEquilibriumTests/DESIGN.md) owns analytic spring/hanging load, branch loading/unloading, ambiguity, original directional pendulum/constrained derivatives and mixed sweep failures. Root owns selected Native/WASM/Embedded integration. Changes to force/chart/row/mass/basis or continuation identity invalidate dependent analyses.
