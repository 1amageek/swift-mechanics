# Inertia

## Purpose and Scope
Own valid 2D/3D mass properties and analytic primitive/compound calculation (RB-002, RB-004). Parent: [MechanicsModel](../DESIGN.md). No children.

## Responsibilities and Boundaries
Validate positive dynamic mass and inertia, and symmetric physically realizable 3D tensors. Calculate uniform box/sphere/z-axis cylinder and planar rectangle/disk, transform/compose primitive parts. Exact CAD moments, arbitrary solid intersection/union and body dynamics are external responsibilities.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Model](../DESIGN.md) | parent | Composition | Registers kernels | CoreError propagates distinctly |
| [Core Spatial](../../MechanicsCore/Spatial/DESIGN.md) | depends on | Rigid transform and inertia laws | Rotate and shift COM tensors | Only rigid transforms |
| [Bodies](../Bodies/DESIGN.md) | used by | Valid mass properties | Dynamic body authority | No inverse-mass dynamics here |

## Architecture
```text
primitive + density -> analytic COM tensor -> physical validation -> MassProperties
parts + transforms + overlap policy -> domain admission -> mass-weighted COM
                                   -> rotation + parallel axis -> compound tensor
```

## Contracts and Invariants
Mass is kg, density is kg/m^3 (3D) or kg/m^2 (2D), dimensions/COM are meters, inertia is kg m^2 about COM in the declared body/compound frame. Mass and admitted rotational inertia must be strictly positive. 3D tensors are SPD; second moment S = trace(I)/2 identity - I is PSD, which enforces principal-moment triangle inequalities including rotated tensors. Caller supplies symmetry tolerance (kg m^2) and dimensionless physicality tolerance in [0,1); accepted symmetric roundoff is explicitly averaged into a symmetric stored tensor. All seven principal minors of normalized S + physicalityRelative identity must be nonnegative. This bounds any negative second-moment eigenvalue by the supplied dimensionless tolerance; independent determinant tolerances would incorrectly admit slender nonphysical tensors. Tolerance never repairs negative mass or singular admitted inertia. Finite inputs/results and invalid density/dimensions fail explicitly; CoreError remains propagated.

Compound policy is mandatory: requireDisjointBoundingBoxes admits only parts whose conservative transformed bounding boxes have disjoint interiors (outward-rounded bounds may conservatively reject touching solids); intersecting boxes fail as ambiguous, even when solids might be disjoint. additiveOverlappingMaterials explicitly treats overlapping parts as independent material contributions, allowing double counting by declaration. Outward rounding prevents collapsed bounds from admitting coincident small solids at large coordinates. No geometric union is computed. Parts are generated from validated analytic domains, not caller-invented bounds. Empty composition fails. Overflow or precision loss producing invalid positive properties fails validation.

## State, Ownership, and Lifecycle
All results and parts are immutable Sendable values. MassPropertyOrigin records supplied/analytic/compound generation and retains the mandatory overlap policy through frame transformation. Calculation uses local arrays/scalars only; no caches, borrow escape, shared mutable state or target-dependent storage.

## Failure, Concurrency, and Constraints
ModelError identifies domain/mass/inertia/overlap failures. CoreError reports arithmetic failure. O(n^2) pair admission and O(n) summation are explicit; callers own part count and invocation budget. Arrays copy by standard Swift value semantics; no zero-copy performance claim is made for model construction.

## Verification and Change Impact
Test owner: [MechanicsModelTests](../../../Tests/MechanicsModelTests/DESIGN.md).

InertiaTests covers analytic boxes/sphere/cylinder/planar domains, rotated physical and nonphysical tensors, singular/negative/asymmetric inputs, off-center compound tensors, rigid rotation, ambiguous overlap and explicit additive overlap. Body/compiler/CAD consumers recheck changed policy or frame conventions. Graph validity and dynamics/contact proof are excluded.
