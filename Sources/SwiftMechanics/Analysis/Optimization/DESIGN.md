# Optimization component

## Purpose and Scope
Parent: [responsibility owner](../DESIGN.md). Own IM32 / OP-004 and OP-009 under [SPEC](../../../../SPEC.md). This is a registered AF18 frozen convex handoff; later children remain source-free and unqualified. Lower child contracts precede production; child links are added only when their designs exist. The first complete handoff is bounded affine LP / strictly convex QP and its physical feasibility/optimality certificates. Later nonlinear and mechanical estimation responsibilities remain assigned but unqualified.

| Child | Owned contract |
|---|---|
| [ProblemContracts](ProblemContracts/DESIGN.md) | Original normalized problem, caller policy, status and certificate meaning |
| [ConvexPrograms](ConvexPrograms/DESIGN.md) | Actual bounded enumeration, original optimality checks and phase-I/Farkas proof |

The first handoff directly consumes Core, Model and Numerics. Nonlinear, Derivatives and Dynamics are later responsibility prerequisites, not imports of the initial convex implementation.

## Responsibilities and Boundaries
linear_kernels exclusively owns new ProblemContracts, ConvexPrograms, NonlinearKKT and ParameterEstimation child directories plus Tests/MechanicsOptimizationTests. Root alone owns this index, shared registration/probes/scripts/progress, producer changes and commits. Other workers are present; all existing suppliers and the frozen Granular handoff are read-only. Own optimization/identifiability meanings; a root solver's residual is not an optimality certificate.

## Related Designs
| Design | Relationship | Contract used | Cautions |
|---|---|---|---|
| [Numerics](../../Mathematics/Numerics/DESIGN.md) | depends on | Actual dense LU/Cholesky, public CSR records and caller work | Explicit bounded dense KKT fill; no unqualified sparse backend or retry after unavailable failed work |
| [Nonlinear](../../Mathematics/Nonlinear/DESIGN.md) | depends on | Required residual/Jacobian with original residual checks | Square roots only; consumer must own KKT feasibility/optimality acceptance |
| [Derivatives](../Derivatives/DESIGN.md) | depends on | Qualified exact first mechanical products | No general mechanical Hessian authority; selected derivatives only |
| [Dynamics](../../Physics/Dynamics/DESIGN.md) | depends on | Actual spatial rigid mass/bias/forward dynamics | Mechanical estimation must execute actual operators rather than replace them with scalar-only fixtures |
| [Plan](../../../../IMPLEMENTATION_PLAN.md) | coordinates with | IM04/IM30 prerequisite ownership | Selected handoffs do not close full OP domains |

## Architecture
```text
explicit cost/constraint/derivative problem + finite domain/budget
 -> bounded convex candidate enumeration or selected nonlinear KKT
 -> independent ORIGINAL feasibility/stationarity/complementarity/certificate
 -> qualified terminal result or typed unavailable/nonconverged/resource failure
physical observations -> actual mechanical first products -> identified/null directions
```

## Contracts and Invariants
First-domain input/status authority is [ProblemContracts](ProblemContracts/DESIGN.md); numerical enumeration and original certificates are owned by [ConvexPrograms](ConvexPrograms/DESIGN.md). No feasible enumerated candidate alone establishes infeasibility: the child requires an independently accepted original Farkas certificate. Unbounded LP is deferred and not published in this handoff.
Later fixed-active-set nonlinear KKT uses required actual first and second cost/constraint derivatives, original inequalities/multiplier signs/LICQ and positive reduced Lagrangian Hessian to certify strict local minimum only. No absent mechanical second derivative is invented. Later positive mass/nonnegative damping estimation uses actual rigid dynamics and qualified first sensitivities, parameter scaling and measurement/time/unit provenance. Identifiability owns sensitivity rank/null directions, distinct from mechanical mass rank. Uncertainty requires explicit statistical assumptions.
All public operations use protocol requirements and typed errors. Models/results immutable Sendable; exclusive work and buffers are caller bounded. No source declaration of a deferred callable operation may report placeholder success; incomplete callable domains carry the required marker and typed failure.

