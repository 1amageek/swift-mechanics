# Runtime Execution Evidence

## Purpose and Scope
Own explicit determinism qualification, bounded independent world creation/seed derivation and truthful runtime profile queries. Parent: [MechanicsRuntime](../DESIGN.md). No children.

## Responsibilities and Boundaries
Same-build seeded replay is admitted for this local closed transaction domain. Cross-platform numerical equivalence/bitwise portability and full phase profiling require separate measured workload evidence and fail when requested. This component does not execute dynamics or integrations.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Runtime](../DESIGN.md) | parent | Initial runtime scope | Root composition | Full requirement family remains IM08 |
| [Sessions](../Sessions/DESIGN.md) | depends on | Independent state owner construction/query | Batch ownership | Each state has separate Mutex/workspace/history
| [State records](../StateRecords/DESIGN.md) | depends on | Seed/RNG and capacity | Published derivation | No global random state |

## Architecture
```text
root seed + world index -> published SplitMix64 derivation -> bounded independent sessions
session operation counters + reserved slots + workload identity -> evidence report
requested stronger determinism/measured full-phase profile -> explicit unsupported/unavailable failure
```

## Contracts and Invariants
Batch creation rejects count above caller capacity before constructing owners; a failure returns no partial batch. Shared model is immutable; each owner has distinct accepted random/history/workspace and release lifetime. World seed derives deterministically from root seed and UInt64 index using SplitMix64 constants/mixing; repeated batch and sequential creation match.

Profile reports actual transaction counters, reserved scalar slot count, structural physical-scalar bound per single COW buffer detachment and workload identity. The detachment bound is q+2v; callback-created trial copies may trigger arbitrarily many detachments, so no per-trial allocation/copy measurement is claimed. Compilation/collision/solve/integration/output duration, allocation instrumentation and residual measurement are explicitly unavailable in this baseline; requiring measured end-to-end profiling is a typed failure. No fabricated zeros/timing/residuals or marketing feature flags grant success. Numerical equivalence and bitwise target-pair claims remain unqualified; same-build tests do not generalize to another build/backend.

## State, Ownership, and Lifecycle
Immutable records are Sendable value owners. Mutable work lives in an exclusive inout transaction; shared metadata/cancellation state uses identical Mutex storage on every target. Native/WASM/Embedded semantics are qualified only by selected actual target paths.

## Failure, Concurrency, and Constraints
Typed RuntimeFailure identifies domain, missing contributor, incompatible model/continuation, capacity, busy/closed/cancelled or validation failure. Session failures retain last accepted prefix. Limits precede allocation and publication is all-or-nothing. No silent fallback or unimplemented success.

## Verification and Change Impact
[Test owner](../../../../../Tests/MechanicsRuntimeTests/DESIGN.md): Parallel vs sequential independent worlds, capacity/no-partial batch and identical seed derivation/replay; stronger tier/profile request failures. RT-007/008/004 cross-platform requirements retain explicit future workload/measurement obligations.
