# Island Sleep Continuation

## Purpose and Scope

This planned child owns accepted mixed-island sleep, actual physics omission, constrained-impact wake preparation and complete contextual checkpoint/isolated trajectory association. Parent: [Mechanisms](../DESIGN.md). No children. Its lower source law is the qualified StationaryIslandDynamics program. The selected fixed direct-branch zero-external-load domain admits sleeping connected gear A/B while independent striker C moves. Existing all-zero SleepContinuation constructors, records and operations remain unchanged.

## Responsibilities and Boundaries

Own mixed sleep/dwell/wake contributor, per-operation prepared rest authority, whole scalar SmoothODE adapter, actual Integration composition, public owner-specific trajectory query, cold physical/history admission and immutable wake candidate. Lower exclusively owns structural/force proof and compiled island mappings. ConstrainedSleepEvolution owns geometry/root/event order and final joint sleep/event publication; Runtime owns accepted mutation, sequence increment and rollback/RNG. No generic IsolatedIntegrationTrajectory relaxation, old sleep wire migration, fake RuntimeStepControl, producer handle, unconstrained contact solve or post-impact projection is permitted.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Mechanisms](../DESIGN.md) | parent | Component index | Root composition | Old facade remains frozen |
| [Stationary Islands](../StationaryIslandDynamics/DESIGN.md) | depends on | Program, motion, certifyRest, associateRest | Actual island physics and stationary authority | Lower proof must qualify first |
| [Integration](../../../Execution/Integration/DESIGN.md) | depends on | SmoothODEEquations, ExplicitIntegrating, IntegrationContinuationProvider.record | Genuine scalar stepping and history | No private reporting constructors or private counter publication |
| [Runtime](../../../Execution/Runtime/DESIGN.md) | depends on | RuntimeSessionOperating, RuntimeCheckpointHandling, required contributor validation and codec | Atomic whole state/checkpoints | Full accepted source and global sequence remain exact |
| [Constrained Impulse](../../../Execution/Hybrid/ConstrainedNormalImpulse/DESIGN.md) | depends on | Opaque ConstrainedNormalImpulseResult/PreparedConstrainedImpact | Original whole momentum/contact/retained-row acceptance | It does not grant Runtime source sequence or geometry-event authority |
| [Constrained Sleep Evolution](../../../Execution/Hybrid/ConstrainedSleepEvolution/DESIGN.md) | used by | Endpoint contributor, query and wake candidate requirements | Noncyclic event owner composition | Sleep consumes an abstract endpoint witness, not concrete Hybrid history |
| [Tests](../../../../../Tests/MechanicsIslandSleepTests/DESIGN.md) | used by | Mixed omission/checkpoint/wake proof | Dedicated behavioral owner | Stage receipts are not total cold-admission work |

## Architecture

```text
immutable island program -> IslandCheckpointedMechanismSleep
accepted checkpoint -> exact history/source -> per-operation rest proofs
actual Integration trial -> whole scalar point
  -> sleeping island: lower associateRest + zero derivative, no physical supplier
  -> awake island: lower real motion -> mapped derivative
  -> whole physical + sleep + Integration + abstract endpoint contributor
full checkpoint handler -> original force/rest/history validation -> Runtime admission
isolated query -> actual complete temporary Runtime -> immutable source-bound endpoint
constrained accepted result + endpoint -> original source check -> real awake acceleration
  -> opaque wake candidate -> event owner -> one real Runtime trial
```

## Contracts and Invariants

Planned public `IslandMechanismSleepContinuing: RuntimeContributorHandling` exposes model/program/descriptor/continuation/schema/schemas, `initialRecord(physical:acceptedSequence:)`, `initialIntegrationRecord(physical:acceptedSequence:)`, `history(_:)`, `step(_:work:) throws(IslandSleepFailure) -> IslandSleepAdvanceResult`, `query(from:to:work:cancellation:) throws(IslandSleepFailure) -> IslandSleepTrajectoryEndpoint`, and `prepareImpactWake(source:endpoint:impact:work:) throws(IslandSleepFailure) -> PreparedIslandImpactWake`. `IslandCheckpointedMechanismSleep` is the immutable Sendable reference implementation, initialized with identity, issued program, lower `any StationaryIslandComputing`, MechanismSleepContinuationPolicy, actual ExplicitIntegrationPolicy and bounded IslandSleepOperationPolicy. There is no mutable current state on the owner. `work` is caller-provided IslandSleepWork with separate physical numerical/load, contributor-encoding and bounded query/step invocation scopes.

