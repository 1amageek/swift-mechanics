# MechanicsGeometricConstraintTests

## Purpose and Scope
Dedicated behavioral tests for [GeometricRelations](../../Sources/SwiftMechanics/Physics/Constraints/GeometricRelations/DESIGN.md) and [ManifoldProjection](../../Sources/SwiftMechanics/Physics/Constraints/ManifoldProjection/DESIGN.md). No children.

## Responsibilities and Boundaries
Own independent scalar trigonometric/physical geometry and manifold assembly/failure oracles. Runtime evolution/reaction integration remains upper scope.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [GeometricRelations](../../Sources/SwiftMechanics/Physics/Constraints/GeometricRelations/DESIGN.md) | depends on | Public geometry evaluation and original acceptance | Source contract tested here | Independent scalar geometry oracles |
| [ManifoldProjection](../../Sources/SwiftMechanics/Physics/Constraints/ManifoldProjection/DESIGN.md) | depends on | Public local assembly and failure prefix | Source contract tested here | No upper evolution qualification |

## Architecture
```text
real compiled revolute/spherical/sixDOF fixtures -> public evaluation/assembly -> independent oracles
```

## Contracts and Invariants
The compiler canonicalizes joint records before constructing the tree; fixtures fill q/v using a public tree layout and joint ID/ranges, and mixed quaternion oracles use those ranges. An exact identity-frame toggle proves analytic rank one. A separate nonidentity-frame witness retains tiny roundoff derivatives and verifies the frozen rank producer's row-relative scale-invariant limitation; no original derivative is zeroed.

The regular two-row second-frame transverse axis chart has independent full physical cross, moving-direction rate/bias and same/opposite branch oracles. The previous unqualified three-row cross representation is excluded after its demonstrated off-manifold rank-changing defect.

No type/existence-only success claims. Explicit analytic geometry, derivatives, norms, all rows, rank and failed-work prefixes are checked.

## Verification and Change Impact
Run dedicated Native tests with fixed Swift 6.4.0, -j4 and 240-second timeout on the actual registered repository graph. Root owns registered Native and original WASM/Embedded qualification. There is no shared test resource outside immutable fixtures and operation-local work.
