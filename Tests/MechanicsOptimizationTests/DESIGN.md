# MechanicsOptimizationTests

## Purpose and Scope
Parent [module](../../Sources/MechanicsOptimization/DESIGN.md). Selected initial convex handoff qualified; root owns executions and the [parent evidence record](../../Sources/MechanicsOptimization/DESIGN.md#selected-af18-qualification).

## Responsibilities and Boundaries
Own independent original primal/dual/KKT/Farkas equations, analytic LP/QP optima and failure/resource oracles. No nonlinear residual-as-optimality or generic mechanical Hessian claim.

## Related Designs
[ProblemContracts](../../Sources/MechanicsOptimization/ProblemContracts/DESIGN.md), [ConvexPrograms](../../Sources/MechanicsOptimization/ConvexPrograms/DESIGN.md). Future nonlinear/identification tests have separate responsibility.

## Architecture
```text
actual public OptimizationSolving -> ORIGINAL analytic equations -> falsifiable optimum/infeasibility/failure assertions
```

## Contracts and Invariants
Sparse input and physical reference metadata execute actual dense KKT suppliers. Independent objective/dual signs/certificate re-evaluation, tie uniqueness semantics and invalid basis status. Capacity failure must not become infeasible. Actual supplier failure retains unavailable consumption and stops once. Real altered-rhs solver results with accepted internal residual must fail original optimality; successful known work must be absorbed before rejected output shape; replaced budget marks unavailable consumption. Phase-I failure residual authority is explicit.

## State, Ownership, and Lifecycle
The fault-injection supplier's invocation count is the only shared mutable test state. Each test constructs a fresh immutable supplier owner; the supplier retains its counter until its last reference is released. Reference solver calls occur after leaving the counter critical section.

| State | Storage on Native / WASM / Embedded | Isolation | Read | Mutation | Release |
|---|---|---|---|---|---|
| Invocation count | Same `Mutex<Int>` owned by `FaultyOptimizationLinearSolver` | `withLock` on all targets | `invocationCount` through `withLock` | Both required `solve` entries increment through `withLock` | Last supplier reference releases the Mutex owner |

The fixture requires macOS 15 / iOS 18 / tvOS 18 / watchOS 11 on Apple platforms. Its three test bodies (four construction sites) guard availability and record a test issue if unavailable; no raw counter or weaker Sendable fallback is supplied. Test declarations retain discovery on the package's earlier deployment baseline.

## Failure, Concurrency, and Constraints
Test-local buffers and ledgers, no shared global state. Root timeout-qualified Native/ordinary/Embedded paths own platform evidence. No independent builds by component owner.

## Verification and Change Impact
Focused LP/QP/rank/Farkas/scaling/budget/cancel/supplier tests qualify only admitted finite-box convex domain. General nonlinear/unbounded LP/identification and full OP-004/009 remain open.