The new descriptor/chart and contributor signature losslessly bind the lower canonical full physical law/mapping, sleep criteria/dwell, Integration method/scales/policy, all selected operation bounds and exact contributor participation. Old wire is not accepted as new mixed authority. New history records whole q/v/time/global accepted sequence, stable island IDs/mapping, per-island flags/rest onset, and last wake source sequence/time/event ID/kind/affected islands. Scalar bytes retain exact bits and canonical order. An awake island may have nonzero v even when another sleeps. Sleeping island v/a must be exactly zero, original rest association must hold, group flags/onset must agree and accepted dwell must pass; small thresholds alone never freeze nonzero motion.

At each actual Integration operation, source checkpoint/model/catalog/q/v/a/time/sequence/records/RNG are captured and validated. Operation-local immutable rest certificates are retained through prepare/derivative/write, independently of shared memo replacement. Lower certifyRest issues proof on an actual physical source; lower associateRest checks unchanged local equilibrium at later admitted times. During omission, no island compiled-state/rigid/dynamics/constraint solver callback is invoked for that island; only bounded association and actual zero vector field are evaluated. Every awake island executes lower real motion and original acceptance at every stage; row-free striker uses the original forward port. Mapping returns whole q'=v and accepted accelerations in original coordinate order. No sleeping output is substituted for awake force acceptance.

An optional abstract `IslandEndpointContributing: RuntimeContributorHandling` supplies required public non-generic operations `recordEndpoint(source:physical:acceptedSequence:work:) throws(RuntimeFailure) -> RuntimeContributorState` and `validateAssociation(record:physical:acceptedSequence:budget:) throws(RuntimeFailure) -> RuntimeValidationEvidence`. The participant exposes its one bounded schema through the original contributor contract. It can enrich pure nonphysical event history at each actual endpoint; it cannot alter physical law or waive lower/Sleep proofs. ConstrainedSleepEvolution implements it for its own event history. Sleep imports no concrete event codec/catalog internals. The participant receives nonzero admission/known encoding work and is checked on both outcomes. All third-party schemas and record bytes remain declared; unsupported additional stateful/RNG-changing contributors are refused, not removed from an isolated checkpoint.

The SmoothODE write boundary has no numerical ledger argument. Its bounded sleep/participant record-encoding work therefore uses a distinct operation-local work owner and public contributorEncoding receipt; it is never fabricated as Integration supplier work. Any captured mutable receipt uses the same Mutex on all profiles. Read/prepare/derivative numerical work stays in the actual Integration ledger; LoadWork crosses that NumericalWork-only interface via a separate operation-local lower work receipt. The advance result preserves actual IntegrationAdvanceResult and separate equationExecution load and contributorEncoding reports. Failure preserves actual IntegrationFailure or Runtime/lower cause, last accepted snapshot and the known receipts; no internal Integration report is reconstructed.

Planned `IslandSleepCheckpointAdmitting: RuntimeCheckpointHandling` adds `admitWithReport(_:model:configuration:cancellation:) throws(IslandSleepAdmissionFailure) -> IslandSleepAdmissionResult`. `IslandSleepCheckpointHandler<Revisions: ModelRevisionUpdating>` composes the sleep owner, optional abstract participant and revisions. Each invocation creates an operation-local provider containing actual complete physical/time/global sequence and cold-work receipt before delegating to ReferenceRuntimeCheckpointHandler. It requires the exact bounded schema union; each required record validates independently against that same checkpoint. Both Integration and sleep histories must match exact physical scalar bits/time and checkpoint.acceptedSteps. Awake stored acceleration is checked against lower original force; sleeping flags require original rest/zero-a proof. Participant contextual time/q/v/global sequence cannot be waived by a caller-supplied generic success handler. Record-only mixed sleep validation and generic model migration fail explicitly.

