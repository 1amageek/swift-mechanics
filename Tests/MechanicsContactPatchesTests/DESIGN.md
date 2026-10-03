# MechanicsContactPatchesTests

## Purpose and Scope
Parent [package](../../DESIGN.md), no children. Test owner for [PressureFields](../../Sources/MechanicsContactPatches/PressureFields/DESIGN.md) and [PlanePatches](../../Sources/MechanicsContactPatches/PlanePatches/DESIGN.md).

## Responsibilities and Boundaries
Independent analytic pressure/area/resultant/moment and nodal/prescribed work, actual Flexible validation/refinement, and typed failure/resources. Root owns exact profile composition; no equilibrated hydroelastic qualification.

## Related Designs
The linked production children own input, geometry, integration and resource authority; tests consume required public service operations.

## Architecture
```text
real validated Tet + analytic pressure/plane -> public patch service -> independent integrals and typed failure evidence
```

## Contracts and Invariants
Independent analytic loaded face-cut and affine refinement integrals reject averaged-pressure moment errors. Current geometry and pressure assignments stay immutable.

## State, Ownership, and Lifecycle
Local workspace, input and work per test; no shared mutable resources.

## Failure, Concurrency, and Constraints
Root schedules timeout-qualified tests after registration/source freeze. No independent build.

## Verification and Change Impact
Each physical/failure path is tested once at stable boundaries; exact profiles remain root-owned.
