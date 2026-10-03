# Integration Behavioral Proof

## Purpose and Scope
Own Native proof for [Equations](../../Sources/MechanicsIntegration/Equations/DESIGN.md), [Continuation](../../Sources/MechanicsIntegration/Continuation/DESIGN.md) and [Stepping](../../Sources/MechanicsIntegration/Stepping/DESIGN.md). Parent: [Integration](../../Sources/MechanicsIntegration/DESIGN.md). No children.

## Responsibilities and Boundaries
Independent analytic manufactured smooth equations run through actual compiled hinge state and Runtime transactions. Root owns target qualification and accumulated integration.

## Related Designs
The three component links above own equations/chart, payload and stage contracts; [Runtime](../../Sources/MechanicsRuntime/DESIGN.md) supplies real transactions.

## Architecture
```text
actual compiled hinge -> required continuation + session -> manufactured equation
 -> RK4/Heun trials -> analytic values/order + unchanged rejected prefix
```

## Contracts and Invariants
Fixtures own all mutable state; any cross-task counter uses Mutex. Analytic solutions and refinement ratios are independent of the implementation equations. Restart uses actual native checkpoint bytes and compares continued accepted physical/contributor state.

## Failure, Concurrency, and Constraints
The actual final focused command was `python3 Scripts/run_with_timeout.py 180 swift test --build-path .build/cohort-integration --filter Integration` after root registration and the causal phase extraction. All nine tests in three suites passed (exit 0). Native tests guard declared OS availability. No global mutable test state.

## Verification and Change Impact
Local suites prove admitted explicit domain only. Implicit/HHT, general manifold/dense output, nonsmooth/stiff-method qualification and target-pair strong determinism remain full IM09 obligations.


| Suite | Tests | Actual proof |
|---|---:|---|
| IntegrationOrderTests | 3 | RK4 fourth-order and Heun second-order refinement, adaptive dimensional decay/error acceptance, exact target and terminal short step |
| IntegrationContinuationTests | 2 | Rejected actuation/RNG/history restoration, actual checkpoint/restart continuation, changed/corrupt options and stale physical association |
| IntegrationFailureTests | 4 | Supplier ledger replacement/reset rejection with unavailable work and no retry, malformed derivative and independent budgets, retry/minimum/accepted-prefix limits, cancellation rollback |

Root selected final Native, ordinary WASM and Embedded public probes all exited 0 using the original profile stack reservation. They exercise actual RK4/Heun stages, accepted contributor continuation, checkpoint/restart and malformed derivative failure. This qualifies those exact selected workloads, not arbitrary provider domains or target-pair strong determinism. No allocator/COW benchmark or rebuilt per-function frame measurement is claimed.

Nested supplier failure fixture charges real derivative work and throws explicit unknown nested work; Integration must retain known charges, report unavailable work, preserve physical/history/RNG prefix and perform no retry. Diagnostic bounding and Runtime prefix retention must preserve this flag.

AF16 focused Native run passed five IntegrationFailure tests, including the real charged nested-failure regression. The same required equation/integrator/public Runtime path propagated unknown-work evidence and retained its accepted prefix on original Native/ordinary-WASM/Embedded probes, exit 0. Earlier unchanged integration order/continuation evidence remains valid; full IM09 obligations remain.
