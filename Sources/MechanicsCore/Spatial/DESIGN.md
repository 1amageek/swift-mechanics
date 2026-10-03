# Spatial
## Purpose and Scope
Parent: [MechanicsCore](../DESIGN.md). Children: none. Own rigid frame maps, origin-referenced motion/wrench transformation and inertia change-of-frame/parallel-axis algebra.
## Responsibilities and Boundaries
Transform X_AB maps B coordinates to A: p_A = R_AB p_B + t_AB. A motion is ordered angular then linear, and defines a velocity field v(p) = linear + angular cross p. It is not automatically the COM velocity. Wrench torque is about the represented frame origin. Actual body IDs, COM data and physical inertia validity belong to model consumers.
## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Core](../DESIGN.md) | parent | Finite immutable spatial values | Frame and power contracts | Application must supply frame identities |
| [Geometry](../Geometry/DESIGN.md) | depends on | Vector3, Matrix3, UnitQuaternion | Rotation/translation algebra | Unit rotation is guaranteed by its owner |
## Architecture
```text
RigidTransform -> motion adjoint / wrench dual -> invariant wrench-motion power
InertiaTransformer -> R I R^T / I + m ((r dot r) Identity - r r^T)
```
## Contracts and Invariants
Motion mapping: omega_A = R omega_B; linear_A = R linear_B + t cross omega_A. Wrench mapping: force_A = R force_B; torque_A = R torque_B + t cross force_A. Power is torque dot angular + force dot linear and is invariant under these paired maps. Composition means destination-from-intermediate composed with intermediate-from-source. All results preserve finite-value failure semantics. Parallel-axis mass must be finite/nonnegative; tensor realizability is checked by the model owner, not invented here.
## Verification and Change Impact
Tests/MechanicsCoreTests/SpatialTests.swift owns independent point/frame composition, origin moment, power, rotated and shifted inertia fixtures. Sources/CoreVerification invokes real protocol requirements. Changes affect joint reactions, dynamics, loads, CAD binding and sensor interpretation.
