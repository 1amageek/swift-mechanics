# Collision proxy records

## Purpose and Scope
Parent: [MechanicsCollision](../DESIGN.md). Owns initial analytic sphere, rigid box and local z<=0 half-space proxies, immutable identity/provenance/quality, SI dimensions and bounded operation policies. Children: none. Other CL-001/002 primitives, hulls, compounds, meshes and heightfields remain deferred.

## Responsibilities and Boundaries
CollisionProxy requires an explicit Model collisionGeometry representation; display/inertial geometry is never substituted. Pose maps shape-local coordinates to the identified query frame. Geometry identity includes collider/body/frame, frame and geometry revisions, shape, margin, representation and resolution; pose is excluded to permit value-owned sliding continuation. Revision metadata and the exact shape snapshot prevent stale reuse. Caller owns source revision authenticity and advances frame revision when coordinate meaning changes.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Module](../DESIGN.md) | parent | Initial producer handoff | Composition | Full CL remains incomplete |
| [Model representations](../../MechanicsModel/Representations/DESIGN.md) | depends on | Explicit collision representation, quality and provenance | Authority | Missing collision data fails |
| [Core geometry](../../MechanicsCore/Geometry/DESIGN.md) | depends on | Finite values and unit rotations | SI geometry | Arithmetic failure propagates |
| [Geometry](../Geometry/DESIGN.md) | used by | Proxy/domain records | Analytic queries | Unsupported pair is explicit |
| [Discovery](../Discovery/DESIGN.md) | used by | Bounds/filter records | Candidates | No shape substitution |
| [Persistence](../Persistence/DESIGN.md) | used by | Pose-independent exact identity | Manifold/trigger continuation | Source edits invalidate |
| [Sweep](../Sweep/DESIGN.md) | used by | Immutable endpoints | Translation CCD | Rotation changes fail |

## Architecture
```text
Model collision representation + shape + source/frame revisions + pose + margin
 -> immutable CollisionProxy -> query / candidate / continuation / sweep services
```

## Contracts and Invariants
Sphere radius and box half extents are finite positive meters. Half-space solid is local z<=0; outward normal is transformed +Z. Nonnegative margin is a Minkowski expansion; witness point A moves +normal*marginA and B moves -normal*marginB, separation decreases by their sum. Approximation bound is Model maximumDeviationMeters (exact means zero); pair error sums bounds. Query policy rejects a proxy above requested maximum source deviation, and records preserve contact resolution independently of display LOD. Analytic resolution is explicit; sampled resolution requires finite positive spacing.

All records are immutable Sendable. CollisionBudget supplies scalar-slot storage, operation, iteration and output-record caps; no guessed cap/default is installed. Work uses checked integer arithmetic, observes cancellation and rejects arithmetic overflow. Scalar slots cover numeric work/data arrays conservatively; external identity strings/representation storage remain caller-owned input. Service-local outputs are bounded before allocation/append.

## State, Ownership, and Lifecycle
Inputs and outputs are caller-owned values. No global state, mutable reference, pointer, asynchronous resource or target-specific storage/conformance is present. History owners decide whether to accept returned trial continuation values.

## Failure, Concurrency, and Constraints
Invalid dimensions/kinds/metadata/policy, unsupported geometry, stale identities, finite-arithmetic failure, cancellation and exhausted resources are typed failures. No truncated successful result or placeholder witness is returned. Unsupported shapes are absent API declarations; explicit pair/sweep capability failures remain callable complete rejection paths.

## Verification and Change Impact
[Tests](../../../Tests/MechanicsCollisionTests) exercise real transformed proxy geometry, margin/quality, display independence, invalid shape/frame and storage/capacity. Changes recheck all children and future IM21/23/39 consumers. Root owns exact Native/WASM/Embedded composition; initial evidence does not establish all CL domains.
