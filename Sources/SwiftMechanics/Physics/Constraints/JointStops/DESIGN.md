# JointStops

## Purpose and Scope
Parent: [Constraints](../DESIGN.md). No children. IM.AF35.23 owns source-bound scalar gap preparation and one hard stop impact at an original boundary state for selected JT-005/DY-006. Selected Native, ordinary WASM and Embedded WASM behavioral evidence is owned by [JointStopsQualification](../../../../../Verification/JointStopsQualification/DESIGN.md); canonical registration and its current graph proof remain root responsibilities. Speed limits, compliant evolution, root location, simultaneous/constrained impacts, periodic wrap and complete limit enforcement remain open. Existing URDF limits remain unsupported.

## Responsibilities and Boundaries
Bind caller-owned lower/upper bounds to an actual compiled model stamp, joint identity and encoder SI unit; consume original scalar limit rows; compute a real unconstrained-tree velocity jump and original acceptance. Compiler owns tree/state/layout authority, Observations owns source-bound encoder quantities, ScalarJointPorts owns gap signs, Dynamics owns actual inertia/momentum/energy, ContactLaws owns threshold restitution. This child owns no body reaction, accepted Runtime token, event ordering, time advancement or foreign-format import authority.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [Constraints](../DESIGN.md) | parent | JT-005 responsibility | Full requirement remains open |
| [ScalarJointPorts](../ScalarJointPorts/DESIGN.md) | depends on | Real unwrapped revolute/prismatic rowsOnly gaps | Original impact branch remains unsupported |
| [Compiler](../../../Modeling/Compiler/DESIGN.md) | depends on | CompiledMechanicalModel evaluate/makeState | Compiler contains no bound inventory |
| [Joints](../../../Modeling/Joints/ArticulatedTrees/DESIGN.md) | depends on | Actual scalar q/v ranges and coordinate rates | Fixed-root spatial scalar tree only |
| [Observations](../../../Analysis/Observations/KinematicObservations/DESIGN.md) | depends on | Original source preparation and encoder | Source-associated rate/unit convention |
| [Dynamics](../../Dynamics/DenseDynamics/DESIGN.md) | depends on | Physical inverseMassProduct | Original system identity and ledger retained |
| [RigidEquations](../../Dynamics/RigidEquations/DESIGN.md) | depends on | Body Newton/Euler and actual kinetic energy | Dense assembly is not an impact acceptance oracle alone |
| [ContactLaws](../../ContactLaws/Impact/DESIGN.md) | depends on | ThresholdRestitutionPredictor | IM20 approach speed is in m/s |

## Architecture
```text
compiled model + actual compiled state + explicitly model-bound stop definition
    -> original ObservationSource + original encoder + ScalarJointPorts gap rows
    -> retained immutable prepared stop with original signed full-v rows
    -> boundary/approach admission -> original physical mass inverse
    -> positive restitution impulse -> full actual velocity jump
    -> model.makeState + original source/encoder reconstruction
    -> original normal-rate, Newton/Euler momentum, kinetic-loss and impulse-work gates
    -> tentative immutable result; no Runtime/event publication
```

## Contracts and Invariants
The definition owns a finite strict lower<upper interval in the declared .angle or .length SI coordinate, a ModelStamp, actual joint ID, explicit unwrapped/periodic selection and original ContactLawPair. No compiled/URDF bounds are invented. A positive metersPerCoordinateUnit defines the stop's one-dimensional normal metric: prismatic exactly1 m/m; rotary explicitly caller-selected m/rad. It is not inferred CAD contact geometry. This converts actual rotary rate to the m/s required by IM20 threshold restitution; no rad/s-as-m/s call exists. The normal metric does not grant a point/body reaction identity.

Admit spatial fixed-root trees composed only of fixed/revolute/prismatic joints, actual dynamic scalar authorities and fixed anchors. No descriptor extensions/features are admitted because this child cannot certify their constraint/force meaning. Target requires one q and one v slot; fixed targets, screw/multiaxis/quaternion charts and prescribed work are explicit refusals. Original encoder q, qdot, v, unit and orderedAxisRates convention must match actual published layout and source. Original scalar row gaps are lower=q-lower and upper=upper-q, with derivatives +1/-1. Their full-v rows use only the original identified scalar slot, scaled by the explicit normal metric. Preparation reports both gaps without selecting a reaction.

