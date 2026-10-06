# Exclusive explicit held-force macro coupling

## Purpose and Scope
Parent: [CoSimulation](../DESIGN.md). Children: none. Own a two-participant equal-clock coordinator, scalar spring/damper exchange, original physical acceptance, macro receipt publication, cumulative admitted-work ledger and recovery/poison lifecycle.

## Responsibilities and Boundaries
Only create actual MechanicalParticipants internally. Each participant's Runtime independently commits/rolls back. The coordinator's exclusivity/operation gate prevents public observation of mixed provisional macros; it does not create a distributed commit protocol. Generic, asynchronous, delayed/interpolated and iterative participant modes explicitly fail admission.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [CoSimulation](../DESIGN.md) | parent | Selected physical scope | Composition | EX-008 products remain open |
| [MechanicalParticipants](../MechanicalParticipants/DESIGN.md) | depends on | Actual real owned sessions/receipts | Sole physical contributors | No private supplier APIs |
| [Numerics](../../../Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | Caller-exclusive NumericalWork | Cold creation/encoder | Successful original receipts retain actual work |

## Architecture
```text
short common Mutex: check busy/closed/poison, checkout published prefix + cumulative ledger
    -> outside lock: checkpoint both -> compute paired held effort -> step both
    -> outside lock: original evidence/energy -> publish immutable receipt under Mutex
    -> failure: outside lock attempt every restart, inspect actual prefixes
    -> short Mutex: preserve/invalidate publication, record cumulative work, poison if required
```

## Contracts and Invariants
Let e=q2-q1-restLength, r=v2-v1, spring k>=0 N/m, damper d>=0 N*s/m. At macro source time t, F1=k*e+d*r and F2=-F1 are held through the identical effective ControlClock interval; delay is zero. Source expected time/tick and requested macro order must equal the actual current publication. Each next command is sourced afresh from the actual accepted states; no stale automatic command reuse.

Original exchanged work is Wex=F1*(q1End-q1Start)+F2*(q2End-q2Start), verified against both actual Control actuatorIntervalWork values. Fixed disturbance work is separately verified. Both actual kernel initial/endpoint K and original force residuals must satisfy the participant original energy balance. Original held powers are F1*v1+F2*v2 at start and end and average Wex/dt. Spring energy U=k*e^2/2; exact continuous linear-trajectory damping oracle for this constant-force scalar domain is D=d*dt*(rStart^2+rStart*rEnd+rEnd^2)/3. The held-force discretization defect epsilon=Wex+delta(U)+D is checked against an explicit dimensional energy tolerance and the total absolute accumulated defect against a caller maximum. It is reported unchanged, never called physical loss. D and U must be nonnegative; with k=0, pair work/start/end held power must be nonpositive within explicit dimensional tolerances. k>0 permits release of actual stored U and is judged by the original energy defect. This is an explicitly bounded explicit macro method, not an energy-exact continuous spring solver.

## State, Ownership, and Lifecycle
| Logical state | Native storage/isolation | WASM storage/isolation | Embedded storage/isolation | Entries/lifetime |
|---|---|---|---|---|
| Busy/closed/poison flags, macro publication, cumulative ledger/defect | Mutex<CoSimulationState> | Same | Same | begin/finish/status/shutdown; coordinator lifetime |
| Participant physical/contributor/RNG accepted state | Original Runtime Mutex | Same original supplier | Same original supplier | Original Control methods; private owned sessions |
| Callback observation capture | Mutex<ControlObservation?> | Same | Same | Local store/read; one observation operation |
| Macro scratch/checkpoints/results | Exclusive local values | Same | Same | Checked out operation; released on return/throw |
Every supplied callback/Runtime operation runs outside critical sections. No stream is exposed. Concurrent/reentrant steps and snapshots fail busy. shutdown during operation marks closing, requests original participant shutdown outside lock, and prevents later publication. A failed restoration poisons the owner; status remains inspectable, but later step/snapshot success is forbidden. New construction is the recovery path.

## Failure, Concurrency, and Constraints
No iterations/retries are declared. Each macro attempts at most one step per participant and, on failure, one restart per participant. All original per-call numerical/actuation/validation ceilings are irreversibly precharged to the cumulative ledger before callback dispatch; successful actual charged work is tracked separately, and an unavailable failed supplier is terminal. Remaining cumulative budget must admit the declared quantum before a call. Recovery uses the same ledger, including precharged restarts/observations; it does not recreate budgets or clear cancellation. Failed/suspended restore records actual known owner prefixes or explicit current-prefix unavailability, including supplier RuntimeFailure.lastAccepted/IntegrationFailure.accepted when present. An all-restored rejected macro preserves publication and cumulative consumption; unavailable work still poisons it.

Retained checkpoint bytes must fit the caller aggregate byte limit before physical stepping. Checked integer sums/products precede budget/capacity arithmetic. Fixed two participants bound orchestration storage; existing supplier array and codec bounds remain explicit in configurations. User callbacks cannot be installed in this initial coordinator. Policy values are all explicit, without default accuracy, time, force, damping, memory or iteration constants.

## Verification and Change Impact
Later independent held spring/damper force, original kinetic/interface/disturbance work and explicit defect thresholds, pure-damper passivity, clock/source/order/delay/refusal, both-prefix restoration, repeated cumulative limits, unknown work poison, actual canceled-prefix evidence, reentry/shutdown and target profiles are required. No build/test/probe/Git during source-first work. One scope-local source review and focused corrections precede freeze.

### Selected cumulative admission accounting
The public budget bounds cumulative admitted numerical operations/iterations, actuation work ceilings, validation work ceilings, codec byte-capacity reservations, macro count and retained checkpoint bytes. The ledger reports these conservative reservations as reservations, not measured consumption. Successful encoder/cold numerical work and original step work remain separate actual receipts. No hidden Control decode work is fabricated. A fixed single integration attempt/accepted-step configuration is required. For each participant: creation reserves one numerical budget, two actuation budgets (factory and association), two validation ceilings; observation reserves one actuation budget; step reserves supplier numerical budget plus outer arithmetic, four actuation budgets (two observations, preparation and admission association), two validation ceilings and one runtime step-work ceiling; restart reserves two actuation budgets, two validation ceilings and one codec byte ceiling. Actuator contributor validation is already bounded by the validation ceiling. Checkpoint encoding and original decode verification reserve two codec byte ceilings. Encoder preparation reserves its explicit numerical budget. Recovery plus its verification observations are fully reserved before the first physical step, preventing exhausted normal-work allowance from making restoration unbudgeted. Unused recovery reservations remain charged. The coordinator charges a conservative 512-operation/64-scalar straight-line physical-evidence quantum per macro. All additions and products reject overflow before dispatch. The public failure carries current owner prefixes as optional actual evidence, never cached prefixes labeled current.

Current-prefix acquisition failure retains the most recent actual receipt separately as lastKnown; this is never substituted for current. Dropping the coordinator invokes both original shutdown operations outside state locks. Numerical/actuation recorded totals cover reconciled original receipts only; failed supplier receipts remain in typed failure evidence and opaque work is represented by its admitted ceiling, not fabricated measured totals.

### Source review closure and qualification gaps
One scope-local source review traced default real Control/Runtime dispatch, exact public AF30 encoder issuance, original receipt gates, checkpoint identity, both recovery attempts, cancellation prefixes and common isolation. Focused fixes retained actual post-step accepted prefixes, separated current/lastKnown, made budget quantities explicit conservative capacity reservations and preserved unavailable-work terminal state. Relative energy/force/power tolerances must be less than one, preventing vacuous relative acceptance; force residual scales use the actual total held plus fixed external force. Source review does not establish compilation or runtime behavior.

| Obligation | Source owner | Remaining qualification evidence |
|---|---|---|
| Actual physical held effort and original q/v/K/work | PrismaticCoSimulationParticipant, CoSimulationEvidence | Independent coupled physical fixture and rejected interval |
| Full contributor/RNG rollback and cancellation actual prefix | HeldPrismaticCoSimulation | Both-owner replay, post-commit failure, canceled restore |
| Cumulative reservation and terminal unavailable work | CoSimulationWorkLedger, coordinator | Repeated failure/recovery limits and supplier evidence |
| Busy/reentry/shutdown and owner release | Common Mutex state and capture | Actual concurrent/reentrant/shutdown execution |
| Native / WASM / Embedded same storage and conformance | Common source without conditional synchronization | Fixed toolchain/SDK compile, link and runtime; all currently unverified |

Consulted original qualified local supplier source on 2026-10-05. This handoff changes no supplier and registers no new target. It is an excluded, unqualified source freeze, with no build/test/probe/benchmark/profile/new-test/Git evidence. EX-008 full external engines, generic participants, iterative/delayed exchange and vehicle/soil/fluid physical assembly remain outside this selected product.

D is the nonnegative continuous comparator damping energy evaluated along the actual trajectory; the public receipt names it continuousDampingOracleJoules. It is not measured held-port dissipation. Original exchangedWorkJoules and energyDefectJoules remain the physical and discretization evidence, respectively.

### Historical independent qualification preparation
The [selected public fixture owner](../../../../../Verification/CoSimulationQualification/DESIGN.md) fixes nine synchronous physical/refusal/recovery cases and a separately awaited Native Task cancellation case. Fixtures consume original immutable2363 Control/Runtime APIs, with independent constant-force motion, kinetic work and integrated power oracles. All eighteen production Swift files remain identical to that original producer. The current live RuntimeSession change is outside this evidence premise. No compiler or runtime has executed these fixtures; existing source review is not upgraded to behavioral success. Future source repairs require a concrete original failing case and a matching new producer before rerun.


### AF38 concrete Native stack-lifetime repair
The original immutable2270 Native execution terminated with SIGBUS at the Runtime stack guard during the existing cancellationPoison case. Its actual call chain passed through owned HeldPrismaticCoSimulation.step to the original prismatic participant, Control, RK4 and committed Runtime acquire. The owned step object prologue reserves0x44*4096+0x740+0x60 =280,480 bytes before nested supplier frames. This is an actual selected-path failure, not an energy oracle failure or permission to replace Runtime.

Split checkpoint verification/reservations, each participant advance/reconciliation, original evidence/publication, and pre-mutation failure publication into non-inlined bounded phases. These phases borrow the same exclusively local work ledger and known original prefixes. No new shared state or accepted-state mirror is introduced. Checkpoints remain operation-local immutable byte arrays. Preserve original reservation order, mutationAttempted boundary, first-before-second order, exact record-on-failure behavior, publication cancellation check and both-owner original recovery. No numerical law, tolerance, budget, supplier, stack-size or test-serialization change is permitted. The unchanged2270 producer remains immutable; a separate matching full-module/object composition must bind the changed source before focused original10/public9 validation. Compare actual changed object frames with the retained original frame and crash evidence; Native evidence does not qualify portable profiles.

### AF39 repair verification
The matching fresh2270 producer compiled and linked the phase split. Its actual fixed owned step frame is60,992 bytes; prepare, advance, accept and pre-mutation rejection frames are123,376/46,192/26,784/15,536 bytes. Original step frame280,480 bytes and SIGBUS remain retained. Actual step relocations bind all four phase helpers and both participant advances. Maximum step plus one phase frame is184,368 bytes; this is not a total-stack/high-water guarantee. The [qualification owner](../../../../../Verification/CoSimulationQualification/DESIGN.md#AF39-matched-repair-Native-evidence) records original Native10/public9 GREEN and source/object/module/link identities before and after runtime. Reservation order, held-force equations, original failure prefixes, both-owner rollback and cancellation were unchanged. Native-only closure supersedes the historical unexecuted Native rows above for these selected cases; WASM/Embedded and arbitrary concurrent shutdown remain unqualified.
