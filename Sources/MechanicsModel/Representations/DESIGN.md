# Representations

## Purpose and Scope
Own independent geometric, display, collision and inertial representation/provenance records (MD-005). Parent: [MechanicsModel](../DESIGN.md). No children.

## Responsibilities and Boundaries
Geometry references are opaque assets with explicit source identity/revision and exact versus bounded approximation status. Physics consumers select inertia and collision records independently of display assets. Asset resolution, shape queries, CAD integration and meshing belong to downstream adapters.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Model](../DESIGN.md) | parent | Composition | Registers records | No asset existence claim |
| [Identity](../Identity/DESIGN.md) | depends on | Immutable IDs | Distinct occurrence IDs | Shared source is allowed |
| [Inertia](../Inertia/DESIGN.md) | depends on | Valid mass properties | Separate physical authority | Display edits never derive inertia |

## Architecture
```text
SourceProvenance -> GeometryRepresentation(kind, asset, quality)
                -> InertialRepresentation(properties)
BodyRepresentations -> geometry / display / collision (independent optional slots)
```

## Contracts and Invariants
Slots enforce their representation role and fail if mixed. Source keys and asset keys are nonempty; revisions are immutable UInt64. Approximation deviation is a finite nonnegative geometric distance in meters. Inertial quality is explicitly exact or carries maximum absolute mass (kg), COM (m) and tensor element (kg m^2) errors; negative/nonfinite bounds fail. Inertia values are kg, m and kg m^2 in the body frame. MassPropertyOrigin retains compound overlap policy independently of source identity. Source identity is distinct from mechanical occurrence identity. Missing slots remain nil; requiring one yields a typed missingRepresentation failure. Values own all storage with no shared mutable state.

## Verification and Change Impact
Test owner: [MechanicsModelTests](../../../Tests/MechanicsModelTests/DESIGN.md).

RecordTests replaces display geometry and proves unchanged inertia/collision; it verifies role mismatch, missing requirements and invalid approximation metadata. Compiler/collision/CAD consumers recheck changes to roles or provenance.
