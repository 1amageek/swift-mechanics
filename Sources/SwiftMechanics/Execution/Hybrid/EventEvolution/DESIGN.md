# Root Located Hybrid Evolution

## Purpose and Scope
Own bounded directed scalar root location, equal-time ordering, isolated real Runtime/Integration reintegration and accepted impact/terminal segmentation. Parent: [MechanicsHybrid](../DESIGN.md). No children. Full DY006/TI005..006 remain IM24 after the admitted initial handoff.

## Responsibilities and Boundaries
Own the preceding responsibility and immutable public artifacts. Runtime owns publication/lifecycle, Integration owns smooth stages, Dynamics owns mass/original inertial operators, Collision owns geometric witnesses and ContactLaws owns selected threshold restitution. Constraint/wake reconciliation is an IM16 consumer obligation.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Hybrid](../DESIGN.md) | parent | IM24 dispatch | Sole module composition | Full eventual domains retained |
| [Runtime](../../Runtime/DESIGN.md) | depends on | Required trials/checkpoint/contributors | Last accepted prefix | No nested Integration on outer owner |
| [Integration](../../Integration/DESIGN.md) | depends on | Actual Euclidean explicit reintegration | Isolated query owner | No dense-output guarantee |
| [Dynamics](../../../Physics/Dynamics/DESIGN.md) | depends on | Actual inverse mass/original action | Hard jump | No compliant force substitute |
| [Collision](../../../Physics/Collision/DESIGN.md) | depends on | Exact analytic witness | Actual root gap | Translation CCD is not curved trajectory |
| [ContactLaws](../../../Physics/ContactLaws/Impact/DESIGN.md) | depends on | Required impact prediction | Restitution/loss | No additional damping |
| [Tests](../../../../../Tests/MechanicsHybridTests/DESIGN.md) | verified by | Analytic jumps and bounce | Behavior proof | Selected profiles root-owned |

## Architecture
```text
accepted identified state -> independent trajectory query -> directed root/gap
 -> exact framed point row -> mass-based impulse -> original momentum/law/energy acceptance
 -> outer Runtime transaction -> accepted event history / retained failed prefix
```

## Contracts and Invariants
Initial evolution is pure smooth Euclidean trajectory queries with immutable shared model and exclusively owned temporary Runtime session per query. Query creates/checkpoints/restarts through actual required Runtime methods and invokes required ExplicitIntegrating; no dense output, linear interpolation or ballistic-as-translation-CCD is used. Source RNG and non-integrator contributors must remain unchanged. Concrete sphere-plane ballistic bracketing uses known constant acceleration only to choose monotonic search intervals/apex; actual gap samples and root acceptance come from Collision witnesses at independently reintegrated states. Bisection accepts only direction-compatible rate, caller time width and gap residual. Equal-time candidates group by explicit time tolerance and sort numeric event IDs. Simultaneous independent modes are solved as one jump; coupled modes remain unqualified. Every accepted smooth terminal or jump is one outer Runtime transaction; subsequent failure retains the most recent accepted segment, not the entire run initial state. No Integration.advance runs on the outer session inside its trial. Post-jump Integration.initialRecord explicitly resets adaptive history from actual new physical point/derivative; outer Runtime global sequence, RNG and other contributors are preserved. Event spacing/cascade/query/root budgets stop chatter; resting support is unqualified.

## Runtime Flows
Validate identity/domain/capacity -> operation-local bounded phases -> selected supplier witnesses -> independent original acceptance -> immutable result or typed failure. Non-inline phase boundaries return setup/root/impulse workspace before nested final Runtime validation; target-specific physics/memory fallbacks do not exist.

## State, Ownership, and Lifecycle
Immutable Sendable inputs/results/providers, exclusively owned inout ledgers/workspaces. Persistent event state is an explicit required contributor. Shared cancellation uses identical short Mutex<Bool> storage on all targets; attempt work/results are exclusively owned values; callbacks/supplier execution stay outside locks. Isolated query sessions explicitly shutdown after synchronous use; no queued ordering or global cache. Apple Runtime-dependent paths declare macOS15/iOS-tvOS18/watchOS11 availability.

## Failure, Concurrency, and Constraints
Caller provides count/byte/storage/iteration/operation/time/error limits. Hybrid query/root/event counts are separate from NumericalWork, CollisionWork, ContactWork and Integration charged-work reports. Successful supplier work remains in its original unit; failed unavailable work is marked and stops without retry. Bounded phases preserve all source inputs. Allocations/COW and wall-time latency are unmeasured; no performance claim follows from owned buffers or Sendable. Invalid revisions/direction/root, unresolved impulse, unsupported physics, capacity/cascade/spacing exhaustion and cancellation fail with actual accepted prefix.

