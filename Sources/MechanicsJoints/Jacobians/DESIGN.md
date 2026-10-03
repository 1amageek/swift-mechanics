# Jacobians

## Purpose and Scope
Own public geometric/spatial/point Jacobian queries, J*v and transpose wrench/force products (KI-002..003). Parent: [MechanicsJoints](../DESIGN.md). No children.

## Responsibilities and Boundaries
Translate tree-owned world geometric columns into the requested world origin/point representation and expose virtual power. Solving, rank regularization, IK and force laws are external.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Trees](../ArticulatedTrees/DESIGN.md) | depends on | Snapshot body pose/motion/columns/layout | Stable ordered v columns | Snapshot owns matching tree; no cross-tree reuse |
| [Core Spatial](../../MechanicsCore/Spatial/DESIGN.md) | depends on | SpatialMotion/SpatialWrench power | Angular/linear dual pairing | Geometric torque is about body/point; spatial torque is about world origin |

## Architecture
```text
snapshot body geometric columns -> geometric Jacobian (body origin)
                               -> spatial Jacobian (world origin)
                               -> point Jacobian (declared body point)
columns * v -> motion; columns transpose * wrench/force -> generalized loads
```

## Contracts and Invariants
All columns are ordered by snapshot tree v layout and expressed in declared world frame. Geometric linear column is body-origin velocity. Spatial linear column is geometric linear minus omega cross world body position; its wrench must be about world origin. Point linear column adds omega cross rotated body-local offset. Point queries also return actual velocity/acceleration and acceleration bias including centripetal motion. J*v and JT*w obey v dot generalizedLoads = wrench dot motion (or force dot pointVelocity), with torque Nm/force N and power W. Explicit-time prescribed drift is returned separately; virtual work applies to J*v, while actual wrench power additionally includes wrench dot prescribedDrift. Input vectors must match counts and be finite. Unknown body ID fails. Jacobians own arrays and immutable frame/body metadata. Querying an admitted snapshot allocates exactly V columns/output loads; no source-state mutation or metadata introspection.

## Verification and Change Impact
[Tests](../../../Tests/MechanicsJointsTests/DESIGN.md) uses central manifold directional differences, independent geometric point derivatives, analytic moving-frame bias and wrench/force virtual-work identities in geometric/spatial/point representations. Tree/frame/velocity-layout changes invalidate corresponding consumers. No inverse solve or reaction value is fabricated.
