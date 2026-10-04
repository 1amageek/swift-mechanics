# StationaryLoads

## Purpose and Scope
Planned AF23 component; no production implementation or qualification is claimed. Parent: [Mechanisms](../DESIGN.md); no children. Own a bounded immutable catalog of time-invariant physical loads, accepted-selection binding, and explicit logical load-work execution receipts. Uniform spatial gravity and scalar polynomial passive laws are the initial domain. Full RB-007 still requires the separate contact, topology, floating/planar and general-time load domains.

## Responsibilities and Boundaries
Catalog authority is explicit data, not an arbitrary callback's stationarity assertion. Existing Loads owns force/potential/dissipation equations; Dynamics owns spatial mapping and original mass/force acceptance; AffineEvolution owns constrained physical motion; SleepContinuation owns accepted selection and wake publication. This component owns canonical catalog bytes, selection lookup, load dependency support and load invocation accounting. It never mutates a Runtime accepted state or draws RNG.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Mechanisms](../DESIGN.md) | parent | IM16/RB-007 scope | Composition owner | Parent owns registration |
| [PassiveLaws](../../Loads/PassiveLaws/DESIGN.md) | depends on | AffineGravity, PolynomialSpringDamper, ScalarLoadEvaluating, LoadWork | Actual immutable physical laws | Gravity describes one instant; this catalog separately admits time invariance |
| [Dynamics](../../Dynamics/DESIGN.md) | depends on | RigidDynamicsInput gravity/generalizedForces, original rigid assembly | Actual loaded equation | Uniform spatial gravity only |
| [AffineEvolution](../AffineEvolution/DESIGN.md) | used by | planned shared loaded-motion requirement | Active/equilibrium/wake physics | Preserve zero-load facade |
| [SleepContinuation](../SleepContinuation/DESIGN.md) | used by | selection/history and operation receipts | Accepted authority | No hidden external selection |
| [Runtime](../../../Execution/Runtime/DESIGN.md) | coordinates with | validation budgets and actual checkpoint publication | Validation accounting boundary | Lower admission proof must finish before implementation |
| [Tests](../../../../../Tests/MechanicsSleepMechanismTests/DESIGN.md) | verified by | planned loaded physical/replay oracles | Actual proof | No tests executed for AF23 |

## Architecture
```text
bounded immutable catalog -> exact program/version lookup -> immutable selection snapshot
  -> ScalarLoadEvaluator -> aggregate generalized applied contribution
  -> selected AffineGravity value -> real RigidEquationKernel gravity evaluation
operation-local execution owner -> bounded invocation lease -> exclusive local LoadWork
  -> success/failure guard -> explicit receipt; callback outside Mutex
```

## Contracts and Invariants
### Planned data contracts
These names and signatures are the production contract proposal, not existing APIs.

| Type | Owned immutable data / admission |
|---|---|
| StationaryLoadCapacity | Positive maximumPrograms, maximumTermsPerProgram, maximumCoordinates and maximumMetadataBytes; checked canonical byte/word limits before allocation |
| StationaryScalarLoad | Stable term ID, coordinate ID, scalar dimension/kind and exact PolynomialSpringDamper coefficients/domains; coordinate resolves through the bound public layout |
| StationaryLoadProgram | Stable ID/revision, optional AffineGravity and bounded scalar terms. Gravity frame equals model world frame; gradient and uniformTimeDerivative are exactly zero. No arbitrary force/medium callback |
| StationaryLoadCatalog | ModelStamp, exact coordinate layout/frame, canonical ordered programs and capacity. Reject duplicate IDs/versions, invalid coordinate/dimension, overflow and out-of-domain laws |
| StationaryLoadSelection | Program ID/revision and UInt64 generation; exact lookup in the admitted catalog. Generation overflow/change is checked by the accepted-state owner |
| StationaryLoadSample | Bound catalog/program identity, physical model/layout/time/q/v association, unchanged selected gravity, one aggregated GeneralizedForceContribution with force/potential/dissipation, structural dependency coordinate IDs |
| StationaryLoadWorkReport | Explicit scope (equationExecution or checkpointAdmission), admission status (notAdmitted/admitted), caller logical maximumWork/maximumScalars, consumed units, peakScalars, invocationsStarted/completed, maximumInvocations, failedSupplierWorkUnavailable. Counts include known work on failed calls. No numerical arithmetic counter is synthesized |

