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
