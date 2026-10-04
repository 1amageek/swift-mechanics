# SwiftMechanicsCAD module

## Purpose and Scope
Parent [companion package](../../DESIGN.md); child [GeometryAdmission](GeometryAdmission/DESIGN.md). Owns one selected public module for exact geometry-source admission and occurrence-bound queries.

## Responsibilities and Boundaries
Consume CAD public records and builtin evaluation, return source-associated mechanics points/directions and original CAD query values. Caller owns body/frame/occurrence identity, placement and material selection. This module supplies neither a CAD kernel nor a dynamics, contact-proxy, FEM, transmission-law or migration algorithm.

## Related Designs
| Design | Relationship | Contract used | Summary | Caution |
|---|---|---|---|---|
| [Package](../../DESIGN.md) | parent | Independent dependency graph | Optional package composition | Development companion only |
| [GeometryAdmission](GeometryAdmission/DESIGN.md) | child | Sealed exact snapshot and strict query association | Original source authority | Stable CAD selection alone does not reject edits |
| [Tests](../../Tests/SwiftMechanicsCADTests/DESIGN.md) | used by | Original provider behavior | Public caller tests | No internal CAD authority |

## Architecture
```text
CADGeometryAdmitting -> original DocumentEvaluator -> sealed CADGeometryAdmission
CADGeometryQuerying -> source gate -> public CAD query -> occurrence-frame witness
```

## Contracts and Invariants
Public operations use focused protocols, immutable values and typed failures. One issuer file seals snapshot construction. All mutable work is exclusively borrowed operation-local state; no shared cache, unchecked Sendable, target-specific isolation or hidden registry exists. The source pin is exact and immutable.

## Verification and Change Impact
Changes to source association or coordinate conversion require GeometryAdmission behavioral tests and root public composition. Exact moments require a future CAD-owned public integration contract; this module currently refuses that callable path explicitly.

AF28 module source is frozen and its selected public contract passed the [whole companion Native tests](../../Tests/SwiftMechanicsCADTests/DESIGN.md#executed-af28-native-evidence). Root's external public composition remains the direct upper proof owner.
