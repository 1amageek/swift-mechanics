# ContactPatches component

## Purpose and Scope
Parent: [responsibility owner](../DESIGN.md). IM22 owns CT-008 in [SPEC](../../../../SPEC.md): distributed/hydroelastic pressure representations, contact patches and integrated wrenches. Children: [PressureFields](PressureFields/DESIGN.md), [PlanePatches](PlanePatches/DESIGN.md). Initial supplied-pressure Tet4/rigid-plane source is fixed after coherent review; nine Native behavioral cases and selected Native/ordinary-WASM/Embedded-WASM public execution passed. Full CT-008 ownership persists; supplied pressure does not qualify equilibrated hydroelastic contact.

## Responsibilities and Boundaries
The implementation owner owns child directories under Sources/SwiftMechanics/Physics/ContactPatches and Tests/MechanicsContactPatchesTests. Root owns this index, Package.swift, shared probes, progress and commits. Patch pressure, representation-pair admission, integration and independent force/moment/refinement evidence belong here. Flexible discretization, collision witnesses, constitutive laws and rigid response remain with their suppliers. Accepted trajectory and rigid/flexible coupling belong to their consuming work items.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Responsibility owner](../DESIGN.md) | parent | Dispatch and composition | Exclusive source/test ownership | IM48 owns full integration |
| [Flexible](../Flexible/DESIGN.md) | depends on | Verified Tet4 geometry, nodal layout and assembly | Material/discretization authority | Other elements and evolving flexible surfaces are unqualified |
| [ContactResponse](../ContactResponse/DESIGN.md) | depends on | Identified normal ports and physical residual meaning | Contact/mass coupling authority | Frictionless linear endpoint response is not a pressure-field solver |
| [ContactLaws](../ContactLaws/DESIGN.md) | coordinates with | Explicit material-pair and pressure-law domains | Constitutive authority | Scalar stiffness cannot silently become pressure modulus |

## Architecture
```text
validated representations + identified current pressure/geometry domain
 -> bounded patch and quadrature admission
 -> original pressure + integrated framed force/moment
 -> independent resultant, work and refinement acceptance
```

## Contracts and Invariants
Read the actual prerequisite public operations and implementation paths before fixing child contracts. Explicitly identify compliant/rigid representation requirements, SI pressure/area/force units, frame/origin, geometry/material revisions, pressure law and supported pairings. Missing pressure fields or unsupported pairings fail instead of becoming zero pressure. Integration must preserve force, moment and power semantics and independently reject invalid/inverted geometry or nonfinite results. Full CT-008 ownership remains after any qualified initial subset.

## State, Ownership, and Lifecycle
Immutable representation/patch results and exclusive bounded work own their backing storage. Current geometry and revisions determine validity; cache ownership and invalidation must be explicit if introduced. Shared mutable state must preserve the same isolation and Sendable contract on Native/WASM/Embedded. Supplier callbacks run outside control locks.

## Failure, Concurrency, and Constraints
Missing fields, incompatible units/frames/materials, stale geometry, invalid patch, nonconvergence, unsupported domain, cancellation and resource exhaustion are typed failures. Admit counts and checked storage products before materialization. Supplier work is separate; unavailable failed work is explicit and cannot authorize retry. Callable deferred branches carry incomplete implementation markers.

## Verification and Change Impact
Tests/MechanicsContactPatchesTests owns actual admitted representation pairing, independently loaded pressure/resultant/moment, refinement and invalid/resource/cancellation tests. Root owns selected exact-profile public execution after source freeze. Child design must identify its test owner and independent oracle before implementation. Contract changes require affected IM23/IM27/IM39 consumers to recheck their assumptions; no full distributed-contact claim precedes actual CT-008 evidence.

### Consolidation contract
This directory is a component inside the SwiftMechanics module, not a separate SwiftPM target. Its existing public behavior and exact-profile evidence remain its contract authority. Cross-component access uses the documented contracts; internal visibility alone does not grant admission or publication authority. Source relocation requires integrated behavioral requalification.
