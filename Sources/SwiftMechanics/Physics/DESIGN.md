# Physics

## Purpose and Scope
Physical laws, mechanical equation contributions and domain models; never owns accepted session publication. Parent: [SwiftMechanics](../DESIGN.md). Children: [Materials](Materials/DESIGN.md), [Loads](Loads/DESIGN.md), [Dynamics](Dynamics/DESIGN.md), [Flexible](Flexible/DESIGN.md), [Collision](Collision/DESIGN.md), [ContactLaws](ContactLaws/DESIGN.md), [ContactResponse](ContactResponse/DESIGN.md), [ContactPatches](ContactPatches/DESIGN.md), [DeformingContact](DeformingContact/DESIGN.md), [Constraints](Constraints/DESIGN.md), [Transmissions](Transmissions/DESIGN.md), [Actuation](Actuation/DESIGN.md), [Mechanisms](Mechanisms/DESIGN.md), [Fluids](Fluids/DESIGN.md), [Granular](Granular/DESIGN.md).

## Responsibilities and Boundaries
Physical laws, mechanical equation contributions and domain models; never owns accepted session publication. Child contracts own each operation and failure domain. Consumers depend on published protocols and admitted immutable records. Internal visibility is not permission to bypass validation.

## Related Designs
| Design | Relationship | Contract used | Cautions |
|---|---|---|---|
| [SwiftMechanics](../DESIGN.md) | parent | Composition and dependency authority | Changed assumptions require parent requalification |
| [Materials](Materials/DESIGN.md) | child | Its documented assumption/guarantee | Preserve documented capability limits |
| [Loads](Loads/DESIGN.md) | child | Its documented assumption/guarantee | Preserve documented capability limits |
| [Dynamics](Dynamics/DESIGN.md) | child | Its documented assumption/guarantee | Preserve documented capability limits |
| [Flexible](Flexible/DESIGN.md) | child | Its documented assumption/guarantee | Preserve documented capability limits |
| [Collision](Collision/DESIGN.md) | child | Its documented assumption/guarantee | Preserve documented capability limits |
| [ContactLaws](ContactLaws/DESIGN.md) | child | Its documented assumption/guarantee | Preserve documented capability limits |
| [ContactResponse](ContactResponse/DESIGN.md) | child | Its documented assumption/guarantee | Preserve documented capability limits |
| [ContactPatches](ContactPatches/DESIGN.md) | child | Its documented assumption/guarantee | Preserve documented capability limits |
| [DeformingContact](DeformingContact/DESIGN.md) | child | Its documented assumption/guarantee | Preserve documented capability limits |
| [Constraints](Constraints/DESIGN.md) | child | Its documented assumption/guarantee | Preserve documented capability limits |
| [Transmissions](Transmissions/DESIGN.md) | child | Its documented assumption/guarantee | Preserve documented capability limits |
| [Actuation](Actuation/DESIGN.md) | child | Its documented assumption/guarantee | Preserve documented capability limits |
| [Mechanisms](Mechanisms/DESIGN.md) | child | Its documented assumption/guarantee | Preserve documented capability limits |
| [Fluids](Fluids/DESIGN.md) | child | Its documented assumption/guarantee | Preserve documented capability limits |
| [Granular](Granular/DESIGN.md) | child | Its documented assumption/guarantee | Preserve documented capability limits |

## Architecture
```mermaid
flowchart LR
  Inputs[Admitted inputs] --> Owner[Physics]
  Owner --> Outputs[Checked outputs or typed failure]
```

## Contracts and Invariants
Preserve units, frames, stable identity, original residual acceptance and bounded caller policy. No partial result is published as success. Lower contracts retain their documented capability limits.

## State, Ownership, and Lifecycle
Immutable Sendable values are shared; mutable workspace belongs to the documented operation/session owner. Mutex or actor protection and Sendable requirements are identical on Native, WASM and Embedded. Borrowed data cannot outlive its retained owner. Declaration expansion occurs during model construction, not a simulation step.

## Failure, Concurrency, and Constraints
Invalid values, exhausted capacity, cancellation, incompatible model identity and unsupported domains propagate typed failures. Caller budgets bound the admitted operation; plain Swift result-builder loops materialize before lowering and require caller-side construction bounds. No silent alternate physical law is selected.

## Verification and Change Impact
Responsibility-specific Tests targets own child behavior. Package verification runs the actual public path on each declared fixed toolchain/SDK profile. Recheck affected upper consumers after a lower contract changes. Migration requires consolidated Native behavioral tests and matching WASM/Embedded execution; compile success alone is not qualification.

## Selected Vehicle Law Composition

[Vehicles](Vehicles/DESIGN.md) owns selected calibrated vehicle constitutive laws. Its TireLaws child is registered after complete1841-source Native behavioral verification; original WASM/Embedded qualification and complete vehicle assembly requirements remain open. Accepted-state dynamics authority stays with its existing owners.
