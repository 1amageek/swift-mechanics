# Checkpointed Connected Mechanism Sleep

## Purpose and Scope
This component owns accepted static-affine mechanism sleep continuation and wake transactions. Parent: [Mechanisms](../DESIGN.md). No children. It provides genuine suspension for a wholly resting connected scalar mechanism. Mixed awake/sleep components conservatively use complete dynamics. Wake commands and impulses conservatively wake the complete mechanism, including every connected component touched by the source; component-minimal wake/omission is not yet qualified. General force callbacks, gravity, moving constraints and topology migration remain explicit unsupported domains.

## Responsibilities and Boundaries
The owner binds inertias in public compiled-tree body order by resolving descriptor records by body ID and constructs concrete immutable affine, rigid mass and constraint producers: fixed-root scalar joints, immutable inertia, no prescribed anchors, no gravity/external load, stationary affine constraints and piecewise constant generalized commands. It owns accepted sleep flags, rest onset, command generation, last wake identity, accepted time/sequence and physical q/v binding. Runtime alone owns trial rollback, RNG and publication. An arbitrary injected force callback cannot establish stationary-force provenance.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [AffineEvolution](../AffineEvolution/DESIGN.md) | depends on | genuine constrained acceleration and chart | active evolution | scalar stationary affine domain only |
| [StationaryLoads](../StationaryLoads/DESIGN.md) | planned dependency | catalog/selection, explicit execution receipt | AF23 gravity/passive authority | Design-only until lower Runtime proof |
| [ConstrainedDynamics](../ConstrainedDynamics/DESIGN.md) | depends on | mass equation, source-bound impulse | equilibrium and physical wake | temporal meaning and source must agree |
| [ConnectedSleep](../ConnectedSleep/DESIGN.md) | depends on | mass/constraint connected groups, energy, normalized speed | group identity | this component separately proves positive mass |
| [Runtime Checkpoints](../../../Execution/Runtime/Checkpoints/DESIGN.md) | depends on | RuntimeCheckpointHandling full checkpoint admission | restored physical/time/sequence binding | record-only validation rejects sleep records |
| [Runtime Transactions](../../../Execution/Runtime/Transactions/DESIGN.md) | depends on | accept/reject, cancellation and contributors | sole semantic state owner | event state changes only inside accepted trial |
| [Integration](../../../Execution/Integration/DESIGN.md) | depends on | real RK stages and accepted endpoint | active and sleeping evolution | no independent fabricated endpoint |
| [Tests](../../../../../Tests/MechanicsSleepMechanismTests/DESIGN.md) | used by | behavioral oracle | real connected gears and replay | target-local proof only |

## Architecture
```text
CheckpointedMechanismSleep (immutable configuration + bounded pure memo)
    -> per-step SleepMechanismEquation (immutable accepted source + local proof owner)
        -> ReferenceExplicitIntegrator -> Runtime trial -> accepted checkpoint
        -> concrete AffineMechanismEquation (awake)
        -> certified stationary zero vector field (all asleep)
    -> immutable mass/constraint producer -> SPD + original equation proof
    -> complete contextual record validator
```

## Contracts and Invariants
Sleep entry requires positive-definite actual mass, retained constraint connectivity, nonnegative kinetic energy and normalized speed below thresholds, accepted-time dwell, exact zero physical velocity and exact zero original constrained acceleration. Threshold-only candidates never suspend nonzero motion. Static provenance plus unchanged q and constant command proves the vector field remains zero; stationary affine rows have zero time dependence and validity intervals are checked at each omitted stage.

The serialized record binds exact physical q/v, accepted time and global accepted sequence, command drive/generation, flags/rest onset and wake sequence/kind/affected coordinates. Connected coordinates share flags. Malformed, stale, missing, trailing, over-capacity and incompatible records fail explicitly. Generalized impulse wake takes an explicit instantaneous SI momentum input bound to accepted model/time/sequence/layout, then computes actual mass-inverse velocity and constrained reconciliation, checking original M delta-v against applied plus constraint impulse. Hybrid collision contact event authority is not yet connected. Commands have monotonically increasing checkpointed generation and immutable constant-force values. Every wake is accepted atomically with q/v/acceleration, event and integration history reset. No unknown failed supplier work is retried. The sleep-owned typed failure distinguishes preflight RuntimeFailure with the accepted source from an actual IntegrationFailure returned by the integrator; it does not construct another owner's reporting internals.

