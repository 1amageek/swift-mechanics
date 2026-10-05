# Serialized Runtime State Owners

## Purpose and Scope
Own synchronous shared owner metadata, exclusive workspace checkout, transactional publication, observation leases and shutdown/release. Parent: [MechanicsRuntime](../DESIGN.md). No children.

## Responsibilities and Boundaries
One session shares immutable model and accepted snapshots, but owns its workspace/history exclusively. Ordered synchronous operations use a single Mutex<Metadata>; no async stream or I/O is owned in this initial domain. External callbacks, validators, codec operations and resource release run outside locks.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Runtime](../DESIGN.md) | parent | Initial runtime scope | Root composition | Full requirement family remains IM08 |
| [Transactions](../Transactions/DESIGN.md) | depends on | Local trial and cancellation safe points | Checked-out workspace | Consumer callbacks cannot mutate accepted state
| [Checkpoints](../Checkpoints/DESIGN.md) | depends on | Complete admission/codec contract | Initial/restart/accept validation | No partial publication
| [State records](../StateRecords/DESIGN.md) | depends on | Immutable snapshots | Observation lifetime | Retaining snapshots can retain COW storage |

## Architecture
```text
idle -> ticket + workspace checkout -> running callback/admission outside lock
 -> finish(ticket + model + cancel/close checks) -> publish accepted / retain last prefix -> idle
shutdown during work/observation -> closing + cancel -> final lease exits -> closed + release once
```

## Contracts and Invariants
RuntimeSession.swift exclusively issues immutable workspace-creation and operation-binding tokens through explicit fileprivate initializers. Initial and replacement workspaces consume the creation token after complete accepted-state verification; RuntimeSessionMetadata receives an already-created workspace. Trial reset and control creation consume the operation token carrying the exact accepted prefix and cancellation source of the checked-out ticket. Tokens never escape via public results; callbacks cannot manufacture or rebind an owner ticket.

`RuntimeModelReplacing.replaceModel` is an accepted-boundary compare-and-replace operation owned by the session. The immutable request supplies the complete expected source checkpoint, target compiled model, explicit target kinematic state/contributor records/configuration and required checkpoint handler. The model identity remains the same, revision strictly increases and physical time equals the last accepted time. Continuation identity, determinism tier and owner capacities remain unchanged; schemas/workload and chart may change explicitly. Runtime preserves the source RNG exactly and increments the global accepted sequence once; it performs no guessed physical migration. The mechanism owner proves momentum/energy/frame/pose reconciliation before requesting publication. Target complete admission and target workspace allocation happen outside locks. Current source data is bounded before exact comparison. Stale source, unsupported compatibility, missing/invalid target contributors, invalid target physical state, capacity, cancellation, busy or shutdown returns failure with the original complete prefix. On success model/configuration/handler/accepted state/workspace/scalar count switch together under the same publication lock. Every subsequent trial/restart captures one immutable model/configuration/handler context in its lease; checkpoint export captures the accepted state and uses the unchanged owner capacity. Old context/accepted/workspace owners stay retained by the operation lease until outside the lock. Retained pre-transition snapshots remain readable. No changed-capacity/backend transition is silently admitted.

Mutex-dependent entry points require macOS 15, iOS/tvOS 18 or watchOS 11 on Apple platforms. WASM/Embedded use their selected Synchronization implementation. Same storage/isolation/Sendable/entry points apply on Native/WASM/Embedded. Every stored mutable metadata field is inside Mutex<Metadata>; every active control's cancel bit and admitted work counter are inside Mutex<ControlState>. The ordering contract is linearized synchronous try-admission/publication, not queued multi-step scheduling; only short metadata updates use Mutex and complex work is an exclusive operation-local value. An actor would be the owner for a future suspending/queued lifetime. Operations are synchronous non-queuing try-operations with no FIFO/waiting-order guarantee. Exactly one mutating operation may run; reentry/concurrent mutation returns busy with last accepted prefix. snapshot() remains a consistent immutable query during work/closed states. Observation callbacks use bounded leases; mutations during an observation callback return busy, and shutdown waits for its lease exit by reporting draining.

finish checks active ticket, original model stamp and cancel/closing state under the publication lock; a callback result is never authority to commit after shutdown/cancel. Reject/error/cancellation never changes accepted physical/contributor/random state. shutdown is a nonblocking request: closed if quiescent, draining while an active operation/observation remains; the last exit marks closed and invokes the release hook exactly once outside locks. deinit requests the same idempotent release. Resource-hook ownership transfers at construction entry; failed admission invokes it once before returning failure. Consumers requiring asynchronous drain notification/AsyncStream must extend this owner contract and prove stream finish separately; none is declared here.

An observation may read the last accepted prefix while a mutating operation is active. Ending a successful or failed ordinary observation must not cancel that operation. A lifecycle release action carries an active cancellation source only when shutdown has marked the owner closing; the action is applied outside the metadata lock. The closing/draining path still cancels active work immediately, and the last lease exit still retires backing and releases exactly once. Explicit cancel and operation-finish cancellation remain unchanged.

