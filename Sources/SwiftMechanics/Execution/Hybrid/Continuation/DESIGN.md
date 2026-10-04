# Accepted Hybrid Event State

## Purpose and Scope
Own a required Runtime event contributor with exact model/geometry/policy binding, accepted physical q/v/time association, event sequence and last-impact records. Parent: [MechanicsHybrid](../DESIGN.md). No children. Full DY006/TI005..006 remain IM24 after the admitted initial handoff.

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
Only accepted event/terminal state is encoded. Required completeness rejects missing/unknown/wrong-version/corrupt/truncated state. Hybrid entry/trial checks physical time/q/v association; Runtime record-only validation does not independently certify that association. Geometry/options/model migration requires explicit reset and fails until a provider certificate exists. Exact ordered event IDs at the last accepted impact and sequence enable deterministic same-build restart; no hidden event/warm cache exists.

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

The event payload binds model/revision, exact provider chart/geometry signature, sorted event IDs, geometric/impulse acceptance and event time/spacing policy, and accepted q/v/time. Integrator schema separately binds method/options/equation. Runtime's required validator receives only record/model and therefore proves structural payload validity; physical association is checked at Hybrid entry and publication. Pure isolated query states retain the source event record temporarily and are not world event publication. After a jump the public Integration initialRecord resets adaptive step/history at the exact accepted post-jump state; Runtime RNG and global accepted sequence are retained.

| Logical state | Native / ordinary WASM / Embedded storage | Isolation / mutation | Release |
|---|---|---|---|
| Cancellation | Mutex<Bool> in HybridCancellation | isCancelled / cancel via withLock | reference-owner deinit |
| Attempt ledger | uniquely owned HybridEvolutionWork | inout outside locks | operation scope |
| Event continuation | immutable contributor bytes | Runtime performTrial/restart | Runtime owner |

Selected cross-target runtime evidence is root-owned and pending at source freeze. No parallel-thread or allocator measurement is claimed.

### Preflight and history authority correction

Before creating a signature buffer, checked byte sums/products account for every fixed-width field, UTF-8 text, event ID, q/v entry and impulse scale, including maximum final record/schema payload. UTF-8 metadata traversal stops at the smaller caller identifier/remaining byte limit, examining at most that limit plus one byte. Caller-owned input arrays remain borrowed COW values; count rejection precedes sorting, traversal and buffer materialization. Only the proved byte size is reserved/materialized. Public capacity rejection is a behavioral proof of admission, not an allocator measurement.

Decoded HybridHistory retains the exact provider/model/geometry/policy signature as immutable backing. record compares that binding and validates carried q/v count, finite accepted/last time, group/last-time relationship and bounded sorted unique known IDs before constructing bytes. A foreign history, including an otherwise identical catalog with another provider or geometry/policy, is rejected at the generating API rather than delegated to later Runtime validation.
