# Deforming Contact Behavioral Proof

## Purpose and Scope
Own actual geometry/force/history fixtures for [MechanicsDeformingContact](../../Sources/MechanicsDeformingContact/DESIGN.md). No children.

## Responsibilities and Boundaries
Independent geometric, moment and virtual-work oracles prove selected domains only. Full cloth/cable/CCD/dynamic evolution remain unqualified. Root owns commands/registered graph/profile proof.

## Related Designs
[MaterialGeometry](../../Sources/MechanicsDeformingContact/MaterialGeometry/DESIGN.md), [WitnessForces](../../Sources/MechanicsDeformingContact/WitnessForces/DESIGN.md), [ContactTransactions](../../Sources/MechanicsDeformingContact/ContactTransactions/DESIGN.md) own production contracts.

## Architecture
```text
actual validated Tet4 + actual nodal deformation -> real selected geometry/law paths -> independent analytic residuals
```

## Contracts and Invariants
Fixtures retain input snapshots/history. Geometry tests check volume-face topology/material points; force tests compute physical sums and central directional work independently; transaction tests compare accepted prefixes. No shared mutable resources.

## Verification and Change Impact
ContactPublicationTests checks actual delegated initial-history cancellation and current-policy direct material-point admission. ContactCancellationOwner has identical Mutex<Bool> storage, withLock read/mutation and instance lifetime across targets; callback runs outside the lock. The fixture requires the corresponding toolchain/platform availability. Native execution is not generalized to concurrent WASM runtime proof.
No tests have run before root registration. Proof requires actual required public methods, including typed invalid/cancel/capacity/supplier failures; selected exact profiles remain root-owned.
