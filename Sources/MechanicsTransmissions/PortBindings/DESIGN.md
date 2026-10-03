# PortBindings

## Purpose and Scope
Parent [MechanicsTransmissions](../DESIGN.md); no children. Identified scalar joint/body/common-frame bindings and bounded local work/metadata admission. Full TR-001..011 ownership remains after this closed initial handoff.

## Responsibilities and Boundaries
Own the contract below; consumer owns constrained evolution, model/snapshot binding and dynamic reaction solve. Tooth/contact geometry belongs to IM47, not this ideal ratio or constitutive port.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [Parent](../DESIGN.md) | parent | IM13 ownership | Initial subset only |
| [Joints](../../MechanicsJoints/DESIGN.md) | depends on | Scalar manifold axes | Current supplied pose |
| [Model](../../MechanicsModel/DESIGN.md) | depends on | Entity identity | Canonical equality admitted by bytes |
| [Numerics](../../MechanicsNumerics/DESIGN.md) | depends on | NumericalWork | Logical units below |
| [Coordinates](../../MechanicsConstraints/CoordinateEquations/DESIGN.md) | depends on | Layout IDs/scales | Preserve chart dimensions |
| [Ideal](../IdealNetworks/DESIGN.md) | used by | Binding and axial map | No reaction inference |
| [Compliant](../CompliantPorts/DESIGN.md) | used by | Binding and axial map | Constitutive force is separate |
| [Tests](../../../Tests/MechanicsTransmissionsTests/DESIGN.md) | used by | Frame/budget proof | Root owns exact profiles |

## Architecture
```text
identified body/joint/coordinate + current pose -> bounded admission -> actual axis -> axial wrench + scalar power
```

## Contracts and Invariants
Each port binds one actual revolute/prismatic JointManifold, a coordinate index and UInt64 coordinate ID, body/joint/frame EntityIDs, layout/model revision, and caller-supplied joint-to-common-frame pose. The rotated actual joint axis sets signed coordinate convention. Common frame IDs are validated with budgeted borrowed UTF8 traversal before canonical equality. This current axial port map uses the supplied pose/axis/point of application only; the consumer must bind them to the actual model/snapshot. No bearing reaction or omitted tooth geometry is inferred. Rotary effort maps to an axial couple; linear effort maps to force at supplied origin plus origin moment. All reported power is conjugate scalar port power in the declared coordinate chart. Supplied poses provide wrench components, not body twists or prescribed reference drift; the consumer must supply those for actual-body power. Same immutable values, Sendable and local exclusive NumericalWork on all targets.

## Runtime Flows
Admission precedes bounded traversal/allocation. Local non-inlined phases retain fixed stack boundaries. Supplier failure halts once; no retry/substitution. Final cancellation check precedes publication.

## State, Ownership, and Lifecycle
Immutable Sendable binding/output records and operation-local exclusive inout NumericalWork on every target. Caller arrays and string backing retain value ownership; no shared mutable state or unsafe pointers. Mapping allocates its owned output once after admitting 64 scalar-equivalent storage slots per port (covering fixed record fields). No per-inner-loop intermediate arrays.

## Failure, Concurrency, and Constraints
This component is the authority for shared work units: NumericalWork operations count declared scalar arithmetic/logical comparisons, plus two units before every borrowed UTF8 iterator advance/end check and one admitted canonical EntityID comparison. Admission traverses both keys before equality; no unbudgeted key count/prewalk/conversion. Fixed-size Core vector/pose calls count one public primitive invocation, not their private arithmetic. Consumers retain actual supplier work in a distinct constraintWork ledger; failed supplier consumption has its supplier's availability, and failure stops without retry. IdealNetworks owns the assembly-failure completeness flag; direct scalar-port failures retain their distinct constraint cause. requireStorage describes operation peak scalar-equivalent slots, not bytes or cumulative allocations. Caller capacities/revisions/tolerances and checked products/sums control storage. Cancellation is checked at admission, metadata traversal, bounded phase/port boundaries and final publication; Task cancellation also precedes charges. Invalid layout/unit/frame/geometry, unsupported scalar domain, nonfinite results, work/storage exhaustion and cancellation are typed failures. No target-specific isolation or backend branch.

## Verification and Change Impact
Frame mismatch, axis reversal, rack application-origin moment, stale layout/model binding, long-key work exhaustion, storage/capacity and cancellation tests in the test owner. Binding/map changes affect both sibling consumers and root exact profiles.
