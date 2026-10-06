# Identified triangle-mesh queries

## Purpose and Scope
Parent: [Collision](../DESIGN.md). Children: none. Own IM.AF35.1 source implementation of immutable identified triangle meshes, bounded binary hierarchy admission/refit, actual triangle closest-feature queries, ray intersections, and continuous translating sphere/surface sweeps. Selected implementation; qualification owner is [TriangleMeshesQualification](../../../../../Verification/TriangleMeshesQualification/DESIGN.md), with root-owned registration/integration. Arbitrary concave manifold surfaces are admitted for unsigned queries; signed solid queries admit only an independently certified outward tetrahedral boundary. Other closed-solid interiors fail explicitly rather than using uncertified winding or parity.

## Responsibilities and Boundaries
Caller supplies vertices, connectivity, stable face IDs, collision representation provenance/quality, expected source revision, collider/body/frame IDs and pose. These are mechanical mesh proxies, not exact CAD geometry. Distances are to original supplied triangles; their numerical residuals and source approximation deviation are distinct. This child owns its public protocol and records. Existing Core/Model/IM10 contracts are consumed unchanged; unqualified ConvexQueries is not a dependency. No accepted runtime event, dynamic concave body, contact law or mesh-generation consumer is added.

## Related Designs
| Design | Relationship | Contract used | Summary | Cautions |
|---|---|---|---|---|
| [Collision](../DESIGN.md) | parent | CL-002/003/004/006/008 scope | Source handoff | Full requirements remain unqualified |
| [Shapes](../Shapes/DESIGN.md) | depends on | Work, policy, IDs, sphere proxies | Admission/accounting | Source authenticity stays caller owned |
| [Geometry](../Geometry/DESIGN.md) | depends on | CollisionRay, finite bounds and conventions | Query boundary | Mesh features have separate owned identities |
| [Sweep](../Sweep/DESIGN.md) | depends on | CollisionSweep translation contract | Sphere trajectory | Other shapes/rotations fail |
| [Core](../../../Mathematics/Core/Geometry/DESIGN.md) | depends on | Finite vector algebra | Equations | Nonfinite arithmetic fails |

## Architecture
```text
original vertices/connectivity/face IDs + representation/frame/revisions
 -> bounded manifold/triangle admission -> immutable mesh identity
 -> conservative local binary bounds hierarchy
 -> closest triangle feature / all-original-face ray / all-feature sphere CCD
 -> barycentric reconstruction + original distance/plane/TOI checks -> owned output

new source vertices + strictly newer geometry/source revision
 -> original connectivity/face-ID preserving admission -> hierarchy refit -> new mesh value
```

## Contracts and Invariants
Triangles have three distinct valid vertex indices, unique face IDs, finite nonzero area with a scale-normalized roundoff rank threshold. Every vertex is used and duplicate positions are refused. Edge incidence is at most two with opposite orientation; each vertex fan must be connected and have zero or two boundary edges. Nonmanifold topology fails. Open surfaces and concave cavity surfaces use unsigned distance to the exact supplied triangles. Supporting features retain the original face ID and original vertex/edge indices; barycentric weights reconstruct the published point. Normal is toward the query for nonzero unsigned distance; a zero-distance surface query uses selected original face orientation and reports that convention. Exact distance ties select the smallest face ID; a numerical tie count records all evaluated faces in the policy length band without changing the strict minimum.

Signed-solid admission requires exactly four used vertices and four outward oriented manifold faces, each opposite vertex strictly behind the face. This proves a nondegenerate tetrahedral solid with no self-intersection. Inside uses all four original half-space equations; signed distance is negative inside and positive outside, with the outward selected normal obeying query-boundary = normal*signedDistance. An arbitrary closed surface cannot claim solid inside merely from manifold topology. Self-intersecting surfaces are interpreted only as unsigned supplied triangle sets; they are not solid certificates.

Nonzero query points in an uncertifiable tetrahedral boundary band fail `uncertifiedSolid`; a plane strictly outside the length band certifies exterior. Exact reconstructed boundary points use the selected face normal. Triangle rank and barycentric Gram systems have explicit dimensionless roundoff refusal thresholds; admission does not promise numerical success at every possible scale/condition number.