## Verification and Change Impact
[Test owner](../../../../../Tests/MechanicsHybridTests/DESIGN.md) proves analytic momentum/restitution/energy, independent simultaneous modes/order, real bounce time and height/trajectory, restart equivalence, stale geometry/model, nonfinite/coupled mode, rejected jump/continuation and resource/cancel/last-prefix boundaries. Root proves exact selected Native/WASM/Embedded public execution. Domain/frame/impulse/continuation changes invalidate downstream impact derivatives, sensors and constrained wake consumers.

### Actual service and proof boundary

| Component | Actual selected production entry | Behavioral owner |
|---|---|---|
| ImpactPorts | ImpactPortAdapting.prepare / RigidHardImpactAdapter | HybridImpulseTests |
| NormalImpulse | NormalImpulseSolving.solve / IndependentNormalImpulseSolver | HybridImpulseTests |
| EventEvolution | HybridEvolving.advance / ReferenceHybridEvolution; required trajectory/environment witnesses | HybridEvolutionTests |
| Continuation | HybridContinuationProvider and HybridContributors required validation | HybridEvolutionTests |

No build/runtime qualification is inferred from these declarations. The root owns actual selected Native/ordinary WASM/Embedded qualification. Full simultaneous coupled, frictional, general event/manifold, support reconciliation, and nonsmooth time stepping remain IM24 obligations.

The concrete closed environment is a fixed spatial static root and one dynamic, aligned, world-Z prismatic sphere under supplied constant downward SI acceleration, colliding with the root's horizontal half-space. The ODE explicitly owns q'=v and v'=a for this chart. Apex time selects the monotone closing search interval; every root sample executes actual isolated Integration and analytic Collision witnesses. No ballistic closed-form trajectory value or dense output replaces reintegration. Resting/initial closing boundary evolution fails until support or initial-impact policy is implemented.

`HybridEventEnvironment.brackets` is the provider's complete crossing-coverage certificate for its published model/chart configuration. Generic environments must reject uncertified/non-monotone intervals rather than return an empty catalog. The generic engine checks directed bracketing, finite samples, both SI time and gap acceptance, and common-time samples for simultaneous groups; hard coupled groups fail. Each isolated owner has at most one synchronous query lifetime; `maximumQueries` bounds total owner creation, and each query carries its Integration budget. Query reports remain in separate outer arithmetic, supplier arithmetic and derivative-call units; no measured allocator or wall-time claim is made.

`advance` commits each event jump and the eventual terminal smooth segment separately. Any failure retains the actual last accepted segment, so a later failure cannot roll back earlier accepted impacts. During final trial, physical q/v/time and integrator/event records must still match the searched prefix. Unrelated current RNG/non-integrator records are preserved by Runtime; pure admitted equations do not depend on them. Public session accepted sequence is never imported from isolated query counters. A supplied cancellation token bounds root/query loops and the concrete derivative; session shutdown/busy rules remain Runtime's authority.

### Preflight and history authority correction

Before creating a signature buffer, checked byte sums/products account for every fixed-width field, UTF-8 text, event ID, q/v entry and impulse scale, including maximum final record/schema payload. UTF-8 metadata traversal stops at the smaller caller identifier/remaining byte limit, examining at most that limit plus one byte. Caller-owned input arrays remain borrowed COW values; count rejection precedes sorting, traversal and buffer materialization. Only the proved byte size is reserved/materialized. Public capacity rejection is a behavioral proof of admission, not an allocator measurement.

Decoded HybridHistory retains the exact provider/model/geometry/policy signature as immutable backing. record compares that binding and validates carried q/v count, finite accepted/last time, group/last-time relationship and bounded sorted unique known IDs before constructing bytes. A foreign history, including an otherwise identical catalog with another provider or geometry/policy, is rejected at the generating API rather than delegated to later Runtime validation.

### Portable trajectory/impact phase lifetime

Actual original-profile Native qualification passed 15 tests and the public probe. Both ordinary WASM and Embedded public execution then trapped during nested Runtime trajectory admission. Instruction-identical diagnostic artifacts with privately relocated larger stack completed the analytic/replay/cancel checks; that diagnostic is excluded from supported-profile evidence. Original ordinary fixed frames included advance 19,088, computeSegment 31,680, locate 11,312, hybrid query 7,968, isolated query 20,944, session init 6,288 and admission 32,624 bytes before lower calls; Embedded corresponding Hybrid frames were 21,152 / 35,888 / 13,104 / 8,896 / 23,920. These measurements identify overlapping phase lifetimes, not an allocator or future-frame guarantee.

