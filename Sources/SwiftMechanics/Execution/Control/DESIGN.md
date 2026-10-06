# Control

## Purpose and Scope
Parent: [Execution](../DESIGN.md). Children: [Ports](Ports/DESIGN.md), [SampledFeedback](SampledFeedback/DESIGN.md), [MechanicalPlant](MechanicalPlant/DESIGN.md), [Continuation](Continuation/DESIGN.md). Own sampled physical feedback orchestration for the selected AF31 scalar fixed-root spatial prismatic plant. Full CO requirements remain open outside qualified child domains.

## Responsibilities and Boundaries
Compose admitted feedback, controller sampling, actual mechanical evolution and controller continuation. Runtime retains sole accepted-state authority; the original RK4 integrator and rigid dynamics remain physical suppliers. Raw sensors and delivery queues belong to Observations. This directory is one component within the existing SwiftMechanics module.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [LinearEstimation](LinearEstimation/DESIGN.md) | child | Source-bound fixed-clock Kalman prediction, Joseph update and continuation | Selected Native8/public7 plus Task on immutable2124 | Actual Support/Public13, Testing14; portable and accepted Runtime association remain open |
| [Execution](../DESIGN.md) | parent | Trial ownership and publication | Responsibility placement | Preserve accepted-state authority |
| [Ports](Ports/DESIGN.md) | child | Identified dimensioned feedback | Input admission | Raw feedback is not a session publication witness |
| [SampledFeedback](SampledFeedback/DESIGN.md) | child | Effective interval and held controller effort | Tentative sampling | No guessed nominal-step substitution |
| [MechanicalPlant](MechanicalPlant/DESIGN.md) | child | Original RK4 and physical endpoint evidence | Actual plant response | Sampled actuator work differs from actual interval work |
| [Continuation](Continuation/DESIGN.md) | child | Full checkpoint association and bound session | Atomic state and replay | No external accepted-state mirror |
| [Runtime](../Runtime/DESIGN.md) | depends on | Trial, observe, checkpoint and shutdown | Sole commit authority | Required public operations only |
| [SensorPipeline](../../Analysis/Observations/SensorPipeline/DESIGN.md) | coordinates with | Identified immutable readings | Future shared-world composition | Separate privately owned sessions do not establish one atomic sensor-control world |

## Architecture
```text
identified feedback -> Ports -> SampledFeedback -> held effort
                         original RK4 -> MechanicalPlant -> endpoint evidence
controller + actuator + integration continuation -> Runtime trial -> commit -> bound observe
```

## Contracts and Invariants
Consume child guarantees without duplicating their time, physical or codec rules. Preserve full model/chart/source/units association, original equations and caller acceptance tolerances. All candidate control records are tentative until the original bound session commits. Actual held interval energy must come from the physical plant contract. Unsupported controller/plant/composition domains fail explicitly.

## State, Ownership, and Lifecycle
Runtime owns the accepted physical/controller/actuator/integration/RNG tuple. Child continuation records own persistent control state. MechanicalPlant owns only call-local tentative scratch, using identical Mutex and Sendable contracts on all profiles. External callbacks run outside critical sections.

## Failure, Concurrency, and Constraints
Children retain typed original failures and cumulative known work. Caller-owned limits precede arithmetic, traversal and allocation. Cancelled, rejected, busy, corrupt or unsupported operations publish no candidate state. Combined sensor/control ownership requires a subsequent same-session composition contract.

## Verification and Change Impact
[MechanicsControlTests](../../../../Tests/MechanicsControlTests/DESIGN.md) owns real plant, clock, energy, rejection and replay tests. Root owns registration and original-profile public composition. Child contract changes require checking sibling assumptions and the Execution parent. DESIGN existence is not behavioral qualification.

### Registered external scalar commands
Child [ExternalCommands](ExternalCommands/DESIGN.md) owns the qualified selected timestamped scalar scheduling/drive service. [Qualification](../../../../Verification/ExternalCommandsQualification/DESIGN.md) owns Native, ordinary/Embedded and canonical evidence; Runtime acceptance, transport, vector channels and coupled evolution remain separate obligations.

## Selected task-space control

[TaskSpace](TaskSpace/DESIGN.md) owns tentative fixed-root Euclidean point acceleration and body-origin wrench control. Its child contract records selected Native qualification and explicit unsupported-domain refusals. Accepted Runtime publication, constrained force allocation and original portable execution remain separate obligations.
