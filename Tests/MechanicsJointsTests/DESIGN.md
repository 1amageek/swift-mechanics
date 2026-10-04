# MechanicsJointsTests

## Purpose and Scope
Behavioral ownership of admitted joint manifolds, rooted planar/spatial trees, moving-frame derivatives and Jacobian/power operators (IM06). Parent: [MechanicsJoints](../../Sources/SwiftMechanics/Modeling/Joints/DESIGN.md).

## Responsibilities and Boundaries
Independent analytic fixtures, central configuration-direction derivatives and explicit domain failures. No loop solving, reaction solving or integrated dynamics claims.

## Related Designs
[KinematicAlgebra](../../Sources/SwiftMechanics/Modeling/Joints/KinematicAlgebra/DESIGN.md), [JointManifolds](../../Sources/SwiftMechanics/Modeling/Joints/JointManifolds/DESIGN.md), [ArticulatedTrees](../../Sources/SwiftMechanics/Modeling/Joints/ArticulatedTrees/DESIGN.md), [Jacobians](../../Sources/SwiftMechanics/Modeling/Joints/Jacobians/DESIGN.md).

## Architecture
```text
local independent fixture -> actual joint/tree operator -> analytic/differential/power oracle
```

## Contracts and Invariants
Tests use local immutable descriptors and explicit numerical/capacity policy. No shared filesystem/database/static fixtures. Tests verify body-origin versus world-origin wrench distinction, 7/6 quaternion mappings and supplied moving-anchor derivative behavior.

## Verification and Change Impact
Run timeout-wrapped swift test --build-path .build/joint-kernels --filter MechanicsJointsTests. Exact-profile Native/WASM/Embedded execution is root-owned; native behavioral evidence does not imply unrun platforms or complete mechanics integration.
