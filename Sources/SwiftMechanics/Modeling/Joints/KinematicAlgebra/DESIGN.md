# Kinematic Algebra

## Purpose and Scope
Own geometric velocity/acceleration composition for moving rigid frames. Parent: [MechanicsJoints](../DESIGN.md). No children.

## Responsibilities and Boundaries
Compose and invert externally supplied instantaneous pose, velocity and acceleration. Dynamics, force response, temporal interpolation and trajectory generation are external.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Core Spatial](../../../Mathematics/Core/Spatial/DESIGN.md) | depends on | Rigid transforms, angular/linear vectors | SI and rigid frames | Core origin-referenced spatial motion differs from geometric velocity at moving origin |
| [Manifolds](../JointManifolds/DESIGN.md) | used by | Moving-frame derivative composition | Product-of-motions joints | Relative linear velocity is derivative of moving origin |
| [Trees](../ArticulatedTrees/DESIGN.md) | used by | Composition/inversion | Moving anchors and bodies | Supplied acceleration includes second derivative |

## Architecture
```text
parent motion + relative transform/derivatives -> composed pose + geometric motion/acceleration
moving transform/derivatives -> inverse transform/derivatives
```

## Contracts and Invariants
All vectors are expressed in the fixed parent frame at the moving frame origin. Pose maps moving frame to parent. Linear velocity is translation derivative; linear acceleration its second derivative. Angular velocity satisfies Rdot = skew(omega) R; angular acceleration is omega derivative. Composition contains transport, centripetal and 2 omega cross relative-linear Coriolis terms. Inversion differentiates both rotation and translation. Position is m, velocity m/s, angular velocity rad/s, acceleration m/s^2 and rad/s^2. Finite Core arithmetic errors propagate. Values are immutable Sendable; operation-local scalars own all workspace and have no shared state.

## Verification and Change Impact
[Tests](../../../../../Tests/MechanicsJointsTests/DESIGN.md) verifies analytic rotating/translating frames, inversion composition, point velocities and acceleration. Manifold/tree consumers must recheck changes to origin, frame or acceleration conventions.