Catalog serialization uses exact finite scalar bit patterns, IDs, versions, coordinate IDs/dimensions, gravity values and every law coefficient/domain. Its bounded canonical signature binds the ODE chart; accepted records additionally bind the selected version/generation. Zero coefficients, zero instantaneous forces and zero gravity vectors retain their structural dependencies. Scalar terms depend on their declared coordinate. Gravity support is the union of ancestor joint coordinates of admitted inertial bodies, resolved from public tree.joints/layout; no private parent indices or sampled-zero inference. Whole-mechanism wake is a valid conservative closure.

### Planned public operations
```swift
public protocol StationaryLoadEvaluating: Sendable {
    func evaluate(_ program: StationaryLoadProgram, catalog: StationaryLoadCatalog,
                  physical: KinematicState, work: inout LoadWork)
        throws(StationaryLoadError) -> StationaryLoadSample
}
public protocol StationaryLoadExecuting: Sendable {
    func beginInvocation() throws(StationaryLoadError) -> StationaryLoadInvocation
    func finishInvocation(_ invocation: StationaryLoadInvocation, work: LoadWork,
                          failedSupplierWorkUnavailable: Bool) throws(StationaryLoadError)
    func report() -> StationaryLoadWorkReport
    func close() -> StationaryLoadWorkReport
}
```
ReferenceStationaryLoadEvaluator evaluates actual scalar laws and aggregates their applied force/potential/dissipation. It passes selected gravity unchanged to Dynamics; it does not duplicate COM gravity or pretend that generalized command values are gravity. StationaryLoadExecution is a final Sendable operation-local owner initialized with explicit scope, caller LoadBudget, maximumInvocations K and the admitted n-scalar aggregation reservation. StationaryLoadInvocation is an opaque immutable identity-bound lease retaining its owner, admitted initial LoadWork and captured cancellation authority. Public construction cannot forge an invocation. `finishInvocation` accepts a lease exactly once and verifies its owner/ticket before consuming the supplied work. Supplier output remains cooperative, not sandboxed; monotone fabricated work is not claimed detectable.

StationaryLoadError owns invalidInput, invalidCatalog, staleBinding, capacity, invocationLimit, busy, cancelled, supplierLedgerFailure, unsupportedDomain and loads(LoadError). Invocation ledger corruption restores the known prefix, records unavailable work and stops the operation without retry. A preflight notAdmitted receipt retains the literal requested limits and zero executed load counters, rather than normalizing an invalid K to a different admitted limit. Caller reporting uses a report even when physical evaluation fails; a RuntimeFailure bridge preserves cancellation and unavailable-work status, while the enclosing sleep result/failure retains the explicit load receipt.

## Runtime Flows
Admission checks catalog counts and metadata iterators before materializing signatures/lookup structures. Each invocation claims a bounded exclusive ticket and remaining logical work allowance, reserves its structural scalar envelope, and admits a one-unit boundary marker before any lower callback. A granted invocation ticket counts against K on success and failure, including a marker/capacity failure after checkout; terminal failure finalizes/releases its ticket and stops further calls. K rejection grants no ticket. Failure of capacity/K/marker admission calls no supplier. The owner snapshots that known prefix, releases the Mutex, and supplies local exclusive LoadWork to scalar evaluation and the same invocation's real rigid assembly. On success or failure, finalize checks budget numeric limits, consumed/peak monotonicity, captured owner cancellation and ticket identity before merging counters. The opaque captured cancellation source is authoritative; closure equality is unavailable in LoadBudget and is not falsely claimed. Concrete reference producers retain the supplied budget; a replaced callback cannot bypass the owner's captured cancellation poll. Finalization stores known work before propagating cancellation or physical failure. An uncompleted lease is a typed operation failure, not discarded work.

## State, Ownership, and Lifecycle
Catalogs, selections and samples are immutable Sendable values/reference contexts. Semantic selection is owned solely by Runtime contributor bytes. Execution metadata uses the identical Mutex<State> declaration on Native/WASM/Embedded: invocation tickets, known prefixes, aggregate report, active/closed/failed state. `beginInvocation`, `finishInvocation`, `report`, `close` are its only access paths. `close` seals further invocation admission; the operation wrapper calls it after finalizing its lease on every terminal path. Closing with an outstanding external lease records unavailable work and prevents successful late output; finish still preserves the known prefix before returning failure. Overlapping or reentrant invocation on the same execution is rejected as busy; independent sessions create independent executions. Callbacks, original producer calls and cancellation callbacks run outside the lock. The wrapper releases/closes execution on every terminal success/failure path; reports retain only immutable accounting, not mechanical authority. No global current-program registry or target-dependent raw storage.

