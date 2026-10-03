# MechanicsOptimization

## Purpose and Scope
Parent: [system/package](../../DESIGN.md). Own IM32 / OP-004 and OP-009 under [SPEC](../../SPEC.md). This is an unregistered source dispatch boundary. Lower child contracts precede production; child links are added only when their designs exist. The first complete handoff is bounded affine LP / strictly convex QP and its physical feasibility/optimality certificates. Later nonlinear and mechanical estimation responsibilities remain assigned but unqualified.

## Responsibilities and Boundaries
linear_kernels exclusively owns new ProblemContracts, ConvexPrograms, NonlinearKKT and ParameterEstimation child directories plus Tests/MechanicsOptimizationTests. Root alone owns this index, shared registration/probes/scripts/progress, producer changes and commits. Other workers are present; all existing suppliers and the frozen Granular handoff are read-only. Own optimization/identifiability meanings; a root solver's residual is not an optimality certificate.

## Related Designs
| Design | Relationship | Contract used | Cautions |
|---|---|---|---|
| [Numerics](../MechanicsNumerics/DESIGN.md) | depends on | Actual dense LU/Cholesky, public CSR records and caller work | Explicit bounded dense KKT fill; no unqualified sparse backend or retry after unavailable failed work |
| [Nonlinear](../MechanicsNonlinear/DESIGN.md) | depends on | Required residual/Jacobian with original residual checks | Square roots only; consumer must own KKT feasibility/optimality acceptance |
| [Derivatives](../MechanicsDerivatives/DESIGN.md) | depends on | Qualified exact first mechanical products | No general mechanical Hessian authority; selected derivatives only |
| [Dynamics](../MechanicsDynamics/DESIGN.md) | depends on | Actual spatial rigid mass/bias/forward dynamics | Mechanical estimation must execute actual operators rather than replace them with scalar-only fixtures |
| [Plan](../../IMPLEMENTATION_PLAN.md) | coordinates with | IM04/IM30 prerequisite ownership | Selected handoffs do not close full OP domains |

## Architecture
```text
explicit cost/constraint/derivative problem + finite domain/budget
 -> bounded convex candidate enumeration or selected nonlinear KKT
 -> independent ORIGINAL feasibility/stationarity/complementarity/certificate
 -> qualified terminal result or typed unavailable/nonconverged/resource failure
physical observations -> actual mechanical first products -> identified/null directions
```

## Contracts and Invariants
First domain: finite-box affine LP and strictly convex affine QP, bounded exhaustive active-basis enumeration with rank screening before real LU and independent original primal/dual/stationarity/complementarity checks. Exhaustive infeasible status requires every admitted basis to be processed without rank/resource ambiguity; premature termination is not infeasible. A separately selected affine-equality-only unbounded LP requires a feasible point and independently checked recession ray. General indefinite/PSD QP and inequality-unbounded LP stay unavailable.
Later fixed-active-set nonlinear KKT uses required actual first and second cost/constraint derivatives, original inequalities/multiplier signs/LICQ and positive reduced Lagrangian Hessian to certify strict local minimum only. No absent mechanical second derivative is invented. Later positive mass/nonnegative damping estimation uses actual rigid dynamics and qualified first sensitivities, parameter scaling and measurement/time/unit provenance. Identifiability owns sensitivity rank/null directions, distinct from mechanical mass rank. Uncertainty requires explicit statistical assumptions.
All public operations use protocol requirements and typed errors. Models/results immutable Sendable; exclusive work and buffers are caller bounded. No source declaration of a deferred callable operation may report placeholder success; incomplete callable domains carry the required marker and typed failure.

## State, Ownership, and Lifecycle
Call-local candidate/workspace ownership; immutable returned certificates retain actual input identity/domain. No shared mutable caches. Native/WASM/Embedded use the same Sendable/storage/isolation contracts. External derivative callbacks execute outside locks and their ledger validity/failure must remain explicit.

## Failure, Concurrency, and Constraints
Preflight checked dimensions, metadata and total enumeration/storage/arithmetic budgets. Rank uncertainty, incompatible derivatives, nonfinite outputs, stale observation, cancellation and unavailable supplier work remain distinct failures. No silent numerical fallback or guessed operational cap establishes infeasibility/optimality.

## Verification and Change Impact
Independent analytic LP/QP optima, dual signs and original constraints; tied objective/degenerate basis, Farkas or exhaustive infeasibility, recession ray, nonconvergence/resource/cancellation and actual supplier failures. Later physical mass/damping recovery and zero/collinear sensitivity directions must exercise actual Dynamics/Derivatives. Root reviews/registers only frozen handoffs and runs exact-profile qualification. Full OP-004/009 and IM48 remain open outside each admitted domain.
