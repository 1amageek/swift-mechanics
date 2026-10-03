# Mesh

## Purpose and Scope
Own identified Tet4 reference nodes, source/material assignments, reference geometry admission and centroid refinement. Parent [MechanicsFlexible](../DESIGN.md); no children. Full IM19 element/reduction family remains owned by IM19 beyond this initial handoff.

## Responsibilities and Boundaries
Own reference geometry and validated constant shape gradients. [Tetrahedra](../Tetrahedra/DESIGN.md) owns current state and mechanical assembly. Material law semantics belong to Materials; boundary groups are preserved metadata, not imposed constraints or loads.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Parent](../DESIGN.md) | parent | IM19 ownership | Initial producer | Full family audit later |
| [Model](../../MechanicsModel/DESIGN.md) | depends on | EntityID, SourceProvenance | Material/source/frame identity | No display mesh inference |
| [Materials](../../MechanicsMaterials/Elasticity/DESIGN.md) | depends on | Immutable PolynomialHyperelasticity | Assigned physical law | No plastic history |
| [Numerics](../../MechanicsNumerics/LinearAlgebra/DESIGN.md) | depends on | NumericalWork | Checked storage/arithmetic | Outer computation only |
| [Tetrahedra](../Tetrahedra/DESIGN.md) | used by | ValidatedTetrahedralMesh | Reference interpolation | Current layout checked by consumer |
| [Tests](../../../Tests/MechanicsFlexibleTests/DESIGN.md) | used by | Public validate/refine requirements | Geometry/assignment evidence | Native evidence local |

## Architecture
```text
reference nodes + ordered Tet4 cells + assigned material/source/frame
 -> bounded identity/connectivity validation -> positive reference edges
 -> inverse edge matrix / reference volume / constant gradients
 -> immutable validated mesh -> mechanical assembly
```

## Contracts and Invariants
TetrahedralMesh.frame is an identified frame. Nodes carry unique UInt64 IDs, reference positions in meters and optional boundary group. Cells carry unique IDs, four distinct in-range ordered node indexes, identified material and provenance. Materials carry unique EntityKind.material IDs, law/source, positive reference density and nonnegative mass-damping rate. Every node participates. Duplicate geometric connectivity fails even under different cell IDs. Caller minimum reference volume and scaled-determinant inverse tolerance admit positive, nondegenerate geometry. Shape gradients are rows of inverse edge matrix, with gradient0 the negative sum; reference volume is determinant/6. Immutable validated records are constructed only by the validator. Centroid refinement retains existing nodes/boundary groups, mesh source and cell material/source, creates explicitly caller-identified interior nodes, and retains parent cell identity. New revision differs from old. It preserves an affine patch and total reference volume; no arbitrary refinement convergence or load/constraint prolongation claim.

## Runtime Flows
Capacity -> checked storage -> unique identities/connectivity/material lookup -> reference determinant/inverse -> immutable result. Refine reserves both retained input and new geometry/validation workspace before constructing output; all children are validated before publication.

## State, Ownership, and Lifecycle
Immutable Sendable input/result arrays. Operation-local participation and reference-cell arrays; no shared mutable state, target branches or unsafe pointers. Scalar workspace conservatively reserves 26 per prepared reference cell plus node participation. Refinement intentionally owns new node/cell arrays through COW copying at its output boundary; four-index child arrays are persistent connectivity, not inner-loop numerical temporaries. Borrowed input excluded; simultaneously retained output and prepared geometry included. NumericalWork is caller-owned exclusive inout.

## Failure, Concurrency, and Constraints
Typed identity/connectivity/assignment/reference-quality/unused-node/revision/capacity/Core/numerical/cancel failures. Checked products/sums precede allocation. NumericalWork charges conservative outer scalar-arithmetic counts and validation comparison units; matrix inverse reserves its known fixed arithmetic bound. Cancellation checks before work and cell boundaries; Task cancellation is checked on each charged block. Material-ID duplicate/lookup and frame-ID equality admit metadata length through borrowed UTF-8 scans before semantic EntityID equality. Two work units are reserved before each iterator advance (including end detection), representing byte admission and subsequent comparison; no count, key copy or array prewalk occurs. Caller/Task cancellation is checked on each advance. Unicode canonical equality remains Model authority; work units bound input traversal, not CPU instructions or normalization internals. Source strings are retained without equality scans. No failed output/retry.

## Verification and Change Impact
Invalid orientation/rest degeneracy/index/identity/missing assignment/unused-node and capacity/work/storage/cancellation fixtures; refined source/material/boundary/parent records and positive child volumes. Changes invalidate Tetrahedra and downstream mesh/coupling adapters; mechanical equations are verified by their owner.
