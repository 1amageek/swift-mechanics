# Dynamics component

## Purpose and Scope
Parent: [responsibility owner](../DESIGN.md). Own IM15 rigid equation terms, forward/inverse/mixed solves and physical energy/wrench accounting. The initial producer must publish a verified admitted tree domain before broader DY family closure. Children: [RigidEquations](RigidEquations/DESIGN.md), [DenseDynamics](DenseDynamics/DESIGN.md). [SPEC](../../../../SPEC.md) owns requirements and [plan](../../../../IMPLEMENTATION_PLAN.md) owns the prerequisite graph.

## Responsibilities and Boundaries
Consume public tree motion/Jacobian and complete inertia records; own mass/bias/force equation meaning and independent residual acceptance. Constraint/contact response, accepted-time evolution, collision, actuation and model compilation remain consumers or independent owners. Generic numerical tree elimination is not an articulated-body dynamics implementation.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [RigidEquations](RigidEquations/DESIGN.md) | child | Framed original inertia and known load equations | Admitted spatial tree | Uniform gravity; no unknown reactions |
| [DenseDynamics](DenseDynamics/DESIGN.md) | child | Forward/inverse/mixed and independent physical acceptance | Float64/referenceCPU Cholesky | Dense complexity; no ABA claim |
| [Responsibility owner](../DESIGN.md) | parent | Scope and dispatch | Single-writer package composition | Full closure remains IM48 |
| [Numerics](../../Mathematics/Numerics/DESIGN.md) | depends on | Actual residual-accepted dense solve and work budgets | Finite equation solution | Nested resource/failure evidence is explicit |
| [Joints](../../Modeling/Joints/DESIGN.md) | depends on | q/v/vdot convention, framed body/point Jacobians and prescribed bias | Actual tree motion | Geometric linear velocity differs from origin spatial linear velocity |
| [Loads](../Loads/DESIGN.md) | depends on | Framed JT loads and power partition | Mechanical external work | Potential/impulse/force semantics remain distinct |
| [Model](../../Modeling/Model/DESIGN.md) | depends on | Complete physical mass/COM/inertia records | Actual inertial meaning | Display geometry never supplies missing mass |

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
Test owner: [MechanicsDynamicsTests](../../../../Tests/MechanicsDynamicsTests/DESIGN.md). Independent free rigid-body Euler and mechanical pendulum fixtures, forward/inverse reconstruction, JT/power balance and invalid/resource paths must exercise production code. Root separately owns exact Native/WASM/Embedded selected composition. Changed inertial/equation conventions invalidate downstream constraints/contact/integration/analysis/observations.

### Initial producer handoff (2026-10-03)
Ten Native behavioral tests in two suites passed through actual public services with timeout180 and .build/dynamics-kernels. Independent rotated asymmetric Euler, offset-COM pendulum and two-link M/C/G fixtures verify actual equations; nonzero supplied snapshot acceleration verifies use of accelerationBias. Forward/inverse/mixed/mass-only, power/momentum and independent original-body residual acceptance execute; a deliberately incorrect numerical result is rejected. Missing/mismatched inertia, inconsistent velocity, frame/domain/capability, pivot, all configured budget boundaries, unavailable complete energy and caller cancellation fail explicitly. A former bitwise bias fixture was corrected to its declared 1e-10 tolerance because Joints computes bias via floating-point actualAcceleration-J*a; analytic equations remain the acceptance oracle.

Root FoundationVerification separately compiled/linked and exited 0 on Native, swift-6.4.0-RELEASE_wasm and swift-6.4.0-RELEASE_wasm-embedded (--traits EmbeddedUnicode), using Swift 6.4.0 release and Node.js 24.19.0 WASI Preview 1 for each WASM artifact. Actual RigidEquationComputing/RigidDynamicsSolving witnesses execute offset-COM pendulum M/bias/gravity, published passive damper work, scaled forward/inverse/mixed/mass-only original residuals, complete energy/dissipation and exact velocity/nonuniform-gravity rejection. The Embedded path required an explicit MechanicsModel import in WorldRigidBody; the final Native ten-test run includes that visibility correction. Native and ordinary WASM mathematical probe evidence remains valid because no algorithm changed. These selected synchronous operations do not qualify arbitrary injected providers, trajectories, loops/contact/impact, planar or V0 queries, distributed nonuniform gravity, recursive articulated algorithms/DY005 performance, every platform or full DY-family closure. Full IM15 ownership remains as specified in the plan.

Ownership audit: immutable Sendable inputs/results; internal ForceAccumulator and local arrays plus caller NumericalWork/LoadWork are operation-local exclusively owned values, not shared reference state. No unsafe pointer, unchecked Sendable, target-conditioned storage/conformance, no-op lock or isolation escape exists. Identical source contracts execute on all three selected profiles. Runtime state adoption and target race/lifecycle remain the Runtime owner's distinct proof.

### Consolidation contract
This directory is a component inside the SwiftMechanics module, not a separate SwiftPM target. Its existing public behavior and exact-profile evidence remain its contract authority. Cross-component access uses the documented contracts; internal visibility alone does not grant admission or publication authority. Source relocation requires integrated behavioral requalification.

### AF24 lower physical handoff

[RigidEquations](RigidEquations/DESIGN.md#af24-additive-planar-physical-source-contract) owns additive planar/source-tagged equation authority; [DenseDynamics](DenseDynamics/DESIGN.md#af24-additive-physical-solve-contract) owns consumed physical solve witnesses. Existing spatial public values and calls remain available. Actual lower behavioral qualification precedes planar constrained consumers; source dispatch grants no qualification.

## AF25 original coordinate power composition

[RigidEquations](RigidEquations/DESIGN.md) owns additive original physical coordinate partition evidence consumed by [NonlinearEvolution](../Mechanisms/NonlinearEvolution/DESIGN.md). Full-column MechanicalEnergy virtual power and genuine prescribed-anchor drift power retain their existing meanings. The child publishes known/dynamic coordinate, root-actuation, geometric-reaction, drive and known-load powers from the original full source; the parent introduces no alternative energy or force algorithm. Selected original-profile qualification belongs [FoundationVerification](../../../../Verification/FoundationVerification/DESIGN.md#af25-upper-public-composition-contract); prospective interfaces alone are not evidence.
