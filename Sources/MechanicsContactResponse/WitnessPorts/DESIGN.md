# WitnessPorts

## Purpose and Scope
Parent [MechanicsContactResponse](../DESIGN.md); no children. Own framed witness-to-law/kinematic port adaptation for IM21's initial frictionless linear compliant domain.

## Responsibilities and Boundaries
Own current collision/model/frame/placement/history identity binding, geometric residual and relative point Jacobian. [ImplicitNormal](../ImplicitNormal/DESIGN.md) owns coupled physical equations/time approximation. No collision generation, constitutive parameter pairing or accepted-state mutation.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Parent](../DESIGN.md) | parent | IM21 scope | Closed initial handoff | Full CT family remains IM21 |
| [Collision](../../MechanicsCollision/Geometry/DESIGN.md) | depends on | Witness points/normal/poses/features | Geometric authority | Stale identities/poses fail |
| [Dynamics](../../MechanicsDynamics/RigidEquations/DESIGN.md) | depends on | Immutable M, actual snapshot/bias/original inertia | Mechanical authority | Only published rigid spatial domain |
| [ContactLaws](../../MechanicsContactLaws/Response/DESIGN.md) | depends on | ContactInput/linear normal response/trial history | Constitutive authority | Frictionless undamped noncohesive only |
| [Complementarity](../../MechanicsComplementarity/Solve/DESIGN.md) | depends on | Orthant SPD solve/original residual | Numerical supplier | Associated cone is not Coulomb |
| [Tests](../../../Tests/MechanicsContactResponseTests/DESIGN.md) | used by | Public requirements | Analytic coupling and failures | Native evidence local |

## Architecture
```text
current CollisionSnapshot + body-local collider placements + actual rigid snapshot
 -> bounded identity/revision/pose/witness/basis checks
 -> B-minus-A point Jacobian and prescribed drift
 -> immutable law/kinematic port -> coupled response
```

## Contracts and Invariants
CollisionSnapshot revision equals caller expected revision. Contact history body references and world-frame reference use the current tree revision; witness geometry revisions match history. Witness geometry equals the selected current proxies, including representations and revisions; proxies are at actual body pose composed with the declared collider-to-body placement. World-frame identity equals rigid snapshot world frame. Caller bindings select witnesses after upstream joint/user exclusions; this adapter does not infer or override those policies. Present proxy filters remain authoritative: both must be enabled, nontrigger, and mutually eligible under each layerBits/maskBits veto. Two distinct bodies/indices, nonduplicate contact coordinate IDs and matching basis.normal are required. Only regular exact analytic witnesses with zero approximationError are admitted. Original pointB-pointA=normal*separation and unit normal are independently checked against caller length/normal tolerances. Current normal direction is held fixed. Positive linear normal stiffness with zero damping, no friction/cohesion/rolling/spinning and compliantDampingOnly loss are admitted; selected unsupported parameters fail before mass response. At each point Jpoint=Jbody.linear+Jbody.angular cross offset; row=n dot(JpointB-JpointA), relative prescribed drift likewise. Angular velocity is world axes. Return retained immutable reference to binding/snapshot body kinematics and one row array; no per-inner-loop intermediate arrays. Body ID lookup is bounded and metadata-admitted before the public geometricColumns call.

## Runtime Flows
Capacity -> account identity UTF8 -> current proxies/history/model revision/frame -> actual collider poses -> original geometric/basis residual -> law admission -> point columns/drift -> immutable port.

## State, Ownership, and Lifecycle
Immutable Sendable values; local row workspace only. Caller owns NumericalWork exclusive inout. Metadata scans reserve two units before each borrowed UTF8 iterator advance/end check; canonical Unicode equality remains producer authority after admission. Compared geometry asset/provenance strings are included; no unbounded String.count/copy/map before budget checks. Fixed Core vector/pose operations use documented conservative scalar-operation bounds. No cache, unsafe pointer or target branch.

## Failure, Concurrency, and Constraints
Typed capacity/stale/layout/frame/pose/witness/unsupported-law/nonfinite/Core/Joint/numerical/cancel failures. Caller capacities bound contacts/colliders/bodies/velocities. Checked allocation products. Caller/Task cancellation checked during metadata and loops; partial port does not escape on failure.

## Verification and Change Impact
Current/stale geometry/body/frame/placement/basis/history and unsupported friction/damping/cohesion checks, long-key budget, offset-point virtual work. Contract changes invalidate coupled response and root exact-profile adapter probes.