## State, Ownership, and Lifecycle
Call-local candidate/workspace ownership; immutable returned certificates retain actual input identity/domain. No shared mutable caches. Native/WASM/Embedded use the same Sendable/storage/isolation contracts. External derivative callbacks execute outside locks and their ledger validity/failure must remain explicit.

## Failure, Concurrency, and Constraints
Preflight checked dimensions, metadata and total enumeration/storage/arithmetic budgets. Rank uncertainty, incompatible derivatives, nonfinite outputs, stale observation, cancellation and unavailable supplier work remain distinct failures. No silent numerical fallback or guessed operational cap establishes infeasibility/optimality.

## Verification and Change Impact
Independent analytic LP/QP optima, dual signs and original constraints; tied objective/degenerate basis, Farkas or exhaustive infeasibility, recession ray, nonconvergence/resource/cancellation and actual supplier failures. Later physical mass/damping recovery and zero/collinear sensitivity directions must exercise actual Dynamics/Derivatives. Root reviews/registers only frozen handoffs and runs exact-profile qualification. Full OP-004/009 and IM48 remain open outside each admitted domain.

## Selected AF18 Qualification

Root traced actual admission/rank/KKT/phase-I/original certificate/publication and successful/failed supplier ledgers, then registered the frozen 24-source/two-child implementation. All 23 Native behavioral tests in the three convex suites passed in `.build/af18-optimization-native-recheck.log`. Test-only findings were Mutex availability and Swift Testing macro type-check complexity; their exact corrections preserve mathematics and thresholds. The one comprehensive source review and findings-limited rechecks leave no concrete blocker within this admitted domain.

Required public LP/QP/Farkas/refusal and SI scaling compositions compiled/linked and exited 0 on original Native arm64 macOS27, swift-6.4.0-RELEASE_wasm and its matching Embedded SDK with EmbeddedUnicode, Node24.19.0 WASI Preview1. `.build/af18-optimization-{native,wasm,embedded}-run.log` owns actual execution; original artifact/stack profiles are unchanged. These are selected public-path checks, not every Native failure path on WASM, actual WASI parallelism, allocator/performance evidence or full OP-004/009 closure. Existing provider evidence remains valid because no producer implementation changed. Full IM32/IM48 remains open.

## AF19 Nonlinear Source Dispatch

linear_kernels next owns only new `NonlinearKKT/` and dedicated unregistered `Tests/MechanicsNonlinearOptimizationTests/`. The whole child is excluded until freeze; existing convex source/tests remain read-only. Root owns this index, graph/probes/progress/producer changes/commits. Read actual public NonlinearSolving/LinearSolving supplier paths before the child DESIGN and source. The child owns required caller cost/constraint first and second derivative provenance, fixed explicitly supplied active set, actual nonlinear KKT solve and independent original feasibility/multiplier/stationarity/complementarity/LICQ/reduced-Lagrangian-curvature acceptance. Positive reduced curvature establishes a strict local result, never global nonlinear optimality. Sparse derivatives and explicitly bounded dense certification fill retain their actual meaning. Mechanical Hessians are not inferred from first-only Derivatives. Rank uncertainty, nonconvergence, callback failure/cancellation, unavailable work and maximum live/work limits are child contracts before declarations. Analytic nonlinear optima and saddle/false-internal-residual rejection must exercise real producer APIs. General active-set discovery, unbounded LP and physical identification remain required later IM32 work.

### Consolidation contract
This directory is a component inside the SwiftMechanics module, not a separate SwiftPM target. Its existing public behavior and exact-profile evidence remain its contract authority. Cross-component access uses the documented contracts; internal visibility alone does not grant admission or publication authority. Source relocation requires integrated behavioral requalification.
