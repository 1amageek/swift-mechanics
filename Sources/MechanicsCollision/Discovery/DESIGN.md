# Conservative candidates and filtering

## Purpose and Scope
Parent: [MechanicsCollision](../DESIGN.md). Owns stateless exhaustive AABB candidate discovery with explicit filter precedence/capacity and scene ray/overlap query ordering. Children: none. Cached refit trees/spatial acceleration remain deferred; each invocation rebuilds bounds from its immutable current snapshot, so no stale hidden tree exists.

## Responsibilities and Boundaries
Sphere world bounds include radius+margin. Oriented box bounds use absolute rotated-axis extents plus margin. Floating arithmetic bounds round outward with nextDown/nextUp; half-space is unbounded, ensuring conservative pairing. Optional linear-displacement endpoint union is conservative for fixed orientation; caller supplies start/end proxies and rotation-changing swept bounds are unsupported. Discovery returns candidates, never a mechanical contact response.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Module](../DESIGN.md) | parent | CL-003/007/008 subset | Composition | Exhaustive O(n²) |
| [Shapes](../Shapes/DESIGN.md) | depends on | Immutable proxies/budget | Current snapshot | Duplicate/dangling IDs fail |
| [Geometry](../Geometry/DESIGN.md) | depends on | AABB, actual pair/ray/point queries | Candidates/query refinement | Unsupported candidate pair propagates |
| [Persistence](../Persistence/DESIGN.md) | used by | Deterministic candidate keys | Trigger refinement | Accepted runtime scheduling external |

## Architecture
```text
snapshot -> validate references/current frames -> outward AABBs -> exhaustive pairs
disabled -> layer/mask -> joint exclusion -> same-body policy -> pure bounded user policy
allowed overlapping bounds -> pair keys sorted by collider key
```

## Contracts and Invariants
Filter order is deterministic and early rejection never invokes later user policy. Joint exclusions must reference existing distinct collider IDs, irrespective of whether another filter would reject the pair. Self exclusion means same body ID. Custom service is Sendable, pure over immutable proxy inputs, receives remaining operations, reports actual positive bounded work and throws typed failure; arbitrary callback runtime must honor that contract. No callback failure becomes a filtered no-hit.

Input snapshots require distinct collider IDs and common frame identity/revision. Geometry/source snapshots remain exact; display LOD is not consulted. Candidate capacity exhaustion fails the entire call. Pairwise and query storage/operations use checked bounds and local arrays reserved within caller record caps. O(n²) discovery is bounded by explicit operations and cancellation per pair; no guessed object limit or truncation.

## State, Ownership, and Lifecycle
Scene/proxy/filter inputs and outputs are caller-owned values. No persistent broadphase state is retained. Exact immutable snapshots replace update/refit invalidation for this admitted implementation.

## Failure, Concurrency, and Constraints
Duplicate/dangling identities, invalid filter report, unsupported swept orientation/query, nonfinite bound, capacity/storage/work/cancel failures propagate. Unbounded plane bounds conservatively produce extra pairs; they do not miss finite contacts.

## Verification and Change Impact
[DiscoveryTests](../../../Tests/MechanicsCollisionTests/DiscoveryTests.swift) compares candidate pairs against independently exhaustive actual admitted intersections, including scale disparity and translation endpoint sweeps; enumerates filter precedence and invalid references; verifies deterministic query ties and capacity/cancellation. Frozen 1e-10 m+1e-11 relative SI tolerance. Changes recheck Persistence and future IM21/26/33 consumers.
