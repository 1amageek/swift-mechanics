# MechanicsGeometricConstraintTests

## AF25 allocation evidence owner
`PhysicalAllocationTests` uses actual planar compiled fourbar/slider geometry through the additive public producer and builtin acceptance. It preserves original rows/rank/nullity, checks independent/zero physical row classification and zero-Z multiplier freedom, and refuses active duplicate/toggle rows. Source/time/identity/normalization, stale certificates, cancellation and finite numerical work are tested before publication. Owner: [GeometricRelations](../../Sources/SwiftMechanics/Physics/Constraints/GeometricRelations/DESIGN.md#af25-physical-allocation-certificate). Root executes frozen tests/profile composition.

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

AF23 PrescribedGeometryTests owns actual named moving-anchor point g/rate/bias and mixed 4/3 sample-preserving assembly. Dynamic torque/work/replay belongs MechanicsNonlinearMechanismTests.

### AF24 planar geometry and physical covectors
PlanarGeometricTests uses actual BodyRecord2D/MassProperties2D compiler inputs and verifies independent fourbar sin/cos g/rate/bias, retained duplicated/zero rows, perturbed manifold assembly, exact identity toggle rank and planar distance normalization. Plane-breaking endpoints/targets and planar alignment fail. Spatial v2 and AF23 v3 behavior remains regression scope; planar source uses a distinct v4 signature.

PhysicalRowTests exercises the non-generic protocol requirement, sealed builtin witness and original upper-consumer acceptance. Independent point-force/couple oracles check original per-body virtual-work projection for every row including planar structural-zero z, real endpoint positions, normalization-invariant force and internal action/reaction, spatial z force and moving transverse-axis couples. Source/time/identity/row/domain/storage/work/body-limit/cancellation failures must publish no witness. Original dependent rows remain available and rank ambiguity is never turned into unique physical allocation. Root owns all actual test/build/profile executions after source freeze; these source fixtures alone are not completion evidence.

AF24 frozen Native handoff: the registered exact Swift 6.4.0 release graph `.build/ar01-native`, focused suite filter, `-j 4` and 240-second timeout exited zero. The five selected Geometric suites passed 21 tests, including eight new planar/physical-row cases and the existing spatial/manifold/AF23 regressions. Evidence: `.build/af24-lower-native.log`. This proves the Native source/row/projection/normalization/rank and refusal behaviors exercised; public original WASM/Embedded handoff remains IM.IM16.22.

### AF25 lower Native qualification

The frozen source executed 28 declarations in six suites: 27 initially passed; the allocation stale-gate accounting test was corrected and all seven PhysicalAllocation declarations then passed. Exact Swift 6.4.0 release/macOS 27 arm64, `.build/ar01-native`, `-j 4`, and a 240-second external timeout were used. Logs: `.build/af25-lower-native-tests.log` and the allocation-only `.build/af25-allocation-native-recheck.log`. Original production did not change during test-helper corrections. Source/profile composition is canonical in [FoundationVerification](../../Verification/FoundationVerification/DESIGN.md#af25-lower-integrated-qualification); full upper/root/loop domains remain separate.