Cold admission derives lower operation capacities from remaining Runtime validation work/scratch, counts actual numerical/load proof cost plus decoding/association owner cost into RuntimeValidationEvidence owner units, and exposes distinct checkpointAdmission receipts. Numerical/load work remain separately inspectable; no hidden cold proof is represented as equationExecution or total operation work. Warm bounded memo hits can reduce repeated supplier cost only after lower associateRest succeeds; per-step prepared proof authority is immutable and eviction-independent. Fresh-owner restart must perform actual cold proof and report it, not infer safety from record metadata.

`query` owns a full temporary Runtime session per admitted invocation, actual checkpoint encode/restart and actual ExplicitIntegrating calls. It uses the same complete source schema and the real endpoint participant, allowing genuine sleep/event history updates that generic IsolatedIntegrationTrajectory intentionally rejects. Every temporary owner is synchronously shutdown on success/failure. The returned opaque endpoint retains full original source checkpoint, actual queried physical endpoint and source-bound semantic sleep/event history plus actual Integration reports. Its private Runtime/Integration accepted counters are diagnostic only. The outer acceptance producer rebuilds actual histories using original global S+1, never copies private query counters or manufactures an accepted token. Pure selected evolution leaves RNG unchanged and unsupported RNG/stateful participant paths fail.

`prepareImpactWake` consumes a genuine AF30 immutable result whose original input/constraints/model/law equals the owner-issued endpoint's complete physical source and program, plus unchanged original source checkpoint and sequence. q/time/revision/prescribed fields remain unchanged across the impulse; velocity is exactly the accepted joint-law result. It never invokes reconcileVelocity or projects the result again. Actual contact row support and original retained reaction expand affected coordinates through lower island mapping; every affected sleeping gear island wakes as a whole. The producer calls actual lower awake motion at accepted post-impact q/v/time to obtain original acceleration, verifies every original row/force and produces real physical/Integration/sleep candidate records at S+1. The opaque candidate is not independently publishable: the event owner must validate geometry/event binding and combine its matching event record in one Runtime transaction.

## Runtime Flows

Initial actual force/state admission -> real accepted steps accrue dwell -> lower rest proof -> mixed omission. Query source validation -> full private restart -> actual integration/participant endpoints -> immutable queried endpoint. Original constrained impulse -> exact result/source association -> connected island wake -> genuine awake acceleration -> immutable candidate. Final event owner performs one trial with whole endpoint and records; failed admission retains the original accepted checkpoint/RNG. Terminal smooth publication is a separate accepted segment. After any earlier accepted event, a later failure retains that last accepted prefix.

## State, Ownership, and Lifecycle

History is required checkpoint data, not owner mutable state. Immutable program/operation contexts retain original model/source/proofs. Optional bounded memo has at most one proof per admitted island and stores immutable certificates through common Mutex; all reads/writes use the same isolation, and no callback runs under lock. Equation preparation, derivative, encoding and post-impact physical calls use noninline phases; completed source/history/result temporaries end before nested callbacks at original 128 KiB. Work receipts share only common Mutex owners; no target-specific raw state, unchecked Sendable, fake controls or manual pointers are introduced.

## Failure, Concurrency, and Constraints

Counts, coordinate/row/island products, identities/signatures, record bytes, schema union, query/step caps, Runtime scratch and S+1 overflow are checked before allocation/callback. Query count K and per-query actual Integration bounds are caller-controlled. Numeric/load/encoding scopes are never silently merged or renamed. A reset restores known admitted prefix, marks unknown failed work and stops without retry. Error reasons retain original typed lower/Runtime/Integration/codec causes with compact immutable payloads and original cancellation priority. e0 post-impulse acceptance is possible, but persistent contact/support advancement needs separate event authority and is not silently treated as a separating e1 trajectory.

## Verification and Change Impact

