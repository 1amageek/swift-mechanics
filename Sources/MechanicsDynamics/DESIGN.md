# MechanicsDynamics

## Purpose and Scope
Parent: [system/package](../../DESIGN.md). Own IM15 rigid equation terms, forward/inverse/mixed solves and physical energy/wrench accounting. The initial producer must publish a verified admitted tree domain before broader DY family closure. Children are indexed after their actual contracts exist. [SPEC](../../SPEC.md) owns requirements and [plan](../../IMPLEMENTATION_PLAN.md) owns the prerequisite graph.

## Responsibilities and Boundaries
Consume public tree motion/Jacobian and complete inertia records; own mass/bias/force equation meaning and independent residual acceptance. Constraint/contact response, accepted-time evolution, collision, actuation and model compilation remain consumers or independent owners. Generic numerical tree elimination is not an articulated-body dynamics implementation.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Root](../../DESIGN.md) | parent | Scope and dispatch | Single-writer package composition | Full closure remains IM48 |
| [Numerics](../MechanicsNumerics/DESIGN.md) | depends on | Actual residual-accepted dense solve and work budgets | Finite equation solution | Nested resource/failure evidence is explicit |
| [Joints](../MechanicsJoints/DESIGN.md) | depends on | q/v/vdot convention, framed body/point Jacobians and prescribed bias | Actual tree motion | Geometric linear velocity differs from origin spatial linear velocity |
| [Loads](../MechanicsLoads/DESIGN.md) | depends on | Framed JT loads and power partition | Mechanical external work | Potential/impulse/force semantics remain distinct |
| [Model](../MechanicsModel/DESIGN.md) | depends on | Complete physical mass/COM/inertia records | Actual inertial meaning | Display geometry never supplies missing mass |

## Architecture
```text
identified tree + valid inertia + q/v + prescribed motion
 -> actual framed kinematics/Jacobians -> mechanical M/bias/energy + explicit applied loads
 -> inverse terms / admitted forward or mixed solve -> original mechanical residual
 -> immutable evidence or typed failure
```

## Contracts and Invariants
Service operations are protocol requirements. Every inertia matches its body frame/identity and admitted physical policy. COM transport and gyroscopic terms follow actual declared world/body conventions. Returned mass, bias, external-force and acceleration terms must reconstruct the original equation and independently satisfy virtual-power/energy expectations. Solver regularization or unavailable physical terms cannot silently alter the problem. Initial admission, mixed authority, unsupported cases and resource limits are child-owned contracts established before implementation.

## State, Ownership, and Lifecycle
Immutable Sendable model/input/output, exclusively owned operation-local workspace; no accepted-state mutation or shared cache. Shared reference additions require identical isolation and conformance on every target. Runtime adoption/checkpoint remains IM08.

## Failure, Concurrency, and Constraints
Invalid/missing inertia, mismatched frames/layouts/revision, singular mass, nonfinite terms, unsupported physics and exhausted work/storage/cancellation yield typed failure. No partial acceleration or manufactured zero bias is successful output. Caller policies own tolerances and bounds; cost/storage are declared per admitted algorithm.

## Verification and Change Impact
Test owner is Tests/MechanicsDynamicsTests when actual sources exist. Independent free rigid-body Euler and mechanical pendulum fixtures, forward/inverse reconstruction, JT/power balance and invalid/resource paths must exercise production code. Root separately owns exact Native/WASM/Embedded selected composition. Changed inertial/equation conventions invalidate downstream constraints/contact/integration/analysis/observations.
