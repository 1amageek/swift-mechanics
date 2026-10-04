# Runtime Behavioral Proof

## Purpose and Scope
Own native behavioral evidence for all five runtime components. Parent: [Runtime](../../Sources/SwiftMechanics/Execution/Runtime/DESIGN.md). No children.

## Responsibilities and Boundaries
Prove actual compiler-bound physical state, contributors, codec, last accepted prefix and shared owner lifecycle. Root owns exact target/runtime probes and full integration.

## Related Designs
[StateRecords](../../Sources/SwiftMechanics/Execution/Runtime/StateRecords/DESIGN.md), [Transactions](../../Sources/SwiftMechanics/Execution/Runtime/Transactions/DESIGN.md), [Checkpoints](../../Sources/SwiftMechanics/Execution/Runtime/Checkpoints/DESIGN.md), [Sessions](../../Sources/SwiftMechanics/Execution/Runtime/Sessions/DESIGN.md), [ExecutionEvidence](../../Sources/SwiftMechanics/Execution/Runtime/ExecutionEvidence/DESIGN.md).

## Architecture
```text
actual compiler tree -> independent sessions -> inout trial + actual counter schema bytes
 -> accept/reject/cancel/shutdown/checkpoint/restart -> analytic accepted trajectory and unchanged failed prefix
```

## Contracts and Invariants
AF23 moving-anchor evidence uses actual compiler/Joints evaluation and required Runtime admission with a translating/rotating prescribed parent frame. Tests prove full derivatives and time association, q/v/a and all anchor scalar bit patterns, signed zeros/quaternion sign and exact v2 bytes, frozen v1 bytes, reject/cancel/RNG rollback, workspace reset, fresh-owner restore followed by identical advancement, replacement source comparison and scalar/metadata caps. Malformed/nonunit/stale/duplicate/unknown/missing samples produce no accepted state. These tests prove Runtime retention/admission; consumer law generation and geometric evolution remain separate owners. Added @Test functions have explicit availability guards; suites remain unannotated.

Admission authority regression runs the required contributor validator and actual model.makeState rejection paths directly through ReferenceRuntimeCheckpointHandler. Neither failure publishes RuntimeAcceptedState; subsequent valid admission preserves exact checkpoint, physical state, RNG and accepted sequence. Existing trial rejection, ticket replacement, restart and model replacement tests remain the session behavior oracle. Shared-module token constructor access is separately checked by a negative compile probe.

Each test owns its model/state/provider; cross-task gates/counters use Mutex or actors. Tests compare real data/trajectory rather than record existence. Codec malformed data and contributor omission never produce accepted state. Source inputs remain unchanged.

## Failure, Concurrency, and Constraints
Timeout-wrapped 180-second focused run in .build/runtime-kernels follows root target registration. Async lifecycle fixtures have bounded time limit and explicit gate release. No shared global state or assumed suite ordering.

## Verification and Change Impact
Native proves declared success/failure domain only. Root separately proves selected Native/WASM/Embedded required generic providers, same Mutex/lifecycle and target concurrency availability. No full physics/stream/allocator/profile claim from these tests.


Focused Native evidence: exact swift-6.4.0-RELEASE frontend, timeout 180 seconds, `.build/runtime-kernels`, 16 tests in four suites passed (exit 0). The final incremental build took 3.07 seconds and test execution 0.004 seconds. This is behavioral correctness evidence, not a benchmark or target-independent latency claim. Apple test bodies explicitly check the declared Synchronization/strict-UTF8 OS baseline and report failure when unavailable.

| Suite | Tests | Proven path |
|---|---:|---|
| RuntimeTransactionsTests | 4 | Actual accept/reject physical, contributor and RNG state; invalid state prefix; shared work budget; floating 7/6 chart and exact raw-quaternion checkpoint |
| RuntimeCheckpointTests | 5 | Restart continuation, corruption/truncation/invalid UTF8 and RNG data, distinct model/build compatibility, provider migration/completeness and capacities |
| RuntimeSessionsTests | 5 | Callback reentry, concurrent shutdown/cancellation publication checks, immutable accepted prefix, foreign ticket workspace recovery, exactly-once release |
| RuntimeExecutionEvidenceTests | 2 | Parallel independent owners vs sequential seed/trajectory, batch cap, actual counters and truthful detachment/unavailable profile evidence |

Atomic replacement proof uses real compiled hinge-to-floating chart changes and actual checkpoint handlers. It checks target workspace/trial/restart, schema/configuration/handler switch, source RNG/sequence, retained old snapshots, stale same-sequence state, missing/invalid/over-capacity targets, continuation/capacity changes, reentrant busy admission, concurrent cancel/shutdown and handler retirement outside the lock. These tests do not certify mechanical joint-break conservation; that belongs to Mechanisms.

Additive qualification: timeout-wrapped `.build/cohort-integration` AF16 focused Native run passed all twenty-one Runtime cases, including five replacement cases, and five IntegrationFailure cases. Three original public profile probes exited 0 for replacement and nested unknown-work propagation. Logs `.build/af16-runtime-native.log` and `.build/af16-{native,wasm,embedded}-run.log` are local execution evidence. No allocator/latency claim.

AR01.8 constructor access proof is recorded by [Compiler tests](../MechanicsCompilerTests/DESIGN.md). The added no-publication behavioral case and unchanged session cases require the root frozen-snapshot Native suite; three-profile runtime evidence remains separately owned by root.

AF23 frozen Native qualification: the exact Swift 6.4.0 release frontend ran `swift test -j 4 --filter MechanicsRuntimeTests` under a 240-second deadline. All 31 tests in seven suites passed with exit 0 (`.build/af23-runtime-native.log`), including nine new complete-anchor cases. This evidence covers Runtime retention and actual model admission on Native; new moving-anchor public WASM/Embedded behavior and prescribed-law dynamics remain separately unqualified until integrated execution.

AF25 RuntimeTransactionsTests exercises acceleration reading after an actual inout trial setter, rejects negative/end indices with invalidInput, and proves reject plus workspace reset preserves the original accepted acceleration. The Transactions owner defines this fixed-buffer contract.