Dedicated tests prove source A/B asleep while C moves, accepted dwell/cold force proof, actual omitted supplier calls and lower work reduction against all-awake evolution, operation-local certificate reentry/eviction independence, actual post-impulse gear wake and genuine ensuing acceleration/motion, exact history S+1/RNG, full registry cold restart and fresh byte replay. Reject altered inertia/program/policy, mixed metadata without actual proof, nonzero sleeping v/a, private-counter import, stale whole source, malformed/missing/capacity/cancel/reset work and failed participant/trial. Event-root/law proof is owned by ConstrainedSleepEvolution tests. Existing constructors/tests remain frozen; full RB007 and general topology/load/contact formulations remain open.

### Qualified AF31 lower and fixed additive API

The issued StationaryIslandProgram and StationaryIslandComputing contracts are qualified by source commit 7e80040. The owner initializer is `init(identity:program:dynamics:policy:integration:operationPolicy:participant:)`; participant defaults to nil. `IslandSleepOperationPolicy` declares maximumSupplierInvocations, maximumQueries, maximumQuerySteps and maximumRecordBytes. `IslandSleepWork` receives physical StationaryIslandWork and contributorEncoding NumericalWork; receipts preserve both exact known prefixes, bounded invocation/query counters and unavailable suffix state. The step result contains the actual IntegrationAdvanceResult and work. The query also receives the actual RuntimeConfiguration and returns its original source, actual accepted endpoint and private accepted-step diagnostic count.

Equation numerical receipts mirror the actual lower local numerical work also absorbed by Integration: these are overlapping scopes, never additive totals. LoadWork remains distinct. Each lower call is admitted by a nonzero numerical/load quantum, stable budget/count/scratch checks and invocation K. The callback executes outside common Mutex receipt storage. A busy receipt refuses overlapping/reentrant use instead of duplicating a mutable ledger. Known work is absorbed on both outcomes; reset restores known prefix and marks the unknown suffix. Contributor encoding has a separate ledger because SmoothODE.write has no numerical argument.

Cold admission derives numerical/load limits from the remaining RuntimeValidationBudget, counts every real lower invocation, and charges decoding, actual numerical operations/iterations, actual load work and bounded scalar scratch in RuntimeValidationEvidence. The public report-bearing handler returns those cold receipts. Warm immutable rest certificates may skip repeated physical proof only after source/local-q/law association; an operation keeps its own immutable certificates so later memo eviction changes cost only. Awake acceleration always receives genuine force admission. The initial record admits actual caller q/v/a/time rather than requiring the model descriptor's initial acceleration.

Query bootstrap uses awake sequence-zero records at the original physical source, then the real codec/Runtime restart restores the complete original checkpoint before any advance. Participant endpoint construction must accept this private bootstrap; full source association is independently validated before the bootstrap. Private sequence counters are diagnostic and never copied into an outer event publication.

### Scoped implementation review findings

The owned review found that adaptive `advance` may reject, accept a shorter step, then continue to the requested time. A query adapter therefore captures the actual private Runtime snapshot on each preparation, checks its complete records/q/v/a/time against the real trial, and retains that source/history/proofs in an immutable per-trial reference context. Normal step adapters keep their single original source. This preserves original Integration algorithms, actual rejected trials and global private history without weakening generic trajectory validation.

The review also bound the optional participant's single schema at construction before signature allocation, included its category/version/byte cap in canonical authority, and charged its source-association evidence into the distinct encoding ledger. No callback runs under the receipt Mutex. Exact source/model comparison consumes public descriptor/policy/layout plus original scalar bit identity, rather than assuming a compiled model is a reference type.

| Shared logical state | Native / WASM / Embedded storage | Read / mutation | Lifetime |
|---|---|---|---|
| Rest memo | same Mutex of immutable certificates | read/store through withLock | immutable owner |
| Per-trial preparation | same Mutex of immutable source/history/proof context | capture/read/store; callbacks outside lock | equation operation |
| Numerical/load/encoding receipt | same Mutex of value ledger + busy flag | bounded checkout/finalization; callbacks outside lock | operation |
| Cold receipt | same Mutex of optional value report | read/store through withLock | checkpoint invocation |

