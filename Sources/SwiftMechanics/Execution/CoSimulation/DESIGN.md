# Selected physical co-simulation

## Purpose and Scope
Parent: [Execution](../DESIGN.md). Own AF35.14's EX-008/CO-008 selected local two-participant, equal-clock, explicitly held scalar force coupling. Children: [MechanicalParticipants](MechanicalParticipants/DESIGN.md), [MacroCoupling](MacroCoupling/DESIGN.md). The selected held-force contract has independent Native10/public9 evidence against a matching immutable2270 producer; shared registration is owned by root and remains pending. Vehicle/terrain/fluid co-simulation and portable qualification remain open.

## Responsibilities and Boundaries
Own exclusive creation of both qualified real Control/Runtime physical participants, macro-boundary observation publication, interface coupling and known-prefix rollback/failure. Runtime remains the sole individual physical/contributor/RNG commit owner. A sequential internal commit with private handles is not distributed two-phase commit. There is no generic callback graph, external engine transport, speculative asynchronous participant or invented physical endpoint.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Execution](../DESIGN.md) | parent | Execution owner boundary | New local product | Shared registration owned by root |
| [MechanicalParticipants](MechanicalParticipants/DESIGN.md) | child | Actual control participant/receipts/checkpoint | Existing RK4/rigid physical path | Only selected prismatic effort domain |
| [MacroCoupling](MacroCoupling/DESIGN.md) | child | Exclusive coordinator/cumulative work/rollback | Macro publication | No cross-Runtime commit token |
| [Runtime sessions](../Runtime/Sessions/DESIGN.md) | depends on | One-owner performTrial/restart/observe/lifecycle | IM08 authority | Restart can fail on cancellation/closed/capacity |
| [Control continuation](../Control/Continuation/DESIGN.md) | depends on | Real factory/step/observe/checkpoint/restart | Qualified AF31.23 | Already commits before step returns |

## Architecture
```text
explicit two real prismatic configurations -> exclusive private participants
macro source tick/time -> save both original checkpoints -> compute held paired force
    -> actual first RK4/Runtime commit -> actual second RK4/Runtime commit
    -> original physical/interface checks -> macro receipt publication
    -> failure: attempt both original restarts -> exact original-prefix checks
                                      -> restored rejection / poisoned known-prefix failure
```

## Contracts and Invariants
Conjugate coordinate/rate/effort units are m, m/s, N. Participants expose only actual receipt values issued by qualified Control/Runtime/Observation APIs. Coupling is an ideal 1:1 generalized translation-port spring/damper; no collinearity, geometrical bearing reaction or world contact-force claim is inferred. Both real clocks must be identical; source time/tick and both accepted states must agree exactly. Zero-order-held force is the only selected exchange; nonzero delay, interpolation and iterative coupling are explicit unsupported policies. Macro receipts include original interface work, kinetic-energy/force evidence, external fixed-disturbance work, spring-energy change, continuum damping loss and the discretization energy defect. Caller bounds the original defect and its cumulative absolute value rather than labeling it physical dissipation.

## State, Ownership, and Lifecycle
The coordinator creates and exclusively retains both concrete participant adapters; no session handle escapes. A common Mutex protects operation admission, published receipts, cumulative ledger, poison and shutdown flags on all targets. Supplier callbacks and Runtime operations execute outside the short lock. Individual accepted state remains inside each original Runtime owner; published macro receipts retain actual immutable accepted values, not independently writable physical mirrors.

## Failure, Concurrency, and Constraints
Failure before mutation preserves known prefix. After mutation, every participant is offered its original checkpoint; successful rollback requires exact actual accepted-state equality, not simply a successful restart return. Failed rollback or unavailable failed-supplier consumption poisons the coordinator; later successful stepping/publication is forbidden and reconstruction is explicit. Cancellation is not rewritten as rollback success. Reports retain actual Runtime failure prefixes when observations cannot be acquired and explicitly mark any current prefix unavailable. All declared supplier quanta accumulate across cold start, macro calls, observation/checkpoint and recovery; budgets are never reset by rollback.

## Verification and Change Impact
Later independent physical coupled-run, force/work/power/energy-defect, rejected macro, both-owner restoration, cancellation/poison/current-prefix, complete contributor/RNG replay, concurrency/reentry/lifecycle and exact target runtime evidence are required. No builds/tests/probes/Git in this source-first phase. Parent/child contracts must remain consistent; changed individual Runtime/Control publication or supplier ledgers invalidate macro assumptions.

Current-prefix acquisition failure retains the most recent actual receipt separately as lastKnown; this is never substituted for current. Dropping the coordinator invokes both original shutdown operations outside state locks. Numerical/actuation recorded totals cover reconciled original receipts only; failed supplier receipts remain in typed failure evidence and opaque work is represented by its admitted ceiling, not fabricated measured totals.

### Historical independent qualification preparation
The [selected public fixture owner](../../../../Verification/CoSimulationQualification/DESIGN.md) fixes nine synchronous physical/refusal/recovery cases and a separately awaited Native Task cancellation case. Fixtures consume original immutable2363 Control/Runtime APIs, with independent constant-force motion, kinetic work and integrated power oracles. All eighteen production Swift files remain identical to that original producer. The current live RuntimeSession change is outside this evidence premise. No compiler or runtime has executed these fixtures; existing source review is not upgraded to behavioral success. Future source repairs require a concrete original failing case and a matching new producer before rerun.


### AF38 selected closure
The fresh common producer uses committed f0325b0 Runtime, not live AF31. Original Native10 execution exposed a concrete stack-guard failure through the owned macro step. The causal phase/lifetime change is specified by [MacroCoupling](MacroCoupling/DESIGN.md#AF38-concrete-Native-stack-lifetime-repair). Original physical laws, complete contributor/RNG rollback, supplier authority and cumulative work remain unchanged. The old2270 producer and failed runtime receipt are retained. The matching repaired producer and unchanged Native10/public9 passed; the fixture owner records the exact proof below.

### Selected Native evidence
The [qualification owner](../../../../Verification/CoSimulationQualification/DESIGN.md#AF39-matched-repair-Native-evidence) binds the repaired18 source files and unchanged8 fixture files to committed f0325b0 Runtime and the matching2270 source/object/module/dylib composition. Original10 Native tests and9 direct public cases passed with unchanged physical laws, SI oracles, tolerances, cumulative work, full contributor/RNG recovery and cancellation. The original SIGBUS evidence is retained. The phase/lifetime repair preserves the public contract; no total-stack, arbitrary concurrency, external-engine or portable qualification follows. Shared registration remains a separate root operation.
