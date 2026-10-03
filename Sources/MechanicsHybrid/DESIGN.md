# MechanicsHybrid

## Purpose and Scope
Parent: [system/package](../../DESIGN.md). IM24 owns DY-006 and TI-005..006 in [SPEC](../../SPEC.md): impact impulses, event location and accepted contact evolution. Children: [ImpactPorts](ImpactPorts/DESIGN.md), [NormalImpulse](NormalImpulse/DESIGN.md), [EventEvolution](EventEvolution/DESIGN.md), [Continuation](Continuation/DESIGN.md). The initial source is fixed after coherent review and findings-limited corrections; fifteen Native behavioral cases and selected Native/ordinary-WASM/Embedded-WASM public execution passed. Full eventual requirement ownership remains; coupled/frictional impulses, general trajectories and IM16 event reconciliation remain unqualified.

## Responsibilities and Boundaries
Worker owns only Sources/MechanicsHybrid child directories and Tests/MechanicsHybridTests. Root owns this module index, Package/global probes/PROGRESS/commits. Hybrid owns discontinuity ordering, original jump/event acceptance and binding to required Runtime continuation. Suppliers retain smooth stages, mass operators, collision witnesses and contact laws. Accepted wake/constraint reconciliation is coordinated with the future IM16 owner through public contracts; no unimplemented participant is inferred.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Root](../../DESIGN.md) | parent | Composition and dispatch | Sole graph/index authority | IM48 remains separate |
| [Runtime](../MechanicsRuntime/DESIGN.md) | depends on | Actual trials, rollback, contributor and cancellation | Verified handoff 6ae2742 | Nonqueuing admission; association must be checked at the actual trial |
| [Integration](../MechanicsIntegration/DESIGN.md) | depends on | Identified explicit smooth equations and accepted stages | Verified handoff 170033b | Euclidean RK4/Heun only; no unqualified dense output |
| [Dynamics](../MechanicsDynamics/DESIGN.md) | depends on | Actual rigid mass and original inertial operators | Verified handoff 9e59193 | Admitted spatial tree domain |
| [ContactResponse](../MechanicsContactResponse/DESIGN.md) | depends on | Identified witness/point ports and physical residual meaning | Verified handoff 170033b | Current compliant response is not hard impulse physics |
| [Collision](../MechanicsCollision/DESIGN.md) | depends on | Analytic witnesses and translation CCD | Verified handoff 13c6985 | General rotational CCD is unsupported |
| [ContactLaws](../MechanicsContactLaws/DESIGN.md) | depends on | Explicit restitution/threshold and damping selection | Verified handoff 2134ea2 | Constitutive prediction does not evolve a body |

## Architecture
```text
real accepted smooth state + identified event/witness domain
 -> bounded location / simultaneous-event policy
 -> actual mass-based jump and independent impulse/law/energy residual
 -> Runtime accepted physical + required event continuation or unchanged prefix
```

## Contracts and Invariants
Child designs precede callable declarations. State layout/frame/revision, event direction/time interval/root tolerance, collision fidelity, restitution/loss law and force-versus-impulse meaning are explicit. Hard-impact equations cannot substitute compliant force times an arbitrary step. Simultaneous ordering/chatter limits are caller-owned. Original momentum/law residuals and modeled energy loss decide acceptance. Missing dense-output/query/physics domains fail explicitly rather than silently interpolating or inventing forces.

## State, Ownership, and Lifecycle
Mutable workspace is exclusive and bounded; persistent event/warm state is an explicit required Runtime contributor. Rejected or failed events preserve accepted physical, event, actuator and random state. Shared state and Sendable/isolation remain identical on Native/WASM/Embedded. External callbacks and solver work occur outside short metadata locks.

## Failure, Concurrency, and Constraints
Invalid event domain, stale witness/model, inconsistent or unresolved simultaneous jump, unsupported chart/backend, nonfinite state, root/cascade/resource exhaustion and cancellation are typed failures with the real accepted prefix. Separate supplier/outer ledgers record known work; unknown failed work cannot authorize retry. API availability follows actual suppliers. Fixed debug stack frames must remain local to phases; no target-specific physics or memory-profile workaround is implicit.

## Verification and Change Impact
Tests/MechanicsHybridTests owns independent analytic velocity/impulse/energy jumps, real bounce/event-time evolution, simultaneous direction/order, rollback/restart and invalid/resource/cancel proof for the explicitly admitted domain. Root owns exact selected-profile public execution after source freeze. Deferred domains remain IM24 responsibility. Changed event/impulse/contributor contracts require rechecking direct and transitive consumers; unrelated supplier evidence remains valid.

Actual initial dependencies: Core, Model, Numerics, Joints, Compiler, Loads, Dynamics, Collision, ContactLaws, Runtime and Integration. Hard impact owns distinct impulse witnesses; it does not reinterpret the compliant ContactResponse adapter. The selected constant-acceleration sphere/plane trajectory uses isolated real reintegration, not translation CCD on curved paths. Test owner: [Hybrid tests](../../Tests/MechanicsHybridTests/DESIGN.md).
