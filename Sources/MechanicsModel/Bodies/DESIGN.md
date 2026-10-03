# Bodies

## Purpose and Scope
Own immutable dynamic/static/prescribed-kinematic 2D/3D body descriptors (RB-001 record contract). Parent: [MechanicsModel](../DESIGN.md). No children.

## Responsibilities and Boundaries
Bind distinct body and frame IDs, pose, independent representations, optional inertia and declared motion mode. Admit dynamic bodies only with validated mass properties. Forces, reactions, prescribed trajectories and contact evolution are implemented by downstream dynamics/kinematics owners.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Model](../DESIGN.md) | parent | Composition | Registers descriptors | No integrated dynamics claims |
| [Identity](../Identity/DESIGN.md) | depends on | Kind-tagged IDs | Body/frame roles | Global reference checks downstream |
| [Inertia](../Inertia/DESIGN.md) | depends on | Validated mass properties | Dynamic admission | Inertia about body COM |
| [Representations](../Representations/DESIGN.md) | depends on | Separate assets/provenance | No mesh-to-mass inference | Missing inertia fails dynamic admission |

## Architecture
```text
body ID + frame ID + mode + pose + representations + inertia -> validated BodyRecord
mode -> force/motion/reaction declaration -> downstream dynamics consumer
```

## Contracts and Invariants
Dynamic bodies require positive validated inertia and are force driven. Static bodies have fixed pose and do not accelerate under forces. Prescribed kinematic bodies obtain motion externally and do not accelerate under forces. All modes permit constraint/contact reaction observations from downstream solvers; mode does not fabricate reactions. No actuator conflict can be checked without the downstream graph. Planar poses use x/y meters and finite angle radians about +z; spatial poses map body coordinates to world using Core rigid transform. Inertia is in the body frame. Body IDs/frame IDs must have their respective kinds. Records own immutable Sendable storage; constructing replacement display assets preserves independent inertia.

## Verification and Change Impact
Test owner: [MechanicsModelTests](../../../Tests/MechanicsModelTests/DESIGN.md).

RecordTests proves modes and admission in both dimensions, ID-role errors and display replacement invariance. Runtime/compiler/dynamics must recheck changes to these declarations and enforce prescribed-trajectory/actuation consistency.
