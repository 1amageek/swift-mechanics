# Beam component tests

## Purpose and Scope
Parent [Beams](../../../Sources/SwiftMechanics/Physics/Flexible/Beams/DESIGN.md). Own element operator evidence, no children.

## Responsibilities and Boundaries
Actual assembly is compared to integrated Hermite physical energies; structural spectra belong to StructuralAnalysis tests.

## Related Designs
Uses parent Beams numerical and physical contracts. Root owns manifest/profile probes.

## Architecture
```text
real uniform beam -> public assembly -> independent energy/mass oracle
```

## Contracts and Invariants
Bending quadratic field energy EI L kappa^2/2, constant-velocity mass rho A L, uniform-slope geometric action L theta^2 and damping alpha M+beta K0.

## State, Ownership, and Lifecycle
Only immutable inputs and per-test work, no shared mutable state.

## Verification and Change Impact
Timeout focused tests after root registration; invalid geometry/storage/cancel must fail. Analysis tests separately own physical frequency/buckling refinement.
