# PrescribedMotions

## Purpose and Scope
Parent: [Joints](../DESIGN.md). No children. AF23 component owning immutable identified analytic relative frame trajectories and mathematically valid pose/velocity/acceleration samples at a requested physical time. Production and dedicated source tests are implemented; execution qualification is root-owned and pending this frozen handoff.

## Responsibilities and Boundaries
Own finite coefficients/axis/rotation/domain validity, bounded canonical law metadata, sampling requirements, independently recomputed original law samples and mathematical failed-work accounting. ArticulatedTrees owns PrescribedAnchorState/FrameMotion and actual tree composition. Geometry/upper own binding to actual compiled model, parent frame/complete required anchor inventory/body modes/coordinate authority and physical closure. Dynamics owns inertia/energy/work. Runtime/history/checkpoint/cancellation control have no dependency in this component. The programme does not retain CompiledMechanicalModel or ModelStamp; Joints-to-Compiler dependency would be a backedge. A complete motion program is not by itself proof of a force-driven domain or full prescribed floating-root partition.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Joints](../DESIGN.md) | parent | Motion conventions and component index | Mathematical kinematics owner | Root owns parent index |
| [ArticulatedTrees](../ArticulatedTrees/DESIGN.md) | depends on | PrescribedAnchorState, JointAnchor, FrameMotion | Identified relative motion input/output | Actual required frame/time set is tree authority |
| [KinematicAlgebra](../KinematicAlgebra/DESIGN.md) | depends on | FrameMotion convention/composition | Parent axes and moving-origin derivatives | Do not invent world-frame substitutions |
| [Core geometry](../../../Mathematics/Core/Geometry/DESIGN.md) | depends on | finite vector/pose/quaternion operations | Analytic scalar/vector mathematics | Raw initial rotation must remain validated, not silently normalized |
| [LinearAlgebra](../../../Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | NumericalWork and bounded arithmetic | Explicit mathematical resource contract | No reverse Joints dependency |
| [GeometricRelations](../../../Physics/Constraints/GeometricRelations/DESIGN.md) | used by | immutable program, sampling and original verification | Consumer binding law to actual model/frame geometry | Geometry does not become law authority |
| [NonlinearEvolution](../../../Physics/Mechanisms/NonlinearEvolution/DESIGN.md) | used by | actual-time sampling requirement | Stage sampling and physical/history association | No Runtime/history dependency back into motion |

## Architecture
```text
bounded immutable identified coefficients + reference relative pose + interval
 -> mathematical admission + canonical law metadata
 -> explicit-time analytic sample (pose, first derivative, second derivative)
 -> independent original law verification -> canonical PrescribedAnchorState array
 -> actual tree / geometry / physical evolution consumers
```

## Contracts and Invariants
Immutable Sendable `AnalyticPrescribedMotion` records declare anchor frame and relative parent frame IDs, reference time t0, pinned initial relative pose (p0,R0), parent-axis translation rate u0/acceleration c, fixed unit parent-frame rotation axis k, angular rate w0/angular acceleration alpha, and a finite validity interval. Duplicate frame IDs, non-frame identifiers, incompatible axes or invalid raw rotations are rejected. For dt=t-t0, the law is:

```text
p(t) = p0 + u0*dt + c*dt^2/2       pdot(t)=u0+c*dt       pddot(t)=c
R(t) = Rot(k, w0*dt+alpha*dt^2/2) * R0
omega(t)=k*(w0+alpha*dt)           angularAcceleration(t)=k*alpha
```

Translation derivatives are at the relative frame origin in parent axes, as required by FrameMotion. A fixed parent-frame axis makes the displayed angular derivative exact. World motion/Coriolis transport belongs to the existing FrameMotionComposer. At t0 the pinned pose remains exact; no identity pose or zero derivative replaces input. Finite coefficient/time products and quaternion/vector results are checked at every requested time. Time outside the declared interval fails rather than clamps/extrapolates.

`PrescribedMotionProgram` stores bounded canonical frame-ordered records and metadata `analytic-anchor-v1`, including both declared frame IDs, every original coefficient/reference pose/raw rotation/t0, law kind and validity interval. It owns no mutable callback state, model ID authority or Runtime state. Programme capacity includes record/sample count, identifier UTF-8 bytes, metadata bytes, scalar workspace and checked arithmetic before allocation. Consumers independently verify the declared parent frame and complete required frame set against the actual model/tree; a mathematically valid partial program cannot stand in for a complete model sample set.

`PrescribedMotionSampling: Sendable` declares a non-generic requirement `sample(program, time, policy, work)` returning immutable `PrescribedMotionSample` with canonical metadata/time and complete identified samples through typed PrescribedMotionError. All existential operations are witnesses. Builtin analytic sampling is concrete mathematical implementation. Sealed `OriginalPrescribedMotionAcceptance` recomputes the immutable original law, validates metadata, exact time/frame/order/raw pose/velocity/acceleration and returns original samples as authority. Supplier diagnostics, matching IDs, copied mutable callbacks and within-tolerance changed law values cannot alter the imposed motion. Exact model.makeState admission remains a separate consumer requirement.

## Runtime Flows
This section describes synchronous mathematical operations only. Consumer reserves irreversible admission and a seeded remaining NumericalWork before opaque sampler invocation. Both success and failure validate supplier budget/counters and absorb known prefix before propagation. Original verification is a bounded direct builtin operation. A policy may expose a Sendable cancellation predicate; there is no RuntimeStepControl, Task/history/clock dependency. Requested time is an explicit input, never a hidden wall clock.

## State, Ownership, and Lifecycle
All records/programs/samples/policies are immutable Sendable. Work and output buffers are exclusive operation locals. No shared mutable cache, target branch, unsafe storage or synchronization exception exists. Output ownership retains immutable sample backing; consumer construction and publication retain complete arrays by value ownership.

## Failure, Concurrency, and Constraints
Typed PrescribedMotionError distinguishes invalid coefficient/axis/frame/law, shape/time/domain/metadata/source, nonfinite arithmetic, capacity, cancellation and supplier ledger reset/unavailable work; nested mathematical failures preserve meaning. Every output/sample/identifier bound passes before traversal/allocation/callback. Success and failure cannot reset seeded budget/counters. Unknown failed opaque work stops and cannot be retried under a smaller step. An analytic interval limit is mathematical correctness, not an estimated operational default.

## Verification and Change Impact
Dedicated mathematical tests are [PrescribedMotionTests](../../../../../Tests/MechanicsJointsTests/PrescribedMotionTests.swift). Component registration and exact-profile proof remain root-owned. Independent analytic translation and fixed-axis quadratic rotation oracles verify pose, velocity and acceleration at t0 and nonzero times, nonidentity pinned rotation/translation, parent-axis conventions, exact interval boundary, canonical metadata and bad coefficient/axis/time/frame/capacity cases. Injected sampler wrong-law/time/source/reset-success/reset-failure/late-cancel tests must exercise the actual supplier and original verifier paths. Consumers additionally require actual tree/geometry/dynamics/Runtime proofs; mathematical tests never qualify moving-base mechanical work, checkpoint replay, or fully prescribed floating-root partition. Motion metadata or derivative changes invalidate those upper assumptions and require their affected behavioral evidence to be renewed.