Resource hook is @Sendable and may reenter queries/shutdown; it cannot deadlock or release twice. Retained observations own immutable values, not an escaping pointer. Workspace checkout removes owner storage before outside work and restores it on every exit. Metadata critical sections only copy ownership headers and update bounded counters; copying large array elements, callbacks and validation remain outside. Replaced/closed backing storage is retained in returned operation-local retirement values and released after leaving the lock; old accepted state stays retained by the active lease. Session deinit releases retained accepted backing after the metadata lock has exited.

## State, Ownership, and Lifecycle
Complete anchor samples follow the same accepted-prefix/workspace lifetime as q/v/a. Session reservation/profile and bounded replacement comparison use [StateRecords physical and metadata accounting](../StateRecords/DESIGN.md#contracts-and-invariants). Required checkpoint handling remains outside locks and actual model.makeState owns frame-set/time validation. Restart restores all physical fields before the next reset; no target-conditioned anchor owner or alternate lock path exists.

Final required-handler verification and expected-source replacement comparison retain complete checkpoint equality and additionally compare exact physical scalar bit patterns, including time/q/v/a and all ordered anchor fields. Shape/scalar/metadata bounds precede that traversal. Numerically equivalent signed zeros or quaternion signs cannot substitute another saved prefix or alter requested publication data. This comparison is Runtime publication authority, not a general numerical equality policy.

Immutable records are Sendable value owners. Mutable work lives in an exclusive inout transaction; shared metadata/cancellation state uses identical Mutex storage on every target. Native/WASM/Embedded semantics are qualified only by selected actual target paths.

## Failure, Concurrency, and Constraints
Typed RuntimeFailure identifies domain, missing contributor, incompatible model/continuation, capacity, busy/closed/cancelled or validation failure. Session failures retain last accepted prefix. Limits precede allocation and publication is all-or-nothing. No silent fallback or unimplemented success.

## Verification and Change Impact
[Test owner](../../../../../Tests/MechanicsRuntimeTests/DESIGN.md): Native concurrent independent owners, busy/reentry, last accepted query during trial, cancel/shutdown while callback waits, observation shutdown/reentry, release once/deinit and transactional restart failure. Root separately qualifies exact selected WASM/Embedded lifecycle and actual available concurrency semantics.

Shared-state matrix (same declarations on all three profiles):

| Logical state | Native / WASM / Embedded storage | Read | Mutation | Release |
|---|---|---|---|---|
| Session accepted/phase/ticket/workspace/observers/counters | Mutex<Metadata> | snapshot/profile/status | acquire/finish/cancel/shutdown/observation lease | returned retirement outside lock; accepted backing at owner destruction outside lock |
| Session current model/configuration/required handler | Same Mutex<Metadata> holding immutable context owner | configuration/profile/lease capture | successful replaceModel publication only | old context retained by operation lease, release outside lock |
| Active ticket cancellation/work budget | Mutex<ControlState> | check/workUnits | cancel/admitWork | retained controls own source; ticket exit cancels it |

Native race/lifecycle tests and root-selected exact target probes establish only exercised paths; actual WASM/Embedded parallel capability is never inferred from Sendable/Mutex compilation.

The additive model-replacement path passed five dedicated Native behavioral tests within twenty-one Runtime tests, including concurrent cancellation/shutdown and old-handler deinit reentry. The unchanged owner operations were exercised in that same run. Root original-profile Native, ordinary WASM and Embedded WASM probes compiled, linked and exited 0 for required replaceModel witness, actual hinge-to-sixDOF target/configuration/schema/handler switch, target trial, checkpoint/restart, source RNG/sequence and stale-source rejection. Exact swift-6.4.0-RELEASE/matching SDK and original stack profiles were used. Race/lifetime evidence is Native only; synchronous WASI does not prove actual parallel execution. This is Runtime atomic-owner evidence, not mechanical break conservation.

### AF31 observation lease cancellation repair

The concrete defect is the non-closing closeIfQuiescent action returning activeSource to apply, which cancels it after an ordinary observation. The selected correction changes only that action's source selection. RuntimeSessionsTests.ordinaryObservationExitPreservesActiveTrialCancellationSource executes both successful and failed observations inside a genuine active trial, then requires another admitted work safe point and original physical publication. Existing RuntimeSessionsTests own explicit cancellation, shutdown draining, observation shutdown and exactly-once release regression. Independent RED/GREEN execution uses committed625f759 with only the owned repair/test overlay; the test design records actual RED failure and GREEN6-case Native lifecycle evidence. Shared-state declarations and the matrix above remain identical on every target.

### AR01 owner qualification
Session workspace and operation tokens are issued only by the checked owner file. Actual Native acceptance/rejection/restart/replacement and lifecycle/race tests preserve publication and release behavior. Existing shared-state matrix remains unchanged; synchronous WASI does not prove multithread races. Integrated test, foreign-access refusal and public profile evidence are owned by [root integration](../../../../../DESIGN.md#ar01-integrated-qualification-2026-10-04) and [FoundationVerification](../../../../../Verification/FoundationVerification/DESIGN.md#ar01-public-profile-execution).
