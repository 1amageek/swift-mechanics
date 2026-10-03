# Articulated Trees

## Purpose and Scope
Own validated connected single-root tree topology, stable q/v ranges, analytic body/frame motions and owned snapshots (KI-001..003 tree domain). Parent: [MechanicsJoints](../DESIGN.md). No children.

## Responsibilities and Boundaries
Admit body/frame/joint/anchor IDs and topology, evaluate rooted forward kinematics and geometric motion/acceleration, and retain dense world geometric columns for Jacobian consumers. Compiler-wide mode/actuation validation, assembled loops, multiple-root mechanism assembly and simulation state transactions remain downstream.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Model Bodies](../../MechanicsModel/Bodies/DESIGN.md) | depends on | BodyRecord2D/3D IDs, frames, reference pose | KinematicBody projects geometry only | Force/mode admission is compiler-owned |
| [Model Coordinates](../../MechanicsModel/Coordinates/DESIGN.md) | depends on | Fixed/planar/spatial base q/v | Root transform and velocity convention | Fixed placement belongs to body record |
| [Manifolds](../JointManifolds/DESIGN.md) | depends on | Pose, subspace and derivatives | Relative joint motion | Singular custom chart fails |
| [Algebra](../KinematicAlgebra/DESIGN.md) | depends on | Moving-anchor derivatives | Parent anchor * joint * inverse child anchor | Explicit-time samples require complete derivatives |
| [Jacobians](../Jacobians/DESIGN.md) | used by | Owned snapshot columns and body state | Virtual-work and point queries | Columns are world geometric at body origin |

## Architecture
```text
body records + dedicated anchor frames + joints + base + revision + capacity
 -> validate IDs / endpoints / incoming edges / cycles / connectivity
 -> stable root-first body order + q/v offsets
state(q,v,vdot,time,prescribed anchors) -> root motion -> parent anchor
 -> joint motion -> inverse child anchor -> body pose/motion/acceleration
 -> immutable snapshot with dense columns and acceleration bias
```

## Contracts and Invariants
Each tree is immutable, single-root and connected, with exactly one incoming joint per nonroot and none for root. Bodies, body frames, joints and dedicated anchor frames have unique role-correct IDs; world frame is distinct. Dangling endpoints, duplicate child ownership, cycles, disconnected bodies and unknown state anchor samples fail explicitly. Output body order is deterministic breadth-first using input joint order. Supplied state revision must equal tree revision. q/v/vdot match the stable layout exactly and remain unchanged. Arithmetic counts/products use checked Int overflow before allocations; caller capacity bounds body count, velocity count and dense Jacobian scalar count.

Spatial tree bodies use BodyRecord3D geometry. Planar bodies project BodyRecord2D pose into world XY/+z, and all anchors/base/joint axes must preserve that plane; mixing body dimensions fails. Fixed root uses its body reference pose and zero base velocities by explicit fixed-root constraint. Floating root uses absolute state pose, world translation velocity and body omega as Model's BaseLayout. This kinematic geometry projection does not change BodyRecord modes or validate physical mode/actuation consistency.

Each fixed anchor maps anchor frame into its owning body. A prescribed anchor is supplied at state time as pose, geometric relative velocity and acceleration expressed in that body frame at the anchor origin. Missing or stale derivatives fail; no identity/zero replacement exists. Parent anchor and inverse moving child anchor include all angular/linear transport terms. Output body motion/acceleration and bias are expressed in world frame at body origin. Dedicated body/anchor/world frame states and parent/child joint frame states are published with their declared world reference. Prescribed drift is exposed separately: actual velocity = J*v + prescribedDrift; acceleration = J*vdot + accelerationBias. SI conventions follow Algebra. Reaction forces, loop constraints and temporal generation/interpolation are not implemented here.

## State, Ownership, and Lifecycle
Descriptors, layouts, state and snapshots are immutable Sendable. Each snapshot owns its tree value and arrays through Swift value/COW semantics. Evaluation uses operation-owned mutable workspace only. It reserves B*V six-scalar columns, B body records, J joint-frame records and B+2J+1 frame records once; per-joint slices borrow caller q/v/vdot with <=6 motion columns and <=7 rate allocations. Output arrays preserve source state. No shared cache, pointer, target branch, unsafe conformance or hidden cross-call mutable state exists.

## Failure, Concurrency, and Constraints
Topology admission O(B+J); column evaluation O(B*V), storage O(B*V+B), including bounded local joint/frame outputs. Prescribed anchor indexing O(J); each supplied sample is consumed once. Caller capacity is checked before layout/column allocation, including six-scalar dense column budget. Finite values and matching sample times are exact admission conditions; derivative consistency across time is the external trajectory supplier's guarantee. JointError and producer Core/Model errors propagate. No backend substitution occurs.

## Verification and Change Impact
[Tests](../../../Tests/MechanicsJointsTests/DESIGN.md) proves serial spatial/planar transforms, parent/child moving-anchor acceleration, floating 7/6 state mapping, deterministic shuffled input ordering, duplicate/dangling/cycle/disconnected failures, stale/missing state and capacity/overflow rejection. Compiler/runtime/dynamics and Jacobian clients recheck topology/layout/frame changes. Assembled-loop and slider-crank loop evidence remains IM12 integration responsibility.
