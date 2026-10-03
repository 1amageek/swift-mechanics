# Joint Manifolds

## Purpose and Scope
Own fixed, revolute, prismatic, spherical, universal, cylindrical, planar, screw, six-DOF and custom joint charts and local motion operators (JT-001..004). Parent: [MechanicsJoints](../DESIGN.md). No children.

## Responsibilities and Boundaries
Publish permitted motion columns, configuration transform, qdot = N(q) v, analytic relative motion/acceleration and manifold integration. Blocked motion is the reciprocal wrench annihilator of the published columns. Constraint/contact reactions, limits, passive laws and loop assembly remain IM12/16 responsibilities.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Model Coordinates](../../MechanicsModel/Coordinates/DESIGN.md) | depends on | 7/6 floating base convention | Six-DOF chart uses the same translation/quaternion/body-omega order | Quaternion tolerance is explicit |
| [Algebra](../KinematicAlgebra/DESIGN.md) | depends on | Geometric moving-frame composition | Product-of-elementary-motions derivatives | Parent-frame geometric columns at moving joint origin |
| [Trees](../ArticulatedTrees/DESIGN.md) | used by | Joint local pose/subspace/derivatives | Stable q/v layout | No global compiler assumptions |

## Architecture
```text
validated JointManifold + q/v/vdot slices + policy -> transform / N*v / permitted columns
ordered elementary transforms -> analytic composed motion / acceleration
chart integration -> new owned q
```

## Contracts and Invariants
Fixed counts 0/0; revolute/prismatic/screw 1/1; universal/cylindrical 2/2; planar 3/3; spherical 4/3 (qw,qx,qy,qz and body omega); six-DOF 7/6 (parent translation xyz, quaternion wxyz; parent linear xyz, body omega xyz). Custom is an ordered product of up to six normalized revolute/prismatic/screw directions; each direction is expressed in the preceding factor frame, not silently a fixed-world axis. Scalar charts use qdot=v. Universal axes must be nonparallel. Planar translations span the two declared nonparallel axes, rotation is about their normalized cross product; an oblique translation basis is explicitly allowed. Screw pitch is signed meters/radian. A full revolution translates 2 pi pitch meters. Axes normalize direction while preserving sign; degenerate axes fail.

Permitted columns are geometric angular/linear derivatives at the moving joint origin expressed in the parent joint frame. Quaternion q must have caller-accepted unit norm and is explicitly normalized; zero or unacceptable drift fails. q/v/vdot counts and finite values are exact. N mapping uses Core body quaternion rate; no Euler chart replaces spherical/six-DOF orientations. Generic chart rank is checked after scaling linear columns by caller characteristic length (m); two-pass orthogonalization residual below the caller dimensionless rank threshold yields chartSingularity. No inverse kinematics is performed. Policy always comes from caller, with no hidden tolerance/default.

## State, Ownership, and Lifecycle
Immutable Sendable descriptors. Evaluation borrows ArraySlice inputs only for the synchronous call, allocating at most six columns and seven qdot entries plus bounded <=6 local intermediates. Returned arrays own storage and retain no pointers. Tree evaluation uses slices of stable caller arrays, preserving inputs.

## Failure, Concurrency, and Constraints
Typed JointError identifies count, geometry, chart, time-step and nonfinite failures; CoreError propagates arithmetic failure. Custom maximum six independent columns is the SE(3) domain, not a guessed runtime tuning value. Rank checks run at most two passes over <=6 columns. Integration follows constant supplied generalized velocity for this local step; it is not an ODE solver or trajectory interpolator.

## Verification and Change Impact
[Tests](../../../Tests/MechanicsJointsTests/DESIGN.md) covers each standard chart, allowed/blocked reciprocal motions, signed screw displacement/power, large rotations, quaternion N, generic reconstruction/singularity and invalid inputs. Tree/compiler/dynamics clients recheck any chart, frame or ordering changes. Local blocked-wrench proof does not claim solved joint reactions.
