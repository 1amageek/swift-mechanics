# Synchronous Trial Transactions

## Purpose and Scope
Own uniquely operation-owned mutable trial/workspace and bounded safe-point control. Parent: [MechanicsRuntime](../DESIGN.md). No children.

## Responsibilities and Boundaries
Trial changes affect local fixed-shape arrays and explicit contributor/random values only. Consumer callbacks own integration/solver laws and invoke safe points before bounded work blocks; runtime owns acceptance validation and never supplies a default step law.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Runtime](../DESIGN.md) | parent | Initial runtime scope | Root composition | Full requirement family remains IM08 |
| [State records](../StateRecords/DESIGN.md) | depends on | Accepted immutable state and capacity | Trial source | No accepted-array mutation
| [Sessions](../Sessions/DESIGN.md) | used by | Exclusive workspace checkout and commit ticket | Serialize owners | All callbacks run outside locks |

## Architecture
```text
accepted snapshot + checked-out reserved workspace -> local inout RuntimeTrial
 -> consumer law + RuntimeStepControl -> accept/reject decision -> candidate checkpoint
```

## Contracts and Invariants
q/v/acceleration buffer lengths are fixed at owner creation and setters reject wrong indices/nonfinite values. Time must not move backwards on acceptance; reject discards every contributor/random/physical change. Contributor replacement is keyed by schema ID and byte limits; records remain values.

RuntimeStepControl owns a Sendable cancellation source with the same Mutex<ControlState> on all targets. beginWorkBlock polls cancellation/Task state before admitting a caller-declared bounded quantum and total work; runtime also polls before/after callbacks and between admission phases. Consumers must implement a published work-unit bound for each block; a wall-clock latency claim is not inferred. Copies of a control share its authoritative work counter; replacing a trial/control from another ticket fails final identity binding. Control retained after a transaction is cancelled, so it cannot authorize later work. No raw target-specific storage or unsafe pointer view is exposed.

Reserved scalar slots are exact q+2v. COW copies can occur when a previous accepted snapshot retains arrays, necessarily preserving immutable observation lifetime. Physical scalar copy upper bound is q+2v per next buffer mutation; this is structural accounting, not measured allocator traffic. Compiler's actual tree validation allocates its own policy-bounded workspace. RT-007's measured steady-state allocation/copy qualification remains open; no zero-allocation claim is made.

## State, Ownership, and Lifecycle
Immutable records are Sendable value owners. Mutable work lives in an exclusive inout transaction; shared metadata/cancellation state uses identical Mutex storage on every target. Native/WASM/Embedded semantics are qualified only by selected actual target paths.

## Failure, Concurrency, and Constraints
Typed RuntimeFailure identifies domain, missing contributor, incompatible model/continuation, capacity, busy/closed/cancelled or validation failure. Session failures retain last accepted prefix. Limits precede allocation and publication is all-or-nothing. No silent fallback or unimplemented success.

## Verification and Change Impact
[Test owner](../../../Tests/MechanicsRuntimeTests/DESIGN.md): Trial/reject/accept and RNG/history rollback, invalid q index/chart/time, safe-point cancellation/work exhaustion. Consumers IM09/12/14/24/29 must supply actual laws and all contributor state.
