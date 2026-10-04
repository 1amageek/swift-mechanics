# Analytic geometry witnesses and queries

## Purpose and Scope
Parent: [MechanicsCollision](../DESIGN.md). Owns sphere-sphere, sphere-box, sphere-half-space and box-half-space signed witness pairs; sphere/box support; point signed distance/closest boundary and bounded rays for the three shapes. Children: none. Box-box and generic iterative convex/concave pairs are explicitly unsupported; no iterative success is inferred.

## Responsibilities and Boundaries
Normal points from first proxy toward second, with positive separation outside and negative penetration. Published invariant dot(n,pB-pA)=separation and unit n are checked against the original returned geometry. The normal and points are in the common identified frame. Contact law/forces are absent. Point query normal is outward from solid; its signed distance obeys point-boundary=normal*distance. Ray direction is unit-normalized; parameter is meters; an inside origin returns its first exit boundary, a boundary origin returns distance zero, and an outside origin returns first entry. A parallel ray without a finite boundary intersection is no-hit. Scene hits sort distance then collider key.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Module](../DESIGN.md) | parent | Qualified subset | Composition | Not a generic convex solver |
| [Shapes](../Shapes/DESIGN.md) | depends on | Exact proxy/pose/margin/quality | Authority | Common frame required |
| [Discovery](../Discovery/DESIGN.md) | used by | Support/AABB and narrow witnesses | Original geometry | No-hit differs from unsupported |
| [Persistence](../Persistence/DESIGN.md) | used by | Framed witnesses/features | Contact identity | Revisions required |
| [Sweep](../Sweep/DESIGN.md) | used by | Original separation | TOI validation | Motion domain separate |

## Architecture
```text
proxy local geometry -> Core rigid transform -> analytic support / point / ray
admitted proxy pair -> base witnesses -> margin offsets -> geometric invariant check
```

## Contracts and Invariants
Coincident sphere centers choose first proxy's local +X rotated into the query frame and record degeneracy. Sphere-box outside uses clamped closest point; inside chooses nearest face, tie order X/Y/Z and positive side at coordinate zero. Normal from sphere to box is inward opposite that face outward normal, yielding penetration distance nearest-face-depth+radius. Boundary feature masks classify every coordinate of the returned closest point equal to a signed box extent, including tangent boundary equality; mask population distinguishes face/edge/corner and positive bits apply only to active axes. Exact edge/corner boundary origins use that same mask; interior points use nearest-face identity and tied interior faces record a diagnostic. Box-plane returns deepest support vertex with zero-direction support ties choosing positive local coordinates. Features carry exact pose-independent geometry identities. Inflated box point/ray queries with nonzero box margin are unsupported (rounded-box query is deferred), rather than approximated as a sharp expanded box.

Support requires nonzero finite direction and returns a true extremal point, including margins. Half-space has unbounded support and explicitly fails bounded support queries. Point/ray residuals and sphere/box surface checks use caller absolute+relative*referenceLength SI tolerance fixed before execution. Ray sphere roots and box slab intervals are finite-checked; unresolved returned hits fail residual acceptance. Operations use O(1) workspace and charge bounded scalar work; scene query arrays have explicit record/storage limits.

Feature mask comparisons use caller length tolerance to identify boundary-equivalent transformed coordinates. The returned point remains the analytic closest point; topology within that numerical boundary band is qualified rather than claimed as an exact face/edge distinction. This keeps a tangent-edge feature stable under floating rigid transforms without silently changing its geometry.

## State, Ownership, and Lifecycle
Services are stateless Sendable; values and local fixed-size workspace are operation-owned. No shape buffer/view survives its owner or shared mutation exists.

## Failure, Concurrency, and Constraints
Invalid ray, unsupported pair/support/query, mismatched frames/quality, overflow, geometric residual rejection and resource exhaustion fail explicitly. Nominal analytic geometry and declared provenance deviation are distinct; no source-shape accuracy beyond metadata is asserted.

## Verification and Change Impact
[GeometryTests](../../../../../Tests/MechanicsCollisionTests/GeometryTests.swift) independently check separation/witness balance, transforms, inside/edge/tie/coincident conventions, support extremality, rays/grazing/inside/ties, margins, quality and typed unsupported cases. Freeze length tolerance 1e-10 m+1e-11 relative*1 m for meter-scale fixtures. Changes invalidate Discovery/Persistence/Sweep and downstream contact adapters.
