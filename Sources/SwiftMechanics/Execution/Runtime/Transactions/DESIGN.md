# Synchronous Trial Transactions

## Purpose and Scope
Own uniquely operation-owned mutable trial/workspace and bounded safe-point control. Parent: [MechanicsRuntime](../DESIGN.md). No children.

## Responsibilities and Boundaries
Trial changes affect local fixed-shape arrays, complete prescribed-anchor samples and explicit contributor/random values only. Consumer callbacks own integration/solver/prescribed-motion laws and invoke safe points before bounded work blocks; runtime owns acceptance validation and never supplies a default step law.

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
RuntimeTrial construction consumes a session-issued immutable creation token. Reset and RuntimeStepControl construction consume a session-issued immutable operation token binding the exact accepted prefix and cancellation source. Explicit fileprivate token initializers in RuntimeSession.swift prevent raw creation/reset/binding by unrelated components in the shared module. Private q/v/acceleration/contributor/random storage and existing final identity checks remain authoritative.

`position(at:)`, `velocity(at:)` and `acceleration(at:)` return the current operation-owned scalar; each rejects an index outside its exact fixed buffer with `.invalidInput`. Reads expose no mutable storage and retain the same Native/WASM/Embedded ownership contract.

q/v/acceleration buffer lengths are fixed at owner creation and setters reject wrong indices/nonfinite values. Time must not move backwards on acceptance; reject discards every contributor/random/physical change. Contributor replacement is keyed by schema ID and byte limits; records remain values.

Trial owns a private anchor array copied from the admitted prefix, with fixed count and frame set. `prescribedAnchor(_ frame:)` returns one safe owned value and `setPrescribedAnchor(_ sample:)` replaces an existing named sample; neither adds/removes a frame nor exposes raw storage. Setter bounds frame metadata before lookup. Source initialization, every reset after accept/reject/failure/restart, and candidate checkpoint preserve all sample fields and accepted ordering. Consumers may update time and samples in either order while constructing a local candidate; actual compiled-tree admission requires every final sample time to equal candidate physical time and the exact expected frame set. No stale sample is refreshed implicitly. Workspace replacement changes shape only after complete new-model admission.

RuntimeStepControl owns a Sendable cancellation source with the same Mutex<ControlState> on all targets. beginWorkBlock polls cancellation/Task state before admitting a caller-declared bounded quantum and total work; runtime also polls before/after callbacks and between admission phases. Consumers must implement a published work-unit bound for each block; a wall-clock latency claim is not inferred. Copies of a control share its authoritative work counter; replacing a trial/control from another ticket fails final identity binding. Control retained after a transaction is cancelled, so it cannot authorize later work. No raw target-specific storage or unsafe pointer view is exposed.

Reserved scalar slots and structural physical-copy envelope use the [StateRecords physical accounting contract](../StateRecords/DESIGN.md#contracts-and-invariants). COW copies can occur when a previous accepted snapshot retains arrays, necessarily preserving immutable observation lifetime. This is structural accounting, not measured allocator traffic. Compiler's actual tree validation allocates its own policy-bounded workspace. RT-007's measured steady-state allocation/copy qualification remains open; no zero-allocation claim is made.

## State, Ownership, and Lifecycle
Immutable records are Sendable value owners. Mutable work lives in an exclusive inout transaction; shared metadata/cancellation state uses identical Mutex storage on every target. Native/WASM/Embedded semantics are qualified only by selected actual target paths.

## Failure, Concurrency, and Constraints
Typed RuntimeFailure identifies domain, missing contributor, incompatible model/continuation, capacity, busy/closed/cancelled or validation failure. Session failures retain last accepted prefix. Limits precede allocation and publication is all-or-nothing. No silent fallback or unimplemented success.

## Verification and Change Impact
[Test owner](../../../../../Tests/MechanicsRuntimeTests/DESIGN.md): Trial/reject/accept and RNG/history rollback, invalid q index/chart/time, safe-point cancellation/work exhaustion. Consumers IM09/12/14/24/29 must supply actual laws and all contributor state.
