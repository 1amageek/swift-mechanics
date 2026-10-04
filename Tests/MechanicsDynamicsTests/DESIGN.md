# MechanicsDynamicsTests

## Purpose and Scope
Native proof owner for initial IM15 RigidEquations and DenseDynamics. Parent [package](../../DESIGN.md); no children.

## Responsibilities and Boundaries
Own original analytic mechanics and failure/budget fixtures. Root owns Native/WASM/Embedded selected runtime composition and commits; consumers own trajectories and constraints.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [RigidEquations](../../Sources/SwiftMechanics/Physics/Dynamics/RigidEquations/DESIGN.md) | depends on | Actual physical equation/energy/work | Original mechanics | Declared spatial tree only |
| [DenseDynamics](../../Sources/SwiftMechanics/Physics/Dynamics/DenseDynamics/DESIGN.md) | depends on | Selected solves/physical residual | Numerical composition | No recursive qualification |

## Architecture
```text
independent Euler/pendulum/two-link equations -> expected force/acceleration/energy
public services -> actual equation/solve -> comparison and typed failure
```

## Contracts and Invariants
Fixtures use real Joints snapshot paths, physical validated Model inertia and public requirement calls. Original residuals and reference expected equations are independently computed. Inputs remain unchanged.

## Failure, Concurrency, and Constraints
Local immutable fixtures and operation-owned ledgers, no shared mutable test resources. Timeout180 and private .build/dynamics-kernels.

## Verification and Change Impact
Euler asymmetry/orientation, COM offset pendulum, two-link inertia/Coriolis/gravity, prescribed bias, forward/inverse/mixed/inverse-mass, energy/power/momentum, velocity/frame/shape/capability/pivot and work/storage/iterations/cancellation. Tests qualify only initial admitted domain.

Local completion evidence: timeout-wrapped `swift test --build-path .build/dynamics-kernels --filter 'RigidMechanicsTests|DynamicsFailureTests'` exited 0 with 10 tests in two suites passing. The two-link acceleration-bias comparison uses an analytic tolerance because the Joints producer removes supplied acceleration by floating-point subtraction. Root owns the separate exact-profile runtime evidence; this Native result does not qualify those profiles.


### AF24 planar proof ownership

New PlanarDynamicsFixtures uses actual immutable BodyRecord2D, real fixed/planarFloating tree evaluation and original MassProperties2D. PlanarRigidMechanicsTests owns independent offset-COM free-body M/C/K/P/L, pendulum/two-link M/C/gravity and force-driven forward/inverse/mixed/mass queries, body reference shifting and prescribed-work identity. PlanarDynamicsFailureTests owns complete source inventory/dimension/frame/velocity/plane-load failures, original numerical wrong-success rejection, numerical and original-equation supplier prefix/reset failures, capacity/pivot/capability/cancellation and explicit unavailable energy. Tests use public physical protocol requirements and retain exact original input. No mutable fixture registry or shared file/runtime resource is introduced; any supplier callback counter is protected by the same Mutex on all targets. Root executes the frozen actual registered graph with timeout, then original Native/WASM/Embedded composition; no copy package or private manifest is qualification evidence.


AF24 shared-state review matrix (source scope; target execution pending):

| Logical state | Native / WASM / Embedded storage and isolation | Read | Mutation | Release |
|---|---|---|---|---|
| PhysicalEquationFault callback count | identical `Mutex<Int>` | count/withLock | originalInertialForce/withLock | immutable owner ARC; no callback under lock |
| SpatialEquationCounter callback count | identical `Mutex<Int>` | count/withLock | originalInertialForce/withLock | immutable owner ARC; no callback under lock |
| Production physical source/system/context | identical immutable Sendable let storage | public source/field getters | none after construction | source retained by result and released by ARC |
| Numerical/load ledgers and force workspace | identical exclusive operation-local values | caller inout scope | admitted operation only | operation scope |

AF24 frozen Native handoff: the exact Swift 6.4.0 release command with the registered `.build/ar01-native` graph, `-j 4`, focused suite filter and 240-second timeout exited zero. RigidMechanicsTests, DynamicsFailureTests, PlanarRigidMechanicsTests and PlanarDynamicsFailureTests passed 21 behavioral tests in four suites. The concrete fixture compile failure was corrected before this execution. Evidence: `.build/af24-lower-native.log`. This qualifies the actual Native planar/spatial equations and failure paths exercised here; public WASM/Embedded composition remains IM.IM16.22, not this result.

After the concrete original Embedded source-extraction counterexample, the immutable source-owner correction repeated the same registered 42-test lower Native filter with exit zero (`.build/af24-repair-native-tests.log`); all 21 Dynamics cases again passed. Final selected unmodified public Native/WASM/Embedded execution and stack-boundary evidence are canonical in [AF24 lower integrated qualification](../../Verification/FoundationVerification/DESIGN.md#af24-lower-integrated-qualification). Test-only fault-counter classes remain Native runtime evidence; public profile proof exercises production immutable owners and actual protocol operations.

### AF25 selected proof ownership
AF25 PartitionedPowerTests owns original planar offset-COM F/torque/K/full-column power and source retention; explicit known-coordinate conflict/duplicate/index, actual D imbalance and capacity refusal. Nonlinear root tests own independent spatial gyroscopic and integrated actuator evidence.
