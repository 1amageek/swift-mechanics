# Projected complementarity solve

## Purpose and Scope
Parent: [MechanicsComplementarity](../DESIGN.md). Owns Float64 referenceCPU projected-gradient solve, original-problem evidence, bounded work and optional warm/preconditioner continuation for SO-004/005. Children: none.

## Responsibilities and Boundaries
Use the verified Numerics dense Cholesky solver on zero RHS to validate exact symmetry and positive definiteness under the caller-selected pivot threshold, then iterate x'=ΠK(x-(Ax+b)/L), L=max row absolute sum. This conservative bound makes fixed-step projected gradient converge for the admitted convex QP. General monotone/indefinite/nonsymmetric LCP, accelerated/device/Float32 profiles and non-associated friction laws are unsupported. No material, geometry, scene or runtime is imported.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Module](../DESIGN.md) | parent | Scope and qualification | Composition | Root owns integration |
| [Problem](../Problem/DESIGN.md) | depends on | Records, frozen acceptance, exact cache snapshot | Authority | No cache bypass |
| [Projection](../Projection/DESIGN.md) | depends on | Public projection/violation requirements | Mathematical K and K* | Normal/tangent ordering |
| [Numerics](../../Numerics/LinearAlgebra/DESIGN.md) | depends on | NumericalBudget/Work/Termination | Resources/failures | No IM04 implementation dependency |

## Architecture
```text
original problem + optional exact cache -> bounded Cholesky admission -> initial iterate projection
Ax+b -> independent primal/dual/complementarity/unit-step optimality evidence
all accepted -> result + original residuals + caller-owned continuation cache
not accepted -> projected step -> repeat
cancel/budget/max-iteration/stagnation/domain failure -> typed failure; no success/cache commit
```

## Contracts and Invariants
Original w=Ax+b is recomputed each pass. Four independent measures must pass: primal and dual cone violation, max absolute x_iw_i for orthant or absolute block x·w for cones, and ||x-ΠK(x-w)||∞. The unit-step optimality measure is independent of the cached/iteration preconditioner. Acceptance never uses iterate movement alone. Objective .5xᵀAx+bᵀx is reported only if finite. Cache mismatch fails, rather than silently cold restarting; cold and warm use identical evidence thresholds. Replaying a cache restores the same deterministic continuation.

Maximum iteration count is caller convergence policy; NumericalBudget separately limits storage/arithmetic/iterations. Validation, original residual, projection and objective charges accumulate in NumericalWork. Four mutable length-n buffers (iterate,w,projectionInput,projected) are allocated once after requiring storage; iterations reuse them in place without intermediate arrays, copy/map/filter or allocating matrix-vector operations. Cholesky preflight uses NumericalWork.remainingBudget/absorb with retained input/cache reserved and its existing provider workspace/storage charge; no duplicate SPD implementation is introduced. The retained problem consumes n²+2n+m scalar slots, including m stored cone coefficients and conservatively counting n 64-bit coordinate IDs; warm cache consumes its own retained matrix/RHS/IDs/coefficients/iterate plus one scalar preconditioner, even if Swift COW shares buffers. Result/cache output retains the final iterate by value. Per-pass arithmetic charges are conservative upper bounds; checked integer arithmetic precedes capacity calculation. Cancellation is checked at entry, every row/block and each iteration, including initially acceptable inputs.

## State, Ownership, and Lifecycle
Solver is stateless Sendable. Only local buffers/work counters mutate; immutable problem/cache values preserve rejected trial and independent rollout histories. Scalar inverse-L preconditioner is an optimization record, not a changed problem. No platform conditional/conformance difference, shared state, async task ownership or pointer is used.

## Failure, Concurrency, and Constraints
Invalid profile/identity/cache, stale restart, overflow, cancellation and budgets fail. Nonconvergence follows caller max iterations or exact iterate stagnation with rejected original residual. Numerical error context identifies numerical operation/profile; composition adds physical scene IDs/time. Failures do not return a truncated successful result.

## Verification and Change Impact
[SolveTests](../../../../../Tests/MechanicsComplementarityTests/SolveTests.swift) uses manufactured n=2 orthant and μ=.5 3D cone optima, independent original balances/complementarity, cold/warm/replay, deliberately wrong warm guess and tiny-step forged cache, max-iteration/storage/work/cancel failures, stale matrix/RHS/revision/frame/layout/law and invalid SPD profile and non-diagonally-dominant SPD admission. Dimensionless residual tolerances are 1e-9 absolute+1e-10 relative with frozen scales 1; solution oracle norm tolerance 1e-7. Profile composition is root-owned; physical friction/scene dynamics remain unverified.
