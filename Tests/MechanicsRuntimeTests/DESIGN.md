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

### AF31 observation lease regression

RuntimeSessionsTests.ordinaryObservationExitPreservesActiveTrialCancellationSource owns one deterministic behavioral declaration with two in-case paths: an ordinary observation succeeds or explicitly fails while the original performTrial callback is active. Both observations read the unchanged accepted prefix. After the observation exits, the original control must admit another work block and the original compiler-bound trial must publish its changed position/time once. A failed observation retains its accepted prefix without poisoning the active ticket. Test fixtures are existing public RuntimeFixtures; no synthetic accepted state or fabricated ticket supplies authority. Each case owns its session and Mutex-backed release count, with no shared static state.

```text
active real trial -> observe accepted prefix -> ordinary lease exit
  -> same ticket safe point -> original admission -> accepted publication
shutdown path -> existing RuntimeSessionsTests -> cancel + drain + release once
```

The owner runs the new test RED before the minimal source repair, then the new test and unchanged RuntimeSessionsTests GREEN from an immutable625f759 private source copy and a dedicated native build path. Exact Swift6.4.0, four jobs, watchdog1200s setup and240s behavior preserve original contracts. Source/profile integration is root-owned; executed evidence follows actual runs, not this plan.


Actual owner Native evidence: private committed625f759 at .build/af31-runtime-observe-fix/source, dedicated .build/af31-runtime-observe-fix/native cache. The only private graph change removes all other one-line testTarget registrations; the existing MechanicsRuntimeTests registration, all production/executable targets, dependencies and flags are unchanged. Private manifest SHA-256:400778b21139ce462d606ecdc046ad89ab107ae6db6b3b184b3b69a7462b1fc6; exact comparison is .build/af31-runtime-observe-fix/private-manifest.diff.

| Proof | Actual evidence |
|---|---|
| Original source RED setup | exit0,294.66s cold compile/link |
| New regression on original source | exit1; one test/one suite,.020s; post-observation beginWorkBlock returned cancelled before admission |
| Corrected source setup | exit0,147.74s compile/link; exact owned source copied and SHA-verified before invocation |
| Affected session suite GREEN | exit0;6 tests/one suite,.010s; new test executes success and deliberate observation failure paths, plus unchanged5 lifecycle cases |
| Resource/lifetime |687MiB private source/cache/evidence; all owner processes stopped after GREEN |

Commands from the private source directory, using the exact release toolchain:

```sh
python3 Scripts/run_with_timeout.py 1200 /Users/1amageek/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swift build --build-tests --build-path /Users/1amageek/Desktop/3D/swift-mechanics/.build/af31-runtime-observe-fix/native -j 4
python3 Scripts/run_with_timeout.py 240 /Users/1amageek/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swift test --skip-build --build-path /Users/1amageek/Desktop/3D/swift-mechanics/.build/af31-runtime-observe-fix/native --filter RuntimeSessionsTests.ordinaryObservationExitPreservesActiveTrialCancellationSource
python3 Scripts/run_with_timeout.py 240 /Users/1amageek/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swift test --skip-build --build-path /Users/1amageek/Desktop/3D/swift-mechanics/.build/af31-runtime-observe-fix/native --filter RuntimeSessionsTests
```

RED logs are red-setup.log/red-tests.log and GREEN logs are green-corrected-setup.log/green-tests.log under .build/af31-runtime-observe-fix. A preliminary relative-path overlay command failed before changing private production; its completed no-change green-setup.log is not correctness evidence. The absolute overlay was checked byte-for-byte before the corrected setup. Only one comprehensive scoped review and the actual targeted behavior recheck were performed. Shared metadata/control remain the same Mutex owners and outside-lock cancellation/release on every target. Native evidence does not certify ordinary/Embedded execution or target multithread capability; root owns that integration.
