# SwiftMechanicsCAD module

## Purpose and Scope
Parent [companion package](../../DESIGN.md); children [GeometryAdmission](GeometryAdmission/DESIGN.md) and [GearBindings](GearBindings/DESIGN.md), plus the AF30 [GearReinitialization](GearReinitialization/DESIGN.md) responsibility. Owns exact geometry-source admission, occurrence-bound queries and explicit gear-to-shaft association.

## Responsibilities and Boundaries
Consume CAD public records and builtin evaluation, return source-associated mechanics points/directions and original CAD query values. Validate explicit gear-to-shaft association and delegate transmission compilation and motion/load equations to the original mechanics owners. Caller owns body/frame/occurrence identity, placement, inertia and material selection. The AF30 explicit gear reinitialization coordinator delegates physical admission and atomic replacement to the original mechanics owners. This module supplies neither a CAD kernel nor a dynamics, contact-proxy, FEM, transmission-law or compatible-state migration algorithm.

## Related Designs
| Design | Relationship | Contract used | Summary | Caution |
|---|---|---|---|---|
| [Package](../../DESIGN.md) | parent | Independent dependency graph | Optional package composition | Development companion only |
| [GeometryAdmission](GeometryAdmission/DESIGN.md) | child | Sealed exact snapshot and strict query association | Original source authority | Stable CAD selection alone does not reject edits |
| [GearBindings](GearBindings/DESIGN.md) | child | Original involute witness and explicit shaft association | CAD gear parameters bind to admitted mechanics | Segregated gear-query protocol; source gates precede original feature resolution |
| [Tests](../../Tests/SwiftMechanicsCADTests/DESIGN.md) | used by | Original provider behavior | Public caller tests | No internal CAD authority |

## Architecture
```text
CADGeometryAdmitting -> original DocumentEvaluator -> sealed CADGeometryAdmission
CADGeometryQuerying -> source gate -> public CAD query -> occurrence-frame witness
CADInvoluteGearQuerying -> source gate -> original feature resolution -> sealed gear witness
gear witness + explicit shaft request -> GearBindings -> original transmission compiler
```

## Contracts and Invariants
Public operations use focused protocols, immutable values and typed failures. One issuer file seals snapshot construction. All mutable work is exclusively borrowed operation-local state; no shared cache, unchecked Sendable, target-specific isolation or hidden registry exists. The source pin is exact and immutable.

## Verification and Change Impact
Changes to source association or coordinate conversion require GeometryAdmission behavioral tests and root public composition. Exact moments require a future CAD-owned public integration contract; this module currently refuses that callable path explicitly.

AF29 GearBindings implementation is owned by admission_authority after this shared registration. Its child contract owns selected ideal external spur support and explicit refusal of other requested fidelities. Root owns registration, public integration and commits; the owner uses an immutable baseline with only its authorized overlay for independent proof.

AF28 module source is frozen and its selected public contract passed the [whole companion Native tests](../../Tests/SwiftMechanicsCADTests/DESIGN.md#executed-af28-native-evidence). Root's external public composition remains the direct upper proof owner.

## AF30 explicit edited-gear reinitialization

Admission_authority exclusively owns GearReinitialization and its test child. Original GeometryAdmission, GearBindings, CAD and core providers remain read-only. The selected operation re-admits the edited document, actually compiles a caller-declared fresh spatial fixed-root two-scalar-shaft descriptor, binds original ideal external spur gears, proves original constrained cold q/v/a/time and delegates whole-checkpoint model replacement to Runtime. Caller inertia is explicit; no exact CAD moments are claimed. CAD recipe and reset integration records must be source/model/time/sequence-bound before publication; unknown contributors cannot be dropped. The compatible migration branch is an explicit marked refusal until its physical/lifecycle proof exists. Child contracts precede Swift and own exact APIs/lifetime/failures. Root owns parent registration, immutable proof dispatch and commits.
