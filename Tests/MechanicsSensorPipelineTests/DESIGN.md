# Sensor Pipeline Behavioral Evidence

## Purpose and Scope

Parent/tested production contract: [SensorPipeline](../../Sources/SwiftMechanics/Analysis/Observations/SensorPipeline/DESIGN.md). Children: none. Own fine-grained behavioral evidence for the selected SE-005..008 and sensor RT-003/006 path. Root owns registration, full integration and original Native/WASM/Embedded public execution. The selected Native domain is qualified with the exact Swift 6.4.0 release compiler: 27 initially passing declarations plus two finding-only passing rechecks across six suites. Cross-profile qualification remains root-owned.

## Responsibilities and Boundaries

Exercise the actual public compiled model, original raw observers, private real RuntimeSession wrapper, original integration, required contributor registry/handler and checkpoint codec. Expected physical measurements, clocks, processing values and statistical moments are independent test oracles. Never fabricate an accepted observation, bypass Runtime commit or accept a mocked matrix/value provider as the real path.

## Related Designs

| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [SensorPipeline](../../Sources/SwiftMechanics/Analysis/Observations/SensorPipeline/DESIGN.md) | tested owner | Complete accepted-time processing/queue/lifecycle contract | Does not qualify unfinished contact/range adapters |
| [Runtime Tests](../MechanicsRuntimeTests/DESIGN.md) | coordinates with | Original ticket/rollback/release authority | Reuse original behavior; test new composed interactions |
| [Observation Tests](../MechanicsObservationsTests/DESIGN.md) | depends on | Original physical observation evidence | Source/time/header alone is insufficient for pipeline acceptance |
| [FoundationVerification](../../Verification/FoundationVerification/DESIGN.md) | used by | Original selected profile composition | Exact SDK/toolchain/stack required |

## Architecture

```text
public compiled analytic mechanics + real observer + original integrator
  -> SensorPipelineSession -> original Runtime commit/observe
  -> compare independent physical/time/statistical oracle
  -> checkpoint fresh owner -> same accepted continuation and output sequences

counterfeit source / rejected trial / overflow / reset / shutdown
  -> typed failure + exact retained physical/contributor/RNG prefix
```

## Contracts and Invariants

| Proof group | Required real path and counterexample |
|---|---|
| Processing | Actual encoder/IMU values, independent bias/noise/nearest-even quantization/saturation order; incorrect order or hidden clipping fails |
| Statistics | Fixed-seed bounded uniform sequence with independent analytic discrete mean/variance and declared statistical thresholds; no Gaussian claim |
| Random association | Same seed/config/accepted trajectory reproduces draws, processed/dropout records and counters; dropout cannot shift later draw association |
| Invalid domains | Nonfinite bias/width/probability/delay, negative width/delay, zero quantization step, reversed saturation bounds and overflow fail before publication |
| Accepted clock | Original adaptive Heun-Euler rejects real trial intervals; fixed ticks follow only accepted brackets, without rejected rows/counter changes |
| Interpolation | Endpoint-only mismatch refuses; prior hold preserves true source time; component-linear interpolation retains both accepted endpoint sources and approximate fidelity |
| Events | Impulse/discrete interpolation, unknown event history and unlocated crossings refuse; admitted explicit pre/post endpoint treatment never silently mixes sides |
| Source authority | Same stamp/time but changed q/v/a or prescribed pose/v/a/frame cannot publish; standalone public checkpoint admission is not owner commit authority |
| Delay | Sampling time, source time, deadline and actual accepted delivery time differ correctly; no wall-clock dependence |
| Capacity/order | Checked tick/queue/batch bounds; pending overflow retains the full original prefix; retain-latest reports the exact lost sequence floor to a slow consumer |
| Restart | Actual full codec/checkpoint and fresh owner restore settings/counters/brackets/pending/ready queues and continued output exactly; changed version/seed/schema/truncated bytes refuse |
| Leases/lifecycle | Real read lease blocks mutation/restart; callback reentry returns busy; shutdown during operation/read drains then releases once; invalid/closed/wrong-epoch leases refuse |
| Headless sets | Bounded independent world/schema batches, explicit dropout status and ordered IDs/units; incompatible action/schema/version requests refuse |
| Supplier/work | Known original work retained on raw failure/cancellation, replaced/reset ledgers or wrong source evidence refuse, no retry/fallback or partial row publication |

All exact prefix comparisons include physical scalar bit patterns, ordered contributor bytes, Runtime RNG and accepted sequence. Noise counters and queue floors must remain unchanged on failed or rejected acceptance. Retained owned immutable batches have an explicitly different lifetime from a checked borrowed lease.

## State, Ownership, and Lifecycle