```text
computeSegment
  -> selectEvent (root brackets, located-array, common-time selection)
  <- SelectedHybridEvents (owned checkpoint backing + sorted IDs only)
  -> impactSegment (geometry/mass/jump/post-jump history workspace)

isolated query
  -> preparedOwner -> createOwner -> Runtime init (same owner)
                   -> restartOwner -> exact checkpoint/RNG/contributors
  <- prepared owner
  -> integrateOwner -> actual Integration -> immutable captured outcome
  -> validateResult -> exact guards/report
  <- result
  -> defer shutdown (same owner, including failure)
```

Required public methods and equations stay unchanged. @inline(never) boundaries end root-selection work before impact setup, and end construction/restart temporaries before integration/result-validation temporaries. Local checkpoint/row arrays remain COW-owned; selected backing outlives the selection method only because the returned immutable value owns it. Existing direction/order/chatter, supplier ledgers, failure-prefix, RNG/contributor and cancellation checks retain their sequence. Original-profile requalification is pending root execution; no source target branch or memory-profile fallback is introduced.

### Measured second lifetime boundary

The first phase extraction preserved Native 15 and Native public execution but both original WASM profiles still trapped. The exact Embedded live trace accounts for 145,152 static bytes (>128 KiB): advance 21,152, compute 3,904, select 14,672, locate 13,104, Hybrid query 8,896, isolated query 2,000, preparedOwner 8,048, createOwner 2,672, Runtime init 5,328, admission 33,712, tree evaluator 17,088, and root bounce 9,664, plus other measured trace frames. Producer/profile changes remain excluded.

The next closed boundaries target only these measured callers: outer advance reports the operation-owned work and calls a run loop; each segment separately owns source/history/compute/publish; selection separately accumulates roots then certifies common time; endpoint queries finish before endpoint geometric checks, which finish before midpoint refinement; charged trajectory invocation finishes before candidate verification. The endpoint order stays low query, high query, low sample, high sample, including failure work. No measured new frame reduction is claimed before root executes the original artifact/profile. Root owns its independent probe assertion lifetime split.

### Measured trial-path lifetime correction

Second extraction preserved Native 15/public behavior. Original WASM then reached a new deeper Integration trial path with 130,016 static caller bytes before lower allocation. Ordinary/Embedded instruction-identical relocated diagnostic copies again passed all checks and remain excluded from qualification. Owned measured Embedded frames included advance 11,104; runSegments 3,328; oneSegment 7,664; compute 3,904; select 2,000; collectRoots 6,256; locate 3,392; readEndpoints 2,416; query 3,328; chargedQuery 2,848; isolated query 2,000; advanceOwner 5,296; integrateOwner 2,672. Verified supplier frames (Integration.run 22,864, Runtime trial 15,232, executeTrial 26,064) remain unchanged.

Failure bookkeeping/failed report absorption/accepted-prefix construction now lives in a non-inline failure-only method, so its future temporaries do not belong to the live successful loop. HybridStepContext and HybridStepResult are immutable final Sendable reference owners: each attempted segment owns one source/history context, and each completed segment owns one accepted outcome; no mutable ledger is stored in either owner. Context/outcome backing is retained by ordinary strong ownership and released outside Runtime metadata locks. Their actual count is bounded by admitted segments/event capacity and terminal/failure exit. All targets use the same declarations; no unchecked conformance, lock removal or target fallback is introduced. Existing external public value results, contributor wire format, arithmetic and prefix semantics are unchanged. New frame margin/allocator reduction is not claimed until original-profile root execution.

### Coherent checkpoint/result ownership boundary

The third extraction still failed original WASM execution in the deeper Integration history decoder. The root measured approximately 131,584 static caller bytes before allocation, including the newly exposed 6,896-byte supplier history frame. Earlier relocated artifacts are causal diagnostics only. The closed correction carries the existing immutable source/history context by reference through internal root phases and returns immutable reference owners for checkpoint, endpoint, located event, selected event, segment and completed run artifacts. Only required public supplier boundaries unpack the physical checkpoint value. Internal Integration-result capture is a reference owner returned before candidate validation; outer successful public-result assembly occurs after the run completes. This targets accumulated value argument/return buffers across the measured chain as one change. No new stack margin is asserted without the root's original-profile execution.

All new owners are final Sendable classes with exclusively let fields. They retain validated COW backing, never own mutable work or a callback, and have no target-dependent declarations. The source context lasts one segment, endpoints last endpoint admission only, located owners are bounded by catalog count, and a selected/segment/completed outcome has one synchronous phase lifetime. The public value API and contributor wire format remain unchanged. Reference allocations are structurally bounded by admitted query/root/catalog/segment counts, but allocator/copy measurements remain unavailable. Required query order, actual reintegration, cancellation, supplier accounting, momentum/law acceptance and one-segment accepted-prefix semantics are unchanged.
