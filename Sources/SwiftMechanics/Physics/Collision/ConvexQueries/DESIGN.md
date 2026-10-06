# Convex support-map queries

## Purpose and Scope
Parent: [Collision](../DESIGN.md). Children: none. Own AF34.8 source implementation of identified mechanical convex proxies, support maps, bounded GJK separation and EPA penetration for sphere, box, capsule, cylinder, cone and full-dimensional convex hull, including spherical margins. Initially admitted under a source-only freeze; the subsequently authorized selected Native proof is linked below. Other target qualification and full requirement closure remain separate. Half-space is unbounded and refused. Lower-dimensional source shapes are not admitted.

## Responsibilities and Boundaries
Adapt existing sphere/box `CollisionProxy` through the qualified `AnalyticCollisionQueries.support` public requirement. Own explicit new `ConvexShape`/`ConvexProxy` mechanical geometry without claiming CAD fidelity: the caller supplies collision representation provenance/quality, expected source revision, IDs, frame, pose, margin and resolution. Analytic local support maps own the new primitive conventions; hull support performs actual max-dot traversal over retained original vertices. Return an owned `ConvexCollisionWitness` with both points, original support features and barycentric weights. The existing `CollisionWitness` has one feature per body and cannot express a mixed simplex; this child does not reinterpret a mixture as an arbitrary feature or change that supplier. No discovery, sweep, persistence, contact law or runtime consumer is installed.

## Related Designs
| Design | Relationship | Contract used | Summary | Cautions |
|---|---|---|---|---|
| [Collision](../DESIGN.md) | parent | CL scope and framed conventions | Source-only handoff | No full CL-001/004 closure |
| [Shapes](../Shapes/DESIGN.md) | depends on | Immutable identities, revisions, margin, policy and work | Admission/accounting | Source revision authenticity stays with proxy owner |
| [Geometry](../Geometry/DESIGN.md) | depends on | Exact sphere/box support including margin | Qualified geometry supplier | No unqualified new supplier is consumed |
| [Core geometry](../../../Mathematics/Core/Geometry/DESIGN.md) | depends on | Finite vector arithmetic | Numerical algebra | Failures propagate |

## Architecture
```text
immutable proxies + policy + exclusive inout work
 -> shape/frame/quality admission
 -> public support pairs (A - B, original features)
 -> closest-simplex GJK -> certified separated/touching witness
                       -> strict interior tetrahedron -> EPA -> penetration witness
 -> original barycentric/point/normal/support-bound acceptance -> owned result
```

## Contracts and Invariants
Coordinates are SI in the pair's common frame. For separation, `n = -(pA-pB)/distance`; for penetration, `n` is the outward CSO face normal. In either case `pB-pA = n*signedSeparation` within policy length tolerance. Positive means separated, negative means penetration. A numerical touching result has zero separation, point balance within tolerance and an independent support plane within tolerance; an origin-containing simplex alone never certifies touching.

Capsule is a local Z segment with endpoints +/-halfLength, Minkowski-expanded by positive radius; halfLength zero is a sphere. Cylinder has positive radius and caps at +/-halfHeight. Cone has a base disk at -halfHeight and apex at +halfHeight; support selects the greater of the disk extremum and apex, with ties choosing the apex. Cylinder/capsule axial ties choose the positive endpoint/cap; a purely axial disk direction selects the disk center, which is a true support point. Hull is the convex hull of the exact supplied vertices, not a surface mesh; max-dot ties select the first original index. Hull admission checks rank three by a scale-normalized independent axis/plane/thickness construction, rejecting lower-dimensional or numerically uncertifiable input. Constructor work is budgeted; retained hull input is owned immutable CoW storage. Proxy margin expands every shape by a sphere in the support direction.

GJK minimizes over every affinely independent nonempty simplex face (at most fifteen), retaining nonnegative weights. Its upper bound is the norm of the reconstructed point; lower bound is the current original support plane (clipped to zero only for the distance bound). Accept only a length-tolerance primal/dual interval and original simplex KKT/weight/point/normal residual checks. Nonzero distance without a positive separating support plane does not certify separation.

EPA requires a nondegenerate tetrahedron with strictly positive origin barycentrics, verified origin reconstruction, and outward faces with positive distance. A bounded deterministic seed expansion samples directions in the first proxy's rotated basis; inability to certify an interior tetrahedron is `unresolvedInteriorSeed`, never a fabricated depth. EPA inserts a true support point, removes all visible faces and closes the oriented horizon. Every current vertex must remain behind every outward face, each directed edge must have one reversed partner, and the origin must remain strictly inside. The closest plane's projection must have nonnegative triangle barycentrics. Its distance is the lower penetration bound and the true support plane distance is the upper bound. Accept only when their interval, original witness balance, weight, simplex, support and unit-normal residuals pass. No iteration flag is sufficient.

