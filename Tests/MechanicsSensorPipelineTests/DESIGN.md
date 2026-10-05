# Sensor Pipeline Behavioral Evidence

## Purpose and Scope

Parent/tested production contract: [SensorPipeline](../../Sources/SwiftMechanics/Analysis/Observations/SensorPipeline/DESIGN.md). Children: none. Own fine-grained behavioral evidence for the selected SE-005..008 and sensor RT-003/006 path. Root owns registration, full integration and original Native/WASM/Embedded public execution. This design fixes proof obligations; no tests or behavior are qualified yet.

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

One scoped review and concrete finding-only rechecks converge this snapshot. No test declarations, build or execution exist at this design handoff. Raw provider/schema, checkpoint authority, pipeline state/lifecycle or interpolation changes reopen only their affected evidence. Root owns all manifest/index/PROGRESS/commit and integrated public artifacts.
