# Analysis

## Purpose and Scope
Read-only physical queries, sensitivities, equilibrium and optimization certificates. Parent: [SwiftMechanics](../DESIGN.md). Children: [Equilibrium](Equilibrium/DESIGN.md), [StructuralAnalysis](StructuralAnalysis/DESIGN.md), [Derivatives](Derivatives/DESIGN.md), [Observations](Observations/DESIGN.md), [Optimization](Optimization/DESIGN.md).

## Responsibilities and Boundaries
Read-only physical queries, sensitivities, equilibrium and optimization certificates. Child contracts own each operation and failure domain. Consumers depend on published protocols and admitted immutable records. Internal visibility is not permission to bypass validation.

## Related Designs
| Design | Relationship | Contract used | Cautions |
|---|---|---|---|
| [SwiftMechanics](../DESIGN.md) | parent | Composition and dependency authority | Changed assumptions require parent requalification |
| [Equilibrium](Equilibrium/DESIGN.md) | child | Its documented assumption/guarantee | Preserve documented capability limits |
| [StructuralAnalysis](StructuralAnalysis/DESIGN.md) | child | Its documented assumption/guarantee | Preserve documented capability limits |
| [Derivatives](Derivatives/DESIGN.md) | child | Its documented assumption/guarantee | Preserve documented capability limits |
| [Observations](Observations/DESIGN.md) | child | Its documented assumption/guarantee | Preserve documented capability limits |
| [Optimization](Optimization/DESIGN.md) | child | Its documented assumption/guarantee | Preserve documented capability limits |

## Architecture
```mermaid
flowchart LR
  Inputs[Admitted inputs] --> Owner[Analysis]
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