## Failure, Concurrency, and Constraints
For L scalar terms and B inertial bodies, a concrete loaded evaluation consumes L scalar producer units and at most B gravity units, plus the documented boundary marker. K admitted invocations bound these logical units by checked K*(1+L+B); this is a logical accounting bound, not CPU time. Aggregate caller maximumWork may be stricter and is enforced before/through calls. Reference aggregation allocates one n-coordinate force vector, no per-term n-vector; reserve n load scalars before allocation. Canonical catalog memory is bounded by caller program/term/metadata limits. Lower numerical assembly/solver budgets independently bound their own matrices and arithmetic. Workspace totals use checked sums/products before allocation and preserve distinct simultaneous buffers.

The generic SmoothODE interface has only NumericalWork. Its loaded adapter therefore captures this explicit execution owner rather than silently converting LoadWork into arithmeticOperations. Stage/prepare/equilibrium/wake supplier calls consume that execution's K and logical budget; known receipts are returned by the loaded sleep port on both success and failure. Runtime-owned full checkpoint validation has a separate operation-local execution derived from RuntimeValidationBudget, with K=1 for its cold loaded proof. Its explicit admission port returns a separate validation receipt. Before any cold proof, the validator reserves the exact concrete upper load allowance 1+L+(gravity-present ? B : 0) from the remaining Runtime work units and n load scalars from remaining scratch; NumericalWork receives only the remaining work/scratch after byte/source and load reservations. If either allocation is impossible, admission fails before that supplier. Thus separately valid ledgers cannot together execute past the whole validation budget. Actual evidence uses the consumed units and simultaneous peaks, not these reserved maxima. Each non-cached required cold proof uses one lease; a cache hit reports its actual bounded association cost and no fabricated load invocation. Standard Runtime admission reports only its existing generic validation evidence: bytes + numerical validation units + load logical units are combined as documented validation units, never as numerical arithmetic. Its scratch evidence includes simultaneously live record, numerical and load buffers. Equation-execution receipts include loaded evaluations during preparation, stages and explicit physical wake, but exclude required-checkpoint validation, byte work and unrelated numerical work. They are not total operation work. Every loaded evaluation in the named execution scope consumes its K, including failures; separately Runtime-owned cold proofs consume the validation scope K. The explicit full-handler admission result/failure retains the validation load receipt; the standard Runtime requirement preserves its existing result/failure contract.

## Verification and Change Impact
See the test owner for independent loaded equilibrium, actual omission, changed-load motion, replay and known/unknown work failures. Catalog/selection/schema changes invalidate loaded chart/checkpoint tests. Zero-load behavior and existing facade source compatibility must remain proven. Original 128 KiB debug profiles require noninline source/evaluation/assembly/solver/association/publication phases with immutable bounded contexts; no stack enlargement or lower-producer fallback establishes qualification. Production work is gated on root's completed lower Runtime admission proof and scoped design review.

### Assume-guarantee summary
| Consumer assumption | Component guarantee / detecting failure |
|---|---|
| Actual immutable supported program, exact model/frame/layout binding | Exact lookup/coefficient signature and source association; stale or unsupported domain fails |
| Caller supplies finite K, logical work/scalar envelope and cancellation authority | Checked admission before callbacks/allocation, all scope invocations counted, separate known receipt on terminal paths |
| Concrete scalar/rigid producers implement their public physical contracts | Actual loads feed original dynamics; no stationarity inference from a sample or unknown callback |
| Consumer finalizes its opaque lease after successful or failed producer calls | Identity/once-only and ledger guards; corrupt/missing work becomes unavailable and cannot authorize retry |
| Runtime validator reserves the separate load allowance before its proof | Actual load + numerical + byte units fit whole RuntimeValidationBudget; a cold proof is not hidden by cache/report scope |
| Runtime alone publishes selected physical/event/history state | Accounting is nonsemantic and never substitutes for accepted authority, RNG or atomic rollback |

| Logical state | Native | ordinary WASM | Embedded WASM | Read / mutation / release |
|---|---|---|---|---|
| Invocation tickets, known/aggregate accounting and terminal status | Mutex<State> | identical Mutex<State> | identical Mutex<State> | report / beginInvocation, finishInvocation, close / operation-owned final receipt and release |
