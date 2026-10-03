# PressureFields

## Purpose and Scope
Parent [ContactPatches](../DESIGN.md), no children. Initial admitted implementation domain: supplied affine Tet4 pressure/rigid-plane representation admission; behavioral/profile qualification pending. Full CT-008 remains open. This is not an equilibrated hydroelastic solve.

## Responsibilities and Boundaries
Own SI pressure input, representation pairing, identity/revision/material/source authority and logical work units. Pressure is supplied physical input in Pa, never inferred from a scalar stiffness. Consumer binds current model/geometry snapshots and owns evolution. Mesh validation belongs to Flexible; contact momentum response belongs to ContactResponse.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [Parent](../DESIGN.md) | parent | CT-008 ownership | Initial subset |
| [Flexible mesh](../../MechanicsFlexible/Mesh/DESIGN.md) | depends on | Validated Tet4/reference cells | No other elements |
| [Flexible state](../../MechanicsFlexible/Tetrahedra/DESIGN.md) | depends on | NodalState | Current positions/velocity must match |
| [ContactResponse](../../MechanicsContactResponse/ImplicitNormal/DESIGN.md) | semantic prerequisite | Opposite wrenches/prescribed power meaning | Not imported or executed; no accepted response claim |
| [PlanePatches](../PlanePatches/DESIGN.md) | used by | Admission/work/immutable inputs | Integration authority there |
| [Tests](../../../Tests/MechanicsContactPatchesTests/DESIGN.md) | used by | Real invalid/resource fixtures | Root owns exact profiles |

## Architecture
```text
validated mesh + current state + identified supplied pressure -> bounded identity/material/layout checks -> admitted rigid-plane pair
```

## Contracts and Invariants
Field stores frame, mesh/pressure revision, node IDs, pressure array, ordered material IDs and source provenance. Body and plane retain ModelReference identities; policy supplies expected model/mesh/pressure/plane revisions. All keys used in equality undergo budgeted borrowed UTF8 traversal before canonical comparison. Field source matches mesh source through budgeted source fields; material assignment is the actual mesh's ordered identifiers, not a guessed equivalent constitutive law. Pressure is finite nonnegative and bounded by caller maximumPressure. All quantities are SI Double: coordinates m, pressure Pa, area m², force N, moment N*m, power W, velocity m/s and angular velocity rad/s. The normal points from compliant toward rigid; forces are minus pressure normal on compliant and plus on rigid. Frame/origin are explicit common-coordinate identities. Body/model geometry binding remains caller authority, with revisions checked here.

## State, Ownership, and Lifecycle
Immutable Sendable input/result backing and operation-local exclusive inout NumericalWork on all targets. No shared mutable state, cache, lock, unsafe pointer, target-specific conformance or hidden fallback. Supplier validation/refinement retains its separate work ledger; integration does not invoke those services.

## Failure, Concurrency, and Constraints
Operations count declared scalar/logical work and fixed-size Core public primitive invocations (private arithmetic not relabeled). UTF8 iterator advancement/end check costs two units, canonical comparison one, charged before execution; no unbudgeted prewalk/conversion. Products/sums checked before storage. Caller capacities/determinant/area/residual tolerances own admission. Final publication and bounded cell/metadata checkpoints observe caller and Task cancellation. Missing field, incompatible pair, stale identity/revision/material/source, inverted cell, degenerate cut, nonfinite output and resource exhaustion are typed failures. Callable deferred pair branches have incomplete markers.

## Verification and Change Impact
Tests exercise missing/unsupported/stale/material/frame/current inversion, metadata and storage/operation/cancel boundaries. Changed field/binding/work contracts require PlanePatches and root consumer profiles to recheck.