## Runtime Flows
```text
accepted source -> contextual source binding -> genuine static-rest certificate
    -> awake stages OR certified omitted stages -> endpoint + sleep history
    -> runtime accept (all state) / reject or cancel (no semantic change)
accepted source -> source-bound impulse OR next constant command
    -> actual endpoint acceleration -> connected wake + event + histories
    -> runtime accept / rollback
checkpoint restore -> bounded decode -> full physical/time/sequence association
    -> genuine equilibrium proof (memo may avoid repeated identical proof)
```

## State, Ownership, and Lifecycle
All semantic state lives in contributor bytes; adapters capture an immutable accepted snapshot for one integrator step. A single bounded pure equilibrium memo retains only q/drive and the derived certificate. Each step adapter owns a separate prepared-proof slot; prepare publishes the immutable source-bound certificate there, and derivative/write consume that local certificate. The global memo is used only while obtaining a proof, so its replacement by another session cannot revoke prepared authority or alter flags. Mutex protects both slots identically on Native/WASM/Embedded. Cache replacement occurs after complete successful proof outside the lock. No external callback/I/O runs in the critical section. Checkpoint restore reconstitutes semantic state independently of the memo.

| Logical State | Native Storage/Isolation | WASM Storage/Isolation | Embedded Storage/Isolation | Read / Mutation | Owner Release / Evidence |
|---|---|---|---|---|---|
| Pure equilibrium memo | Mutex<Certificate?> | same declaration | same declaration | read(q,drive) / store(successful proof) | owning sleep instance; Native same-owner independent-session controlled reentry executed; actual parallel cache replacement remains unexecuted, target runtime probe is owned by system integration |
| Prepared source proof | Mutex<Certificate?> | same declaration | same declaration | read() / store(prepare result) | one captured step adapter; controlled independent-session reentry tests prepare -> different q memo eviction -> actual omitted RK stages/write |
| Trial work capture | Mutex<NumericalWork> | same declaration | same declaration | read() / store(deferred ledger) | operation-local owner; Native accepted/failure/cancel paths executed, target runtime probe is owned by system integration |
| Sleep/command/event semantics | Runtime contributor bytes | same Sendable record | same Sendable record | operation-local decode / trial.replaceContributor | Runtime session checkpoint/rollback; Native replay, rejection and cancellation executed |

## Failure, Concurrency, and Constraints
The original public WASM debug stack profile is 128 KiB. Cumulative producer call depth is a correctness bound: measured monolithic restCertificate frames were 38,160 bytes ordinary WASM and 40,864 bytes Embedded; step frames were 13,536/14,976 bytes and sleep prepare 10,400/11,056 bytes. Combined with existing Runtime/Integrator frames, entry exceeded the original boundary. The rest proof is therefore composed of noninline source admission, snapshot/input setup, rigid assembly, retained-row evaluation/connectivity, equilibrium solve and proof publication phases. Immutable bounded reference contexts retain phase outputs; a phase creates only the rich value temporaries required for its current producer call. No later phase output or source-admission temporary remains on its caller stack. Step preflight/adapter setup is completed before a separate noninline integration phase; the adapter is a Sendable reference owner with immutable source/configuration and Mutex-protected prepared proof. Root owns frame diagnostics and target execution; increasing stack capacity or switching target/backend cannot qualify this path. A later exact Embedded guard identified restEquilibrium -> frozen constrained accept -> originalInertialForce -> validateAcceleration while entered from nested Runtime/Integrator prepareProof; restEquilibrium retained 10,192 bytes. Its invocation/known-ledger absorption and post-call source/temporal/layout/value association are separate noninline phases. Cold proof remains within the same admitted caller work ledger and transactional preparation; no proof relocation or unreported preflight work is introduced. Root must remeasure the cumulative boundary before qualification. A later Embedded run reached impulse wake publication and exceeded the boundary with completed impact temporaries retained: impact 39,888 bytes, publishWake 8,896 bytes, trial closure 12,592 bytes. Impulse computation therefore ends in noninline source admission, original mass/free-velocity construction, incoming reconciliation and original momentum-balance phases before wake publication begins. Immutable bounded reference contexts retain only each phase's admitted outputs. The final transaction captures a separate immutable wake context; source validation, actual derivative evaluation and endpoint/contributor publication are noninline phases, so future physical/contributor temporaries are absent during the nested dynamics call. Validation order, reserved storage, four supplier-ledger absorption on success/failure and original mass authority are unchanged. Numerical work capture remains the identical Mutex owner on every target; deferred capture and Runtime retain failure/rollback/RNG semantics. This lifetime repair requires affected Native behavior evidence and root's original target execution before stack qualification.

