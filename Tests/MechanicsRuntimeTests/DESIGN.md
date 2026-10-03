# Runtime Behavioral Proof

## Purpose and Scope
Own native behavioral evidence for all five runtime components. Parent: [Runtime](../../Sources/MechanicsRuntime/DESIGN.md). No children.

## Responsibilities and Boundaries
Prove actual compiler-bound physical state, contributors, codec, last accepted prefix and shared owner lifecycle. Root owns exact target/runtime probes and full integration.

## Related Designs
[StateRecords](../../Sources/MechanicsRuntime/StateRecords/DESIGN.md), [Transactions](../../Sources/MechanicsRuntime/Transactions/DESIGN.md), [Checkpoints](../../Sources/MechanicsRuntime/Checkpoints/DESIGN.md), [Sessions](../../Sources/MechanicsRuntime/Sessions/DESIGN.md), [ExecutionEvidence](../../Sources/MechanicsRuntime/ExecutionEvidence/DESIGN.md).

## Architecture
```text
actual compiler tree -> independent sessions -> inout trial + actual counter schema bytes
 -> accept/reject/cancel/shutdown/checkpoint/restart -> analytic accepted trajectory and unchanged failed prefix
```

## Contracts and Invariants
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