Rank decisions use scale-normalized affine Gram systems and a dimensionless roundoff threshold (`64*Double.ulpOfOne`); this is a numerical refusal rule, not a physical convergence tolerance. A singular face is omitted in closest-face enumeration; an uncertifiable seed/face/polytope fails explicitly. Duplicate support fails unless the already checked geometric certificate accepts it. Approximation error is the finite sum of proxy provenance errors, separately recorded from numerical residuals. Pair, poses, margin, frame/source/geometry revisions and representation quality remain in the result.

Degeneracy diagnostics distinguish numerical touching and multiple EPA faces with equal minimum plane distance in the caller's numerical band. The latter reports the current polytope tie, not a proof of an exactly nonunique original-shape penetration direction. Signed separation bounds are `[positive support lower bound, witness distance]` for separation and `[-support upper depth, -face lower depth]` for penetration. Touching retains `[-max(0, supporting plane distance), reconstructed point norm]`. Its whole interval must fit the same length tolerance. Iteration counts in results are the cumulative caller-work counter, not an independent reset.

## Runtime Flows
One synchronous call owns all arrays. Admission precedes support evaluation. GJK and EPA check cancellation via charged work and iteration steps; inner face/subset/horizon checks also charge work. Any failure returns no witness. A strict seed may be found after a lower-dimensional GJK simplex; lower-dimensional intermediate simplices are not source geometry.

## State, Ownership, and Lifecycle
Services and returned records are immutable Sendable values. Array storage is local to a single operation; `inout CollisionWork` provides exclusive accounting. Original support records are copied into at most four owned weighted result records; no borrowed buffer, unsafe pointer, shared mutable state, global cache, callback or shutdown resource exists. Native, WASM and Embedded use identical source/storage/isolation contracts.

## Failure, Concurrency, and Constraints
`ConvexCollisionError` distinguishes supplier/frame/policy/cancellation/resource errors, unsupported shape, numerical degeneracy, unresolved interior seed, duplicate support, invalid polytope, rejected residual and nonconvergence. Work iteration exhaustion is nonconvergence; all other supplier accounting failures retain their typed cause. Caller budgets bound operations, live scalar workspace and record counts before growth. Conservative slots cover simultaneous vertex, face, horizon, staging, projection and result arrays; representation identity input storage remains caller owned. Each append/working copy checks capacity first. No guessed iteration/storage cap or silent fallback is installed.

## Verification and Change Impact
Later qualification must independently compare sphere/sphere and sphere/box analytic witnesses, oriented box/box distances and penetrations, primitive support extrema, capsule/cylinder/cone/hull pair fixtures, frame covariance, reversed pair symmetry, rounded margins, barycentric feature mixtures, coincident configurations, boundary contact and near-rank degeneracy. Failures must cover unsupported half-space, rank-deficient hulls, stale/mismatched frame/quality, zero budgets, cancellation, duplicates/nonconvergence and uncertifiable seeds. Exact WASM/Embedded compile/link/runtime checks remain pending; selected Native evidence is owned separately below. Changes to the support supplier, signed-gap convention or weighted witness contract invalidate this child's evidence and future consumers.

Algorithm sources: [Gilbert, Johnson and Keerthi (1988)](https://graphics.stanford.edu/courses/cs448b-00-winter/papers/gilbert.pdf), [van den Bergen, Proximity Queries and Penetration Depth Computation](https://graphics.stanford.edu/courses/cs468-01-fall/Papers/van-den-bergen.pdf). Active-face enumeration and full visible-horizon insertion are this implementation's choices; original support-bound and barycentric reconstruction proofs are retained. Concentric smooth shapes can converge slowly and remain subject to the caller's explicit nonconvergence budget.

### Selected Native Proof Owner
Root subsequently authorized [ConvexQueries qualification](../../../../../Verification/ConvexQueriesQualification/DESIGN.md). Its fixed ten Native tests and nine shared synchronous public groups passed on pinned Swift6.4.0/macOS arm64, with exact17 subject Swift bytes bound to the frozen2363 producer and original weighted support/point/bound oracles unchanged. The proof includes all six support-map shapes and selected GJK/EPA gaps/depths, covariance and instantaneous moved snapshots, touching/coincident boxes, identity/source/quality/work failures and awaited Native cancellation. The proof owner links exact compiler/link/runtime/signature/source receipts and defines its domain. No production change was required. This is not universal smooth-coincidence or ill-conditioned-hull coverage; duplicate-support, unresolved-interior-seed and invalid-polytope error outcomes remain unexercised. Ordinary/Embedded execution and root integration remain separate.

### Selected Registration

Selected original17 source bytes are registered after the linked [qualification owner](../../../../../Verification/ConvexQueriesQualification/DESIGN.md) passed actual Native ten cases, ordinary/Embedded nine shared witnesses with complete original131072-byte guards, and canonical49-case composition. That owner defines the proof domains, receipts and limitations. No production behavior or oracle was changed during qualification.