The configuration fixes coordinate, identity, contributor byte and validation work/scratch bounds before allocation. Numerical products/sums and sequence/generation increments reject overflow. Cancellation is checked at admitted safe points. The actual fixed concrete suppliers preserve their ledgers; injected session ports are guarded by expected source and runtime binding. A sleep RuntimeCheckpointHandling decorator builds an operation-local provider from the full checkpoint physical/time/sequence and delegates admission to ReferenceRuntimeCheckpointHandler. Legacy record-only validation is insufficient. Topology migration requires target equation and connectivity authority not supplied by current stable contracts, and returns a marked typed failure.

## Verification and Change Impact
Tests deliberately reorder descriptor bodies relative to public compiled-tree traversal, use compiled inertial gear bodies and independent analytical torque/impulse/mass oracles. They verify actual suspension work reduction, unchanged resting physical invariants, real command and source-bound impulse wake, active constrained evolution, accepted-time dwell, rejection/RNG/event rollback, restored replay, and malformed/stale/capacity/cancel failures. Changing force provenance, constraints, model, serialized schema, runtime validation or migration changes this contract. Full sleep feature completion also requires topology and general force-domain execution; these gaps cannot be inferred from this admitted profile.

### AF20 selected public profile evidence
Root executed the final unmodified Native, ordinary-WASM and Embedded-WASM compositions with all path completion witnesses and exit zero. [Exact profile evidence](../../../../../Verification/FoundationVerification/DESIGN.md#af20-selected-original-profile-qualification) owns toolchain, stack, runtime and test-snapshot qualification. This extends only the selected public paths documented there; the remaining domain and concurrency limitations above persist.

### Planned AF23 accepted loaded sleep contract
These additive names/contracts are proposals; current executable scope remains the qualified zero-external-load path. A loaded constructor admits StationaryLoadCatalog and initial selection. Existing zero-load construction and legacy step/command/impact remain compatible. A catalog-backed owner uses an explicit work-reporting port; calling a legacy receipt-less operation for that owner is a typed domain error, never a zero-load fallback.

```swift
public protocol LoadedMechanismSleepContinuing: MechanismSleepContinuing {
    func stepWithLoads(_ session: any RuntimeSessionOperating, loadBudget: LoadBudget,
                       maximumLoadInvocations: Int)
        throws(LoadedMechanismSleepFailure) -> LoadedMechanismAdvanceResult
    func selectLoad(_ session: any RuntimeSessionOperating, expected: RuntimeAcceptedState,
                    selection: StationaryLoadSelection, loadBudget: LoadBudget,
                    maximumLoadInvocations: Int, work: inout NumericalWork)
        throws(LoadedMechanismSleepFailure) -> LoadedMechanismWakeResult
    func commandWithLoads(_ session: any RuntimeSessionOperating, expected: RuntimeAcceptedState,
                         drive: [Double], generation: UInt64, loadBudget: LoadBudget,
                         maximumLoadInvocations: Int, work: inout NumericalWork)
        throws(LoadedMechanismSleepFailure) -> LoadedMechanismWakeResult
    func impactWithLoads(_ session: any RuntimeSessionOperating, expected: RuntimeAcceptedState,
                        impulse: MechanismSleepImpulse, loadBudget: LoadBudget,
                        maximumLoadInvocations: Int, work: inout NumericalWork)
        throws(LoadedMechanismSleepFailure) -> LoadedMechanismWakeResult
}
```
LoadedMechanismAdvanceResult holds the actual IntegrationAdvanceResult plus an equationExecution-scope StationaryLoadWorkReport; LoadedMechanismWakeResult holds actual RuntimeTrialOutcome plus the separate equationExecution-scope load report. Neither claims total operation/cold-admission work. LoadedMechanismSleepFailure has `preflight(RuntimeFailure, accepted: RuntimeAcceptedState, loads: StationaryLoadWorkReport)`, `integration(IntegrationFailure, loads: StationaryLoadWorkReport)` and `wake(RuntimeFailure, accepted: RuntimeAcceptedState, loads: StationaryLoadWorkReport)` cases. These wrap actual producer results/failures, never construct lower internal reports. Preflight invalid bounds produce a known empty receipt; invocation-budget failure produces the actual known receipt. Rejected trials consume/report actual attempted work while semantic state/RNG is unchanged. A fresh execution owner is created for each public operation and closed/reported on all terminal paths; the adapter's captured reference bridges the NumericalWork-only SmoothODE boundary.

Loaded history uses a separately versioned schema/signature. It binds exact catalog signature, selected program ID/revision/generation, existing q/v/time/global sequence, drive/command generation, flags/dwell and last wake identity. Kind 3 identifies a load selection event with source/target program versions and generation; existing command/impact event semantics remain. Bounds, ID lengths, generation/sequence overflow and canonical bytes are checked before allocation/traversal. Old zero-load wire remains unchanged; loaded/zero or foreign catalog records are not silently migrated.

```text
full accepted record -> exact catalog/selection lookup -> per-step immutable loaded adapter
 -> shared actual affine loadedMotion -> SPD/connectivity + exact v=0/a=0 + threshold/dwell
 -> active actual stages OR unchanged source with prepared stationary proof
 -> endpoint + history -> full required validation -> Runtime accept / rollback
expected accepted source -> next load generation + catalog target
 -> shared actual loadedMotion at unchanged actual q/v/time
 -> atomic selected version + physical acceleration + whole connected wake + event
    + reset rest onset + exact Integration initial history -> accept / rollback
```
The full handler rejects altered catalog/version/selection, missing records and mismatched physical/time/global sequence. Sleeping restore performs a cold shared loaded-motion proof with the restored program; catalog provenance makes unchanged q, exact v=0 and unchanged program time-independent. Nonzero gravity/passive force may be balanced by each other or retained constraint reactions: nonzero forces are not rejection by themselves. Uniform gravity/passive equations still execute and original physical acceptance remains required. Exact zero acceleration is retained as the omission criterion; merely small residual/velocity does not freeze motion.

Memo keys additionally include exact catalog/program version and selected generation (plus q/drive); each step captures immutable selection and source-bound prepared proof. Catalog lookup and all dependency edges remain valid for zero coefficients/forces. No current-load mutable property exists on the sleep owner. Whole-mechanism wake remains an acceptable conservative compatibility guarantee; component-minimal omission/wake is separately unqualified. A load change cannot reuse the former proof even if its instantaneous net force happens to match.

A planned explicit full-checkpoint handler port `admitWithLoadReport(checkpoint:model:configuration:cancellation:)` returns LoadedSleepAdmissionResult(actual accepted state, checkpointAdmission-scope validation load receipt), or LoadedSleepAdmissionFailure(actual RuntimeFailure, validation receipt). It creates an operation-local contributor/receipt owner before delegating to actual ReferenceRuntimeCheckpointHandler; all required validation and publication remains in that lower path. Its standard RuntimeCheckpointHandling requirement preserves the lower generic contract. Validation's separate K=1 and unit/scratch composition are owned by [StationaryLoads](../StationaryLoads/DESIGN.md); stage load reports do not claim those Runtime-owned validation costs. Lower Runtime contextual/physical admission qualification must complete before implementing either port.

Gravity/passive equilibrium, new-load acceleration/motion, receipts and replay are owned by the [test design](../../../../../Tests/MechanicsSleepMechanismTests/DESIGN.md). This proposal does not connect Hybrid contact, topology migration, arbitrary time-dependent force callbacks or floating/planar formulations and cannot close full RB-007. Implementation/build/registration is gated on root's lower Runtime green and design handoff acceptance.
