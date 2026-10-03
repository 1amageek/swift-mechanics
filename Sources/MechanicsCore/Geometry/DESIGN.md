# Geometry
## Purpose and Scope
Parent: [MechanicsCore](../DESIGN.md). Children: none. Own finite Vector3/Matrix3, normalized UnitQuaternion, and four-coordinate quaternion tangent rates.
## Responsibilities and Boundaries
This is spatial algebra, not CAD geometry. Matrices use fixed row-major fields. Vectors are coordinates without embedded frame identity; the consuming frame/model contract supplies identity. Inertia physical validity is a model responsibility.
## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Core](../DESIGN.md) | parent | Float64 finite immutable values | Mathematical foundation | Coordinates and angular rates cannot be interchanged |
| [Diagnostics](../Diagnostics/DESIGN.md) | depends on | CoreError / NumericalTolerance | Invalid, singular, overflow and domain failure | Matrix inversion singularity tolerance is caller-selected |
| [C math](../../CMechanicsMath/DESIGN.md) | depends on | sin/cos/atan2/hypot | Scalar transcendental computation | Must link/run on each claimed profile |
## Architecture
```text
Vector3 + Matrix3 -> UnitQuaternion / QuaternionRate -> Spatial transforms
```
## Contracts and Invariants
All stored fields are finite. Quaternion initialization normalizes finite nonzero input by scale; q and -q encode the same orientation. Axis construction rejects a zero axis. Product order is active Hamilton composition. Body angular velocity integrates by right multiplication; world angular velocity by left multiplication. q_dot = 0.5 q * (0, omega_body), with q dimension 4 and omega dimension 3. rotationVector selects the principal, sign-equivalent rotation; pi ambiguity uses a canonical quaternion sign. Matrix-to-quaternion conversion requires positive determinant and caller-accepted orthogonality/determinant residuals, then projects to a unit quaternion explicitly. No general affine transform is treated as rigid.

Matrix inversion scales input before evaluating determinant/cofactors; abs(scaled determinant) must exceed the supplied nonnegative relative tolerance. This is a determinant-domain criterion, not a condition-number guarantee. Near-singular problems can be rejected according to that declared policy. Operations that exceed finite machine range fail explicitly. Arithmetic uses no dynamically sized buffers.
## Verification and Change Impact
Tests/MechanicsCoreTests/GeometryTests.swift owns analytic axis rotations, all matrix conversion branches, inverse/residual, q-sign/rate/integration, degenerate and overflow paths. Sources/CoreVerification exercises protocol operations on actual targets. Convention/layout changes invalidate Spatial and all downstream kinematics/dynamics assumptions.