Hierarchy leaves each contain one original triangle. Nodes are outward-rounded unions of original vertex bounds, median split along the widest bound axis; all original faces remain represented. Point pruning requires a conservative lower distance bound strictly above the best original triangle distance plus the tie band. Ray and CCD evaluate all original faces/features, so no-hit follows actual rejection, never an empty candidate list. Refit preserves original connectivity/face IDs, replaces vertices/provenance with strictly newer source and geometry revisions, reruns admission and recomputes every leaf/parent bound. Old values stay valid immutable snapshots.

Local point lower bounds round each subtraction, squared component, sum and square root downward; zero/subnormal lower bounds clamp only to mathematical zero. World bounds use the actual Core quaternion-to-matrix path and outward-rounded interval multiplication/addition for all local bounds plus translation. Overflow fails explicitly rather than producing an unbounded-looking successful finite box. Storage accounting reserves `1024 + 16*vertexCount + 128*faceCount` scalar slots and `8 + vertexCount + 8*faceCount` records with checked arithmetic, covering simultaneous topology/hierarchy/refit/query staging. Admission has bounded quadratic topology checks; hierarchy split sorting charges a conservative quadratic operation allowance. These are accounting rules, not measured performance claims.

Ray triangles use original plane intersection and barycentric checks; coplanar interval clipping proves a miss or explicitly refuses a nonunique intersection interval. Near-boundary uncertifiable classifications fail. A hit checks original ray/triangle reconstruction and records oriented face normal, feature, ties and source quality.

Sphere CCD uses the exact union of each triangle's face slab, finite edge cylinders and vertex spheres. All candidate quadratic/plane roots must lie in their original feature domains and original triangle distance must match the sphere radius (including sphere margin). The earliest admitted root is retained after all faces are considered. A successful noninitial TOI has a positive lower separation and nonpositive upper separation on the original unsigned/signed distance function, width within caller maximum time width, and no earlier rejected candidate ambiguity. Tangencies/unresolvable roots or absent sign-changing brackets fail explicitly. Rotating mesh sweeps are a callable incomplete branch with `FIXME(INCOMPLETE_IMPLEMENTATION)` and typed refusal. Mesh geometry is static during each translation sweep; refit is a separate caller-owned operation.

## State, Ownership, and Lifecycle
Inputs, mesh hierarchy and results are immutable Sendable values. Operation buffers are exclusively local; work is caller-owned `inout`. No shared mutable state, cache, callbacks, pointers, borrowed storage or target-dependent isolation exists. CoW arrays retain their owner through every result; stable features are meaningful only with the exact recorded mesh identity/revision. Refit never mutates an existing snapshot. Native/WASM/Embedded storage and concurrency contracts are identical.

## Failure, Concurrency, and Constraints
Typed errors cover invalid identity/shape/topology, numerical triangle degeneracy, nonmanifold mesh, unsupported solid certification, ambiguous ray/sweep, unsupported shape/rotation, arithmetic, source/frame/quality mismatch, resource exhaustion, cancellation and rejected original residuals. Checked budgets cover input topology validation, node/index/stack/distance staging, all-face reference loops, root generation and bracket refinement before growth. Caller operations/iterations/storage/records provide the bounds; no silent truncation or arbitrary successful bracket is returned. Construction/refit/query cancellation leaves immutable previous values untouched.

## Verification and Change Impact
[TriangleMeshesQualification](../../../../../Verification/TriangleMeshesQualification/DESIGN.md) owns independent public fixtures comparing hierarchy point queries with a full-face reference, manufactured triangle face/edge/vertex distances and barycentrics, tetrahedral signed inside/outside, concave/open surfaces, deterministic seams/ties, high-speed translating sphere against face/edge/vertex, original positive/nonpositive TOI brackets and ray reconstruction. Failures must cover degenerate/nonmanifold mesh, uncertified solid inside, coplanar/near-boundary ray ambiguity, tangent CCD, rotations, stale refit/frame/quality, zero budget and cancellation. Historical selected eight Native SwiftTests and seven shared public cases passed against the former original2363 producer. Capacity recovery removed that old private evidence, so it cannot establish current source/object/link authority. AF37.1 requalified unchanged19 Swift and original fixture5 against a fresh immutable common2270 producer from committed f0325b0 plus independently frozen cohorts: all original8 Native tests and same public7 passed with exact source/object/module/dylib pre/post binding. No source, feature convention, physics, tolerance or work ledger repair was needed. Detailed fresh receipt and resource scope belong to the qualification owner. Matching ordinary WASM/Embedded remains unqualified. No complete signed-volume, tangency or rotating CCD claim is made. Supplier or feature/TOI convention changes require requalification of this owner and future consumers.
