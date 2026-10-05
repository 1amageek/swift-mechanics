# SphereHydrostatics

## Purpose and Scope
Parent: [Loads](../DESIGN.md). Children: none. Owns selected FL-005 behavior for side task SL01.

## Responsibilities and Boundaries
Partially submerged sphere volume/centroid/force and translational potential in homogeneous fluid below a fixed plane. V=pi*r^3*t^2*(1-t/3), t=(r-d)/r clamped by explicit dry/full branches. Partial centroid offset=-r*(2-t)^2/(4*(1-t/3)); U=rho*g*pi*r^4*t^3*(4-t)/12. Full U=-rho*g*V*d. dF/dx=-rho*g*waterplaneArea*n*n^T.
Caller owns calibration, body/frame provenance and geometry. This stateless evaluator supplies mechanical load values, not CAD geometry admission or Runtime evolution. All quantities are SI Float64.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [Loads](../DESIGN.md) | parent | Load composition boundary | Full requirement family remains open |
| [Geometry](../../../Mathematics/Core/Geometry/DESIGN.md) | depends on | Checked Vector3/Matrix3 public operations | Overflow is explicit failure |
| [ForcePorts](../ForcePorts/DESIGN.md) | depends on | LoadWork, LoadError, FramedPointLoad, ForceParts | Retain cumulative work/cancel and force meanings |

## Architecture
```text
immutable SI inputs -> domain/work/storage admission -> analytic law
 -> framed force + derivatives + explicit work -> caller composition
```

## Contracts and Invariants
Public service is a Sendable protocol with a separate implementation. Inputs and results are immutable Sendable values. Invalid parameters, nonfinite arithmetic, outside calibration envelope, work/storage exhaustion and cancellation throw LoadError; no successful default or partial output. Vectors/matrices use published checked operations. Fixed-sized operations reserve logical scalar storage before construction; polar traversal charges each bounded entry. Storage budget excludes caller input and allocator/runtime overhead. Cancellation is checked before publication.

## State, Ownership, and Lifecycle
Only exclusively borrowed inout LoadWork is mutable. No shared reference state, callbacks other than existing cancellation, task/stream resources, pointers or target-specific synchronization.

## Verification and Change Impact
[Test owner](../../../../../Tests/MechanicsEnvironmentalLoadsTests/DESIGN.md) owns independent analytic values, finite-difference derivatives, energy/power/frame covariance, degenerate/domain/overflow and exact work/storage/cancellation failure cases. Native Swift 6.4.0 is the selected behavioral profile. Other platforms are unverified until exact compile/link/runtime proof. Existing suppliers remain unchanged; supplier changes invalidate dependent evidence.

### Public operation accounting

Each evaluation consumes 200 logical work units and reserves 64 logical scalar slots before numerical work. These fixed allowances bound this implementation; they are not wall-clock or allocator-total measurements. The existing cumulative LoadWork ledger and cancellation contract are unchanged. Dry response has zero true displaced volume and no buoyancy centroid. Full submersion uses the sphere center. A partial cap with unrepresentable positive volume fails outsideDomain rather than returning a fabricated centroid. Potential is referenced to dry contact with the fixed plane.

### Selected Native handoff (2026-10-05)

The actual canonical SwiftMechanics module and public protocol calls passed the same-named suite plus shared SideLoadIntegrationTests. The sole [test owner](../../../../../Tests/MechanicsEnvironmentalLoadsTests/DESIGN.md) records commands, execution profile and limits. Source review found immutable Sendable values and exclusively borrowed LoadWork, with no shared mutable storage or target-specific conformance. This qualifies this selected law on Native only; full requirement-family closure and accepted Runtime evolution are not claimed.