Each test owns its compiled fixture, private session and exclusive work. Native race/shutdown tests coordinate through common Mutex/actor test resources; no cross-suite unprotected mutable globals. Fixtures close sessions/leases on success and failure. Statistical tests use fixed seeds and bounded draw counts, not nondeterministic timing. Public failure assertions inspect original causes and unavailable-work metadata rather than silently converting failures into success.

## Failure, Concurrency, and Constraints

Every test command has a watchdog. Producer Native tests qualify local behavior first; root performs actual original profiles after frozen source/design/test handoff. Native race evidence cannot be generalized to synchronous WASI parallel capability. The original Swift6.4.0/matching SDK and131072-byte stack remain unchanged; a source-level rich-error or wrapper-frame failure must be fixed causally rather than hidden with flags, tolerances or a larger stack.

## Verification and Change Impact

One scoped review and concrete finding-only rechecks converge this snapshot. The selected snapshot contains 29 test declarations across six suites, including actual classical RK4 and adaptive rejected-trial execution, full cold replay and Native shutdown races. The inherited observe test requires an immutable accepted-prefix query that leaves the active trial valid; sensor readBatch uses its separate mutation exclusion. Statistical evidence retains 512 fixed-seed samples with an explicit 4 MiB caller validation scratch envelope; this is a caller capacity, not a physical or statistical tolerance change. Raw provider/schema, checkpoint authority, pipeline state/lifecycle or interpolation changes reopen only their affected evidence. Root owns all manifest/index/PROGRESS/commit and integrated public artifacts.

The final Native evidence combines the first actual 29-declaration run (27 declarations green) with the two finding-only rechecks after the separately qualified original Runtime observer-exit correction. No unchanged test was rerun. The corrected isolated build completed with exit 0 in 130.605 seconds; the filtered test command completed with exit 0 in 20.652 seconds (two tests/two suites, actual test duration 3.930 seconds). Both use the original watchdogs (1200-second setup, 240-second behavior), four workers and the original compiler. The statistical contributor encoded 336,389 bytes, requiring 2,691,112 bytes under the declared eight-times payload reservation, within the explicit 4,194,304-byte caller scratch envelope. The scratch change does not change samples, physics or tolerances. Owned shared/private sources matched at execution start and end. These results qualify this selected Native path only; root owns actual WASM/Embedded execution and original stack proof.


## MM01 Merged-Main Lifecycle Gate Repair

The original merged-main run executed 1,573 tests in 324 suites and recorded four issues in two lifecycle tests. The test gate independently expired after three seconds, while the scheduling of parent shutdown assertions occurred about fifteen seconds after test entry. Its `.busy` failure released the active read/trial before the shutdown assertion. This is a test synchronization counterexample; the run does not establish a production lifecycle defect.

The Native-only gate retains logical state under `Mutex`. A condition notification signals actual callback entry and parks the synchronous callback until the parent explicitly opens the gate. The notification lock is acquired before checking the Mutex-protected predicate and by the opener before changing that predicate, preventing a check/wait lost wakeup. Waiting is bounded by the existing sixty-second suite budget, and the original test defer opens the barrier on normal completion or failure. The Native-only async entry method delegates to this synchronous condition wait; it creates no additional Tasks or continuations. No polling or scheduler-speed assertion supplies lifecycle evidence.

The original draining, closed/cancelled, accepted-prefix and exactly-once release assertions remain unchanged. Production sources, the immutable 2,361-source producer, test geometry and physical tolerances remain unchanged. The original full-suite RED is retained separately; the required closure is a focused lifecycle recheck followed by one corrected full registered suite run with the same fixed integration resource baseline.


The MM01 repair closes that counterexample with the original four lifecycle tests passing, followed by the complete registered Native suite: 1,573 tests in 324 suites passed. The incremental fixture setup completed in 3.038 seconds, focused execution in 1.116 seconds and full-suite process in 11.321 seconds (actual test duration 10.868 seconds). All original draining, closed/cancelled, accepted-state and release-once assertions remain unchanged; only `SensorTestGate.swift` executable bytes changed. The immutable production source/object/module/library set matched before and after both runs. The original full-suite RED remains separately preserved; no production defect or portable lifecycle qualification is inferred from it.

The private cumulative evidence imports and links the one fresh, testable 2,361-source producer compiled from merged commit `d6f0026cf88cd50e63fd297b509f27d1c51c25dc`. Its consumer preserves all 101 actual registered test-target and 23 support-target boundaries with 750 selected Swift fixtures. Native support/library minimum deployment is macOS 13, Swift Testing targets use macOS 14, and the existing Mutex methods retain body-level macOS 15 guards. Actual `swift test` passed; strict library signing passed, while strict test-bundle signing reported the pre-existing generated bundle resource/signature discrepancy. No resigning, direct MH_BUNDLE execution or inaccessible DYLD tracing is claimed. Root owns the durable integration record and main commit/push.