The original-profile compile/link/runtime and stack proof remain root-owned and pending; Native evidence qualifies only this owned test target.

### Original-profile preparation lifetime correction

The original 131072-byte guards reached actual rest certification while retaining the completed equation preparation validation frame. Ordinary WASM measured 15424 bytes for `IslandSleepMechanismEquation.prepare` and 2752 bytes for `prepareProofs`; Embedded measured 16800 and 2928 bytes respectively. The observed ordinary trace allocated 147376 bytes and the Embedded trace allocated 134848 bytes before reaching the original lower physics path. These measurements are failure evidence, not successful qualification.

Preparation uses two sequential noninline phases. Capture validates the exact full accepted source, private query sequence, contributor registry, physical scalar bits and sleep history, then returns one immutable `IslandSleepPreparationSource`. Capture's value temporaries end before rest certification begins. Proof preparation consumes that same reference and returns immutable certificates together with the captured authority; it does not recapture source, waive validation or use shared memo as operation authority. `IslandSleepPreparation` retains this source context and the original proof array until the equation operation releases it. The existing common Mutex still owns the prepared reference and callbacks remain outside its lock.

```text
real trial + accepted session snapshot
  -> capture and validate full source/history -> immutable source reference
  -> capture frame returns
  -> original bounded certifyRest calls -> immutable operation preparation
  -> same derivative/write and actual Runtime acceptance
```

The original budgets, work quanta, solver calls, equations, cancellation, source identity and rollback remain unchanged. Existing mixed omission, rejected-trial association, reentry, restart, wake and failure tests own behavioral regression; root owns renewed original-profile guard/raw execution. No stack reservation or acceptance tolerance is increased.

Native compilation against unchanged macOS13 deployment exposed missing availability on new internal Mutex owners. The cache/execution/cold receipt types now carry the same macOS15/iOS18/tvOS18/watchOS11 contract as Runtime; storage/isolation and deployment flags remain unchanged.

The bounded-work recheck reserves owned stage q/v/a and mapped acceleration storage before allocation, and subtracts their live 4n scalars from each nested physical supplier budget. The same reservation is added when absorbing the actual known lower prefix, in both equation and physical receipts. Per-trial proof-reference storage and endpoint encoding are bounded before materialization. This changes no mechanical law, tolerance or profile stack setting.

### IM.AF31.10 Native qualification

The immutable private 625f759 baseline with qualified 7e80040 island source and the separately qualified Runtime observation correction built with exact Swift 6.4.0 and unchanged production flags. `build --build-tests -j 4` passed in 9.90 seconds under a 1200-second watchdog; the sole `MechanicsIslandSleepTests` behavior run passed 13 definitions / 24 expanded cases / 3 suites in 0.261 seconds under a separate 240-second watchdog. This verifies actual mixed omission and reduced Integration work, force-consistent moving C, fresh cold restart/replay, adaptive rejected-trial association, immutable proof reentry, original AF30 retained-row wake and source/work/cancel refusal. Setup/compiler findings were limited to availability and equivalent expression/typed-throws fixes; original suppliers were unchanged. Canonical Native and original WASM/Embedded qualification remain separate root-owned evidence.

### IM.AF31.12 Smooth outer association

`prepareSmoothEndpoint(source:endpoint:work:)` is an additive lower-owned operation returning opaque `PreparedIslandSmoothEndpoint` with original source, genuine queried physical endpoint and sleep/Integration records at original S+1. It validates owner identity, unchanged complete original checkpoint, nondecreasing physical time, actual queried q/v/time/private sequence association and unchanged semantic wake identity. It preserves actual queried sleep flags/rest onset and actual Integration nextStep/error, rather than calling initialRecord or importing private counters. The opaque candidate has no independent publication operation; the upper event owner must combine its matching event record in one contextual Runtime trial. Original-source mismatch, foreign owner, zero-duration and malformed query association fail before publication, retaining known work. No mechanical supplier or existing step/query/wake behavior changes.
