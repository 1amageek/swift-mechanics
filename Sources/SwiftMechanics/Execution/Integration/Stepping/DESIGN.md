# Explicit Integration Transactions

## Purpose and Scope
Own fixed classical RK4 and adaptive Heun/Euler 2/1 stage equations, dimensional max error norm, bounded retry, actual accepted time and terminal-prefix reporting through required Runtime trials. Parent: [MechanicsIntegration](../DESIGN.md). No children.

## Responsibilities and Boundaries
This component owns the preceding responsibility and its immutable public artifacts. Runtime owns physical state/checkpoint/lifecycle; providers own equation and chart semantics. Full TI requirement-family closure remains IM09 after this initial domain.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Integration](../DESIGN.md) | parent | IM09 boundary | Root composition | Full eventual domain retained |
| [Runtime](../../Runtime/DESIGN.md) | depends on | Required trial/contributor/snapshot methods | Verified producer 6ae2742 | Nonqueuing admission; macOS 15 baseline |
| [Numerics](../../../Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | NumericalWork/budget | Supplier declared arithmetic ledger | Failure never authorizes blind retry |
| [Tests](../../../../../Tests/MechanicsIntegrationTests/DESIGN.md) | verified by | Manufactured equations | Behavioral proof | Exact selected profiles root-owned |

## Architecture
```text
model/chart + immutable equation/policy -> explicit owned stages
 -> non-inline trial phase returns -> Runtime admission -> accept + required continuation
 -> reject/failure -> unchanged accepted prefix
```

## Contracts and Invariants
RK4 stages use c=[0,1/2,1/2,1], endpoint weights [1,2,2,1]/6 and an actual endpoint derivative for provider publication. Heun uses Euler predictor and trapezoidal endpoint; error is the difference of order-2 and order-1 estimates, with max |error_i|/(absolute_i+relative_i*max(|old_i|,|new_i|)). Only error<=1 accepts. New h=h*clamp(safety/sqrt(error),minimumFactor,maximumFactor), with error zero selecting maximumFactor, bounded to configured step range. Rejection strictly shrinks and repeats from unchanged accepted history; supplier failures are terminal and never blindly retried. Target-time clipping is exact, including a final gap below minimum step; rejection needing a smaller-than-minimum step fails. Each accepted stage writes actual point, endpoint derivative, time and continuation; Runtime final admission is the publication authority. No implicit/HHT/general manifold/dense output APIs are declared in this initial domain; full IM09 obligations remain.

## Runtime Flows
Validate bounded descriptor/policy and history -> enter required Runtime trial -> read actual chart -> stages/error -> reject or write/readback/continuation -> Runtime final validation -> immutable result. `step` returns the first accepted step; `advance` reaches the requested terminal time with no overshoot. Concurrent unrelated changes invalidate expected accepted association; no run-wide exclusive lease is claimed. No recursive snapshot is used as trial-state authority.

## State, Ownership, and Lifecycle
All policies/providers/results are immutable Sendable values. Stage buffers are operation-owned arrays, reused within an attempt; supplied trial is exclusive inout. The run loop delegates to an explicit non-inline trial-computation phase. That phase owns stage/history/error/publication locals and returns before Runtime performs its final compiled-model admission. The same boundary exists on every target; no target fallback or altered equation is selected. A short attempt-local Mutex retains only fixed scalar evidence for reporting; provider callbacks occur outside locks and the same storage/conformance applies on Native/WASM/Embedded. No shared cache/warm start exists. Continuation state is the required Runtime contributor.

## Failure, Concurrency, and Constraints
Typed RuntimeFailure from providers/runtime becomes contextual IntegrationFailure with actual accepted prefix and known outer/supplier work. Nested failedSupplierWorkUnavailable propagates from every caught provider/runtime failure into IntegrationWorkReport, including preflight/chart/admission failures. Ledger replacement/reset raises the same explicit unknown-work flag; known outer charges remain reported and failure never retries. Outer coordinate combination/error blocks reserve a conservative 32 scalar arithmetic operations per coordinate block; these fixed charges are algorithmic budget bounds, not instrumented operation counts. Supplier NumericalWork arithmetic/iterations and peak storage are separate caller-bounded ledgers accumulated across all attempts. Providers must poll/charge their own published quantum; each outer coordinate block and callback admission charges Runtime work units before execution. Cancellation is cooperative, not a wall-clock guarantee. Count/products/byte estimates are checked before allocation. An attempt reserves at most seven coordinate buffers (7n Double slots); callback-owned storage and Runtime/Compiler validation storage have separate producer limits. Allocator/COW traffic is unmeasured; a callback may retain copies, so no per-trial copy bound is claimed. Apple Mutex-dependent APIs use macOS 15/iOS-tvOS18/watchOS11 availability.

## Verification and Change Impact
[Test owner](../../../../../Tests/MechanicsIntegrationTests/DESIGN.md) proves independent analytic convergence/order, dimensional adaptive targets, actual rejected history and checkpoint continuation, endpoint time, malformed derivative/domain/options/association, retry/work exhaustion and cancellation rollback. Root owns exact selected Native/WASM/Embedded public witnesses. Equation/chart/options/continuation changes invalidate downstream mechanism execution assumptions.


| Shared logical state | Native / WASM / Embedded storage | Read | Mutation | Release |
|---|---|---|---|---|
| Attempt scalar evidence | Same Mutex<IntegrationAttemptEvidence> | read after Runtime trial | store in trial exit defer | operation-local owner release outside provider callbacks |

No target conditional storage/isolation or conformance exists. Native tests and root selected profiles qualify only actual exercised Mutex/public witness paths.


Causal Embedded stack finding: in the preserved initial AF09 artifact, the run-loop frame was 22,544 bytes and remained live beneath Runtime trial/admission; root fixture, Runtime trial and admission frames brought these four measured live frames to 101,616 bytes before Compiler/Joints nesting. An unchanged-function-body diagnostic that adjusted only stack/memory reservation completed the full probe. The trial phase extraction addresses that measured live-call chain; root subsequently rebuilt and ran the final Native, ordinary WASM and Embedded selected public probes successfully (exit 0) with the original profile stack reservation. Final Native focused evidence was nine tests in three suites using `.build/cohort-integration --filter Integration`. Rebuilt per-function frame sizes were not measured, and no numerical frame-size reduction is claimed. This is not an allocation/copy performance claim or a blanket stack bound for other toolchains/providers.

### Nested Hybrid trial lifetime correction

The initial public Integration profile proof remains valid for its exercised caller. A later Hybrid reintegration caller exposes a larger composed peak: the root's private boundary trap stops before overwrite at executeTrial -> stages -> evaluate -> Runtime work admission. Original measured static callers total approximately 131,392 bytes, including executeTrial 26,064, run 22,864 and Runtime.performTrial 15,232. Root owns the Runtime checkpoint admission split and all profile configuration. No larger-stack diagnostic qualifies the original profile.

This component separates one trial into non-inline preparation, stage computation, error assessment and endpoint publication. The executeTrial owner retains only the exclusive stage workspace, scalar interval/proposal and the exit-evidence defer while a stage supplier executes. Preparation's rich expected state/history/descriptor temporaries return before stages; future contributor/history/publication temporaries exist only in the publication phase. IntegrationAttemptContext becomes an immutable final Sendable owner with let fields, avoiding rich context value copies into the required Runtime callback. No mutable workspace enters that owner, and the existing attempt evidence Mutex remains the only shared mutable storage.

```text
Runtime exclusive trial
 -> executeTrial (exclusive workspace; exit evidence defer)
    -> prepareTrial -> scalar interval
    -> stages -> actual required derivative witnesses
    -> assessStep -> reject, or bounded proposal
    -> publishEndpoint -> actual derivative/write/readback/contributor
 <- decision + same evidence
 -> Runtime acceptance/rejection validation
```

The preparation read/prepare/read order, stage tableau, arithmetic charges, adaptive error and proposal rules, accepted-sequence overflow priority, endpoint derivative/write/readback order and contributor generation remain unchanged. Failures still run the same workspace evidence defer; rejection/failure leaves Runtime's accepted physical/contributor/RNG prefix unchanged. Immutable context lifetime is one attempted Runtime transaction. All target declarations, public entry points, budgets and continuation bytes are identical; no synchronization or memory-profile fallback is introduced. The nine Integration cases passed in the registered 299-test Native cohort. The final original-profile Native/ordinary-WASM/Embedded-WASM public probe exited 0, including actual nested Hybrid stages and restart. This qualifies the exercised lifetime revision, not arbitrary providers or a general stack bound; no allocator/copy performance measurement is claimed.
