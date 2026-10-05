# Controller continuation and bound-session publication

## Purpose and Scope
Parent: [Control](../DESIGN.md). Children: none. Own bounded controller clock/sample/hold schema, combination with existing actuator/integration contributors, physical cross-association checkpoint handler and original bound-session facade. DESIGN precedes source; qualification pending. Runtime remains the sole commit authority.

## Responsibilities and Boundaries
Encode/decode actual declared controller continuation, preserve existing actuator codec arithmetic/records and delegate generic Runtime validation/checkpoint/transaction behavior. Cold initialization creates a real RuntimeSession with the qualified wrapped checkpoint handler and initial actuator/controller/integration records. Tentative candidates are staged in its RuntimeTrial; no external mutable clock/PID/RNG mirror exists. Physical calculations belong to MechanicalPlant. Raw observation acquisition, sensor noise/delay/buffers and future remote transport are other owners.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Control](../DESIGN.md) | parent | Dispatch and qualification | Root index/evidence | Full CO-007/008 remains qualified by actual selected scope only |
| [SampledFeedback](../SampledFeedback/DESIGN.md) | depends on | Clock/effectiveDt/candidate law | Continuation meanings | No duplicated time rules |
| [MechanicalPlant](../MechanicalPlant/DESIGN.md) | depends on | Endpoint original physical proof | Publication prerequisite | Cached evidence is tentative |
| [Actuation Continuation](../../../Physics/Actuation/Continuation/DESIGN.md) | depends on | FixedActuatorContinuationCodec/ActuatorRuntimeContributors | Integral/filter binding | Preserve old producer behavior |
| [Runtime](../../Runtime/DESIGN.md) | depends on | performTrial, observe, checkpoint/restart, RNG, handler requirements | Actual commit/lease authority | Bare admitted value does not prove a session commit |
| [Integration Continuation](../../Integration/Continuation/DESIGN.md) | depends on | RK4 descriptor/history | Actual plant endpoint association | Signature and model must match |
| [Tests](../../../../../Tests/MechanicsControlTests/DESIGN.md) | used by | Cold/reject/restart physical replay | Local evidence | Original profile runtime required |

## Architecture
```text
cold model+law+clock -> bounded actuator/controller/integration records -> real RuntimeSession
 -> actual bound trial: pending controller + future actuator, unchanged physical start
 -> real RK4 physical endpoint -> ready controller
 -> full checkpoint cross-association wrapper -> original Runtime admit/finish
 -> actual RuntimeSession.observe -> immutable accepted control interval
```

## Contracts and Invariants
Planned required `ControlSessionCreating.make(plant:controller:clock:initialActuator:seed:policy:work:) throws(ControlFailure) -> any ControlSessionOperating` creates the real underlying RuntimeSession and its wrapped handler; callers cannot initialize this facade with a bare RuntimeAcceptedState or an arbitrary mutable accepted-state mirror. The session facade requirements are `step(input:)`, `observe(_:)`, `checkpoint(codec:)`, `restart(_:codec:)`, `cancel()`, `shutdown()` and `shutdownStatus()`. step input owns the immutable generic scalar observation, exact timestamped target and constant interval disturbance. Return/release of accepted control output occurs only inside a post-finish call to that actual session's observe, after checking the matching clock/actuator/physical prefix. This is a concrete session association, not a claim that a value's internal initializer proves commitment.

Controller continuation records preserve schema/configuration identity, model/joint/frame/indices, period/epoch/tick, phase ready|pending, sourceTime, sampleTickTime, interval start/end, target/mode/sequence, sampled values, applied held effort and endpoint accounting availability. Actuator state remains in its original separately encoded actuator contributor. RNG remains the original RuntimeRandomState; deterministic initial controllers have no independent RNG. Initial ready record is explicitly unissued at tick0, bound to the supplied initial physical time and matching actuator state; sampled fields are unavailable, not successful zero measurements.

During prepare, future ActuatorState.time equals intervalEnd and controller phase is pending while the physical trial time remains intervalStart. Pending records are legal only inside the bound trial and are refused by checkpoint admission. Write stages ready records at the endpoint. Individual RuntimeContributorHandling.validate has no physical state parameter: this child therefore wraps required RuntimeCheckpointHandling.admit/migrate to inspect the full immutable checkpoint for controller/actuator/physical/integration time, model/chart/source and sequence consistency, bounded before delegated admission. No existing Runtime supplier edit is needed. Initial migration is explicitly refused until all control configuration/chart/clock preservation rules are proved. This handler can still be called directly to admit a value; that value is never a Control session publication witness.

Actual RuntimeSession owns physical state, controller/actuator/integrator contributors, random seed/state/draw count and accepted sequence atomically. A rejected/failed trial changes none of that accepted tuple. Saved checkpoint replay under the exact continuation/build/backend/precision identity reproduces next commands, motion and RNG. Missing/extra/duplicate/corrupt contributors, pending or mutually incompatible times, changed laws/bindings and uncheckpointable callbacks fail. No state is kept in an external Mutex alongside Runtime to simulate an atomic update. The transient equation workspace described by MechanicalPlant is call-local scratch only.

## Runtime Flows
Cold construction -> initial full checkpoint association -> underlying Runtime session. Each step obtains the original bound accepted lease, creates a tentative interval equation, invokes actual existing RK4 and checks actual post-finish observe against the requested interval. Any failure discards trial candidates; it never automatically reuses an old command. Restart delegates bytes to the same real session/handler, then releases only its validated observe result. Shutdown follows Runtime owner/quiescence semantics, not a copied raw state. There is no asynchronous output queue in this initial local port.

## State, Ownership, and Lifecycle
The public facade retains one real RuntimeSession and immutable providers/configurations. Runtime's same Mutex owner protects all accepted state on all targets. Controller contributor bytes are the sole persisted clock/sample/hold state; the original actuator contributor is the sole persisted PID/filter state. No unchecked Sendable, conditional conformance or raw Embedded branch. Bytes are constructed/reused at preflighted output/checkpoint boundaries; schema/version and byte limits are explicit. External observation callbacks execute through original Runtime observe outside the owner's critical section. The facade delegates cancellation/shutdown/release to the underlying owner.

## Failure, Concurrency, and Constraints
Bounded codec, metadata, payload, contributor validation and cross-association consume caller budgets before traversal/copy/arithmetic. Protocol operations are requirements. Typed failures retain underlying Actuation/Dynamics/Integration/Runtime causes, phase and known cumulative work/unavailable flags. No accepted result is issued after failed original evidence or a failed callback. Concurrent step/restart and outstanding observers inherit Runtime busy/quiescence behavior. Initial fixed synchronous timestamp/ZOH contract does not claim remote delay/order/interpolation support beyond explicit stale/out-of-order refusal.

## Verification and Change Impact
Actual cold creation, step, checkpoint, rejected pending trial, failed supplier after preparation, RNG draw rejection and restart must reproduce exact contributor bytes/clock/integral/filter/sample/hold/next-command plus physical q/v and actual energy. Directly admitted bare accepted values never release a control event. Pending and physical/controller/actuator time mismatches must refuse before Runtime commit and preserve the previous accepted prefix. Observer callback failure, active observer/restart/shutdown, payload/metadata/validation budgets and stale law/chart are tested on the actual owner. Any schema/clock/law/physical association change requires new compatibility authority and upper replay requalification.
