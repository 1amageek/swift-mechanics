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
| [C math](../../ScalarFunctions/DESIGN.md) | depends on | sin/cos/atan2/hypot | Scalar transcendental computation | Must link/run on each claimed profile |
## Architecture
```text
Vector3 + Matrix3 -> UnitQuaternion / QuaternionRate -> Spatial transforms
```
## Contracts and Invariants
All stored fields are finite. Quaternion initialization normalizes finite nonzero input by scale; q and -q encode the same orientation. Axis construction rejects a zero axis. Product order is active Hamilton composition. Body angular velocity integrates by right multiplication; world angular velocity by left multiplication. q_dot = 0.5 q * (0, omega_body), with q dimension 4 and omega dimension 3. rotationVector selects the principal, sign-equivalent rotation; pi ambiguity uses a canonical quaternion sign. Matrix-to-quaternion conversion requires positive determinant and caller-accepted orthogonality/determinant residuals, then projects to a unit quaternion explicitly. No general affine transform is treated as rigid.

`UnitQuaternion.init(unitW:x:y:z:)` restores already-unit finite components exactly, including sign and signed-zero bits. It never normalizes or chooses a quaternion hemisphere. Squared norm must differ from one by at most 16 Double ulps at one; this fixed rounding envelope belongs to the unit representation, not a configurable physical tolerance. Finite non-unit input yields `CoreError.nonUnitQuaternion`; nonfinite input yields `nonFiniteInput`. Checkpoint consumers validate through this public geometry contract rather than invoking the unchecked internal initializer. Existing normalizing constructors retain their behavior.

Matrix inversion scales input before evaluating determinant/cofactors; abs(scaled determinant) must exceed the supplied nonnegative relative tolerance. This is a determinant-domain criterion, not a condition-number guarantee. Near-singular problems can be rejected according to that declared policy. Operations that exceed finite machine range fail explicitly. Arithmetic uses no dynamically sized buffers.
## Verification and Change Impact
Tests/MechanicsCoreTests/GeometryTests.swift owns analytic axis rotations, all matrix conversion branches, inverse/residual, q-sign/rate/integration, degenerate and overflow paths. Verification/CoreVerification exercises protocol operations on actual targets. Convention/layout changes invalidate Spatial and all downstream kinematics/dynamics assumptions.

Tests/MechanicsCoreTests/QuaternionRestorationTests.swift owns exact raw-component restoration from actual normalizing/axis/product/integration constructors, signed-zero and sign preservation, and rejection of zero/non-unit/extreme/nonfinite data. Native qualification must precede Runtime moving-anchor use; selected target execution remains system-owned.

AF23 registered Native proof passed both restoration tests and four existing Core geometry tests with exit zero; `.build/af23-core-native.log` owns the exact run. This qualifies the new restoration path only on Native pending system-owned target execution.
