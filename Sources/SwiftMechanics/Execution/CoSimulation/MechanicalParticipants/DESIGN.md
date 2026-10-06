# Actual held-effort prismatic participants

## Purpose and Scope
Parent: [CoSimulation](../DESIGN.md). Children: none. Own concrete selected participant configurations, actual qualified factory creation, current observation/encoder preparation, held-force stepping and original checkpoint/restart receipts.

## Responsibilities and Boundaries
Consume ReferenceControlSessionFactory with its real default ReferenceDriveEvaluator, RigidEquationKernel, DenseRigidDynamics and ReferenceExplicitIntegrator. Public configuration includes actual admitted PrismaticControlPlant, SampledController, initial ActuatorState, ControlClock, ControlPolicy, ObservationPolicy and seed. No injected arbitrary session/factory or raw internal observation constructor is accepted. Runtime/control accepted state remains supplier-owned.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [CoSimulation](../DESIGN.md) | parent | Exclusive adapter creation | Macro ownership | Handles stay private |
| [MacroCoupling](../MacroCoupling/DESIGN.md) | used by | Actual observations/held force/checkpoint/restart | Physical contributor | Failure may follow a real commit |
| [MechanicalPlant](../../Control/MechanicalPlant/DESIGN.md) | depends on | Real rigid/RK4 original force/energy evidence | IM15/AF31.23 | Fixed-root single spatial prismatic model only |
| [Control continuation](../../Control/Continuation/DESIGN.md) | depends on | make/step/observe/checkpoint/restart | Actual session publication | No raw staged endpoint API |
| [Observation records](../../../Analysis/Observations/ObservationRecords/DESIGN.md) | depends on | Source preparation | Qualified selected IM.AF30 | No full IM25 claim |
| [Kinematic observations](../../../Analysis/Observations/KinematicObservations/DESIGN.md) | depends on | Original public encoder issuance | Physical current q/v source | No internal memberwise constructor |

## Architecture
```text
admitted plant+servo effort/filter0+real initial state -> original Control factory
actual Control.observe -> public ObservationSourcePreparer -> public KinematicObserver.encoder
held coupling N -> real DriveCommand(.effort) -> ControlSampleInput -> original Control.step
    -> actual original q/v/K/disturbance-work/force-residual receipt
```

## Contracts and Invariants
Admit law servo, mode effort, filterTimeConstant exactly zero; actual limits/state envelopes remain caller-supplied and are never overridden. Admission requires effort secondary-state domain to include the full [-effortLimit,effortLimit] command range. Every command is finite, within effort bounds, and sampled velocity below the servo speed cutoff. Receipt gate requires issued/ready tick+1, exact interval/Runtime time, actual heldEffort equal requested force, clipping false, original q/v matched with physical state and actuator binding/time/mode. Fixed plant.disturbanceNewtons is a separate constant external force; ControlSampleInput has no variable disturbance field. Actual work is heldEffort*(qEnd-qStart) and fixedDisturbance*(qEnd-qStart), not the actuator's start-sample work approximation.

## State, Ownership, and Lifecycle
Adapters are immutable Sendable owners of one real private ControlSessionOperating and immutable configuration. Operation-local observation capture uses let Mutex<ControlObservation?> on every target. Actual callbacks only store/retrieve immutable receipts in short lock scopes. Capture lifetime ends after observe. No public participant/session handle, fake endpoint, mutable physical mirror, unsafe property or target-specific conformance.

## Failure, Concurrency, and Constraints
Caller-ledger precharges immutable declared supplier maximum quanta before operations; step receipts retain actual IntegrationWorkReport and ActuationWork. Opaque failed work remains unavailable. NativeRuntimeCheckpointCodec is fixed and original. Restore must be followed by original observe and exact RuntimeAcceptedState comparison to saved prefix. Runtime capacity/validation/codec and original control cancellation remain authoritative.

## Verification and Change Impact
Later exact underlying RK4/dynamics/control/source-bound encoder dispatch, effort/filter/limit refusal, checkpoint/restart/RNG/controller-state replay and post-commit observe failures must execute. New source is unqualified despite qualified suppliers. Published physical evidence never derives merely from [q,v] array shape.

### Concrete admission and publication
The selected IntegrationBudget has maximumAttempts=1 and maximumAcceptedSteps=1, and Control still proves a real single RK4 endpoint. Public adapter configuration carries its encoder NumericalBudget separately. Identifiers are explicit bounded nonempty UTF8 strings; both models and actuators must have distinct identities. Configuration refuses non-effort initial actuator mode, nonzero servo filter and secondary domains narrower than the entire effort envelope. Initial public observation proves q/v/time and binding; its unissued kinetic zeros are never accepted as physical K evidence. Cold construction failure destroys private sessions through original shutdown. Public boundary snapshot is an immutable pair of original observations and the cumulative ledger; it never exposes a session handle.

### Independent qualification preparation
The [selected public fixture owner](../../../../../Verification/CoSimulationQualification/DESIGN.md) fixes nine synchronous physical/refusal/recovery cases and a separately awaited Native Task cancellation case. Fixtures consume original immutable2363 Control/Runtime APIs, with independent constant-force motion, kinetic work and integrated power oracles. All eighteen production Swift files remain identical to that original producer. The current live RuntimeSession change is outside this evidence premise. No compiler or runtime has executed these fixtures; existing source review is not upgraded to behavioral success. Future source repairs require a concrete original failing case and a matching new producer before rerun.