Impact admits only one selected side within caller normal-gap tolerance in meters; the opposite gap must be strictly outside that tolerance. No position snapping occurs. Normal approach rate vn=J*v must be negative beyond the caller m/s threshold. Actual W=J*M^-1*J^T must be finite positive above the caller effective-mass policy; IM20 produces e in [0,1], rebound and normal kinetic loss. p=-(1+e)*vn/W is a positive compressive normal impulse in N s. The coordinate-conjugate impulse is metersPerCoordinateUnit*p: N m s per radian for rotary, N s for prismatic. J^T*p is the full generalized impulse in original v order. These are impulses, never continuous torque/force or inferred body-origin reactions.

The returned delta-v is a final original inverseMassProduct(J^T*p), independently checked through original body Newton/Euler with includeBias=false. q, time, model revision and fixed anchors remain unchanged; generalized acceleration is explicitly reset to zero at the instantaneous jump and is not a solved continuous acceleration. model.makeState actually validates the proposal; original ObservationSource/encoder are reevaluated. Returned normal rate must equal the original rebound, and both gaps must remain original. Actual pre/post kinetic energies are queried on reconstructed physical systems. Delta-K+normalLoss=0, generalized midpoint impulse work=Delta-K and p*(vnMinus+vnPlus)/2=-normalLoss must pass. No finite-duration power is fabricated.

## Runtime Flows
Capacity/metadata/cancel -> structural domain -> actual compiled source/encoder -> original scalar gaps -> immutable preparation. Impact rechecks current capacity/source/policy -> real mass assembly/inverse -> original restitution -> final mass jump -> actual compiled post reconstruction -> original acceptance -> cancellation -> tentative output. Time evolution/event enforcement has no declared operation in this API.

## State, Ownership, and Lifecycle
Definition, input, policy and results are immutable Sendable; prepared source is a final immutable owner with producer-only initialization. NumericalWork/LoadWork/ContactWork retain exclusive inout ownership. All scratch is call-local, with identical Native/WASM/Embedded contracts and no shared mutable cache, unsafe pointer, target branch or synchronization substitute.

## Failure, Concurrency, and Constraints
Typed failures identify stale source/unit/layout/identity, unsupported domain/wrap/material selection, nonboundary/ambiguous/nonapproaching states, singular normal inertia, original rate/momentum/work/energy rejection, cancellation and resource exhaustion. Immediate incomplete markers precede callable unsupported domains. Checked count products/sums precede allocation; input q/v/body/inertia/anchor/metadata inventories are bounded. A conservative live scalar reservation 24*B*N+4*N*N+1024*B+64*N+256 includes retained initial and post snapshots, physical systems, rows, encoder/query results and acceptance scratch. Original compiled tree evaluation has no ledger: 8192*B+1024*B*N logical operations are charged before each original source/evaluation call. Nested observation/mass ledgers are seeded and monotonically reconciled; failed opaque work is terminal and marked unavailable. The allowances are source-derived, not measured allocations or performance. Caller cancellation is checked at bounded phase/loop boundaries, with original supplier cancellation retained.

## Verification and Change Impact
Source-only review/freeze is not behavior qualification. [JointStopsQualification](../../../../../Verification/JointStopsQualification/DESIGN.md) owns independent analytic coupled prismatic response, both prismatic boundary signs, rotary SI metric/threshold, fresh original encoder, Newton/Euler momentum and kinetic/impulse-work recomputation, selected typed refusals, bounded work and failed supplier ledgers. Its unchanged selected cases executed on exact Native, ordinary and Embedded profiles. Native alone additionally exercises actual awaited Task cancellation; synchronous WASI cases do not qualify target scheduling or concurrency. Original stack reservation and complete stack-write guards are demonstrated only for the executed public artifacts. Allocation/copy counts, scaling, all joint-family/boundary combinations and complete limit enforcement remain unmeasured or open. [FoundationVerification](../../../../../Verification/FoundationVerification/DESIGN.md) owns original supplier evidence; it does not qualify this consumer. Root alone owns canonical registration, integration, Runtime enforcement and foreign-format limit admission.
